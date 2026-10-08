import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/hero_details.dart';
import 'hero_repository.dart';

/// `GET /api/dota/heroes/{id}` на бекенді команди.
class ApiHeroRepository implements HeroRepository {
  const ApiHeroRepository(this._dio);

  final Dio _dio;

  @override
  Future<HeroDetails> fetchHero(int id) async {
    try {
      final response = await _dio.get<Object>('/api/dota/heroes/$id');
      return HeroDetails.fromJson(jsonObject(response.data));
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (error.failure == ApiFailure.notFound) throw HeroNotFoundException(id);
      throw error;
    }
  }
}
