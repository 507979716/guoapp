import 'dart:async';

import 'package:flutter/material.dart';

import 'core_bridge.dart';
import 'detail_screen.dart';
import 'local_store.dart';
import 'models.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.store});
  final AppRepository repository;
  final LocalStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late SourceSite _source;
  List<Drama> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  int _generation = 0;
  int _tab = 0;
  String _submittedQuery = '';
  bool _failedMore = false;

  @override
  void initState() {
    super.initState();
    _source = SourceSite.byId(widget.store.source);
    _load(useCache: true);
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({
    bool more = false,
    bool useCache = false,
    bool force = false,
  }) async {
    if (more && (_loading || _loadingMore || !_hasMore)) {
      return;
    }
    final generation = ++_generation;
    final source = _source;
    final query = source.onlineSearch ? _search.text.trim() : '';
    final page = more ? _page + 1 : 1;
    setState(() {
      _error = null;
      _failedMore = false;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        if (query != _submittedQuery) {
          _items = [];
        }
      }
    });
    if (useCache && !force && query.isEmpty) {
      try {
        final cached = await widget.repository.cached(source.id);
        if (!mounted || generation != _generation) {
          return;
        }
        if (cached.items.isNotEmpty) {
          setState(() {
            _items = cached.items;
            _page = cached.page;
            _hasMore = cached.hasMore;
            _submittedQuery = query;
            _loading = !cached.fresh;
          });
          if (cached.fresh) {
            return;
          }
        }
      } catch (_) {}
    }
    try {
      final result = await widget.repository.catalog(
        source.id,
        page: page,
        query: query,
        force: force,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        final entries = <String, Drama>{};
        if (more) {
          for (final item in _items) {
            entries[item.id] = item;
          }
        }
        for (final item in result.items) {
          entries[item.id] = item;
        }
        _items = entries.values.toList();
        _page = result.page;
        _hasMore = result.hasMore;
        _submittedQuery = query;
        _loading = false;
        _loadingMore = false;
        _error = result.warning.isEmpty ? null : result.warning;
      });
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.toString();
        _failedMore = more;
      });
    }
  }

  void _changeSource(SourceSite source) {
    if (_source.id == source.id) {
      return;
    }
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _source = source;
      _items = [];
      _hasMore = true;
      _page = 1;
      _submittedQuery = '';
      _error = null;
    });
    widget.store.setSource(source.id);
    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    _load(useCache: true);
  }

  void _searchChanged(String query) {
    _debounce?.cancel();
    setState(() {});
    if (_source.onlineSearch) {
      _debounce = Timer(const Duration(milliseconds: 500), () => _load());
    }
  }

  void _openDrama(Drama drama) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(
          drama: drama,
          repository: widget.repository,
          store: widget.store,
        ),
      ),
    );
  }

  List<Drama> get _visible {
    final query = _search.text.trim().toLowerCase();
    return _items.where((drama) {
      if (widget.store.hideVip && drama.vip) {
        return false;
      }
      return _source.onlineSearch ||
          query.isEmpty ||
          ('${drama.title} ${drama.description}').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 840;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_circle_filled_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 9),
                const Text(
                  '短剧库',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              if (_tab == 0)
                IconButton(
                  tooltip: '更新当前站源',
                  onPressed: _loading ? null : () => _load(force: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              PopupMenuButton<String>(
                tooltip: '更多',
                onSelected: (value) {
                  if (value == 'about') {
                    showAboutDialog(
                      context: context,
                      applicationName: '短剧库',
                      applicationVersion: '0.1.1',
                      applicationIcon: const Icon(
                        Icons.play_circle_filled_rounded,
                        size: 48,
                        color: Color(0xFFFF765F),
                      ),
                      children: [
                        const Text('独立运行，打开即可浏览和播放。观看记录与追剧收藏保存在当前设备。'),
                      ],
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'about', child: Text('关于短剧库')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                if (desktop) ...[
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: (value) => setState(() {
                      _tab = value;
                    }),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: const Color(0xFF101114),
                    groupAlignment: -.8,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.explore_outlined),
                        selectedIcon: Icon(Icons.explore),
                        label: Text('发现'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bookmark_border_rounded),
                        selectedIcon: Icon(Icons.bookmark_rounded),
                        label: Text('追剧'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_rounded),
                        label: Text('最近观看'),
                      ),
                    ],
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFF26282E),
                  ),
                ],
                Expanded(child: _tab == 0 ? _catalog() : _saved()),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (value) => setState(() {
                    _tab = value;
                  }),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.explore_outlined),
                      selectedIcon: Icon(Icons.explore),
                      label: '发现',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bookmark_border_rounded),
                      selectedIcon: Icon(Icons.bookmark_rounded),
                      label: '追剧',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_rounded),
                      label: '最近观看',
                    ),
                  ],
                ),
        );
      },
    ),
  );

  Widget _catalog() {
    final items = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: _searchChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              if (_source.onlineSearch) {
                _load();
              }
            },
            decoration: InputDecoration(
              hintText: _source.onlineSearch ? '搜索红果短剧' : '筛选当前已加载短剧',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _search.clear();
                        _searchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: SourceSite.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final source = SourceSite.values[index];
              return Center(
                child: ChoiceChip(
                  label: Text(source.name),
                  selected: source.id == _source.id,
                  showCheckmark: false,
                  onSelected: (_) => _changeSource(source),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _submittedQuery.isNotEmpty && _source.onlineSearch
                      ? '搜索结果 · ${items.length} 部'
                      : '${_source.description} · ${items.length} 部',
                  style: const TextStyle(
                    color: Color(0xFFB3B1BA),
                    fontSize: 12,
                  ),
                ),
              ),
              Tooltip(
                message: widget.store.hideVip ? '当前隐藏 VIP 内容' : '当前显示 VIP 内容',
                child: TextButton.icon(
                  onPressed: () =>
                      widget.store.setHideVip(!widget.store.hideVip),
                  icon: Icon(
                    widget.store.hideVip
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 17,
                  ),
                  label: Text(widget.store.hideVip ? 'VIP：隐藏' : 'VIP：显示'),
                ),
              ),
            ],
          ),
        ),
        if (_loading && _items.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (_error != null && _items.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF322521),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _loading || _loadingMore
                      ? null
                      : () => _load(more: _failedMore, force: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 18),
                      Text('正在加载剧集'),
                    ],
                  ),
                )
              : _items.isEmpty && _error != null
              ? StatusPanel(
                  title: '暂时无法加载',
                  message: _error!,
                  onRetry: () => _load(force: true),
                  icon: Icons.wifi_off_rounded,
                )
              : items.isEmpty
              ? StatusPanel(
                  title: '没有找到匹配的短剧',
                  message: widget.store.hideVip
                      ? '可以换个搜索词、切换站源，或显示 VIP 内容。'
                      : '可以换个搜索词或切换站源。',
                  onRetry:
                      _hasMore &&
                          !_loadingMore &&
                          (!_source.onlineSearch || _search.text.isEmpty)
                      ? () => _load(more: true)
                      : null,
                  action: '加载更多',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
                    return RefreshIndicator(
                      onRefresh: () => _load(force: true),
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              0,
                              padding,
                              16,
                            ),
                            sliver: SliverGrid(
                              gridDelegate: dramaGridDelegate(
                                constraints.maxWidth - 2 * padding,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, index) => DramaTile(
                                  key: ValueKey(items[index].id),
                                  drama: items[index],
                                  repository: widget.repository,
                                  onTap: () => _openDrama(items[index]),
                                ),
                                childCount: items.length,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : _hasMore
                                    ? OutlinedButton.icon(
                                        onPressed: () => _load(more: true),
                                        icon: const Icon(
                                          Icons.expand_more_rounded,
                                        ),
                                        label: const Text('加载更多'),
                                      )
                                    : const Text(
                                        '已经看到这里的全部剧集',
                                        style: TextStyle(
                                          color: Color(0xFF777780),
                                          fontSize: 12,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _saved() {
    final history = widget.store.history;
    final items = _tab == 1
        ? widget.store.favorites
        : history.map((entry) => entry.drama).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tab == 1 ? '我的追剧' : '最近观看',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tab == 1 ? '收藏喜欢的剧，随时接着看' : '点击剧集，继续上次的进度',
                      style: const TextStyle(
                        color: Color(0xFF9999A3),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (_tab == 2 && items.isNotEmpty)
                IconButton(
                  tooltip: '清空观看记录',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final accepted = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('清空观看记录？'),
                        content: const Text('这会删除当前设备保存的观看进度。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (accepted == true) {
                      await widget.store.clearHistory();
                    }
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? StatusPanel(
                  title: _tab == 1 ? '还没有追剧' : '还没有观看记录',
                  message: '去发现页，挑一部喜欢的短剧。',
                  icon: _tab == 1
                      ? Icons.bookmark_border_rounded
                      : Icons.history_rounded,
                )
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    gridDelegate: dramaGridDelegate(constraints.maxWidth - 40),
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final drama = items[index];
                      final entry = widget.store.watched(drama.id);
                      return DramaTile(
                        drama: drama,
                        repository: widget.repository,
                        onTap: () => _openDrama(drama),
                        subtitle: entry == null
                            ? SourceSite.byId(drama.source).name
                            : '看到第 ${entry.episode} 集 · ${formatPosition(entry.position)}',
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
