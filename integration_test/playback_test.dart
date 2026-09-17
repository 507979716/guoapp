import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/main.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fixtureBase = String.fromEnvironment('FIXTURE_BASE_URL');

class DeviceFixtureRepository implements AppRepository {
  final native = NativeRepository();
  final resolved = <int>[];
  final released = <String>[];
  static const drama = Drama(
    id: 'hongguo:700001',
    source: 'hongguo',
    title: '设备播放验证',
    episodes: 3,
  );

  @override
  Future<void> initialize() => native.initialize();
  @override
  Future<CatalogPage> cached(String source) async => CatalogPage([]);
  @override
  Future<String> cover(Drama drama, {bool force = false}) =>
      native.cover(drama, force: force);
  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    bool force = false,
  }) async => CatalogPage([drama]);
  @override
  Future<DramaDetail> detail(Drama drama) async => DramaDetail(drama, [
    for (final entry in {
      1: 'clear.mp4',
      2: 'index.m3u8',
      3: 'encrypted.mp4',
    }.entries)
      Episode({
        'id': '${entry.key}',
        'source': 'hongguo',
        'currentEpisode': entry.key,
        'title': '第${entry.key}集',
        'videoUrl': '$fixtureBase/${entry.value}',
        'referer': '$fixtureBase/',
      }, entry.key),
  ]);
  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async {
    final plan = await native.resolve(drama, episode, quality: quality);
    resolved.add(episode.number);
    if (episode.number == 3) {
      return PlaybackPlan(
        url: plan.url,
        headers: plan.headers,
        decryptionKey: '00112233445566778899aabbccddeeff',
      );
    }
    return plan;
  }

  @override
  Future<void> cancelPlayback() => native.cancelPlayback();
  @override
  Future<void> release(String session) async {
    if (session.isNotEmpty) released.add(session);
    await native.release(session);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native MP4, encrypted HLS, CENC, swipe, rotation and resume', (
    tester,
  ) async {
    expect(fixtureBase, startsWith('http://127.0.0.1:'));
    expect(const bool.fromEnvironment('DISABLE_REMOTE_IMAGES'), isTrue);
    MediaKit.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final repository = DeviceFixtureRepository();
    await repository.initialize();
    final store = LocalStore(await SharedPreferences.getInstance());
    final samples = <Map<String, Object?>>[];

    Future<void> until(bool Function() ready, String step) async {
      final timer = Stopwatch()..start();
      while (!ready()) {
        if (timer.elapsed > const Duration(seconds: 35)) {
          fail('Timed out: $step; resolved=${repository.resolved}');
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Player player() =>
        tester.widget<Video>(find.byType(Video)).controller.player;

    Future<void> decoded(int episode) async {
      await until(
        () =>
            repository.resolved.isNotEmpty &&
            repository.resolved.last == episode &&
            (player().state.width ?? 0) > 0 &&
            player().state.duration.inSeconds >= 18 &&
            player().state.position.inMilliseconds > 500,
        'decode episode $episode',
      );
      expect(find.text('暂时无法播放'), findsNothing);
      expect(tester.takeException(), isNull);
      samples.add({
        'episode': episode,
        'width': player().state.width,
        'height': player().state.height,
        'positionMs': player().state.position.inMilliseconds,
        'durationMs': player().state.duration.inMilliseconds,
      });
      binding.reportData ??= {};
      binding.reportData!['playbackSamples'] = samples;
    }

    await tester.pumpWidget(DuanjuApp(repository: repository, store: store));
    await until(() => find.text('设备播放验证').evaluate().isNotEmpty, 'catalog');
    await tester.tap(find.text('设备播放验证'));
    await until(
      () => find.byKey(const ValueKey('episode-1')).evaluate().isNotEmpty,
      'detail',
    );
    await tester.tap(find.byKey(const ValueKey('episode-1')));
    await until(() => find.byType(Video).evaluate().isNotEmpty, 'player');
    await player().setVolume(0);
    await decoded(1);
    await player().seek(const Duration(seconds: 5));
    await until(() => player().state.position.inSeconds >= 5, 'seek');
    await tester.fling(find.byType(Video), const Offset(0, -160), 900);
    await decoded(2);

    await tester.tap(find.byTooltip('旋转与全屏').first);
    await until(
      () =>
          MediaQuery.orientationOf(tester.element(find.byType(Video))) ==
          Orientation.landscape,
      'landscape',
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('android-landscape-playback');
    await tester.tap(find.byTooltip('退出全屏').first);
    await until(
      () =>
          MediaQuery.orientationOf(tester.element(find.byType(Video))) ==
          Orientation.portrait,
      'portrait',
    );
    await tester.tap(find.byKey(const ValueKey('play-episode-3')));
    await decoded(3);
    await tester.tap(find.byKey(const ValueKey('play-episode-1')));
    await decoded(1);
    await player().seek(player().state.duration - const Duration(seconds: 1));
    await decoded(2);
    final backTooltip = MaterialLocalizations.of(
      tester.element(find.byType(Video)),
    ).backButtonTooltip;
    await tester.tap(find.byTooltip(backTooltip));
    await until(
      () => store.watched(DeviceFixtureRepository.drama.id)?.episode == 2,
      'saved history',
    );
    expect(
      store.watched(DeviceFixtureRepository.drama.id)!.position,
      greaterThan(0),
    );
    expect(repository.released, isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot('android-resume-detail');
    binding.reportData ??= {};
    binding.reportData!['playbackSamples'] = samples;
    binding.reportData!['releasedSessions'] = repository.released.length;
    binding.reportData!['savedEpisode'] = store
        .watched(DeviceFixtureRepository.drama.id)!
        .episode;
    if (const bool.fromEnvironment('CHECK_LIVE_CATALOG')) {
      final catalog = await repository.native.catalog('hongguo');
      expect(catalog.items, isNotEmpty);
      binding.reportData!['hongguoCatalogCount'] = catalog.items.length;
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
