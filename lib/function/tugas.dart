import 'package:syllabind/services/skema_db.dart';

/// Entitas Tugas (Assignment dalam Mapel).
/// Tabel: tugas (SkemaDb.tabelTugas). Bisa punya tenggat (deadline) & status (BELUM/SELESAI).
/// Soft delete via deleted_at. FK ke Mapel dengan CASCADE on purge.
/// dipakai di RepoTugas, LayananHapus, HalamanHome, HalamanAcademic._TabTugas, HalamanDetailMapel._TabTugasMapel
class Tugas {
  final int? id;
  final int mapelId;
  final String judul;
  final String? deskripsi;
  final DateTime? tenggat; // Deadline (opsional)
  final String status; // BELUM | SELESAI
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Hanya terisi saat query memakai JOIN ke tabel mata_pelajaran.
  /// Tidak disimpan di tabel tugas.
  final String? namaMapel;

  Tugas({
    this.id,
    required this.mapelId,
    required this.judul,
    this.deskripsi,
    this.tenggat,
    this.status = SkemaDb.statusBelum,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    this.namaMapel,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// True jika tugas sudah dihapus lembut.
    /// dipakai di RepoTugas.semua, RepoTugas.perMapel, LayananHapus.hapusTugas
    bool get terhapus => deletedAt != null;

    /// True jika status == SELESAI.
    /// dipakai di HalamanHome._barisTugas, HalamanAcademic._TabTugas, HalamanDetailMapel._TabTugasMapel
    bool get selesai => status == SkemaDb.statusSelesai;

    /// Sisa hari menuju tenggat. Negatif = sudah lewat. Null = tidak ada tenggat.
    /// dipakai di HalamanHome._barisTugas, HalamanAcademic._TabTugas, HalamanDetailMapel._TabTugasMapel
    int? get sisaHari {
      if (tenggat == null) return null;
      final hariIni = DateTime.now();
      final a = DateTime(hariIni.year, hariIni.month, hariIni.day);
      final b = DateTime(tenggat!.year, tenggat!.month, tenggat!.day);
      return b.difference(a).inDays;
    }

    /// True jika tenggat sudah lewat DAN status BELUM.
    /// dipakai di HalamanHome._barisTugas, HalamanAcademic._TabTugas, HalamanDetailMapel._TabTugasMapel
    bool get lewatTenggat => sisaHari != null && sisaHari! < 0 && !selesai;

    /// Membuat salinan dengan field yang diubah.
    /// hapusTenggat: true = set tenggat ke null (hapus deadline)
    /// hapusTandaDeletedAt: true = set deletedAt ke null (pulihkan dari sampah)
    /// dipakai di RepoTugas.ubah, RepoTugas.toggleStatus, RepoTugas.hapusLembut, RepoTugas.pulihkan
    Tugas copyWith({
      int? id,
      int? mapelId,
      String? judul,
      String? deskripsi,
      DateTime? tenggat,
      bool hapusTenggat = false,
      String? status,
      DateTime? updatedAt,
      DateTime? deletedAt,
      bool hapusTandaDeletedAt = false,
    }) {
    return Tugas(
      id: id ?? this.id,
      mapelId: mapelId ?? this.mapelId,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      tenggat: hapusTenggat ? null : (tenggat ?? this.tenggat),
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: hapusTandaDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// Mengubah ke Map untuk INSERT/UPDATE ke SQLite.
    /// dipakai di RepoTugas.tambah, RepoTugas.ubah, RepoTugas.toggleStatus, RepoTugas.hapusLembut, RepoTugas.pulihkan
    Map<String, Object?> toMap() => {
          if (id != null) 'id': id,
          'mapel_id': mapelId,
          'judul': judul,
          'deskripsi': deskripsi,
          'tenggat': tenggat?.toIso8601String(),
          'status': status,
          'created_at': createdAt.toIso8601String(),
          'updated_at': updatedAt.toIso8601String(),
          'deleted_at': deletedAt?.toIso8601String(),
        };

    /// Membuat [Tugas] dari baris hasil query SQLite.
    /// dipakai di RepoTugas.semua, RepoTugas.satu, RepoTugas.perMapel, RepoTugas.akanDatang, RepoTugas.lewatTenggat, RepoTugas.ringkasan, RepoTugas.cari
    factory Tugas.fromMap(Map<String, Object?> m) => Tugas(
        id: m['id'] as int?,
        mapelId: m['mapel_id'] as int,
        judul: m['judul'] as String,
        deskripsi: m['deskripsi'] as String?,
        tenggat:
            m['tenggat'] == null ? null : DateTime.parse(m['tenggat'] as String),
        status: m['status'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
        namaMapel: m['nama_mapel'] as String?,
      );
}
