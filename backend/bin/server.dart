import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:backend/ai/gemini_client.dart';
import 'package:backend/ai/hero_analyzer.dart';
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
  final openDota = OpenDotaClient();

  final geminiKey = env['GEMINI_API_KEY'] ?? '';
  final analyzer = geminiKey.isEmpty
      ? null
      : HeroAnalyzer(db, openDota, GeminiClient(apiKey: geminiKey, model: env['GEMINI_MODEL'] ?? 'gemini-3.5-flash-lite'));
  if (analyzer == null) print('AI analysis disabled: GEMINI_API_KEY is not set');

  final sync = HeroSync(db, openDota, analyzer: analyzer);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(cors())
      .addHandler(buildRouter(db, sync, analyzer).call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Listening on http://localhost:${server.port}');

  sync.startPeriodic(syncInterval);
}
