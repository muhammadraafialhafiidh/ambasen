import 'package:flutter/material.dart';

class Matakuliah {
  final String kode;
  final String nama;
  final String kelas;
  final int sks;
  final String dosen;
  final String hari;
  final String jam;
  final String ruang;
  final int hadir;
  final int izin;
  final int alpha;
  final int total;
  final List<Map<String, dynamic>> sessions;

  const Matakuliah({
    required this.kode,
    required this.nama,
    required this.kelas,
    required this.sks,
    required this.dosen,
    required this.hari,
    required this.jam,
    required this.ruang,
    this.hadir = 0,
    this.izin = 0,
    this.alpha = 0,
    this.total = 0,
    this.sessions = const [],
  });
  factory Matakuliah.fromJson(Map<String, dynamic> json) {
    return Matakuliah(
      kode: json['kode'] ?? '',
      nama: json['nama'] ?? json['kode'] ?? '',
      kelas: json['kelas'] ?? '-',
      sks: int.tryParse('${json['sks'] ?? 0}') ?? 0,
      dosen: json['dosen'] ?? '-',
      hari: json['hari'] ?? '-',
      jam: json['jam'] ?? '-',
      ruang: json['ruang'] ?? '-',
      hadir: json['hadir'] ?? 0,
      izin: json['izin'] ?? 0,
      alpha: json['alpha'] ?? 0,
      total: json['total'] ?? 0,
      sessions:
          (json['sessions'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }
  Color get color {
    final hash = kode.hashCode.abs();
    final colors = [
      const Color(0xFF800020),
      const Color(0xFF0D6EFD),
      const Color(0xFF198754),
      const Color(0xFF6F42C1),
      const Color(0xFFFD7E14),
    ];
    return colors[hash % colors.length];
  }

  IconData get icon {
    final icons = [
      Icons.memory,
      Icons.storage,
      Icons.code,
      Icons.computer,
      Icons.menu_book,
    ];
    return icons[kode.hashCode.abs() % icons.length];
  }

  Map<String, dynamic> toUiMap() {
    return {
      'kode': kode,
      'nama': nama,
      'kelas': kelas,
      'sks': sks,
      'dosen': dosen,
      'hari': hari,
      'jam': jam,
      'ruang': ruang,
      'color': color,
      'icon': icon,
      'hadir': hadir,
      'izin': izin,
      'alpha': alpha,
      'total': total,
      'sessions': sessions,
    };
  }
}
