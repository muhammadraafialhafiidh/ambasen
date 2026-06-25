import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'api_config.dart';
import 'html_parser.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  late final Dio _dio;
  late final CookieJar _cookieJar;
  String? csrfToken;
  bool _initialized = false;

  Dio get dio => _dio;
  CookieJar get cookieJar => _cookieJar;
  Future<void> init() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${appDir.path}/.cookies/'),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: ApiConfig.defaultHeaders,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(CookieManager(_cookieJar));
    _initialized = true;
  }

  Future<void> refreshCsrf({
    String path = ApiConfig.loginPath,
    Map<String, dynamic>? queryParameters,
  }) async {
    await init();
    final response = await _dio.get(path, queryParameters: queryParameters);
    final html = response.data?.toString() ?? '';

    print("GET LOGIN STATUS => ${response.statusCode}");

    final token = HtmlParser.extractCsrfToken(html);

    print("TOKEN PARSED => $token");

    csrfToken = token ?? csrfToken;

    print("TOKEN FINAL => $csrfToken");
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool followRedirects = false,
  }) async {
    await init();

    final cookies = await _cookieJar.loadForRequest(
      Uri.parse("${ApiConfig.baseUrl}$path"),
    );

    print("GET URL => ${ApiConfig.baseUrl}$path");
    print("COOKIES SENT =>");

    for (final c in cookies) {
      print("${c.name}=${c.value}");
    }

    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(followRedirects: followRedirects, maxRedirects: 5),
    );
  }

  bool isRedirectToLogin(Response<dynamic> response) {
    if (response.statusCode != 302 && response.statusCode != 301) {
      return false;
    }
    final location = response.headers.value('location') ?? '';
    return location.contains('login');
  }

  Future<Response<dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();

    final headers = <String, dynamic>{
      'Accept': 'application/json',
      if (csrfToken != null) 'X-CSRF-TOKEN': csrfToken,
    };

    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(
        headers: {...?options?.headers, ...headers},
        contentType: Headers.jsonContentType,
      ),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();
    final payload = Map<String, dynamic>.from(data ?? {});
    if (csrfToken != null) {
      payload['_token'] = csrfToken;
    }

    final headers = <String, dynamic>{
      if (csrfToken != null) 'X-CSRF-TOKEN': csrfToken,
    };

    return _dio.delete(
      path,
      data: payload,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(
        headers: {...?options?.headers, ...headers},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await init();
    final payload = Map<String, dynamic>.from(data ?? {});
    if (csrfToken != null) {
      payload['_token'] = csrfToken;
    }

    final headers = <String, dynamic>{
      if (csrfToken != null) 'X-CSRF-TOKEN': csrfToken,
    };

    return _dio.post(
      path,
      data: payload,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(
        headers: {...?options?.headers, ...headers},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
  }

  Future<void> clearSession() async {
    await init();

    print("CLEARING COOKIES");

    final cookiesBefore = await _cookieJar.loadForRequest(
      Uri.parse(ApiConfig.baseUrl),
    );

    print("BEFORE DELETE => ${cookiesBefore.length}");

    await _cookieJar.deleteAll();

    final cookiesAfter = await _cookieJar.loadForRequest(
      Uri.parse(ApiConfig.baseUrl),
    );

    print("AFTER DELETE => ${cookiesAfter.length}");

    csrfToken = null;
  }

  bool isRedirectToMahasiswa(Response<dynamic> response) {
    final location = response.headers.value('location') ?? '';
    return location.contains('/mahasiswa');
  }

  bool isRedirectToDosen(Response<dynamic> response) {
    final location = response.headers.value('location') ?? '';
    return location.contains('/dosen');
  }

  bool isSuccessfulGet(Response<dynamic> response) {
    return response.statusCode == 200;
  }
}
