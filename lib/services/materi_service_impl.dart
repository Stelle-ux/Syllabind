import 'package:sqflite/sqflite.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/services/materi_service.dart';

/// Implementasi service Materi Pembelajaran (Notes/Content).
/// Mengelola CRUD + soft delete + pencarian + query lintas mapel.
/// Tabel: materi_pembelajaran (SkemaDb.tabelMateri). FK ke Mapel (CASCADE on purge), 1→N ke Lampiran (CASCADE on purge).
/// dipakai di HalamanDetailMapel._TabMateri, HalamanAcademic._TabCatatan, LayananHapus, LayananEkspor
/// panggil Db.instance, SkemaDb.tabelMateri, Materi.toMap, Materi.fromMap, Materi.copyWith
class MateriServiceImpl implements MateriService {
  /// Menambah materi baru ke dalam mapel.
  /// Returns: id baris yang baru disisipkan.
  /// dipakai di HalamanDetailMapel._tambahMateri
  /// panggil Db.instance, Materi.toMap
  @override
  Future<int> tambah(Materi materi) async {
    final db = await Db.instance();
    return db.insert(SkemaDb.tabelMateri, materi.toMap());
  }

  /// Semua materi dalam satu mapel (untuk tab Catatan di Detail Mapel).
  /// Parameter termasukSampah: true untuk ambil termasuk yang dihapus lembut.
  /// Urut terbaru duluan (created_at DESC).
  /// dipakai di HalamanDetailMapel._TabMateri._segarkan
  /// panggil Db.instance, Materi.fromMap
  @override
  Future<List<Materi>> perMapel(int mapelId, {bool termasukSampah = false}) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelMateri,
      where: termasukSampah
          ? 'mapel_id = ?'
          : 'mapel_id = ? AND deleted_at IS NULL',
      whereArgs: [mapelId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Materi.fromMap).toList();
  }

  /// Semua materi lintas mapel — dipakai tab "Notes" di halaman Academic.
  /// Memakai JOIN ke mata_pelajaran supaya nama_mapel ikut terbawa
  /// untuk ditampilkan di kartu (badge mapel).
  /// Parameter hanyaDenganCatatan: true → filter isi tidak kosong.
  /// dipakai di HalamanAcademic._TabCatatan._segarkan
  /// panggil Db.instance, Materi.fromMap
  @override
  Future<List<Materi>> semua({bool hanyaDenganCatatan = false}) async {
    final db = await Db.instance();
    final syarat = <String>['t.deleted_at IS NULL', 'm.deleted_at IS NULL'];
    if (hanyaDenganCatatan) {
      syarat.add("t.isi IS NOT NULL AND TRIM(t.isi) <> ''");
    }
    final rows = await db.rawQuery('''
      SELECT t.*, m.nama AS nama_mapel
      FROM ${SkemaDb.tabelMateri} t
      JOIN ${SkemaDb.tabelMapel} m ON m.id = t.mapel_id
      WHERE ${syarat.join(' AND ')}
      ORDER BY t.updated_at DESC
    ''');
    return rows.map(Materi.fromMap).toList();
  }

  /// Cari materi by ID (termasuk yang di Sampah).
  /// dipakai di HalamanDetailMapel._LembarLampiran._segarkan, LayananHapus.hapusPermanenMateri
  /// panggil Db.instance, Materi.fromMap
  @override
  Future<Materi?> cari(int id) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelMateri,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Materi.fromMap(rows.first);
  }

  /// Ubah data materi (judul, isi). Auto update updated_at.
  /// dipakai di HalamanDetailMapel._TabMateri._ubahMateri
  /// panggil Db.instance, Materi.copyWith, Materi.toMap
  @override
  Future<int> ubah(Materi materi) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMateri,
      materi.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [materi.id],
    );
  }

  /// Soft delete: hanya mengisi deleted_at dengan waktu sekarang.
  /// Materi hilang dari daftar, lampiran tetap ada (tidak dihapus otomatis).
  /// Untuk hapus bersih bersamaan lampiran, gunakan DeleteService.hapusPermanenMateri.
  /// dipakai di HalamanDetailMapel._TabMateri._hapusMateri, LayananHapus.hapusMateri
  /// panggil Db.instance
  @override
  Future<int> hapusLembut(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMateri,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Alias eksplisit — sama dengan hapusLembut.
  /// dipakai di LayananHapus.hapusMateri
  @override
  Future<int> hapusMateri(int id) => hapusLembut(id);

  /// Alias singkat untuk hapusLembut — digunakan oleh UI yang ingin API sederhana.
  /// dipakai di HalamanDetailMapel._TabMateri._hapusMateri
  @override
  Future<int> hapus(int id) => hapusLembut(id);

  /// Batal soft delete: kosongkan deleted_at. Materi kembali ke daftar.
  /// dipakai di HalamanPengaturan._LembarSampah._pulihkan (jika diperlukan)
  /// panggil Db.instance
  @override
  Future<int> pulihkan(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelMateri,
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus permanen (purge). Lampiran ikut terhapus lewat CASCADE FK.
  /// ⚠️ Pemanggil HARUS menghapus file fisik lampiran SEBELUM memanggil ini
  /// (lihat LampiranServiceImpl.hapusFileFisik & DeleteService.hapusPermanenMateri).
  /// dipakai di HalamanPengaturan._LembarSampah._hapusPermanen (via LayananHapus)
  /// panggil Db.instance
  @override
  Future<int> hapusPermanen(int id) async {
    final db = await Db.instance();
    return db.delete(SkemaDb.tabelMateri, where: 'id = ?', whereArgs: [id]);
  }

  /// Hapus permanen tugas (delegasi ke TugasService).
  /// dipakai di DeleteService.hapusPermanenTugas
  /// panggil TugasService.hapusPermanen
  @override
  Future<int> hapusPermanenTugas(int id) async {
    // This is a placeholder - actual implementation is in TugasServiceImpl
    // We need to access TugasService from here, but it's not available
    // This method should not be in MateriService - it's a design issue
    throw UnimplementedError('hapusPermanenTugas should be called on TugasService');
  }

  /// Cari materi berdasarkan kata kunci (judul atau isi catatan).
  /// Hanya mencari materi aktif (deleted_at IS NULL). Case-insensitive via LIKE.
  /// Urut terbaru diupdate duluan.
  /// dipakai di HalamanAcademic._TabCatatan._cari
  /// panggil Db.instance, Materi.fromMap
  @override
  Future<List<Materi>> cariKata(String kata) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelMateri,
      where:
          "deleted_at IS NULL AND (judul LIKE ? OR isi LIKE ?)",
      whereArgs: ['%$kata%', '%$kata%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Materi.fromMap).toList();
  }
}