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
typedef _CloseDart = void Function(Pointer<Void>);
typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
typedef _StrCall = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _StrLimitC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Uint32);
typedef _StrLimitDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _NoArg = Pointer<Utf8> Function(Pointer<Void>);

class WhereException implements Exception {
  WhereException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WhereCore {
  WhereCore._(this._lib, this._handle, this.dbPath, this.libraryPath);

  final DynamicLibrary _lib;
  Pointer<Void> _handle;

  /// Where the database lives; also used to open extra handles in isolates.
  final String dbPath;
  final String? libraryPath;

  late final _close = _lib.lookupFunction<_CloseC, _CloseDart>('where_close');
  late final _free = _lib.lookupFunction<_FreeC, _FreeDart>('where_string_free');
  late final _search = _lib.lookupFunction<_StrLimitC, _StrLimitDart>('where_search');
  late final _recent = _lib.lookupFunction<_StrLimitC, _StrLimitDart>('where_recent');
  late final _create = _lib.lookupFunction<_StrCall, _StrCall>('where_create');
  late final _get = _lib.lookupFunction<_StrCall, _StrCall>('where_get');
  late final _update = _lib.lookupFunction<_StrCall, _StrCall>('where_update');
  late final _delete = _lib.lookupFunction<_StrCall, _StrCall>('where_delete');
  late final _relate = _lib.lookupFunction<_StrCall, _StrCall>('where_relate');
  late final _index = _lib.lookupFunction<_StrCall, _StrCall>('where_index_folder');
  late final _export = _lib.lookupFunction<_StrCall, _StrCall>('where_export');
  late final _findSource = _lib.lookupFunction<_StrCall, _StrCall>('where_find_source');
  late final _stats = _lib.lookupFunction<_NoArg, _NoArg>('where_stats');
  late final _indexRoots = _lib.lookupFunction<_NoArg, _NoArg>('where_index_roots');
  late final _reindexAll = _lib.lookupFunction<_NoArg, _NoArg>('where_reindex_all');

  /// Opens the database at [dbPath]. [libraryPath] overrides where the
  /// native library is loaded from (useful in development).
  static WhereCore open(String dbPath, {String? libraryPath}) {
    final lib = DynamicLibrary.open(libraryPath ?? defaultLibraryPath());
    final open = lib.lookupFunction<_OpenC, _OpenC>('where_open');
    final p = dbPath.toNativeUtf8();
    try {
      final handle = open(p);
      if (handle == nullptr) {
        throw WhereException('Could not open the database at $dbPath');
      }
      return WhereCore._(lib, handle, dbPath, libraryPath);
    } finally {
      malloc.free(p);
    }
  }

  static String defaultLibraryName() {
    if (Platform.isWindows) return 'where_ffi.dll';
    if (Platform.isMacOS) return 'libwhere_ffi.dylib';
    return 'libwhere_ffi.so';
  }

  /// Where the engine ships inside each platform's app package:
  /// - Windows: next to Where.exe
  /// - Linux:   bundle/lib/ (next to the Flutter libraries)
  /// - macOS:   Where.app/Contents/Frameworks/
  /// Falls back to the bare name so the system search path is tried.
  static String defaultLibraryPath() {
    final name = defaultLibraryName();
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = <String>[
      if (Platform.isMacOS) '$exeDir$sep..${sep}Frameworks$sep$name',
      if (Platform.isLinux) '$exeDir${sep}lib$sep$name',
      '$exeDir$sep$name',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return name;
  }

  dynamic _decode(Pointer<Utf8> result) {
    try {
      final body = jsonDecode(result.toDartString()) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        throw WhereException(body['error'].toString());
      }
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

  /// SearchResults JSON: {query, hits: [{object, score, reason, via}], elapsed}.
  Map<String, dynamic> search(String query, {int limit = 50}) =>
      _withString(query, (p) => _search(_handle, p, limit)) as Map<String, dynamic>;

  /// Most recently updated objects, optionally of one kind ('' = all).
  List<dynamic> recent({String kind = '', int limit = 20}) =>
      _withString(kind, (p) => _recent(_handle, p, limit)) as List<dynamic>;

  Map<String, dynamic> create(
    String kind,
    String title, {
    String body = '',
    String? projectId,
    Map<String, dynamic>? properties,
    String? sourceKey,
  }) =>
      _withString(
        jsonEncode({
          'kind': kind,
          'title': title,
          'body': body,
          if (projectId != null) 'project_id': projectId,
          if (properties != null) 'properties': properties,
          if (sourceKey != null) 'source_key': sourceKey,
        }),
        (p) => _create(_handle, p),
      ) as Map<String, dynamic>;

  /// {object, related: [{kind, direction, object}]}
  Map<String, dynamic> get(String id) =>
      _withString(id, (p) => _get(_handle, p)) as Map<String, dynamic>;

  /// Update title/body and merge properties (a null value removes a property).
  Map<String, dynamic> update(
    String id, {
    String? title,
    String? body,
    Map<String, dynamic>? properties,
  }) =>
      _withString(
        jsonEncode({
          'id': id,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (properties != null) 'properties': properties,
        }),
        (p) => _update(_handle, p),
      ) as Map<String, dynamic>;

  /// Removes the object from Where. Files on disk are never touched.
  void delete(String id) => _withString(id, (p) => _delete(_handle, p));

  void relate(String fromId, String toId, {String kind = 'contains', bool remove = false}) =>
      _withString(
        jsonEncode({'from': fromId, 'to': toId, 'kind': kind, 'remove': remove}),
        (p) => _relate(_handle, p),
      );

  Map<String, dynamic> indexFolder(String path) =>
      _withString(path, (p) => _index(_handle, p)) as Map<String, dynamic>;

  List<dynamic> indexRoots() => _decode(_indexRoots(_handle)) as List<dynamic>;

  List<dynamic> reindexAll() => _decode(_reindexAll(_handle)) as List<dynamic>;

  String export(String format, String path) => _withString(
        jsonEncode({'format': format, 'path': path}),
        (p) => _export(_handle, p),
      ) as String;

  /// The object saved under [key] (e.g. "url:https://…"), or null.
  Map<String, dynamic>? findSource(String key) =>
      _withString(key, (p) => _findSource(_handle, p)) as Map<String, dynamic>?;

  Map<String, dynamic> stats() => _decode(_stats(_handle)) as Map<String, dynamic>;

  void close() {
    if (_handle != nullptr) {
      _close(_handle);
      _handle = nullptr;
    }
  }
}
