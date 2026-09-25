import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'state.dart';
import 'where_core.dart';

/// A small HTTP server that lets the Where browser extension save links.
///
/// Security (spec §26):
/// - Listens on 127.0.0.1 only — never reachable from the network.
/// - A browser must be approved once in Where (Allow / Deny dialog); it then
///   sends its token in the `X-Where-Token` header on every request.
/// - Requests from web pages are refused: only browser-extension origins are
///   accepted, and no CORS headers are sent, so pages can't read responses.
/// - Only http(s) links are stored; bodies are capped at 64 KB.
class BrowserBridge {
  BrowserBridge(this.state);

  static const port = 47771;
  static const version = '0.3.0';
  static const _maxBody = 64 * 1024;

  final WhereState state;
  HttpServer? _server;
  String? error;

  bool get running => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _server = server;
      error = null;
      server.listen((req) {
        _handle(req);
      }, onError: (_) {});
    } catch (e) {
      error = 'Port $port is already in use, so browsers can’t connect. '
          'Is another copy of Where running?';
    }
    state.bump();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final origin = req.headers.value('origin');
      if (origin != null && !_isExtensionOrigin(origin)) {
        return _send(res, 403, {'error': 'Only the Where browser extension can talk to Where.'});
      }
      final path = req.uri.path;
      final method = req.method;

      if (method == 'GET' && path == '/v1/status') {
        return _send(res, 200, {'app': 'Where', 'version': version, 'connected': _authorized(req)});
      }

      if (method == 'POST' && path == '/v1/pair') {
        final body = await _json(req);
        final client = _clean(body['client'] as String?, 40, fallback: 'Your browser');
        final token = await state.requestBrowserPairing(client);
        if (token == null) {
          return _send(res, 403, {'error': 'The connection was declined in Where.'});
        }
        return _send(res, 200, {'token': token});
      }

      if (!_authorized(req)) {
        return _send(res, 401, {'error': 'Not connected yet. Click Connect in the extension.'});
      }

      if (method == 'GET' && path == '/v1/projects') {
        final projects = state.list('project');
        return _send(res, 200, {
          'projects': [
            for (final p in projects) {'id': p.id, 'title': p.title},
          ],
        });
      }

      if (method == 'GET' && path == '/v1/links/lookup') {
        final url = req.uri.queryParameters['url'] ?? '';
        final link = LinkInfo.isWebUrl(url) ? state.findLink(url) : null;
        if (link == null) return _send(res, 200, {'link': null});
        final detail = state.detail(link.id);
        final project = detail?.parents.where((p) => p.kind == 'project').toList() ?? const <WObject>[];
        return _send(res, 200, {
          'link': {
            'id': link.id,
            'title': link.title,
            'note': link.body,
            'project_id': project.isEmpty ? null : project.first.id,
          },
        });
      }

      if (method == 'POST' && path == '/v1/links') {
        final body = await _json(req);
        final url = (body['url'] as String? ?? '').trim();
        if (!LinkInfo.isWebUrl(url)) {
          return _send(res, 400, {'error': 'Only web pages (http or https) can be saved.'});
        }
        final projectId = body['project_id'] as String?;
        final link = state.saveLink(
          url: url,
          title: _clean(body['title'] as String?, 300),
          note: body.containsKey('note') ? (body['note'] as String? ?? '') : null,
          projectId: (projectId == null || projectId.isEmpty) ? null : projectId,
          source: _clean(body['client'] as String?, 40, fallback: 'Browser'),
        );
        state.toast('Saved from your browser: ${link.title}');
        return _send(res, 200, {'id': link.id, 'title': link.title});
      }

      return _send(res, 404, {'error': 'Unknown request.'});
    } on WhereException catch (e) {
      return _send(res, 400, {'error': e.message});
    } on FormatException {
      return _send(res, 400, {'error': 'That request wasn’t valid.'});
    } catch (e) {
      return _send(res, 500, {'error': 'Something went wrong in Where: $e'});
    }
  }

  static bool _isExtensionOrigin(String origin) =>
      origin.startsWith('chrome-extension://') ||
      origin.startsWith('moz-extension://') ||
      origin.startsWith('extension://');

  bool _authorized(HttpRequest req) => state.isBrowserToken(req.headers.value('x-where-token'));

  static String _clean(String? s, int max, {String fallback = ''}) {
    final v = (s ?? '').replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (v.isEmpty) return fallback;
    return v.length > max ? v.substring(0, max) : v;
  }

  static Future<Map<String, dynamic>> _json(HttpRequest req) async {
    final bytes = <int>[];
    await for (final chunk in req) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBody) throw const FormatException('too large');
    }
    if (bytes.isEmpty) return {};
    final v = jsonDecode(utf8.decode(bytes));
    if (v is! Map<String, dynamic>) throw const FormatException('not an object');
    return v;
  }

  static Future<void> _send(HttpResponse res, int status, Map<String, dynamic> body) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.headers.set('Cache-Control', 'no-store');
    res.write(jsonEncode(body));
    await res.close();
  }
}
