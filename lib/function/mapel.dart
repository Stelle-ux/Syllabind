import 'package:syllabind/services/skema_db.dart';

/// Entitas Mata Pelajaran (Subject).
/// Tabel: mata_pelajaran (SkemaDb.tabelMapel). Soft delete via deleted_at — tidak dihapus fisik sampai purge dari Sampah.
/// Relasi: 1→N ke Materi & Tugas (CASCADE on purge).
/// dipakai di RepoMapel, RepoMateri, RepoTugas, LayananHapus, HalamanHome, HalamanAcademic, HalamanDetailMapel
class Mapel {
  final int? id;
  final String nama;
  final String? deskripsi;
  final String? warna; // Hex color, null = pakai warna tema
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt; // null = aktif, non-null = di Sampah

  /// Jumlah materi aktif — hanya terisi saat query memakai subquery hitung.
  final int jumlahMateri;

  /// Jumlah tugas aktif — hanya terisi saat query memakai subquery hitung.
  final int jumlahTugas;

  Mapel({
    this.id,
    required this.nama,
    this.deskripsi,
    this.warna,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.jumlahMateri = 0,
    this.jumlahTugas = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// True jika mapel sudah dihapus lembut (ada di Sampah).
    /// dipakai di RepoMapel.semua, RepoMapel.sampah, HalamanPengaturan._LembarSampah
    bool get terhapus => deletedAt != null;

    /// Membuat salinan dengan field yang diubah.
    /// hapusTandaDeletedAt: true = set deletedAt ke null (pulihkan dari sampah)
    /// hapusTandaWarna: true = set warna ke null (pakai warna tema)
    /// dipakai di RepoMapel.ubah, RepoMapel.hapusLembut, RepoMapel.pulihkan
    Mapel copyWith({
      int? id,
      String? nama,
      String? deskripsi,
      String? warna,
      DateTime? updatedAt,
      DateTime? deletedAt,
      bool hapusTandaDeletedAt = false,
      bool hapusTandaWarna = false,
    }) {
    return Mapel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      deskripsi: deskripsi ?? this.deskripsi,
      warna: hapusTandaWarna ? null : (warna ?? this.warna),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: hapusTandaDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// Mengubah ke Map untuk INSERT/UPDATE ke SQLite.
    /// dipakai di RepoMapel.tambah, RepoMapel.ubah, RepoMapel.hapusLembut, RepoMapel.pulihkan
    Map<String, Object?> toMap() => {
          if (id != null) 'id': id,
          'nama': nama,
          'deskripsi': deskripsi,
          'warna': warna,
          'created_at': createdAt.toIso8601String(),
          'updated_at': updatedAt.toIso8601String(),
          'deleted_at': deletedAt?.toIso8601String(),
        };

    /// Membuat [Mapel] dari baris hasil query SQLite.
    /// dipakai di RepoMapel.semua, RepoMapel.satu, RepoMapel.sampah, RepoMapel.cari
    factory Mapel.fromMap(Map<String, Object?> m) => Mapel(
        id: m['id'] as int?,
        nama: m['nama'] as String,
        deskripsi: m['deskripsi'] as String?,
        warna: m['warna'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
        jumlahMateri: (m['jumlah_materi'] as int?) ?? 0,
        jumlahTugas: (m['jumlah_tugas'] as int?) ?? 0,
      );
}
