import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/api_config.dart';

void configureApiTransport(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        // Route the socket to the IP while retaining the URI hostname for
        // TLS SNI, certificate verification and the HTTP Host header.
        final host = uri.host == ApiConfig.backendTlsHost
            ? ApiConfig.backendIp
            : uri.host;
        final task = await Socket.startConnect(
          proxyHost ?? host,
          proxyPort ?? uri.port,
        );
        if (uri.scheme != 'https' || proxyHost != null) return task;
        Socket? connected;
        final secureSocket = task.socket.then((socket) {
          connected = socket;
          return SecureSocket.secure(socket, host: uri.host);
        });
        return ConnectionTask.fromSocket(secureSocket, () {
          task.cancel();
          connected?.destroy();
        });
      };
      return client;
    },
  );
}
