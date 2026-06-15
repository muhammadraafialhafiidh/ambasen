class UserSession {
  final String nama;
  final String nim;
  final String? prodi;
  final String? email;
  final double? kehadiranPersen;
  final int? totalHadir;
  final int? totalIzin;
  final int? totalAlpha;
  final int? totalSks;
  final int? totalPertemuan;

  const UserSession({
    required this.nama,
    required this.nim,
    this.prodi,
    this.email,
    this.kehadiranPersen,
    this.totalHadir,
    this.totalIzin,
    this.totalAlpha,
    this.totalSks,
    this.totalPertemuan,
  });

  String get initials {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get displaySubtitle {
    final prodiText = prodi != null && prodi!.isNotEmpty ? ' · $prodi' : '';
    return 'NIM: $nim$prodiText';
  }

  UserSession copyWith({
    String? nama,
    String? nim,
    String? prodi,
    String? email,
    double? kehadiranPersen,
    int? totalHadir,
    int? totalIzin,
    int? totalAlpha,
    int? totalSks,
    int? totalPertemuan,
  }) {
    return UserSession(
      nama: nama ?? this.nama,
      nim: nim ?? this.nim,
      prodi: prodi ?? this.prodi,
      email: email ?? this.email,
      kehadiranPersen: kehadiranPersen ?? this.kehadiranPersen,
      totalHadir: totalHadir ?? this.totalHadir,
      totalIzin: totalIzin ?? this.totalIzin,
      totalAlpha: totalAlpha ?? this.totalAlpha,
      totalSks: totalSks ?? this.totalSks,
      totalPertemuan: totalPertemuan ?? this.totalPertemuan,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      nama: json['nama']?.toString() ?? 'Mahasiswa',
      nim: json['nim']?.toString() ?? '-',
      prodi: json['prodi']?.toString(),
      email: json['email']?.toString(),
      kehadiranPersen: (json['kehadiran'] is num)
          ? (json['kehadiran'] as num).toDouble()
          : double.tryParse(json['kehadiran']?.toString() ?? ''),
      totalHadir: json['total_hadir'] is int
          ? json['total_hadir']
          : int.tryParse('${json['total_hadir'] ?? 0}'),
      totalIzin: json['total_izin'] is int
          ? json['total_izin']
          : int.tryParse('${json['total_izin'] ?? 0}'),
      totalAlpha: json['total_alpha'] is int
          ? json['total_alpha']
          : int.tryParse('${json['total_alpha'] ?? 0}'),
      totalSks: json['total_sks'] is int
          ? json['total_sks']
          : int.tryParse('${json['total_sks'] ?? 0}'),
      totalPertemuan: json['total_pertemuan'] is int
          ? json['total_pertemuan']
          : int.tryParse('${json['total_pertemuan'] ?? json['totalPresensis']?.toString() ?? '0'}'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nim': nim,
      'prodi': prodi,
      'email': email,
      'kehadiran': kehadiranPersen,
      'total_hadir': totalHadir,
      'total_izin': totalIzin,
      'total_alpha': totalAlpha,
      'total_sks': totalSks,
      'total_pertemuan': totalPertemuan,
    };
  }
}
