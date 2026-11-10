import 'package:sqflite/sqflite.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/function/ringkasan_tugas.dart';
import 'package:syllabind/services/tugas_service.dart';

/// Implementasi service Tugas (Assignments).
/// Mengelola CRUD + status toggle + query berbasis tenggat + ringkasan.
/// Tabel: tugas (SkemaDb.tabelTugas). FK ke Mapel (CASCADE on purge). Status: BELUM | SELESAI.
/// dipakai di HalamanHome, HalamanAcademic._TabTugas, HalamanDetailMapel._TabTugasMapel, LayananHapus, LayananEkspor
/// panggil Db.instance, SkemaDb.tabelTugas, Tugas.toMap, Tugas.fromMap, Tugas.copyWith, RingkasanTugas
class TugasServiceImpl implements TugasService {
  /// Menambah tugas baru ke dalam mapel.
  /// Returns: id baris yang baru disisipkan.
  /// Otomatis menghitung prioritas berdasarkan tenggat.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._tambahTugas
  /// panggil Db.instance, Tugas.toMap, Tugas.prioritasOtomatis
  @override
  Future<int> tambah(Tugas tugas) async {
    final db = await Db.instance();
    final tugasDenganPrioritas = tugas.copyWith(
      prioritas: tugas.prioritasOtomatis,
    );
    return db.insert(SkemaDb.tabelTugas, tugasDenganPrioritas.toMap());
  }

  /// Semua tugas dalam satu mapel (untuk tab Tugas di Detail Mapel).
  /// Urut: tenggat null di akhir, lalu tenggat terdekat duluan.
  /// Parameter termasukSampah: true untuk ambil termasuk yang dihapus lembut.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._segarkan
  /// panggil Db.instance, Tugas.fromMap
  @override
  Future<List<Tugas>> perMapel(int mapelId, {bool termasukSampah = false}) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelTugas,
      where: termasukSampah
          ? 'mapel_id = ?'
          : 'mapel_id = ? AND deleted_at IS NULL',
      whereArgs: [mapelId],
      orderBy: 'CASE WHEN tenggat IS NULL THEN 1 ELSE 0 END, tenggat ASC',
    );
    return rows.map(Tugas.fromMap).toList();
  }

  /// Semua tugas lintas mapel — dipakai tab "Task" di halaman Academic.
  /// Memakai JOIN ke mata_pelajaran supaya nama_mapel ikut terbawa.
  /// Parameter status: filter BELUM atau SELESAI (null = semua).
  /// Urut: tenggat null di akhir, lalu tenggat terdekat duluan.
  /// dipakai di HalamanAcademic._TabTugas._segarkan
  /// panggil Db.instance, Tugas.fromMap
  @override
  Future<List<Tugas>> semua({String? status}) async {
    final db = await Db.instance();
    final syarat = <String>['t.deleted_at IS NULL'];
    final args = <Object?>[];
    if (status != null) {
      syarat.add('t.status = ?');
      args.add(status);
    }
    final rows = await db.rawQuery('''
      SELECT t.*, m.nama AS nama_mapel
      FROM ${SkemaDb.tabelTugas} t
      JOIN ${SkemaDb.tabelMapel} m ON m.id = t.mapel_id
      WHERE ${syarat.join(' AND ')}
      ORDER BY CASE WHEN t.tenggat IS NULL THEN 1 ELSE 0 END, t.tenggat ASC
    ''', args);
    return rows.map(Tugas.fromMap).toList();
  }

  /// Tugas dengan tenggat terdekat yang belum lewat (untuk kartu "Fokus Hari Ini" di Home).
  /// Hanya tugas yang tenggatnya jatuh dalam batasHari ke depan (default 7 hari).
  /// Sengaja memakai batas bawah (tenggat >= sekarang) supaya tugas yang
  /// sudah lewat TIDAK muncul dua kali — sekali di bagian "Lewat tenggat"
  /// dan sekali lagi di sini dengan label negatif.
  /// dipakai di HalamanHome._segarkan
  /// panggil Db.instance, Tugas.fromMap
  @override
  Future<List<Tugas>> tenggatTerdekat({int batasHari = 7}) async {
    final db = await Db.instance();
    final kini = DateTime.now();
    final batas = kini.add(Duration(days: batasHari));
    final rows = await db.rawQuery('''
      SELECT t.*, m.nama AS nama_mapel
      FROM ${SkemaDb.tabelTugas} t
      JOIN ${SkemaDb.tabelMapel} m ON m.id = t.mapel_id
      WHERE t.deleted_at IS NULL AND m.deleted_at IS NULL
        AND t.status = ? AND t.tenggat IS NOT NULL
        AND t.tenggat >= ? AND t.tenggat <= ?
      ORDER BY t.tenggat ASC
    ''', [
      SkemaDb.statusBelum,
      kini.toIso8601String(),
      batas.toIso8601String(),
    ]);
    return rows.map(Tugas.fromMap).toList();
  }

  /// Tugas yang tenggatnya sudah lewat dan belum selesai (untuk bagian "Lewat Tenggat" di Home).
  /// dipakai di HalamanHome._segarkan
  /// panggil Db.instance, Tugas.fromMap
  @override
  Future<List<Tugas>> lewatTenggat() async {
    final db = await Db.instance();
    final kini = DateTime.now().toIso8601String();
    final rows = await db.rawQuery('''
      SELECT t.*, m.nama AS nama_mapel
      FROM ${SkemaDb.tabelTugas} t
      JOIN ${SkemaDb.tabelMapel} m ON m.id = t.mapel_id
      WHERE t.deleted_at IS NULL AND m.deleted_at IS NULL
        AND t.status = ? AND t.tenggat IS NOT NULL AND t.tenggat < ?
      ORDER BY t.tenggat ASC
    ''', [SkemaDb.statusBelum, kini]);
    return rows.map(Tugas.fromMap).toList();
  }

  /// Cari tugas by ID (termasuk yang di Sampah).
  /// dipakai di HalamanDetailMapel._TabTugasMapel._ubahTugas, LayananHapus.hapusPermanenTugas
  /// panggil Db.instance, Tugas.fromMap
  @override
  Future<Tugas?> cari(int id) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelTugas,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Tugas.fromMap(rows.first);
  }

  /// Ubah data tugas (judul, deskripsi, tenggat). Auto update updated_at.
  /// Otomatis menghitung ulang prioritas jika tenggat berubah.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._ubahTugas
  /// panggil Db.instance, Tugas.copyWith, Tugas.toMap, Tugas.prioritasOtomatis
  @override
  Future<int> ubah(Tugas tugas) async {
    final db = await Db.instance();
    final tugasDenganPrioritas = tugas.copyWith(
      updatedAt: DateTime.now(),
      prioritas: tugas.prioritasOtomatis,
    );
    return db.update(
      SkemaDb.tabelTugas,
      tugasDenganPrioritas.toMap(),
      where: 'id = ?',
      whereArgs: [tugas.id],
    );
  }

  /// Toggle status tugas: BELUM ↔ SELESAI.
  /// Dipakai saat user tap checkbox di daftar tugas.
  /// Otomatis mengupdate updated_at.
  /// dipakai di HalamanHome._tandai, HalamanAcademic._TabTugas._toggle, HalamanDetailMapel._TabTugasMapel._toggle
  /// panggil Db.instance
  @override
  Future<int> ubahStatus(int id, String status) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelTugas,
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete: hanya mengisi deleted_at dengan waktu sekarang.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._hapusTugas, LayananHapus.hapusTugas
  /// panggil Db.instance
  @override
  Future<int> hapusLembut(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelTugas,
      {'deleted_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Alias eksplisit — sama dengan hapusLembut.
  /// dipakai di LayananHapus.hapusTugas
  @override
  Future<int> hapusTugas(int id) => hapusLembut(id);

  /// Alias singkat untuk UI — sama dengan hapusLembut.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._hapusTugas
  @override
  Future<int> hapus(int id) => hapusLembut(id);

  /// Batal soft delete: kosongkan deleted_at. Tugas kembali ke daftar.
  /// dipakai di HalamanPengaturan._LembarSampah._pulihkan (jika diperlukan)
  /// panggil Db.instance
  @override
  Future<int> pulihkan(int id) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelTugas,
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hapus permanen (purge). Tidak ada CASCADE ke tabel lain (tugas leaf).
  /// dipakai di HalamanPengaturan._LembarSampah._hapusPermanen (via LayananHapus)
  /// panggil Db.instance
  @override
  Future<int> hapusPermanen(int id) async {
    final db = await Db.instance();
    return db.delete(SkemaDb.tabelTugas, where: 'id = ?', whereArgs: [id]);
  }

  /// Ringkasan untuk Home: (belum, selesai, lewat tenggat).
  /// Query agregat tunggal — efisien untuk kartu statistik.
  /// dipakai di HalamanHome._segarkan
  /// panggil Db.instance, RingkasanTugas
  @override
  Future<RingkasanTugas> ringkasan() async {
    final db = await Db.instance();
    final r = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN status = '${SkemaDb.statusBelum}' THEN 1 ELSE 0 END) AS belum,
        SUM(CASE WHEN status = '${SkemaDb.statusSelesai}' THEN 1 ELSE 0 END) AS selesai,
        SUM(CASE WHEN status = '${SkemaDb.statusBelum}'
                  AND tenggat IS NOT NULL
                  AND tenggat < ? THEN 1 ELSE 0 END) AS lewat
      FROM ${SkemaDb.tabelTugas}
      WHERE deleted_at IS NULL
    ''', [DateTime.now().toIso8601String()]);

    final row = r.first;
    return RingkasanTugas(
      belum: (row['belum'] as int?) ?? 0,
      selesai: (row['selesai'] as int?) ?? 0,
      lewat: (row['lewat'] as int?) ?? 0,
    );
  }
}