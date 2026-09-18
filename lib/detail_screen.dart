import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_layout.dart';
import 'core_bridge.dart';
import 'local_store.dart';
import 'models.dart';
import 'player_screen.dart';
import 'remote_widgets.dart';
import 'widgets.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.store,
  });
  final Drama drama;
  final AppRepository repository;
  final LocalStore store;
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  DramaDetail? _detail;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStoreChanged);
      widget.store.addListener(_onStoreChanged);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _generation++;
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.detail(widget.drama);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
      try {
        await widget.store.refreshDrama(detail.drama);
      } catch (_) {}
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _play(int index, {bool resume = false}) async {
    final detail = _detail;
    if (detail == null || index < 0 || index >= detail.episodes.length) {
      return;
    }
    if (detail.episodes[index].vip) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('这是一集 VIP 内容'),
          content: const Text('站源可能只提供试看或限制播放。'),
          actions: [
            TextButton(
              autofocus: AppLayout.isTelevision(context),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('尝试播放'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) {
        return;
      }
    }
    final saved = widget.store.watched(detail.drama.id);
    final position =
        resume &&
            saved?.episode == detail.episodes[index].number &&
            !saved!.finished
        ? saved.position
        : 0.0;
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          detail: detail,
          initialIndex: index,
          initialPosition: position,
          repository: widget.repository,
          store: widget.store,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final drama = _detail?.drama ?? widget.drama;
    final watched = widget.store.watched(drama.id);
    var resumeIndex = 0;
    final episodes = _detail?.episodes ?? [];
    if (watched != null && episodes.isNotEmpty) {
      final found = episodes.indexWhere(
        (episode) => episode.number == watched.episode,
      );
      if (found >= 0) {
        resumeIndex = watched.finished && found + 1 < episodes.length
            ? found + 1
            : found;
      }
    }
    final television = AppLayout.isTelevision(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.goBack): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: television ? 64 : null,
          title: Text(drama.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: '更新剧集信息',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: widget.store.isFavorite(drama.id) ? '取消追剧' : '加入追剧',
              onPressed: () => widget.store.toggleFavorite(drama),
              icon: Icon(
                widget.store.isFavorite(drama.id)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: television
              ? _televisionBody(drama, episodes, resumeIndex, watched)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 112,
                                  height: 168,
                                  child: DramaCover(
                                    drama: drama,
                                    repository: widget.repository,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        drama.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        SourceSite.byId(drama.source).name +
                                            (drama.episodes > 0
                                                ? ' · 共 ${drama.episodes} 集'
                                                : ''),
                                        style: const TextStyle(
                                          color: Color(0xFFABA8B4),
                                        ),
                                      ),
                                      if (drama.category.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          drama.category,
                                          style: const TextStyle(
                                            color: Color(0xFFABA8B4),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 18),
                                      FilledButton.icon(
                                        key: const ValueKey('start-play'),
                                        onPressed: episodes.isEmpty
                                            ? null
                                            : () => _play(
                                                resumeIndex,
                                                resume: true,
                                              ),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: Text(
                                          watched != null && episodes.isNotEmpty
                                              ? '继续第 ${episodes[resumeIndex].number} 集'
                                              : '立即播放',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (drama.description.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              child: Text(
                                drama.description,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFADABB5),
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        if (_loading)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        else if (_error != null)
                          SliverToBoxAdapter(
                            child: StatusPanel(
                              title: '剧集信息暂时不可用',
                              message: _error!,
                              onRetry: _load,
                            ),
                          )
                        else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Row(
                                children: [
                                  Text(
                                    '选集',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '共 ${episodes.length} 集',
                                    style: const TextStyle(
                                      color: Color(0xFF9996A4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 96,
                                    mainAxisExtent: 52,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              delegate: SliverChildBuilderDelegate((_, index) {
                                final episode = episodes[index];
                                final current =
                                    watched?.episode == episode.number;
                                return OutlinedButton(
                                  key: ValueKey('episode-${episode.number}'),
                                  onPressed: () => _play(index),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: current
                                        ? const Color(0xFF452A27)
                                        : null,
                                    side: BorderSide(
                                      color: current
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : const Color(0xFF33343D),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${episode.number}'),
                                      if (episode.vip) ...[
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.workspace_premium_rounded,
                                          color: Color(0xFFF6C86B),
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }, childCount: episodes.length),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _televisionBody(
    Drama drama,
    List<Episode> episodes,
    int resumeIndex,
    WatchEntry? watched,
  ) => LayoutBuilder(
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: (constraints.maxWidth * .34).clamp(210.0, 340.0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 138,
                      child: DramaCover(
                        drama: drama,
                        repository: widget.repository,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drama.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            SourceSite.byId(drama.source).name,
                            style: const TextStyle(color: Color(0xFFABA8B4)),
                          ),
                          if (episodes.isNotEmpty)
                            Text('共 ${episodes.length} 集'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (drama.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    drama.description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Color(0xFFADABB5),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (episodes.isNotEmpty)
                  RemoteButton(
                    key: const ValueKey('start-play'),
                    autofocus: true,
                    label: watched != null
                        ? '继续第 ${episodes[resumeIndex].number} 集'
                        : '立即播放',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => _play(resumeIndex, resume: true),
                  ),
                RemoteButton(
                  label: widget.store.isFavorite(drama.id) ? '已追剧' : '加入追剧',
                  icon: widget.store.isFavorite(drama.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  onPressed: () => widget.store.toggleFavorite(drama),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? StatusPanel(
                  title: '剧集信息暂时不可用',
                  message: _error!,
                  onRetry: _load,
                )
              : episodes.isEmpty
              ? StatusPanel(
                  title: '暂时没有可播放的集数',
                  message: '可以更新剧集信息后重试。',
                  onRetry: _load,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Text(
                        '选集',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => RemoteGrid(
                          key: ValueKey('detail-episodes-${drama.id}'),
                          itemKeys: episodes
                              .map((episode) => '${episode.number}')
                              .toList(),
                          columns: ((constraints.maxWidth - 36) / 96)
                              .floor()
                              .clamp(1, 8),
                          itemExtent: 64,
                          itemBuilder: (_, index, node, onFocus) =>
                              RemoteEpisodeButton(
                                key: ValueKey(
                                  'episode-${episodes[index].number}',
                                ),
                                number: episodes[index].number,
                                vip: episodes[index].vip,
                                current:
                                    watched?.episode == episodes[index].number,
                                focusNode: node,
                                onFocus: onFocus,
                                onPressed: () => _play(index),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}
