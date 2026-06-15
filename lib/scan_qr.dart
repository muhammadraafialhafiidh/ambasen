import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dashboard.dart';
import 'list_matakuliah.dart';
import 'models/scan_result.dart';
import 'profil.dart';
import 'izin.dart';
import 'services/location_service.dart';
import 'services/mahasiswa_service.dart';
import 'services/session_manager.dart';
import 'services/fixed_fab.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _step = 1; // 1: scan, 2: process, 3: result
  bool _isSuccess = false;
  bool _isProcessing = false;
  bool _cameraReady = false;
  bool _locationReady = false;
  ScanResult? _scanResult;
  final _session = SessionManager.instance;
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );

  late AnimationController _beamController;
  late Animation<double> _beamAnimation;
  Timer? _timer;

  final Color _maroon = const Color(0xFF800020);
  final Color _maroonDark = const Color(0xFF5A0016);
  final Color _maroonLight = const Color(0xFFC0003A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _beamAnimation = Tween<double>(begin: 0, end: 230).animate(_beamController);
    _beamController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    _preparePermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraReady || _step != 1) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_scannerController.start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_scannerController.stop());
    }
  }

  Future<void> _preparePermissions() async {
    try {
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }
      if (!cameraStatus.isGranted) return;

      final locationGranted = await LocationService.instance.ensurePermission();
      if (!locationGranted) return;

      await LocationService.instance.getCurrentPosition(useCache: false);

      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _locationReady = true;
      });
      if (_step == 1) await _scannerController.start();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _beamController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetected(String rawValue) async {
    if (_isProcessing || _step != 1 || !_cameraReady || !_locationReady) return;
    _isProcessing = true;
    await _scannerController.stop();

    setState(() {
      _step = 2;
      _beamController.duration = const Duration(milliseconds: 400);
      _beamController.repeat();
    });

    try {
      final validation = await MahasiswaService.instance.validateScanToken(rawValue);
      if (!validation.success) {
        _finishScan(false, validation);
        return;
      }

      final position = await LocationService.instance.getCurrentPosition();
      final result = await MahasiswaService.instance.processAttendance(
        rawQr: rawValue,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _finishScan(result.success, result);
    } on LocationException catch (e) {
      _finishScan(false, ScanResult(success: false, message: e.message));
    } catch (e) {
      _finishScan(
        false,
        ScanResult(success: false, message: 'Gagal memproses presensi: $e'),
      );
    } finally {
      _isProcessing = false;
    }
  }

  void _finishScan(bool success, ScanResult result) {
    if (!mounted) return;
    setState(() {
      _step = 3;
      _isSuccess = success;
      _scanResult = result;
      _beamController.stop();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? '✅ Presensi berhasil dicatat!' : '❌ ${result.message}',
        ),
        backgroundColor:
            success ? const Color(0xFF198754) : const Color(0xFFDC3545),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getDateStr() {
    final now = DateTime.now();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final weekdays = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _getTimeStr() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _resetScan() {
    setState(() {
      _step = 1;
      _isSuccess = false;
      _scanResult = null;
      _isProcessing = false;
      _beamController.duration = const Duration(seconds: 2);
      _beamController.repeat();
    });
    if (_cameraReady) _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeader(),
                _buildStepIndicator(),
                _buildScanViewport(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _step == 3 ? _buildResultCard() : _buildScanButtons(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 68,
        width: 68,
        margin: const EdgeInsets.only(top: 30),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_maroonDark, _maroonLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _maroon.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Center(
              child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: const FixedCenterDockedFabLocation(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_maroonDark, _maroon],
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan QR Presensi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'Arahkan kamera ke QR code dosen',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepDot(1),
                _buildStepLine(2),
                _buildStepDot(2),
                _buildStepLine(3),
                _buildStepDot(3),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              _step == 1
                  ? 'Langkah 1: Mulai scan kamera'
                  : (_step == 2
                      ? 'Langkah 2: Memproses QR Code...'
                      : 'Langkah 3: Selesai'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int dotStep) {
    final isDone = dotStep < _step;
    final isActive = dotStep == _step;

    final bgColor = isDone ? const Color(0xFF198754) : Colors.white;
    final borderColor = isDone
        ? const Color(0xFF198754)
        : (isActive ? _maroon : Colors.grey.shade300);
    final textColor =
        isDone ? Colors.white : (isActive ? _maroon : Colors.grey.shade400);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$dotStep',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine(int targetStep) {
    final isDone = targetStep <= _step;
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? const Color(0xFF198754) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildScanViewport() {
    return Container(
      height: 320,
      color: const Color(0xFF1A1A2E),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_cameraReady && _locationReady && _step < 3)
            Positioned.fill(
              child: ClipRect(
                child: MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    if (_isProcessing || _step != 1) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value != null && value.isNotEmpty) {
                      unawaited(_handleQrDetected(value));
                    }
                  },
                ),
              ),
            ),
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFFFD700), width: 3),
                        left: BorderSide(color: Color(0xFFFFD700), width: 3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFFFD700), width: 3),
                        right: BorderSide(color: Color(0xFFFFD700), width: 3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFFFD700), width: 3),
                        left: BorderSide(color: Color(0xFFFFD700), width: 3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFFFD700), width: 3),
                        right: BorderSide(color: Color(0xFFFFD700), width: 3),
                      ),
                    ),
                  ),
                ),
                if (!_cameraReady || !_locationReady)
                  Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 80,
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                if (_step < 3)
                  AnimatedBuilder(
                    animation: _beamAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _beamAnimation.value,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFFFFD700),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _step == 1
                    ? Colors.amber.shade700
                    : (_step == 2
                        ? Colors.lightBlue
                        : (_isSuccess
                            ? const Color(0xFF198754)
                            : const Color(0xFFDC3545))),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _step == 1
                        ? Icons.videocam
                        : (_step == 2
                            ? Icons.sync
                            : (_isSuccess ? Icons.check : Icons.warning)),
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _step == 1
                        ? 'Menunggu QR...'
                        : (_step == 2
                            ? 'Memproses...'
                            : (_isSuccess ? 'Terdeteksi!' : 'Gagal...')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButtons() {
    final nama = _session.user?.nama ?? 'Mahasiswa';
    final nim = _session.user?.nim ?? '-';

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              _buildInfoRow(Icons.person, '$nama  $nim'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.calendar_today, _getDateStr()),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, _getTimeStr()),
            ],
          ),
        ),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Arahkan kamera ke QR Code dari layar dosen. '
                'Pastikan izin kamera dan lokasi sudah diaktifkan.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _maroon, size: 18),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(_isSuccess ? '✅' : '❌', style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          Text(
            _isSuccess ? 'Presensi Berhasil!' : 'Scan Gagal!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isSuccess
                  ? const Color(0xFF198754)
                  : const Color(0xFFDC3545),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSuccess
                ? 'Kehadiran Anda telah tercatat oleh sistem.'
                : 'QR Code tidak valid atau sudah kadaluarsa. Hubungi dosen Anda.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_isSuccess)
            Column(
              children: [
                if (_scanResult?.mataKuliah != null) ...[
                  _buildResultRow(
                    Icons.book,
                    'Mata Kuliah',
                    _scanResult!.mataKuliah!,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildResultRow(
                  Icons.calendar_today,
                  'Tanggal',
                  _scanResult?.tanggal ?? _getDateStr(),
                ),
                const SizedBox(height: 8),
                _buildResultRow(
                  Icons.access_time,
                  'Waktu',
                  _scanResult?.waktu ?? _getTimeStr(),
                ),
                const SizedBox(height: 8),
                _buildResultRow(
                  Icons.person,
                  'Status',
                  _scanResult?.status ?? 'HADIR ✓',
                  valColor: const Color(0xFF198754),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC3545).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Color(0xFFDC3545), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanResult?.message ??
                          'QR Code telah expired atau di luar area yang diizinkan.',
                      style: const TextStyle(
                        color: Color(0xFFDC3545),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Scan Lagi',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _maroon,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(
    IconData icon,
    String label,
    String val, {
    Color? valColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: _maroon, size: 16),
          const SizedBox(width: 8),
          Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: valColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Beranda', 0),
            _buildNavItem(Icons.menu_book, 'Mata Kuliah', 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.description, 'Izin', 2),
            _buildNavItem(Icons.person, 'Profil', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () {
        Widget? targetPage;
        if (index == 0) targetPage = const DashboardScreen();
        if (index == 1) targetPage = const ListMatakuliahScreen();
        if (index == 2) targetPage = const IzinScreen();
        if (index == 3) targetPage = const ProfilScreen();

        if (targetPage != null) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => targetPage!,
              transitionDuration: Duration.zero,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
