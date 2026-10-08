import 'package:dio/dio.dart';

import '../../../core/dota/rank.dart';
import '../../../core/network/api_client.dart';
import '../domain/meta_report.dart';
import 'meta_repository.dart';

/// `GET /api/meta/dota?rank=…` на бекенді команди.
class ApiMetaRepository implements MetaRepository {
  const ApiMetaRepository(this._dio);

  final Dio _dio;

  @override
  Future<MetaReport> fetchMeta({Rank rank = Rank.all}) async {
    try {
      final response = await _dio.get<Object>(
        '/api/meta/dota',
        queryParameters: rank == Rank.all ? null : {'rank': rank.apiValue},
      );
      return MetaReport.fromJson(jsonObject(response.data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
