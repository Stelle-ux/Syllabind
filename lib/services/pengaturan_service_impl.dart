import 'package:sqflite/sqflite.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/services/pengaturan_service.dart';

/// Implementasi service Pengaturan (Key-Value store sederhana).
/// dipakai di main.dart, HalamanPengaturan, LayananEkspor
class PengaturanServiceImpl implements PengaturanService {
  /// Mengambil nilai setting berdasarkan kunci.
  /// dipakai di tema, warnaAksen, bahasa, setTema, setWarnaAksen, setBahasa
  @override
  Future<String?> ambil(String kunci) async {
    final db = await Db.instance();
    final rows = await db.query(
      SkemaDb.tabelPengaturan,
      where: 'kunci = ?',
      whereArgs: [kunci],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['nilai'] as String;
  }

  /// Menyimpan/memperbarui nilai setting berdasarkan kunci.
  /// dipakai di setTema, setWarnaAksen, setBahasa
    @override
    Future<void> simpan(String kunci, String nilai) async {
    final db = await Db.instance();
    await db.insert(
      SkemaDb.tabelPengaturan,
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mengambil semua setting sebagai Map.
  /// dipakai di LayananEkspor.eksporSemua
    @override
    Future<Map<String, String>> semua() async {
    final db = await Db.instance();
    final rows = await db.query(SkemaDb.tabelPengaturan);
    return {
      for (final r in rows) r['kunci'] as String: r['nilai'] as String,
    };
  }

  /// Menghapus setting berdasarkan kunci.
  /// dipakai di HalamanPengaturan._resetKeDefault
    @override
    Future<void> hapus(String kunci) async {
    final db = await Db.instance();
    await db.delete(
      SkemaDb.tabelPengaturan,
      where: 'kunci = ?',
      whereArgs: [kunci],
    );
  }

  /// Mengambil nilai tema (system/terang/gelap).
  /// dipakai di main.dart._muat, HalamanPengaturan._muatPengaturan
    @override
    Future<String> tema() async =>
        await ambil(PengaturanService.kunciTema) ?? 'system';

  /// Menyimpan nilai tema.
  /// dipakai di HalamanPengaturan._ubahTema
    @override
    Future<void> setTema(String nilai) =>
        simpan(PengaturanService.kunciTema, nilai);

  /// Mengambil nilai warna aksen (hex).
  /// dipakai di main.dart._muat, HalamanPengaturan._muatPengaturan
    @override
    Future<String> warnaAksen() async =>
        await ambil(PengaturanService.kunciWarnaAksen) ?? '#2F6F6B';

  /// Menyimpan nilai warna aksen.
  /// dipakai di HalamanPengaturan._ubahWarnaAksen
    @override
    Future<void> setWarnaAksen(String hex) =>
        simpan(PengaturanService.kunciWarnaAksen, hex);

  /// Mengambil nilai bahasa (id/en).
  /// dipakai di main.dart._muat, HalamanPengaturan._muatPengaturan
    @override
    Future<String> bahasa() async {
      final nilai = await ambil(PengaturanService.kunciBahasa);
      return nilai == 'en' ? 'en' : 'id';
    }

  /// Menyimpan nilai bahasa.
  /// dipakai di HalamanPengaturan._ubahBahasa
    @override
    Future<void> setBahasa(String kode) =>
        simpan(PengaturanService.kunciBahasa, kode == 'en' ? 'en' : 'id');
}