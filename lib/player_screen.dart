import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'core_bridge.dart';
import 'local_store.dart';
import 'models.dart';
import 'playback_loader.dart';
import 'player_controls.dart';
import 'widgets.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.detail,
    required this.initialIndex,
    required this.repository,
    required this.store,
    this.initialPosition = 0,
  });
  final DramaDetail detail;
  final int initialIndex;
  final double initialPosition;
  final AppRepository repository;
  final LocalStore store;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _video;
  late final PlaybackLoader _loader;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _saveTimer;
  Future<void> _operations = Future<void>.value();
  late int _index;
  int _openedIndex = -1;
  int _generation = 0;
  int _requestedQuality = 0;
  bool _loading = true;
  bool _fullscreen = false;
  bool _closed = false;
  bool _acceptErrors = false;
  bool _foreground = true;
  String? _error;
  PlaybackPlan? _plan;
  double _speed = 1;
  double _aspectRatio = 9 / 16;
  double _resumePosition = 0;
  bool _rotating = false;
  bool get _mobile => Platform.isAndroid || Platform.isIOS;
  String get _session => _plan?.session ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.initialIndex;
    _loader = PlaybackLoader(widget.repository);
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    _video = VideoController(_player);
    _subscriptions.add(
      _player.stream.error.listen((error) {
        if (!_closed && _acceptErrors && mounted && error.trim().isNotEmpty) {
          setState(() {
            _loading = false;
            _error = '播放暂时中断，请重试；也可以换一集或降低清晰度。';
          });
        }
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed &&
            !_loading &&
            !_closed &&
            _error == null &&
            _index + 1 < widget.detail.episodes.length) {
          _play(_index + 1);
        }
      }),
    );
    _subscriptions.add(
      _player.stream.videoParams.listen((parameters) {
        final width = parameters.dw ?? parameters.w ?? 0;
        final height = parameters.dh ?? parameters.h ?? 0;
        if (width > 0 && height > 0 && mounted && !_closed) {
          setState(() {
            _aspectRatio = width / height;
          });
        }
      }),
    );
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveProgress(),
    );
    _play(_index, position: widget.initialPosition);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _player.pause();
      _saveProgress();
    }
  }

  Future<void> _saveProgress() async {
    if (_openedIndex < 0) {
      return;
    }
    final position = _player.state.position.inMilliseconds / 1000;
    final duration = _player.state.duration.inMilliseconds / 1000;
    if (position < .1) {
      return;
    }
    final store = widget.store;
    final entry = WatchEntry(
      drama: widget.detail.drama,
      episode: widget.detail.episodes[_openedIndex].number,
      position: position,
      duration: duration,
      updatedAt: DateTime.now(),
    );
    try {
      await Future<void>.value();
      await store.saveWatch(entry);
    } catch (_) {}
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operations.catchError((Object _) {}).then((_) => operation());
    _operations = next;
    return next;
  }

  Future<void> _play(int index, {double position = 0}) async {
    if (_closed || index < 0 || index >= widget.detail.episodes.length) {
      return;
    }
    final ticket = ++_generation;
    _acceptErrors = false;
    _resumePosition = position;
    setState(() {
      _index = index;
      _loading = true;
      _error = null;
    });
    PlaybackPlan? prepared;
    try {
      await _serialize(() async {
        if (_closed || ticket != _generation) {
          return;
        }
        await _saveProgress();
        _openedIndex = -1;
        await _player.stop();
        final previousSession = _session;
        _plan = null;
        if (previousSession.isNotEmpty) {
          await widget.repository.release(previousSession);
        }
      });
      if (_closed || ticket != _generation) {
        return;
      }
      prepared = await _loader.load(
        widget.detail.drama,
        widget.detail.episodes[index],
        quality: _requestedQuality,
      );
      if (prepared == null) {
        return;
      }
      final plan = prepared;
      await _serialize(() async {
        if (_closed || ticket != _generation) {
          await widget.repository.release(plan.session);
          return;
        }
        if (plan.url.isEmpty) {
          throw AppFailure('站源未返回播放地址，请重试');
        }
        final platform = _player.platform;
        if (platform is NativePlayer) {
          await platform.setProperty(
            'demuxer-lavf-o',
            [
              'seg_max_retry=3',
              'strict=experimental',
              'allowed_extensions=ALL',
              'protocol_whitelist=[http,https,tcp,tls,crypto,data,file]',
              if (plan.decryptionKey.isNotEmpty)
                'decryption_key=${plan.decryptionKey}',
            ].join(','),
          );
          await platform.setProperty('network-timeout', '20');
        }
        _plan = plan;
        _acceptErrors = true;
        await _player.open(
          Media(
            plan.url,
            httpHeaders: plan.headers,
            start: position > 0
                ? Duration(milliseconds: (position * 1000).round())
                : null,
          ),
          play: _foreground,
        );
        if (_closed || ticket != _generation) {
          return;
        }
        _openedIndex = index;
        await _player.setRate(_speed);
        if (mounted && !_closed && ticket == _generation) {
          setState(() {
            _loading = false;
          });
        }
      });
    } catch (error) {
      if (prepared != null) {
        await widget.repository.release(prepared.session);
      }
      if (!_closed && mounted && ticket == _generation) {
        setState(() {
          _loading = false;
          _error = error is AppFailure ? error.message : '无法播放这一集，请重试或换一集。';
        });
      }
    }
  }

  Future<void> _retry({int? quality}) async {
    final position = _openedIndex == _index
        ? _player.state.position.inMilliseconds / 1000
        : _resumePosition;
    if (quality != null) {
      _requestedQuality = quality;
    }
    await _play(_index, position: position);
  }

  bool get _showFullscreen =>
      _fullscreen ||
      (_mobile &&
          _aspectRatio >= 1 &&
          MediaQuery.orientationOf(context) == Orientation.landscape);

  Future<void> _rotate() async {
    if (_rotating) {
      return;
    }
    final fullscreen = !_showFullscreen;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _rotating = true;
    setState(() {
      _fullscreen = fullscreen;
    });
    try {
      if (Platform.isWindows) {
        await windowManager.setFullScreen(fullscreen);
      } else if (_mobile) {
        if (fullscreen) {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
          );
          await SystemChrome.setPreferredOrientations(
            _aspectRatio >= 1
                ? [
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]
                : [
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ],
          );
        } else {
          await SystemChrome.setPreferredOrientations(
            landscape
                ? [DeviceOrientation.portraitUp]
                : DeviceOrientation.values,
          );
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    } finally {
      _rotating = false;
    }
  }

  void _seek(int seconds) {
    final desired = _player.state.position + Duration(seconds: seconds);
    final maxDuration = _player.state.duration;
    final target = desired < Duration.zero
        ? Duration.zero
        : maxDuration > Duration.zero && desired > maxDuration
        ? maxDuration
        : desired;
    _player.seek(target);
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    unawaited(_saveProgress());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(widget.repository.release(_session));
    unawaited(_loader.close().catchError((Object _) {}));
    unawaited(
      _operations.catchError((Object _) {}).then((_) => _player.dispose()),
    );
    if (Platform.isWindows) {
      unawaited(windowManager.setFullScreen(false));
    } else if (_mobile) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.detail.drama.title;
    final episode = widget.detail.episodes[_index];
    final fullscreen = _showFullscreen;
    return PopScope(
      canPop: !fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && fullscreen) {
          _rotate();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              _rotate,
          const SingleActivator(LogicalKeyboardKey.f11): _rotate,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (fullscreen) {
              _rotate();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seek(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seek(10),
          const SingleActivator(LogicalKeyboardKey.space): () =>
              _player.playOrPause(),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: fullscreen
                ? null
                : AppBar(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: const Color(0xFF101114),
                    actions: [
                      IconButton(
                        tooltip: '旋转与全屏',
                        onPressed: _rotate,
                        icon: const Icon(Icons.screen_rotation_alt_rounded),
                      ),
                    ],
                  ),
            body: SafeArea(
              top: fullscreen,
              bottom: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 840;
                  if (fullscreen) {
                    return _videoPane();
                  }
                  if (desktop ||
                      constraints.maxWidth > constraints.maxHeight * 1.3) {
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _videoPane()),
                              _actionBar(episode),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: desktop ? 312 : 210,
                          child: _episodePanel(),
                        ),
                      ],
                    );
                  }
                  final height = (constraints.maxWidth / _aspectRatio).clamp(
                    0.0,
                    constraints.maxHeight * .64,
                  );
                  return Column(
                    children: [
                      SizedBox(
                        height: height,
                        width: double.infinity,
                        child: _videoPane(),
                      ),
                      _actionBar(episode),
                      Expanded(child: _episodePanel()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoPane() => Stack(
    fit: StackFit.expand,
    children: [
      Video(
        controller: _video,
        fit: BoxFit.contain,
        controls: (_) => PlayerControls(
          player: _player,
          fullscreen: _showFullscreen,
          title:
              '${widget.detail.drama.title} · 第 ${widget.detail.episodes[_index].number} 集${widget.detail.episodes[_index].vip ? ' · VIP 试看' : ''}',
          swipeEnabled: _mobile,
          onFullscreen: _rotate,
          onPrevious: _index > 0 ? () => _play(_index - 1) : null,
          onNext: _index + 1 < widget.detail.episodes.length
              ? () => _play(_index + 1)
              : null,
        ),
      ),
      if (_loading)
        ColoredBox(
          color: Colors.black.withValues(alpha: .78),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在准备播放'),
              ],
            ),
          ),
        ),
      if (_error != null)
        ColoredBox(
          color: Colors.black.withValues(alpha: .9),
          child: StatusPanel(
            title: '暂时无法播放',
            message: _error!,
            onRetry: () => _retry(),
            action: '重试播放',
            icon: Icons.play_disabled_rounded,
          ),
        ),
    ],
  );

  Widget _actionBar(Episode episode) => Container(
    color: const Color(0xFF191A20),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Row(
      children: [
        IconButton(
          tooltip: '上一集',
          onPressed: _index > 0 ? () => _play(_index - 1) : null,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        Text('第 ${episode.number} 集'),
        IconButton(
          tooltip: '下一集',
          onPressed: _index + 1 < widget.detail.episodes.length
              ? () => _play(_index + 1)
              : null,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        const Spacer(),
        PopupMenuButton<double>(
          tooltip: '播放倍速',
          initialValue: _speed,
          onSelected: (speed) {
            setState(() {
              _speed = speed;
            });
            _player.setRate(speed);
          },
          itemBuilder: (_) => [
            for (final speed in [.75, 1.0, 1.25, 1.5, 2.0])
              PopupMenuItem(value: speed, child: Text('${speed}x')),
          ],
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text('${_speed}x'),
          ),
        ),
        if ((_plan?.qualities.length ?? 0) > 1)
          PopupMenuButton<int>(
            tooltip: '清晰度',
            onSelected: (quality) => _retry(quality: quality),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('自动（优先高清）')),
              for (final quality in _plan!.qualities)
                PopupMenuItem(value: quality, child: Text('${quality}P')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_plan!.quality > 0 ? '${_plan!.quality}P' : '自动'),
            ),
          ),
      ],
    ),
  );

  Widget _episodePanel() => Container(
    color: const Color(0xFF101114),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '选集 · 共 ${widget.detail.episodes.length} 集',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) => TextButton.icon(
                  onPressed: () =>
                      widget.store.toggleFavorite(widget.detail.drama),
                  icon: Icon(
                    widget.store.isFavorite(widget.detail.drama.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                  ),
                  label: Text(
                    widget.store.isFavorite(widget.detail.drama.id)
                        ? '已追剧'
                        : '追剧',
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 76,
              mainAxisExtent: 46,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: widget.detail.episodes.length,
            itemBuilder: (_, index) {
              final episode = widget.detail.episodes[index];
              return TextButton(
                key: ValueKey('play-episode-${episode.number}'),
                onPressed: () => _play(index),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: index == _index
                      ? const Color(0xFF763D32)
                      : const Color(0xFF24252C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == _index)
                      const Icon(Icons.equalizer_rounded, size: 14),
                    Text('${episode.number}'),
                    if (episode.vip)
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: Color(0xFFF6C86B),
                        size: 13,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
