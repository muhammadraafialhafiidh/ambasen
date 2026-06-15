class Izin {
  final int id;
  final String mk;
  final String jenis;
  final String tgl;
  final String status;
  final String ket;
  final String catatan;
  final String diajukan;

  const Izin({
    required this.id,
    required this.mk,
    required this.jenis,
    required this.tgl,
    required this.status,
    required this.ket,
    this.catatan = '',
    this.diajukan = '',
  });

  factory Izin.fromJson(Map<String, dynamic> json) {
    return Izin(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      mk: json['mk']?.toString() ?? json['matakuliah']?.toString() ?? json['mata_kuliah']?.toString() ?? '-',
      jenis: json['jenis']?.toString() ?? '-',
      tgl: json['tgl']?.toString() ?? json['tanggal']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'Menunggu',
      ket: json['ket']?.toString() ?? json['keterangan']?.toString() ?? '',
      catatan: json['catatan']?.toString() ?? '',
      diajukan: json['diajukan']?.toString() ?? json['created_at']?.toString() ?? '',
    );
  }
}