import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/meta_report.dart';

/// `GET /api/meta/dota` з `docs/openapi.yaml`.
abstract interface class MetaRepository {
  Future<MetaReport> fetchMeta();
}

/// Віддає `assets/mocks/meta.json` — копію `backend/database/seeds/meta.json`.
class MockMetaRepository implements MetaRepository {
  MockMetaRepository({AssetBundle? bundle, this.latency = const Duration(milliseconds: 600)})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<MetaReport> fetchMeta() async {
    await Future<void>.delayed(latency);
    final raw = await _bundle.loadString('assets/mocks/meta.json');
    return MetaReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
