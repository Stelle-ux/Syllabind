import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/services/lampiran_repository.dart';

/// Implementasi repository Lampiran (Attachments: Gambar + File dalam satu tabel).
///
/// Mengelola CRUD + copy file ke internal storage + query lintas mapel + ukuran.
/// Tabel: `lampiran` ([SkemaDb.tabelLampiran]). FK ke [Materi] (CASCADE on purge).
///
/// Aturan file:
///   - Saat menambah lampiran, file **DISALIN** ke folder internal aplikasi
///     (`<dokumen>/lampiran/`). File asli di galeri/Downloads TIDAK disentuh.
///   - Saat menghapus lampiran, salinan internal dihapus; file asli tetap ada.
///   - Saat mapel dihapus permanen, semua salinan internal ikut dihapus.
class LampiranRepositoryImpl implements LampiranRepository {
  /// Folder alternatif saat berjalan di unit test.
  ///
  /// `getApplicationDocumentsDirectory()` bergantung pada kanal platform
  /// yang tidak tersedia di Dart VM, sehingga tes yang benar-benar menyalin
  /// berkas (bukan sekadar mencatat baris) akan gagal sebelum sampai ke
  /// logika aplikasi. Kait ini dipakai hanya kalau diisi oleh tes.
  static Directory? folderUji;

  /// Mengembalikan folder internal untuk menyimpan salinan lampiran.
  ///
  /// Path: `<app_documents>/lampiran/`. Dibuat otomatis jika belum ada.
  Future<Directory> _folderLampiran() async {
    final base = folderUji ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'lampiran'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Menyalin [sumber] ke folder internal lalu menyimpan barisnya ke DB.
  ///
  /// Nama file disimpan unik: `microsecondsSinceEpoch_namaAsli` untuk hindari tabrakan.
  /// File asli TIDAK dihapus/dipindahkan — hanya disalin.
  ///
  /// Returns: `id` baris lampiran yang baru disisipkan.
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
  ///
  /// Lampiran **selalu** menempel pada sebuah materi (lihat skema: kolom
  /// `materi_id`). Supaya pengguna bisa menambah lampiran langsung dari
  /// Library tanpa harus memikirkan catatan, tiap mapel punya satu catatan
  /// penampung dengan judul ini yang dibuat otomatis saat pertama dibutuhkan.
  static const String judulPenampung = 'Lampiran';

  /// Mencari catatan penampung di [mapelId], membuatnya kalau belum ada.
  ///
  /// Mengembalikan `id` materi yang bisa dipakai [tambahDariFile].
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
  ///
  /// Kalau catatan penampung belum ada, ia dibuat lebih dulu. Dengan begitu
  /// tombol "+" di Library cukup meminta mapel tujuan, tanpa memaksa
  /// pengguna membuka Detail Mapel → Catatan.
  ///
  /// Returns: `id` baris lampiran yang baru disisipkan.
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
  ///
  /// Urut lama ke baru (created_at ASC) supaya urutan penambahan terjaga.
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
  ///
  /// Hanya lampiran yang catatan **dan** mapelnya masih aktif (deleted_at IS NULL).
  /// Tanpa saringan ini, menghapus catatan atau mapel akan menyisakan lampiran
  /// "hantu" yang tetap ikut terhitung di kartu ringkasan dan daftar Library.
  /// Parameter [tipe]: filter `GAMBAR` atau `FILE` (null = semua).
  /// Urut terbaru duluan (created_at DESC).
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
  ///
  /// File asli milik pengguna TIDAK disentuh.
  /// Toleran: kalau file sudah tidak ada (dihapus manual lewat aplikasi lain),
  /// database tetap dibersihkan.
  @override
  Future<void> hapus(int id) async {
    final l = await cari(id);
    if (l == null) return;

    await _hapusFileAman(l.lokasiFile);

    final db = await Db.instance();
    await db.delete(SkemaDb.tabelLampiran, where: 'id = ?', whereArgs: [id]);
  }

  /// Mengubah nama tampilan satu lampiran (rename).
  ///
  /// Hanya kolom `nama_file` di database yang berubah — berkas fisik di
  /// penyimpanan aplikasi TIDAK dipindah atau dinamai ulang. Ini disengaja:
  /// `lokasi_file` tetap valid walau namanya diubah, dan file asli milik
  /// pengguna tidak pernah disentuh.
  ///
  /// Returns: Jumlah baris yang terpengaruh (1 kalau berhasil, 0 kalau tidak ada).
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
  ///
  /// Dipanggil SEBELUM `MapelRepositoryImpl.hapusPermanen()`, karena setelah baris
  /// database hilang lewat CASCADE, lokasi file tidak bisa dilacak lagi.
  ///
  /// Returns: Jumlah file yang berhasil dihapus.
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
  ///
  /// Returns: Jumlah file yang berhasil dihapus.
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
  ///
  /// Sengaja dibuat toleran: kalau pengguna menghapus filenya sendiri lewat
  /// aplikasi lain, database tetap harus bisa dibersihkan.
  ///
  /// Returns: `true` jika file dihapus, `false` jika sudah tidak ada/error.
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
  ///
  /// Sama seperti [semua]: lampiran milik catatan/mapel terhapus tidak
  /// dihitung, supaya angka "Total" cocok dengan yang terlihat di daftar.
  ///
  /// Returns: Total byte (0 jika kosong).
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
  ///
  /// Returns: Map `{ 'GAMBAR': n, 'FILE': m }`.
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