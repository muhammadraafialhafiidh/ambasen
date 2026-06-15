class ScanResult {
  final bool success;
  final String message;
  final String? mataKuliah;
  final String? tanggal;
  final String? waktu;
  final String? status;

  const ScanResult({
    required this.success,
    required this.message,
    this.mataKuliah,
    this.tanggal,
    this.waktu,
    this.status,
  });
}
