import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'skema_db.dart';

/// Membuka dan menyiapkan koneksi database Syllabind (Singleton).
/// dipakai di Semua Service, LayananHapus, LayananEkspor, main.dart, test/data_test.dart
class Db {
  Db._();

  static Database? _db;

  /// Set true saat menjalankan unit test di Dart VM.
  /// dipakai di test/data_test.dart (setUp), test/bahasa_test.dart, test/lampiran_opsional_test.dart
  static bool modeUji = false;

  /// Folder sementara yang dibuat instance di jalur FFI.
  static Directory? _folderSementara;

  /// Semua folder sementara yang pernah dibuat proses ini.
  static final List<Directory> _pernahDibuat = <Directory>[];

  /// Mengembalikan instance database singleton, membuatnya bila belum ada.
  /// dipakai di Semua Service (via await Db.instance()), LayananHapus, LayananEkspor, main.dart
  static Future<Database> instance() async {
    if (_db != null) return _db!;

    if (modeUji || !Platform.isAndroid && !Platform.isIOS) {
      // Jangan bergantung pada TMPDIR/TMP: di Windows variabel itu kerap
      // berisi path gaya MSYS (`/c/Users/...`) yang diterjemahkan salah
      // menjadi `C:\c\Users\...` dan membuat createTemp gagal. Folder
      // sementara dibuat di dalam proyek supaya pasti bisa ditulis.
      final akar = Directory(p.join(Directory.current.path, 'build', 'uji_tmp'));
      await akar.create(recursive: true);
      final dir = await akar.createTemp('syllabind_uji_');
      _folderSementara = dir;
      _pernahDibuat.add(dir);
      _db = await databaseFactory.openDatabase(
        p.join(dir.path, SkemaDb.namaFile),
        options: OpenDatabaseOptions(
          version: SkemaDb.versi,
          onCreate: SkemaDb.buat,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      return _db!;
    }

    final folder = await getApplicationDocumentsDirectory();
    final lokasi = p.join(folder.path, 'db', SkemaDb.namaFile);

    _db = await openDatabase(
      lokasi,
      version: SkemaDb.versi,
      onCreate: SkemaDb.buat,
      onConfigure: (db) async {
        // WAJIB: SQLite mematikan foreign key secara bawaan.
        // Tanpa baris ini, ON DELETE CASCADE tidak berjalan.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  /// Mereset database untuk unit test: menutup koneksi & menghapus singleton.
  /// dipakai di test/data_test.dart (setUp/tearDown), test/bahasa_test.dart, test/lampiran_opsional_test.dart
  static Future<void> reset() async {
    await _db?.close();
    _db = null;
    await _bersihkanFolderSementara();
  }

  /// Menutup koneksi database (cleanup saat aplikasi ditutup).
  /// dipakai di main.dart (dispose), test/data_test.dart (tearDownAll)
  static Future<void> tutup() async {
    await _db?.close();
    _db = null;
    await _bersihkanFolderSementara();
    await _sapuSisaFolder();
  }

  /// Menghapus folder sementara yang sebelumnya gagal dihapus.
  /// dipakai di tutup
  static Future<void> _sapuSisaFolder() async {
    for (final dir in List<Directory>.from(_pernahDibuat)) {
      if (await _hapusFolder(dir)) _pernahDibuat.remove(dir);
    }
  }

  /// Menghapus folder sementara milik koneksi yang baru ditutup.
  /// dipakai di tutup, reset
  static Future<void> _bersihkanFolderSementara() async {
    final dir = _folderSementara;
    _folderSementara = null;
    if (dir == null) return;
    if (await _hapusFolder(dir)) {
      _pernahDibuat.remove(dir);
    }
  }

  /// Mencoba menghapus satu folder sampai tiga kali.
  /// dipakai di _sapuSisaFolder, _bersihkanFolderSementara
  static Future<bool> _hapusFolder(Directory dir) async {
    for (var percobaan = 0; percobaan < 3; percobaan++) {
      try {
        if (!await dir.exists()) return true;
        await dir.delete(recursive: true);
        return true;
      } catch (_) {
        // Masih terkunci; tunggu sebentar lalu coba lagi.
        await Future<void>.delayed(Duration(milliseconds: 40 * (percobaan + 1)));
      }
    }
    return !(await dir.exists());
  }
}
