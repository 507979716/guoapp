import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LocalStore extends ChangeNotifier {
  LocalStore(this.preferences) {
    for (final row in readJsonList(preferences.getString('history'))) {
      try {
        final entry = WatchEntry.fromJson(row);
        _history[entry.drama.id] = entry;
      } catch (_) {}
    }
    for (final row in readJsonList(preferences.getString('favorites'))) {
      try {
        final drama = Drama.fromJson(row);
        _favorites[drama.id] = drama;
      } catch (_) {}
    }
  }
  final SharedPreferences preferences;
  final Map<String, WatchEntry> _history = {};
  final Map<String, Drama> _favorites = {};
  Future<void> _writes = Future<void>.value();

  List<WatchEntry> get history =>
      _history.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  List<Drama> get favorites => _favorites.values.toList().reversed.toList();
  WatchEntry? watched(String id) => _history[id];
  bool isFavorite(String id) => _favorites.containsKey(id);
  bool get hideVip => preferences.getBool('hideVip') ?? true;
  String get source =>
      SourceSite.byId(preferences.getString('source') ?? '').id;

  Future<void> setSource(String value) async {
    await preferences.setString('source', value);
  }

  Future<void> setHideVip(bool value) async {
    await preferences.setBool('hideVip', value);
    notifyListeners();
  }

  Future<void> toggleFavorite(Drama drama) async {
    if (_favorites.containsKey(drama.id)) {
      _favorites.remove(drama.id);
    } else {
      _favorites[drama.id] = drama;
    }
    notifyListeners();
    final content = jsonEncode(
      _favorites.values.map((e) => e.toJson()).toList(),
    );
    await _queue(() async {
      await preferences.setString('favorites', content);
    });
  }

  Future<void> saveWatch(WatchEntry entry) async {
    _history[entry.drama.id] = entry;
    if (_history.length > 300) {
      final entries = history;
      for (final old in entries.skip(300)) {
        _history.remove(old.drama.id);
      }
    }
    notifyListeners();
    final content = jsonEncode(history.map((e) => e.toJson()).toList());
    await _queue(() async {
      await preferences.setString('history', content);
    });
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _queue(() async {
      await preferences.remove('history');
    });
  }

  Future<void> refreshDrama(Drama drama) async {
    final favorite = _favorites.containsKey(drama.id);
    final watched = _history[drama.id];
    if (!favorite && watched == null) {
      return;
    }
    if (favorite) {
      _favorites[drama.id] = drama;
    }
    if (watched != null) {
      _history[drama.id] = WatchEntry(
        drama: drama,
        episode: watched.episode,
        position: watched.position,
        duration: watched.duration,
        updatedAt: watched.updatedAt,
      );
    }
    final favorites = jsonEncode(
      _favorites.values.map((item) => item.toJson()).toList(),
    );
    final history = jsonEncode(
      this.history.map((item) => item.toJson()).toList(),
    );
    notifyListeners();
    await _queue(() async {
      await preferences.setString('favorites', favorites);
      await preferences.setString('history', history);
    });
  }

  Future<void> _queue(Future<void> Function() action) {
    _writes = _writes.catchError((Object _) {}).then((_) => action());
    return _writes;
  }
}
