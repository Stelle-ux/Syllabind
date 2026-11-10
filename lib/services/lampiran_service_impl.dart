import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/services/lampiran_service.dart';

/// Implementasi service Lampiran (Attachments: Gambar + File dalam satu tabel).
/// dipakai di HalamanDetailMapel._LembarLampiran, HalamanPenyimpanan, LayananHapus, LayananEkspor
class LampiranServiceImpl implements LampiranService {
  /// Folder alternatif saat berjalan di unit test.
  /// dipakai di test/lampiran_opsional_test.dart
  static Directory? folderUji;

  /// Mengembalikan folder internal untuk menyimpan salinan lampiran.
  /// dipakai di tambahDariFile, hapusFileMilikMapel, hapusFileMilikMateri
  Future<Directory> _folderLampiran() async {
    final base = folderUji ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'lampiran'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Menyalin sumber ke folder internal lalu menyimpan barisnya ke DB.
  /// Menambah lampiran dari file fisik (galeri/Downloads) ke materi tertentu.
  /// dipakai di HalamanDetailMapel._LembarLampiran._tambahLampiran, HalamanPenyimpanan._tambahLampiran
    @override
    Future<int> tambahDariFile({
      required int materiId,
      required File sumber,
      required String tipe, // 'GAMBAR' | 'FILE'
    }) async {
    final dir = await _folderLampiran();

    // Nama unik: waktu + nama asli, supaya tidak tertimpa.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final namaAsli = p.basename(sumber.path);
    final namaSimpan = '${stamp}_$namaAsli';
    final tujuan = File(p.join(dir.path, namaSimpan));

    await sumber.copy(tujuan.path);
    final ukuran = await tujuan.length();

    final db = await Db.instance();
    return db.insert(
      SkemaDb.tabelLampiran,
      Lampiran(
        materiId: materiId,
        tipe: tipe,
        namaFile: namaAsli,
        lokasiFile: tujuan.path,
        ukuranFile: ukuran,
      ).toMap(),
    );
  }

  /// Judul catatan penampung lampiran di dalam sebuah mapel.
  /// Lampiran selalu menempel pada sebuah materi (lihat skema: kolom materi_id).
  /// Supaya pengguna bisa menambah lampiran langsung dari Library tanpa harus memikirkan catatan,
  /// tiap mapel punya satu catatan penampung dengan judul ini yang dibuat otomatis saat pertama dibutuhkan.
  /// dipakai di _catatanPenampung
  static const String judulPenampung = 'Lampiran';

  /// Mencari catatan penampung di mapelId, membuatnya kalau belum ada.
  /// Mengembalikan id materi yang bisa dipakai tambahDariFile.
  /// dipakai di tambahKeMapel
  /// panggil Db.instance, Materi.toMap
  Future<int> _catatanPenampung(int mapelId) async {
    final db = await Db.instance();

    final ada = await db.query(
      SkemaDb.tabelMateri,
      columns: ['id'],
      where: 'mapel_id = ? AND judul = ? AND deleted_at IS NULL',
      whereArgs: [mapelId, judulPenampung],
      limit: 1,
    );
    if (ada.isNotEmpty) return ada.first['id'] as int;

    return db.insert(
      SkemaDb.tabelMateri,
      Materi(mapelId: mapelId, judul: judulPenampung).toMap(),
    );
  }

  /// Menambah lampiran langsung dari sebuah mapel (dipakai halaman Library/Penyimpanan).
  /// dipakai di HalamanPenyimpanan._tambahLampiran
    @override
    Future<int> tambahKeMapel({
      required int mapelId,
      required File sumber,
      required String tipe,
    }) async {
    final materiId = await _catatanPenampung(mapelId);
    return tambahDariFile(materiId: materiId, sumber: sumber, tipe: tipe);
  }

  /// Semua lampiran milik satu materi (untuk bottom sheet di Detail Mapel).
  /// dipakai di HalamanDetailMapel._LembarLampiran._muatLampiran
    @override
    Future<List<Lampiran>> perMateri(int materiId) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelLampiran,
      where: 'materi_id = ?',
      whereArgs: [materiId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Lampiran.fromMap).toList();
  }

  /// Semua lampiran lintas mapel — dipakai halaman Library/Penyimpanan.
  /// dipakai di HalamanPenyimpanan._muatLampiran, HalamanPenyimpanan._hapusSemuaLampiran, LayananEkspor.eksporSemua
    @override
    Future<List<Lampiran>> semua({String? tipe}) async {
    final db = await Db.instance();
    final rows = await db.rawQuery('''
      SELECT l.*
        FROM ${SkemaDb.tabelLampiran} l
        JOIN ${SkemaDb.tabelMateri} m ON m.id = l.materi_id
        JOIN ${SkemaDb.tabelMapel}  mp ON mp.id = m.mapel_id
       WHERE m.deleted_at IS NULL
         AND mp.deleted_at IS NULL
         ${tipe == null ? '' : 'AND l.tipe = ?'}
       ORDER BY l.created_at DESC
    ''', tipe == null ? null : [tipe]);
    return rows.map(Lampiran.fromMap).toList();
  }

  /// Cari lampiran by ID.
  /// dipakai di hapus, ubahNama
    @override
    Future<Lampiran?> cari(int id) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelLampiran,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Lampiran.fromMap(rows.first);
  }

  /// Hapus satu lampiran: baris DB + salinan file internal.
  /// dipakai di HalamanDetailMapel._LembarLampiran._hapusLampiran, HalamanPenyimpanan._hapusLampiran
    @override
    Future<void> hapus(int id) async {
    final l = await cari(id);
    if (l == null) return;

    await _hapusFileAman(l.lokasiFile);

    final db = await Db.instance();
    await db.delete(SkemaDb.tabelLampiran, where: 'id = ?', whereArgs: [id]);
  }

  /// Mengubah nama tampilan satu lampiran (rename).
  /// dipakai di HalamanDetailMapel._LembarLampiran._ubahNamaLampiran, HalamanPenyimpanan._ubahNamaLampiran
    @override
    Future<int> ubahNama(int id, String namaBaru) async {
    final db = await Db.instance();
    return db.update(
      SkemaDb.tabelLampiran,
      {'nama_file': namaBaru},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus SEMUA file fisik milik sebuah mapel.
  /// dipakai di LayananHapus.hapusPermanenMapel
    @override
    Future<int> hapusFileMilikMapel(int mapelId) async {
    final db = await Db.instance();
    final rows = await db.rawQuery('''
      SELECT l.lokasi_file
      FROM ${SkemaDb.tabelLampiran} l
      JOIN ${SkemaDb.tabelMateri} m ON m.id = l.materi_id
      WHERE m.mapel_id = ?
    ''', [mapelId]);

    var n = 0;
    for (final r in rows) {
      if (await _hapusFileAman(r['lokasi_file'] as String)) n++;
    }
    return n;
  }

  /// Menghapus semua file fisik milik satu materi.
  /// dipakai di LayananHapus.hapusPermanenMateri
    @override
    Future<int> hapusFileMilikMateri(int materiId) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelLampiran,
      columns: ['lokasi_file'],
      where: 'materi_id = ?',
      whereArgs: [materiId],
    );

    var n = 0;
    for (final r in rows) {
      if (await _hapusFileAman(r['lokasi_file'] as String)) n++;
    }
    return n;
  }

  /// Menghapus file, tapi TIDAK melempar error kalau file sudah tidak ada.
  /// dipakai di hapus, hapusFileMilikMapel, hapusFileMilikMateri
    Future<bool> _hapusFileAman(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
        return true;
      }
    } on FileSystemException {
      // Diamkan — file terkunci atau sudah hilang.
    }
    return false;
  }

  /// Total ukuran semua lampiran dalam byte (hanya yang masih aktif).
  /// dipakai di HalamanPenyimpanan._muatLampiran
    @override
    Future<int> totalUkuran() async {
    final db = await Db.instance();
    final r = await db.rawQuery('''
      SELECT COALESCE(SUM(l.ukuran_file), 0) AS t
        FROM ${SkemaDb.tabelLampiran} l
        JOIN ${SkemaDb.tabelMateri} m ON m.id = l.materi_id
        JOIN ${SkemaDb.tabelMapel}  mp ON mp.id = m.mapel_id
       WHERE m.deleted_at IS NULL AND mp.deleted_at IS NULL
    ''');
    return (r.first['t'] as int?) ?? 0;
  }

  /// Jumlah lampiran dikelompokkan per tipe (hanya yang masih aktif).
  /// dipakai di HalamanPenyimpanan._muatLampiran
    @override
    Future<Map<String, int>> jumlahPerTipe() async {
    final db = await Db.instance();
    final rows = await db.rawQuery('''
      SELECT l.tipe AS tipe, COUNT(*) AS n
        FROM ${SkemaDb.tabelLampiran} l
        JOIN ${SkemaDb.tabelMateri} m ON m.id = l.materi_id
        JOIN ${SkemaDb.tabelMapel}  mp ON mp.id = m.mapel_id
       WHERE m.deleted_at IS NULL AND mp.deleted_at IS NULL
       GROUP BY l.tipe
    ''');
    return {
      for (final r in rows) r['tipe'] as String: (r['n'] as int?) ?? 0,
    };
  }
}