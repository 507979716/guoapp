import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

typedef _NativeRequest = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartRequest = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _NativeFree = Void Function(Pointer<Utf8>);
typedef _DartFree = void Function(Pointer<Utf8>);

String _nativeRequest(String body) {
  final DynamicLibrary library;
  if (Platform.isAndroid) {
    library = DynamicLibrary.open('libduanju_core.so');
  } else if (Platform.isWindows) {
    library = DynamicLibrary.open(
      path.join(path.dirname(Platform.resolvedExecutable), 'duanju_core.dll'),
    );
  } else if (Platform.isIOS) {
    library = DynamicLibrary.process();
  } else {
    throw UnsupportedError('当前首版支持 Android 手机和 Windows 电脑');
  }
  final request = library.lookupFunction<_NativeRequest, _DartRequest>(
    'DuanjuRequest',
  );
  final free = library.lookupFunction<_NativeFree, _DartFree>('DuanjuFree');
  final input = body.toNativeUtf8();
  Pointer<Utf8> output = nullptr;
  try {
    output = request(input);
    if (output == nullptr) {
      throw StateError('本地核心没有返回结果');
    }
    return output.toDartString();
  } finally {
    malloc.free(input);
    if (output != nullptr) {
      free(output);
    }
  }
}

class AppFailure implements Exception {
  AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract class AppRepository {
  Future<void> initialize();
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    bool force = false,
  });
  Future<CatalogPage> cached(String source);
  Future<String> cover(Drama drama, {bool force = false});
  Future<DramaDetail> detail(Drama drama);
  Future<PlaybackPlan> resolve(Drama drama, Episode episode, {int quality = 0});
  Future<void> cancelPlayback();
  Future<void> release(String session);
}

class NativeRepository implements AppRepository {
  int _playbackSequence = DateTime.now().microsecondsSinceEpoch;

  Future<Map<String, dynamic>> _call(Map<String, dynamic> input) async {
    try {
      final body = jsonEncode(input);
      final encoded = await Isolate.run(
        () => _nativeRequest(body),
      ).timeout(const Duration(seconds: 70));
      final response = jsonDecode(encoded) as Map<String, dynamic>;
      if (response['ok'] != true) {
        throw AppFailure(response['error'] as String? ?? '读取失败，请重试');
      }
      final data = response['data'];
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw AppFailure('站源响应超时，请重试或切换站源');
    } catch (_) {
      throw AppFailure('本地核心加载失败，请使用完整安装包重新安装');
    }
  }

  @override
  Future<void> initialize() async {
    final directory = await getApplicationSupportDirectory();
    await _call({'action': 'initialize', 'directory': directory.path});
  }

  @override
  Future<CatalogPage> catalog(
    String source, {
    int page = 1,
    String query = '',
    bool force = false,
  }) async => CatalogPage.fromJson(
    await _call({
      'action': 'catalog',
      'source': source,
      'page': page,
      'query': query,
      'force': force,
    }),
  );
  @override
  Future<CatalogPage> cached(String source) async =>
      CatalogPage.fromJson(await _call({'action': 'cached', 'source': source}));
  @override
  Future<String> cover(Drama drama, {bool force = false}) async {
    final result = await _call({
      'action': 'cover',
      'drama': drama.toJson(),
      'force': force,
    });
    final file = result['path'] as String? ?? '';
    if (file.isEmpty) {
      throw AppFailure('海报暂时不可用');
    }
    return file;
  }

  @override
  Future<DramaDetail> detail(Drama drama) async => DramaDetail.fromJson(
    await _call({'action': 'detail', 'drama': drama.toJson()}),
  );
  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
  }) async => PlaybackPlan.fromJson(
    await _call({
      'action': 'resolve',
      'drama': drama.toJson(),
      'chapter': episode.raw,
      'index': episode.number,
      'quality': quality,
      'sequence': ++_playbackSequence,
    }),
  );
  @override
  Future<void> cancelPlayback() async {
    await _call({'action': 'cancelPlayback', 'sequence': ++_playbackSequence});
  }

  @override
  Future<void> release(String session) async {
    if (session.isEmpty) {
      return;
    }
    try {
      await _call({'action': 'release', 'session': session});
    } catch (_) {}
  }
}
