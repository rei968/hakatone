import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:backend/api/middleware.dart';
import 'package:backend/api/router.dart';
import 'package:backend/db/app_database.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final db = AppDatabase.open(Platform.environment['DB_PATH'] ?? 'mangodata.db');

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cors())
      .addHandler(buildRouter(db).call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Listening on http://localhost:${server.port}');
}