import 'package:sqflite/sqflite.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/services/mapel_repository.dart';

/// Implementasi repository Mata Pelajaran (Subject).
///
/// Mengelola CRUD + soft delete + Sampah + hitungan subquery.
/// Tabel: `mata_pelajaran` ([SkemaDb.tabelMapel]).
///
/// Aturan hapus:
///   - `hapusLembut()`  → isi `deleted_at`; hilang dari daftar, masih di Sampah.
///   - `pulihkan()`     → kosongkan `deleted_at`; kembali ke daftar.
///   - `hapusPermanen()` → hapus baris + CASCADE ke materi/tugas/lampiran.
class MapelRepositoryImpl implements MapelRepository {
  /// Menambah mata pelajaran baru.
  ///
  /// Returns: `id` baris yang baru disisipkan (AUTOINCREMENT).
  @override
  Future<int> tambah(Mapel mapel) async {
    final db = await Db.instance();
    return db.insert(SkemaDb.tabelMapel, mapel.toMap());
  }

  /// Semua mapel aktif, lengkap dengan jumlah materi dan tugas.
  ///
  /// Hitungan memakai subquery sehingga tidak perlu query tambahan per kartu
  /// (menghindari N+1) dan langsung akurat di daftar Academic.
  /// Parameter [termasukSampah]: `true` untuk ambil semua (termasuk terhapus).
  ///
  /// Returns: List [Mapel] urut nama A-Z (case-insensitive).
  @override
  Future<List<Mapel>> semua({bool termasukSampah = false}) async {
    final db = await Db.instance();
    final rows = await db.rawQuery('''
      SELECT m.*,
             (SELECT COUNT(*) FROM ${SkemaDb.tabelMateri} x
                WHERE x.mapel_id = m.id AND x.deleted_at IS NULL) AS jumlah_materi,
             (SELECT COUNT(*) FROM ${SkemaDb.tabelTugas} y
                WHERE y.mapel_id = m.id AND y.deleted_at IS NULL) AS jumlah_tugas
      FROM ${SkemaDb.tabelMapel} m
      WHERE ${termasukSampah ? '1 = 1' : 'm.deleted_at IS NULL'}
      ORDER BY m.nama COLLATE NOCASE ASC
    ''');
    return rows.map(Mapel.fromMap).toList();
  }

  /// Hanya mapel di Sampah (deleted_at IS NOT NULL), urut terbaru dulu.
  @override
  Future<List<Mapel>> isiSampah() async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelMapel,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(Mapel.fromMap).toList();
  }

  /// Cari mapel by ID (termasuk yang di Sampah).
  @override
  Future<Mapel?> cari(int id) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelMapel,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Mapel.fromMap(rows.first);
  }

  /// Ubah data mapel (nama, deskripsi, warna). Auto update updated_at.
  @override
  Future<int> ubah(Mapel mapel) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMapel,
      mapel.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [mapel.id],
    );
  }

  /// Soft delete: hanya mengisi `deleted_at` dengan waktu sekarang.
  ///
  /// Mapel hilang dari daftar utama, muncul di Sampah.
  /// Materi & Tugas IKUT terhapus lembut via trigger? TIDAK — mereka
  /// punya `deleted_at` sendiri tapi tidak diisi otomatis. Lihat [DeleteService]
  /// untuk hapus bersih bersamaan.
  @override
  Future<int> hapusLembut(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMapel,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Batal soft delete: kosongkan `deleted_at`. Mapel kembali ke daftar utama.
  @override
  Future<int> pulihkan(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMapel,
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus permanen (purge). CASCADE menghapus materi, tugas, lalu lampiran.
  ///
  /// ⚠️ Pemanggil HARUS menghapus file fisik lampiran SEBELUM memanggil ini
  /// (lihat [LampiranRepositoryImpl.hapusFileFisik] & [DeleteService.hapusPermanenMapel]).
  /// Jika file tidak dihapus dulu, file orphan tersisa di storage.
  @override
  Future<int> hapusPermanen(int id) async {
    final db = await Db.instance();
    return db.delete(SkemaDb.tabelMapel, where: 'id = ?', whereArgs: [id]);
  }

  /// Jumlah mapel aktif (deleted_at IS NULL).
  @override
  Future<int> jumlah() async {
    final db = await Db.instance();
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${SkemaDb.tabelMapel} WHERE deleted_at IS NULL',
    );
    return (r.first['n'] as int?) ?? 0;
  }
}