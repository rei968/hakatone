import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:backend/api/middleware.dart';
import 'package:backend/api/router.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/opendota/opendota_client.dart';
import 'package:backend/sync/hero_sync.dart';

Future<void> main() async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8080');
  final syncInterval = Duration(hours: int.parse(env['SYNC_INTERVAL_HOURS'] ?? '6'));

  final db = AppDatabase.open(env['DB_PATH'] ?? 'mangodata.db');
  final sync = HeroSync(db, OpenDotaClient());

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cors())
      .addHandler(buildRouter(db, sync).call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Listening on http://localhost:${server.port}');

  sync.startPeriodic(syncInterval);
}
