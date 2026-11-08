import 'package:sqflite/sqflite.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/services/pengaturan_repository.dart';

/// Implementasi repository Pengaturan (Key-Value store sederhana).
///
/// Tabel: `pengaturan` ([SkemaDb.tabelPengaturan]).
/// Kunci tetap: `tema` (system/terang/gelap), `warna_aksen` (hex),
/// `bahasa` (id/en), `versi_skema`, `dibuat_pada`.
class PengaturanRepositoryImpl implements PengaturanRepository {
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

  @override
  Future<void> simpan(String kunci, String nilai) async {
    final db = await Db.instance();
    await db.insert(
      SkemaDb.tabelPengaturan,
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Map<String, String>> semua() async {
    final db = await Db.instance();
    final rows = await db.query(SkemaDb.tabelPengaturan);
    return {
      for (final r in rows) r['kunci'] as String: r['nilai'] as String,
    };
  }

  @override
  Future<void> hapus(String kunci) async {
    final db = await Db.instance();
    await db.delete(
      SkemaDb.tabelPengaturan,
      where: 'kunci = ?',
      whereArgs: [kunci],
    );
  }

  // ── Pembantu bertipe (typed helpers) ──────────────────────────────────────

  @override
  Future<String> tema() async =>
      await ambil(PengaturanRepository.kunciTema) ?? 'system';

  @override
  Future<void> setTema(String nilai) =>
      simpan(PengaturanRepository.kunciTema, nilai);

  @override
  Future<String> warnaAksen() async =>
      await ambil(PengaturanRepository.kunciWarnaAksen) ?? '#2F6F6B';

  @override
  Future<void> setWarnaAksen(String hex) =>
      simpan(PengaturanRepository.kunciWarnaAksen, hex);

  @override
  Future<String> bahasa() async {
    final nilai = await ambil(PengaturanRepository.kunciBahasa);
    return nilai == 'en' ? 'en' : 'id';
  }

  @override
  Future<void> setBahasa(String kode) =>
      simpan(PengaturanRepository.kunciBahasa, kode == 'en' ? 'en' : 'id');
}