import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/matakuliah.dart';
import '../models/scan_result.dart';
import '../models/user_session.dart';
import 'api_config.dart';
import 'api_service.dart';
import 'html_parser.dart';
import 'session_manager.dart';

class MahasiswaService {
  MahasiswaService._();
  static final MahasiswaService instance = MahasiswaService._();

  final _api = ApiService.instance;
  final _session = SessionManager.instance;

  Future<void> loadSessionData({String? nimFallback}) async {
    await _api.init();

    UserSession? user;

    // Try dashboard JSON API first
    try {
      final dashboard = await _api.get(ApiConfig.mahasiswaDashboardApi);
      if (_api.isSuccessfulGet(dashboard)) {
        final data = dashboard.data;
        if (data is Map<String, dynamic>) {
          final userJson = data['mahasiswa'] as Map<String, dynamic>?;
          if (userJson != null) {
            // Merge top-level attendance fields from dashboard API
            // into the userJson so UserSession.fromJson sees them.
            // Dashboard API returns: attendancePercentage, hadirCount,
            // izinCount, absenCount, totalPresensis at the top level.
            final merged = Map<String, dynamic>.from(userJson);
            void mergeIfAbsent(String srcKey, String dstKey) {
              if (!merged.containsKey(dstKey) && data.containsKey(srcKey)) {
                merged[dstKey] = data[srcKey];
              }
            }

            mergeIfAbsent('attendancePercentage', 'kehadiran');
            mergeIfAbsent('hadirCount', 'total_hadir');
            mergeIfAbsent('izinCount', 'total_izin');
            mergeIfAbsent('absenCount', 'total_alpha');
            mergeIfAbsent('totalPresensis', 'total_pertemuan');
            if (!merged.containsKey('totalSks') &&
                data.containsKey('totalSks')) {
              merged['total_sks'] = data['totalSks'];
            }
            user = UserSession.fromJson(merged);
          }
        }
      }
    } catch (_) {}

    // Fallback: try profile JSON API (apiShow wraps fields inside 'data' key)
    if (user == null) {
      try {
        final profile = await _api.get(ApiConfig.mahasiswaProfileApi);
        if (_api.isSuccessfulGet(profile)) {
          final raw = profile.data;
          if (raw is Map<String, dynamic>) {
            // apiShow wraps everything inside 'data': {success: true, data: {...}}
            final inner = raw['data'] as Map<String, dynamic>? ?? raw;
            user = UserSession.fromJson(inner);
          }
        }
      } catch (_) {}
    }

    // Always try to fetch additional fields from the Profile API
    // (Laravel apiShow wraps fields inside 'data' key)
    if (user != null) {
      try {
        final profile = await _api.get(ApiConfig.mahasiswaProfileApi);
        if (_api.isSuccessfulGet(profile)) {
          final raw = profile.data;
          if (raw is Map<String, dynamic>) {
            // Unwrap the 'data' key from apiShow response
            final inner = raw['data'] as Map<String, dynamic>? ?? raw;
            user = user.copyWith(
              nama: user.nama != 'Mahasiswa'
                  ? user.nama
                  : (inner['name']?.toString() ?? inner['nama']?.toString()),
              prodi: user.prodi ?? inner['prodi']?.toString(),
              email: (user.email != null && user.email!.isNotEmpty)
                  ? user.email
                  : inner['email']?.toString(),
              phone: (user.phone != null && user.phone!.isNotEmpty)
                  ? user.phone
                  : inner['phone']?.toString(),
              address: (user.address != null && user.address!.isNotEmpty)
                  ? user.address
                  : inner['address']?.toString(),
              jurusan: (user.jurusan != null && user.jurusan!.isNotEmpty)
                  ? user.jurusan
                  : inner['jurusan']?.toString(),
              angkatan: (user.angkatan != null && user.angkatan!.isNotEmpty)
                  ? user.angkatan
                  : inner['angkatan']?.toString(),
              noHp: (user.noHp != null && user.noHp!.isNotEmpty)
                  ? user.noHp
                  : inner['no_hp']?.toString(),
            );
          }
        }
      } catch (_) {}
    }

    _session.setUser(
      user ?? UserSession(nama: 'Mahasiswa', nim: nimFallback ?? '-'),
    );

    await loadMatakuliah();
  }

  /// Sync profile fields from profile API into the existing session user.
  /// This is called after profile edit to ensure all fields (including email)
  /// are refreshed in the UI.
  Future<void> syncProfileFields() async {
    print("SYNC PROFILE DIPANGGIL");
    final oldUser = _session.user;
    if (oldUser == null) return;

    await _api.init();
    try {
      final profile = await _api.get(ApiConfig.mahasiswaProfileApi);
      if (_api.isSuccessfulGet(profile)) {
        final raw = profile.data;
        if (raw is Map<String, dynamic>) {
          final inner = raw['data'] as Map<String, dynamic>? ?? raw;
          final profile = await _api.get(ApiConfig.mahasiswaProfileApi);

          print("PROFILE STATUS => ${profile.statusCode}");
          print("PROFILE DATA => ${profile.data}");
          _session.user = oldUser.copyWith(
            nama:
                (inner['name']?.toString() ?? inner['nama']?.toString()) ??
                oldUser.nama,
            prodi: inner['prodi']?.toString() ?? oldUser.prodi,
            email: inner['email']?.toString() ?? oldUser.email,
            phone: inner['phone']?.toString() ?? oldUser.phone,
            address: inner['address']?.toString() ?? oldUser.address,
            jurusan: inner['jurusan']?.toString() ?? oldUser.jurusan,
            angkatan: inner['angkatan']?.toString() ?? oldUser.angkatan,
            noHp: inner['no_hp']?.toString() ?? oldUser.noHp,
          );
        }
      }
    } catch (e, s) {
      print("PROFILE ERROR => $e");
      print(s);
    }
  }

  Future<Map<String, dynamic>> apiUpdateProfile({
    required String name,
    String? phone,
    String? address,
    String? jurusan,
    String? angkatan,
    String? noHp,
  }) async {
    await _api.init();

    // Refresh CSRF token before PUT to avoid CSRF mismatch
    // Use the HTML profile page (not the JSON API) so extractCsrfToken can find the token
    await _api.refreshCsrf(path: ApiConfig.mahasiswaProfile);

    final response = await _api.put(
      ApiConfig.profileEdit,
      data: {
        'name': name,
        'phone': phone,
        'address': address,
        'jurusan': jurusan,
        'angkatan': angkatan,
        'no_hp': noHp,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) {
        // Update local session with returned data
        final returned = data['data'] as Map<String, dynamic>?;
        final oldUser = _session.user;
        if (oldUser != null) {
          _session.user = oldUser.copyWith(
            nama: returned?['name']?.toString() ?? name,
            phone: returned?['phone']?.toString() ?? phone,
            address: returned?['address']?.toString() ?? address,
            jurusan: returned?['jurusan']?.toString() ?? jurusan,
            angkatan: returned?['angkatan']?.toString() ?? angkatan,
            noHp: returned?['no_hp']?.toString() ?? noHp,
          );
        }
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Profil berhasil diperbarui.',
        };
      }
      return {
        'success': false,
        'message': data['message']?.toString() ?? 'Gagal memperbarui profil.',
      };
    }

    return {'success': false, 'message': 'Gagal memperbarui profil.'};
  }

  Future<List<Matakuliah>> loadMatakuliah() async {
    await _api.init();

    final response = await _api.get(ApiConfig.mahasiswaMatakuliahApi);

    print("MATKUL STATUS => ${response.statusCode}");
    print("MATKUL DATA => ${response.data}");

    if (!_api.isSuccessfulGet(response)) {
      throw Exception('Gagal memuat daftar mata kuliah.');
    }

    final data = response.data;

    List<dynamic> jsonList;

    if (data is String) {
      jsonList = jsonDecode(data);
    } else {
      jsonList = data as List<dynamic>;
    }

    final list = jsonList.map((e) => Matakuliah.fromJson(e)).toList();
    for (final mk in list) {
      print("MODEL => ${mk.nama}");
    }
    _session.setMatakuliah(list);

    return list;
  }

  /// Validasi token — ScanQRController::scan() atau PresensiController::form()
  Future<ScanResult> validateScanToken(String rawQr) async {
    final token = extractToken(rawQr);
    if (token.isEmpty) {
      return const ScanResult(
        success: false,
        message: 'QR Code tidak dapat dibaca. Pastikan scan jelas.',
      );
    }

    final sessionError = _checkSession();
    if (sessionError != null) return sessionError;

    final useAbsenFirst = _isAbsenQrUrl(rawQr);

    if (useAbsenFirst) {
      final absen = await _validateAbsenForm(token);
      if (absen != null) return absen;
      final mahasiswa = await _validateMahasiswaScan(token);
      if (mahasiswa != null) return mahasiswa;
    } else {
      final mahasiswa = await _validateMahasiswaScan(token);
      if (mahasiswa != null) return mahasiswa;
      final absen = await _validateAbsenForm(token);
      if (absen != null) return absen;
    }

    return const ScanResult(success: false, message: 'QR tidak valid');
  }

  /// Proses absen — ScanQRController::process() atau PresensiController::store()
  Future<ScanResult> processAttendance({
    required String rawQr,
    required double latitude,
    required double longitude,
  }) async {
    final token = extractToken(rawQr);
    if (token.isEmpty) {
      return const ScanResult(
        success: false,
        message: 'QR Code tidak dapat dibaca. Pastikan scan jelas.',
      );
    }

    final sessionError = _checkSession();
    if (sessionError != null) return sessionError;

    final useAbsenFirst = _isAbsenQrUrl(rawQr);

    if (useAbsenFirst) {
      final absenResult = await _processAbsenScan(
        token: token,
        latitude: latitude,
        longitude: longitude,
      );
      if (absenResult != null && absenResult.success) return absenResult;

      final mahasiswaResult = await _processMahasiswaScan(
        token: token,
        latitude: latitude,
        longitude: longitude,
      );
      if (mahasiswaResult != null) return mahasiswaResult;

      return absenResult ??
          mahasiswaResult ??
          const ScanResult(
            success: false,
            message: 'Gagal memproses presensi.',
          );
    }

    final mahasiswaResult = await _processMahasiswaScan(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
    if (mahasiswaResult != null && mahasiswaResult.success) {
      return mahasiswaResult;
    }

    final absenResult = await _processAbsenScan(
      token: token,
      latitude: latitude,
      longitude: longitude,
    );
    if (absenResult != null) return absenResult;

    return mahasiswaResult ??
        const ScanResult(success: false, message: 'QR tidak valid');
  }

  ScanResult? _checkSession() {
    if (!_session.isLoggedIn) {
      return const ScanResult(
        success: false,
        message: 'Sesi habis. Silakan login ulang terlebih dahulu.',
      );
    }
    return null;
  }

  /// GET /mahasiswa/scan/{token} — ScanQRController::scan()
  Future<ScanResult?> _validateMahasiswaScan(String token) async {
    try {
      final response = await _api.get(ApiConfig.mahasiswaScanToken(token));

      if (_api.isRedirectToLogin(response)) {
        return const ScanResult(
          success: false,
          message: 'Sesi habis. Silakan login ulang terlebih dahulu.',
        );
      }

      if (response.statusCode == 200) {
        return const ScanResult(success: true, message: 'QR valid');
      }
    } catch (e) {
      print(e);
    }

    return null;
  }

  /// GET /absen?token= — PresensiController::form()
  Future<ScanResult?> _validateAbsenForm(String token) async {
    try {
      final response = await _api.get(
        ApiConfig.absenForm,
        queryParameters: {'token': token},
      );
      if (response.statusCode == 404) return null;

      final body = response.data?.toString() ?? '';
      if (_isValidAbsenPage(response.statusCode, body)) {
        _api.csrfToken = HtmlParser.extractCsrfToken(body) ?? _api.csrfToken;
        return const ScanResult(
          success: true,
          message: 'QR valid, siap diproses.',
        );
      }
    } catch (_) {}
    return null;
  }

  /// POST /mahasiswa/scan/process — ScanQRController::process()
  Future<ScanResult?> _processMahasiswaScan({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    print("=== MASUK PROCESS MAHASISWA ===");
    print("TOKEN = $token");
    print("LAT = $latitude");
    print("LONG = $longitude");

    try {
      await _api.refreshCsrf(path: ApiConfig.mahasiswaScanToken(token));

      final response = await _api.post(
        ApiConfig.mahasiswaScanProcess,
        data: {
          'token': token,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );

      print("STATUS = ${response.statusCode}");
      print("BODY = ${response.data}");

      return _parseStoreResponse(response);
    } catch (e) {
      print("ERROR = $e");

      return ScanResult(success: false, message: e.toString());
    }
  }

  /// POST /absen — PresensiController::store()
  Future<ScanResult?> _processAbsenScan({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final form = await _api.get(
        ApiConfig.absenForm,
        queryParameters: {'token': token},
      );
      if (form.statusCode == 404) return null;

      final formBody = form.data?.toString() ?? '';
      if (!_isValidAbsenPage(form.statusCode, formBody)) return null;
      _api.csrfToken = HtmlParser.extractCsrfToken(formBody) ?? _api.csrfToken;

      final nama = _session.user?.nim ?? _session.user?.nama ?? 'guest';
      final response = await _api.post(
        ApiConfig.absenStore,
        data: {
          'token': token,
          'nama': nama,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      );

      return _parseAbsenStoreResponse(response);
    } catch (_) {
      return null;
    }
  }

  bool _isValidAbsenPage(int? statusCode, String body) {
    if (statusCode != 200) return false;
    final lower = body.toLowerCase();
    return lower.contains('presensi.absen') ||
        lower.contains('absen') && lower.contains('token');
  }

  ScanResult _parseStoreResponse(Response<dynamic> response) {
    if (_api.isRedirectToLogin(response)) {
      return const ScanResult(
        success: false,
        message: 'Sesi habis. Silakan login ulang terlebih dahulu.',
      );
    }

    final data = response.data;
    print("DATA RESPONSE = $data");

    if (data is Map<String, dynamic>) {
      final success = data['success'] == true;
      final message =
          data['message']?.toString() ??
          (success ? 'Presensi berhasil dicatat!' : 'Presensi gagal.');

      return ScanResult(
        success: success,
        message: message,
        mataKuliah:
            data['mata_kuliah']?.toString() ?? data['matakuliah']?.toString(),
        tanggal: data['tanggal']?.toString(),
        waktu: data['waktu']?.toString(),
        status: success ? 'HADIR ✓' : null,
      );
    }

    if (data is String) {
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          return _parseStoreResponse(
            Response(requestOptions: response.requestOptions, data: json),
          );
        }
      } catch (_) {}
    }

    return const ScanResult(
      success: false,
      message: 'Gagal memproses presensi.',
    );
  }

  ScanResult _parseAbsenStoreResponse(Response<dynamic> response) {
    if (_api.isRedirectToLogin(response)) {
      return const ScanResult(
        success: false,
        message: 'Sesi habis. Silakan login ulang terlebih dahulu.',
      );
    }

    final body = response.data?.toString().toLowerCase() ?? '';
    if (body.contains('presensi.sukses') ||
        body.contains('sukses') ||
        body.contains('berhasil')) {
      return const ScanResult(
        success: true,
        message: 'Presensi berhasil dicatat!',
        status: 'HADIR ✓',
      );
    }

    return const ScanResult(
      success: false,
      message: 'Gagal memproses presensi.',
    );
  }

  static bool _isAbsenQrUrl(String rawQr) {
    final lower = rawQr.toLowerCase();
    return lower.contains('/absen') || lower.contains('absen?');
  }

  static String extractToken(String rawQr) {
    final trimmed = rawQr.trim();
    if (trimmed.isEmpty) return '';

    final tokenFromQuery = RegExp(
      r'[?&]token=([^&\s#]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (tokenFromQuery != null) {
      return Uri.decodeComponent(tokenFromQuery.group(1)!);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final queryToken = uri.queryParameters['token'];
      if (queryToken != null && queryToken.isNotEmpty) return queryToken;

      final segments = uri.pathSegments;
      final scanIndex = segments.indexOf('scan');
      if (scanIndex != -1 && scanIndex + 1 < segments.length) {
        return segments[scanIndex + 1];
      }
    }

    if (RegExp(r'^[A-Za-z0-9_-]{6,128}$').hasMatch(trimmed)) {
      return trimmed;
    }

    return '';
  }
}
