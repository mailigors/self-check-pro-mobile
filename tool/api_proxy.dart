import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_proxy/shelf_proxy.dart';

const backendOrigin = 'http://192.168.0.161:3002';
const proxyPort = 3001;

Future<void> main() async {
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
      .addHandler(proxyHandler(backendOrigin));

  final server = await io.serve(handler, InternetAddress.anyIPv4, proxyPort);
  stdout.writeln(
    'CORS proxy listening on http://${server.address.address}:${server.port} -> $backendOrigin',
  );
}
