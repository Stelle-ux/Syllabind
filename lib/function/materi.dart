import 'package:syllabind/services/skema_db.dart';

/// Entitas Materi Pembelajaran (Note/Content dalam Mapel).
/// Tabel: materi_pembelajaran (SkemaDb.tabelMateri). Kolom isi = isi catatan (bisa null/empty).
/// Soft delete via deleted_at. FK ke Mapel dengan CASCADE on purge. Relasi: 1→N ke Lampiran (CASCADE on purge).
/// dipakai di RepoMateri, RepoLampiran, LayananHapus, HalamanDetailMapel._TabMateri
class Materi {
  final int? id;
  final int mapelId;
  final String judul;
  final String? isi; // Konten catatan
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Hanya terisi saat query memakai JOIN ke tabel mata_pelajaran.
  /// Tidak disimpan di tabel materi_pembelajaran.
  final String? namaMapel;

  Materi({
    this.id,
    required this.mapelId,
    required this.judul,
    this.isi,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.namaMapel,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// True jika materi sudah dihapus lembut.
    /// dipakai di RepoMateri.semua, RepoMateri.perMapel, LayananHapus.hapusMateri
    bool get terhapus => deletedAt != null;

    /// Membuat salinan dengan field yang diubah.
    /// hapusIsi: true = set isi ke null (hapus konten catatan)
    /// hapusTandaDeletedAt: true = set deletedAt ke null (pulihkan dari sampah)
    /// dipakai di RepoMateri.ubah, RepoMateri.hapusLembut, RepoMateri.pulihkan
    Materi copyWith({
      int? id,
      int? mapelId,
      String? judul,
      String? isi,
      bool hapusIsi = false,
      DateTime? updatedAt,
      DateTime? deletedAt,
      bool hapusTandaDeletedAt = false,
    }) {
    return Materi(
      id: id ?? this.id,
      mapelId: mapelId ?? this.mapelId,
      judul: judul ?? this.judul,
      isi: hapusIsi ? null : (isi ?? this.isi),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: hapusTandaDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// Mengubah ke Map untuk INSERT/UPDATE ke SQLite.
    /// dipakai di RepoMateri.tambah, RepoMateri.ubah, RepoMateri.hapusLembut, RepoMateri.pulihkan
    Map<String, Object?> toMap() => {
          if (id != null) 'id': id,
          'mapel_id': mapelId,
          'judul': judul,
          'isi': isi,
          'created_at': createdAt.toIso8601String(),
          'updated_at': updatedAt.toIso8601String(),
          'deleted_at': deletedAt?.toIso8601String(),
        };

    /// Membuat [Materi] dari baris hasil query SQLite.
    /// dipakai di RepoMateri.semua, RepoMateri.satu, RepoMateri.perMapel, RepoMateri.cari
    factory Materi.fromMap(Map<String, Object?> m) => Materi(
        id: m['id'] as int?,
        mapelId: m['mapel_id'] as int,
        judul: m['judul'] as String,
        isi: m['isi'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
        namaMapel: m['nama_mapel'] as String?,
      );
}
