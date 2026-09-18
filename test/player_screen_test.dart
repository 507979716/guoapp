import 'dart:async';

import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class ScriptedPlayer extends PlatformPlayer {
  ScriptedPlayer() : super(configuration: const PlayerConfiguration());
  final opened = <Media>[];
  final played = <bool>[];
  bool disposed = false;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final media = playable as Media;
    opened.add(media);
    played.add(play);
    final failed = media.uri.contains('broken');
    state = state.copyWith(
      position: failed ? Duration.zero : media.start ?? Duration.zero,
      duration: failed ? Duration.zero : const Duration(minutes: 2),
      playing: play,
      buffering: false,
      width: failed ? 0 : 320,
      height: failed ? 0 : 180,
    );
    positionController.add(state.position);
    durationController.add(state.duration);
    playingController.add(play);
    if (failed) {
      fail();
    }
  }

  void fail() {
    errorController.add('synthetic network failure');
    errorController.add('synthetic decoder failure');
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(
      position: Duration.zero,
      duration: Duration.zero,
      playing: false,
      buffering: false,
      width: 0,
      height: 0,
    );
    positionController.add(Duration.zero);
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration duration) async {
    state = state.copyWith(position: duration);
    positionController.add(duration);
  }

  @override
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> playOrPause() async {
    state = state.copyWith(playing: !state.playing);
    playingController.add(state.playing);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

class RouteRepository extends FixtureRepository {
  int primaryCalls = 0;
  int fallbackCalls = 0;
  bool broken = false;
  bool deferFallback = false;
  final active = <String>{};
  Completer<PlaybackPlan>? pending;

  PlaybackPlan plan(bool alternate) {
    final session = 'route-${primaryCalls + fallbackCalls}';
    active.add(session);
    return PlaybackPlan(
      url: 'https://media.test/${broken ? 'broken' : 'working'}-$session.mp4',
      session: session,
      routeIndex: alternate ? 1 : 0,
      routeCount: 2,
      quality: 1080,
      qualities: const [1080, 720],
    );
  }

  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async {
    primaryCalls++;
    return plan(false);
  }

  @override
  Future<PlaybackPlan> fallback(PlaybackPlan current) async {
    fallbackCalls++;
    if (deferFallback) {
      pending = Completer<PlaybackPlan>();
      return pending!.future;
    }
    return plan(true);
  }

  @override
  Future<void> release(String session) async {
    active.remove(session);
  }
}

void main() {
  Future<void> settleOperations(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  Future<void> mount(
    WidgetTester tester,
    RouteRepository repository,
    ScriptedPlayer platform,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    final detail = await repository.detail(FixtureRepository.free);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: PlayerScreen(
          detail: detail,
          initialIndex: 0,
          initialPosition: 7,
          repository: repository,
          store: store,
          playerFactory: () => Player(platformPlayer: platform),
          videoBuilder: (controls) => controls,
        ),
      ),
    );
    await settleOperations(tester);
  }

  Future<void> unmount(WidgetTester tester, ScriptedPlayer player) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settleOperations(tester);
    expect(player.disposed, isTrue);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'duplicate errors switch once while keeping progress, rate and pause state',
    (tester) async {
      final repository = RouteRepository();
      final player = ScriptedPlayer();
      await mount(tester, repository, player);
      await tester.tap(find.byTooltip('播放倍速'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5x').last);
      await tester.pumpAndSettle();
      await player.seek(const Duration(seconds: 28));
      await tester.pump();
      await tester.tap(find.byTooltip('暂停'));
      await settleOperations(tester);
      player.fail();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleOperations(tester);
      expect(repository.fallbackCalls, 1);
      expect(repository.primaryCalls, 1);
      expect(player.opened.last.start, const Duration(seconds: 28));
      expect(player.state.rate, 1.5);
      expect(player.played.last, isFalse);
      expect(repository.active.length, 1);
      expect(find.text('暂时无法播放'), findsNothing);
      await unmount(tester, player);
      expect(repository.active, isEmpty);
    },
  );

  testWidgets(
    'recovery exhaustion releases sessions and manual retry keeps the saved position',
    (tester) async {
      final repository = RouteRepository()..broken = true;
      final player = ScriptedPlayer();
      await mount(tester, repository, player);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
        await settleOperations(tester);
      }
      expect(repository.primaryCalls, 2);
      expect(repository.fallbackCalls, 2);
      expect(find.text('暂时无法播放'), findsOneWidget);
      expect(repository.active, isEmpty);
      await tester.pump(const Duration(seconds: 25));
      expect(repository.primaryCalls + repository.fallbackCalls, 4);
      repository.broken = false;
      await tester.tap(find.text('重试播放'));
      await settleOperations(tester);
      expect(player.opened.last.start, const Duration(seconds: 7));
      expect(find.text('暂时无法播放'), findsNothing);
      await unmount(tester, player);
      expect(repository.active, isEmpty);
    },
  );

  testWidgets(
    'switching episodes ignores a delayed fallback and frees both old plans',
    (tester) async {
      final repository = RouteRepository()..deferFallback = true;
      final player = ScriptedPlayer();
      await mount(tester, repository, player);
      player.fail();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await settleOperations(tester);
      expect(repository.pending, isNotNull);
      await tester.tap(find.byKey(const ValueKey('play-episode-2')));
      await settleOperations(tester);
      final currentURL = player.opened.last.uri;
      final late = PlaybackPlan(
        url: 'https://media.test/late.mp4',
        session: 'late',
      );
      repository.active.add(late.session);
      repository.pending!.complete(late);
      await settleOperations(tester);
      expect(player.opened.last.uri, currentURL);
      expect(repository.active.length, 1);
      expect(repository.active, isNot(contains('late')));
      await unmount(tester, player);
      expect(repository.active, isEmpty);
    },
  );
}
