import 'package:syllabind/services/skema_db.dart';

/// Entitas Lampiran (Attachment: Gambar atau File).
///
/// Tabel: `lampiran` ([SkemaDb.tabelLampiran]).
/// Satu tabel untuk keduanya, dibedakan kolom `tipe` (GAMBAR/FILE).
/// FK ke [Materi] dengan CASCADE on purge.
/// File fisik disalin ke `app_documents/lampiran/` saat ditambah.
class Lampiran {
  static const String tipeGambar = SkemaDb.tipeGambar;
  static const String tipeFile = SkemaDb.tipeFile;

  final int? id;
  final int materiId;
  final String tipe; // GAMBAR | FILE
  final String namaFile; // Nama asli file
  final String lokasiFile; // Path absolut di app_documents/lampiran/
  final int ukuranFile; // Byte
  final DateTime createdAt;

  Lampiran({
    this.id,
    required this.materiId,
    required this.tipe,
    required this.namaFile,
    required this.lokasiFile,
    this.ukuranFile = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// True jika tipe == GAMBAR.
  bool get gambar => tipe == tipeGambar;

  /// Ukuran dalam bentuk terbaca, mis. "1,4 MB".
  String get ukuranTerbaca {
    if (ukuranFile < 1024) return '$ukuranFile B';
    if (ukuranFile < 1024 * 1024) {
      return '${(ukuranFile / 1024).toStringAsFixed(1)} KB';
    }
    return '${(ukuranFile / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Mengubah ke Map untuk INSERT ke SQLite.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'materi_id': materiId,
        'tipe': tipe,
        'nama_file': namaFile,
        'lokasi_file': lokasiFile,
        'ukuran_file': ukuranFile,
        'created_at': createdAt.toIso8601String(),
      };

  /// Membuat [Lampiran] dari baris hasil query SQLite.
  factory Lampiran.fromMap(Map<String, Object?> m) => Lampiran(
        id: m['id'] as int?,
        materiId: m['materi_id'] as int,
        tipe: m['tipe'] as String,
        namaFile: m['nama_file'] as String,
        lokasiFile: m['lokasi_file'] as String,
        ukuranFile: (m['ukuran_file'] as int?) ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
