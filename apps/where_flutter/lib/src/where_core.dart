// Dart binding for the Rust core (crates/where_ffi).
//
// Every call returns JSON: {"ok": value} or {"error": "message"}.
// The returned C string is always freed with where_string_free.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _OpenC = Pointer<Void> Function(Pointer<Utf8>);
typedef _CloseC = Void Function(Pointer<Void>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _StrCallC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StrCall = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StrLimitC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Uint32);
typedef _StrLimit = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _NoArgC = Pointer<Utf8> Function(Pointer<Void>);

class WhereException implements Exception {
  WhereException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WhereCore {
  WhereCore._(this._lib, this._handle);

  final DynamicLibrary _lib;
  Pointer<Void> _handle;

  late final _close = _lib.lookupFunction<_CloseC, void Function(Pointer<Void>)>('where_close');
  late final _free = _lib.lookupFunction<_FreeC, void Function(Pointer<Utf8>)>('where_string_free');
  late final _search = _lib.lookupFunction<_StrLimitC, _StrLimit>('where_search');
  late final _recent = _lib.lookupFunction<_StrLimitC, _StrLimit>('where_recent');
  late final _create = _lib.lookupFunction<_StrCallC, _StrCall>('where_create');
  late final _get = _lib.lookupFunction<_StrCallC, _StrCall>('where_get');
  late final _index = _lib.lookupFunction<_StrCallC, _StrCall>('where_index_folder');
  late final _stats = _lib.lookupFunction<_NoArgC, _NoArgC>('where_stats');

  /// Opens the database at [dbPath]. [libraryPath] overrides where the
  /// native library is loaded from (useful in development).
  static WhereCore open(String dbPath, {String? libraryPath}) {
    final lib = DynamicLibrary.open(libraryPath ?? _defaultLibraryName());
    final open = lib.lookupFunction<_OpenC, _OpenC>('where_open');
    final p = dbPath.toNativeUtf8();
    try {
      final handle = open(p);
      if (handle == nullptr) throw WhereException('Could not open database at $dbPath');
      return WhereCore._(lib, handle);
    } finally {
      malloc.free(p);
    }
  }

  static String _defaultLibraryName() {
    if (Platform.isWindows) return 'where_ffi.dll';
    if (Platform.isMacOS) return 'libwhere_ffi.dylib';
    return 'libwhere_ffi.so';
  }

  dynamic _decode(Pointer<Utf8> result) {
    try {
      final body = jsonDecode(result.toDartString()) as Map<String, dynamic>;
      if (body.containsKey('error')) throw WhereException(body['error'] as String);
      return body['ok'];
    } finally {
      _free(result);
    }
  }

  dynamic _withString(String s, Pointer<Utf8> Function(Pointer<Utf8>) f) {
    final p = s.toNativeUtf8();
    try {
      return _decode(f(p));
    } finally {
      malloc.free(p);
    }
  }

  /// Returns SearchResults JSON: {query, hits: [{object, score, reason, via}], elapsed}.
  Map<String, dynamic> search(String query, {int limit = 50}) =>
      _withString(query, (p) => _search(_handle, p, limit)) as Map<String, dynamic>;

  List<dynamic> recent({String kind = '', int limit = 20}) =>
      _withString(kind, (p) => _recent(_handle, p, limit)) as List<dynamic>;

  Map<String, dynamic> create(String kind, String title, {String body = '', String? projectId}) =>
      _withString(
        jsonEncode({'kind': kind, 'title': title, 'body': body, if (projectId != null) 'project_id': projectId}),
        (p) => _create(_handle, p),
      ) as Map<String, dynamic>;

  Map<String, dynamic> get(String id) => _withString(id, (p) => _get(_handle, p)) as Map<String, dynamic>;

  Map<String, dynamic> indexFolder(String path) =>
      _withString(path, (p) => _index(_handle, p)) as Map<String, dynamic>;

  Map<String, dynamic> stats() => _decode(_stats(_handle)) as Map<String, dynamic>;

  void close() {
    if (_handle != nullptr) {
      _close(_handle);
      _handle = nullptr;
    }
  }
}
