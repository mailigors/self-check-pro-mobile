import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

const backendOrigin = 'http://185.108.211.9:8081';
const proxyPort = 3001;

const _hopByHop = {
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailers',
  'transfer-encoding',
  'upgrade',
  'host',
  'origin',
  'referer',
  'content-length',
};

Future<void> main() async {
  final backend = Uri.parse(backendOrigin);
  final client = HttpClient()..autoUncompress = false;

  Future<Response> forward(Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('');
    }

    final target = backend.replace(
      path: request.requestedUri.path,
      query: request.requestedUri.hasQuery ? request.requestedUri.query : null,
    );

    try {
      final outbound = await client.openUrl(request.method, target);
      outbound.followRedirects = false;
      request.headers.forEach((name, value) {
        if (_hopByHop.contains(name.toLowerCase())) return;
        outbound.headers.set(name, value);
      });
      // Host с портом, иначе nginx/Spring часто отдают 404 на чужом vhost.
      outbound.headers.set(
        HttpHeaders.hostHeader,
        backend.hasPort ? '${backend.host}:${backend.port}' : backend.host,
      );
      stdout.writeln('${request.method} ${request.requestedUri.path} -> $target');
      if (request.method != 'GET' && request.method != 'HEAD') {
        await outbound.addStream(request.read());
      }
      final inbound = await outbound.close();
      final headers = <String, String>{};
      inbound.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'transfer-encoding' || lower == 'content-encoding') return;
        if (values.isNotEmpty) headers[name] = values.join(',');
      });
      return Response(inbound.statusCode, body: inbound, headers: headers);
    } catch (error, stack) {
      stderr.writeln('Proxy error $target\n$error\n$stack');
      return Response(
        HttpStatus.badGateway,
        body: 'Нет соединения с API ($target): $error',
      );
    }
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: {
            ACCESS_CONTROL_ALLOW_ORIGIN: '*',
            ACCESS_CONTROL_ALLOW_METHODS: 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
            ACCESS_CONTROL_ALLOW_HEADERS:
                'Origin,Content-Type,Authorization,Accept,X-Requested-With',
            ACCESS_CONTROL_EXPOSE_HEADERS: 'Authorization,Content-Type',
          },
        ),
      )
      .addHandler(forward);

  final server = await io.serve(handler, InternetAddress.anyIPv4, proxyPort);
  stdout.writeln(
    'API proxy listening on http://127.0.0.1:${server.port} -> $backendOrigin',
  );
}
