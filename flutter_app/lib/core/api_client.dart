import 'dart:io';

import 'package:dio/dio.dart';

import 'models.dart';
import 'storage.dart';

class ApiException implements Exception {
  final int? code;
  final String message;

  ApiException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// API 客户端: 统一 Result 解析 + JWT + multipart 上传
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  /// 统一入口: Docker Nginx /snapcal/ → snapcal-server:8081 (8081 直连兜底)
  static const baseUrl = 'http://myblog.wiki/snapcal/api';

  final _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  void Function()? onUnauthorized;

  Future<Options> _opts() async {
    final token = await TokenStore.read();
    return Options(headers: {if (token != null) 'Authorization': 'Bearer $token'});
  }

  dynamic _unwrap(Response resp) {
    final j = resp.data;
    if (j is! Map<String, dynamic>) throw ApiException('响应格式异常');
    final code = j['code'] as int? ?? -1;
    if (code == 401) {
      onUnauthorized?.call();
      throw ApiException('登录已过期，请重新登录', 401);
    }
    if (code != 200) throw ApiException(j['message'] as String? ?? '请求失败 ($code)', code);
    return j['data'];
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, required T Function(dynamic data) fromJson}) async {
    try {
      final resp = await _dio.get(path, queryParameters: query, options: await _opts());
      return fromJson(_unwrap(resp));
    } on DioException catch (e) {
      throw ApiException('网络异常: ${e.message}');
    }
  }

  Future<T> post<T>(String path, {Object? body, required T Function(dynamic data) fromJson}) async {
    try {
      final resp = await _dio.post(path, data: body, options: await _opts());
      return fromJson(_unwrap(resp));
    } on DioException catch (e) {
      throw ApiException('网络异常: ${e.message}');
    }
  }

  Future<T> put<T>(String path, {Object? body, required T Function(dynamic data) fromJson}) async {
    try {
      final resp = await _dio.put(path, data: body, options: await _opts());
      return fromJson(_unwrap(resp));
    } on DioException catch (e) {
      throw ApiException('网络异常: ${e.message}');
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path, options: await _opts());
    } on DioException catch (e) {
      throw ApiException('网络异常: ${e.message}');
    }
  }

  /// multipart 上传 (图片识别 / 头像)
  Future<T> upload<T>(String path, {required File file, required T Function(dynamic data) fromJson, String fieldName = 'file'}) async {
    try {
      final form = FormData.fromMap({fieldName: await MultipartFile.fromFile(file.path)});
      final resp = await _dio.post(path, data: form, options: await _opts());
      return fromJson(_unwrap(resp));
    } on DioException catch (e) {
      throw ApiException('上传失败: ${e.message}');
    }
  }

  // MARK: - 业务接口封装

  Future<User> me() => get('/user/me', fromJson: (d) => User.fromJson(d));

  Future<void> sendEmailCode(String email, {required String purpose}) =>
      postVoid('/auth/email-code', body: {'email': email, 'purpose': purpose});

  Future<(String, User)> login(String account, String password) async {
    final d = await post(
      '/auth/login',
      body: {'username': account, 'password': password},
      fromJson: (d) => d as Map<String, dynamic>,
    );
    return (d['token'] as String, User.fromJson(d['user']));
  }

  Future<(String, User)> register({
    required String username,
    required String email,
    required String password,
    required String code,
  }) async {
    final d = await post(
      '/auth/register',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'code': code,
      },
      fromJson: (d) => d as Map<String, dynamic>,
    );
    return (d['token'] as String, User.fromJson(d['user']));
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      postVoid('/auth/password/reset',
          body: {'email': email, 'code': code, 'newPassword': newPassword});

  /// POST 但后端 data 为 null (只校验 code)
  Future<void> postVoid(String path, {Object? body}) =>
      post(path, body: body, fromJson: (_) => const <String, dynamic>{});

  Future<User> updateProfile(Map<String, dynamic> body) => put('/user/profile', body: body, fromJson: (d) => User.fromJson(d));

  Future<User> uploadAvatar(File file) => upload('/user/avatar', file: file, fromJson: (d) => User.fromJson(d));

  Future<Meal> saveMeal(MealSaveReq req) => post('/meal', body: req.toJson(), fromJson: (d) => Meal.fromJson(d));

  Future<Meal> updateMeal(int id, MealUpdateReq req) => put('/meal/$id', body: req.toJson(), fromJson: (d) => Meal.fromJson(d));

  Future<void> deleteMeal(int id) => delete('/meal/$id');

  Future<List<Meal>> mealsOfDay([DateTime? day]) => get('/meal/day', query: day == null ? null : {'date': dateKey(day)}, fromJson: (d) => (d as List).map((e) => Meal.fromJson(e)).toList());

  Future<Map<String, List<Meal>>> mealsRange(int days) => get('/meal/range', query: {'days': '$days'}, fromJson: (d) => (d as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).map((e) => Meal.fromJson(e)).toList())));

  Future<RecognizeResult> recognize(File image) => upload('/vision/recognize', file: image, fromJson: (d) => RecognizeResult.fromJson(d));

  Future<List<Food>> searchFood(String kw) => get('/food/search', query: {'kw': kw}, fromJson: (d) => (d as List).map((e) => Food.fromJson(e)).toList());

  Future<List<Food>> foodCategories() => get('/food/categories', fromJson: (d) => (d as List).map((e) => Food.fromJson({'id': 0, 'name': e})).toList());

  Future<({List<Food> records, int total})> foodList({required int page, int size = 50, String? kw, String? category}) => get('/food/list', query: {'current': '$page', 'size': '$size', if (kw != null && kw.isNotEmpty) 'kw': kw, if (category != null) 'category': category}, fromJson: (d) => (records: (d['records'] as List).map((e) => Food.fromJson(e)).toList(), total: (d['total'] as num).toInt()));

  Future<List<Food>> favorites() => get('/food/favorites', fromJson: (d) => (d as List).map((e) => Food.fromJson(e)).toList());

  Future<bool> toggleFavorite(int foodId) => post('/food/favorites/$foodId/toggle', body: {}, fromJson: (d) => d['favored'] as bool);

  Future<List<Food>> recentFoods() => get('/food/recent', fromJson: (d) => (d as List).map((e) => Food.fromJson(e)).toList());

  Future<WaterToday> waterToday() => get('/water/today', fromJson: (d) => WaterToday.fromJson(d));

  Future<WaterToday> waterAdd(int ml) => post('/water', body: {'amountMl': ml}, fromJson: (d) => WaterToday.fromJson(d));

  Future<List<DailyIntake>> statsDaily(int days) => get('/stats/daily', query: {'days': '$days'}, fromJson: (d) => (d as List).map((e) => DailyIntake.fromJson(e)).toList());

  Future<List<WeightRecord>> weightList(int days) => get('/weight/list', query: {'days': '$days'}, fromJson: (d) => (d as List).map((e) => WeightRecord.fromJson(e)).toList());

  Future<void> weightSave(double kg) async => post('/weight', body: {'weightKg': kg}, fromJson: (d) => d);
}
