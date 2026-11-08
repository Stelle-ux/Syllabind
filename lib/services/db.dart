import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'skema_db.dart';

/// Membuka dan menyiapkan koneksi database Syllabind (Singleton).
///
/// - Di Android/iOS memakai `sqflite` bawaan (factory dari plugin registrant).
/// - Di Windows/Linux/macOS (dipakai untuk unit test) memakai `databaseFactory`
///   global yang **sudah disiapkan oleh berkas tes** di `setUpAll`.
///
/// **Kenapa tidak mengimpor `sqflite_common_ffi` di sini.**
/// `sqflite_common_ffi` hanya ada di `dev_dependencies` — dibutuhkan unit test
/// di Dart VM, bukan oleh aplikasi Android. Sebelumnya berkas ini mengimpornya
/// dari `lib/` sehingga kode produksi bergantung pada paket khusus tes. Kini
/// FFI sepenuhnya urusan tes: tes memanggil `sqfliteFfiInit()` dan menyetel
/// `databaseFactory`, lalu [instance] memakai factory global itu apa adanya.
///
/// **Reused in:** Semua Repository (`RepoMapel`, `RepoMateri`, `RepoTugas`,
/// `RepoLampiran`, `RepoPengaturan`), [LayananHapus], [LayananEkspor],
/// [main.dart] (inisialisasi awal), [test/data_test.dart] (setup test)
/// **Calls:** [SkemaDb.buat], [getApplicationDocumentsDirectory], sqflite [openDatabase]
class Db {
  Db._();

  static Database? _db;

  /// Set `true` saat menjalankan unit test di Dart VM.
  ///
  /// Berkas tes **wajib** memanggil `sqfliteFfiInit()` dan menyetel
  /// `databaseFactory = databaseFactoryFfiNoIsolate` sebelum memakai [instance].
  /// `NoIsolate` dipakai (bukan versi isolate) karena isolate terpisah membuat
  /// `flutter test` menganggap masih ada timer menggantung sehingga tes UI tidak
  /// pernah selesai.
  ///
  /// **Reused in:** [test/data_test.dart] (setUp), [test/bahasa_test.dart], [test/lampiran_opsional_test.dart]
  static bool modeUji = false;

  /// Folder sementara yang dibuat [instance] di jalur FFI.
  /// Disimpan supaya [reset]/[tutup] bisa menghapusnya. Tanpa ini setiap
  /// inisialisasi meninggalkan satu folder berisi DB dan folder itu menumpuk
  /// sampai ratusan. Di Android jalur ini tidak dipakai (DB di dokumen app).
  static Directory? _folderSementara;

  /// Semua folder sementara yang pernah dibuat proses ini dan belum tentu
  /// terhapus.
  ///
  /// **Kenapa daftar, bukan satu variabel.** `flutter test` menjalankan
  /// beberapa berkas tes **secara paralel sebagai proses terpisah**, dan
  /// semuanya memakai folder `build/uji_tmp` yang sama. Saat satu proses
  /// menghapus foldernya sendiri, `Directory.delete` bisa melempar karena
  /// folder induk sedang sibuk dihapus proses lain - dan kegagalan itu
  /// sengaja ditelan (lihat [_bersihkanFolderSementara]). Hasilnya satu
  /// folder tertinggal per suite run, padahal tiap berkas tes lulus sendiri.
  ///
  /// Dibuktikan: `flutter test` = 1 folder bocor; `flutter test
  /// --concurrency=1` = 0. Dengan sapuan susulan di [tutup], sisa itu
  /// dihabiskan di akhir proses.
  static final List<Directory> _pernahDibuat = <Directory>[];

  /// Mengembalikan instance database singleton, membuatnya bila belum ada.
  ///
  /// Logika pemilihan backend:
  /// - `modeUji == true` atau non-Android/iOS → `databaseFactory` global
  ///   (sudah disetel tes menjadi FFI di [setUpAll])
  /// - Android/iOS → sqflite native ([openDatabase], factory dari plugin)
  ///
  /// Selalu mengaktifkan `PRAGMA foreign_keys = ON` agar CASCADE berjalan.
  ///
  /// Returns: Instance [Database] yang siap dipakai.
  ///
  /// **Reused in:** Semua Repository (via `await Db.instance()`), [LayananHapus], [LayananEkspor], [main.dart]
  /// **Calls:** [SkemaDb.buat], [getApplicationDocumentsDirectory], sqflite [openDatabase]/[DatabaseFactory.openDatabase]
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
  ///
  /// Dipanggil di `setUp`/`tearDown` test agar setiap test punya DB bersih.
  /// Folder sementara milik koneksi lama ikut dihapus supaya tidak menumpuk.
  ///
  /// **Reused in:** [test/data_test.dart] (setUp/tearDown), [test/bahasa_test.dart], [test/lampiran_opsional_test.dart]
  /// **Calls:** [Database.close], [_bersihkanFolderSementara]
  static Future<void> reset() async {
    await _db?.close();
    _db = null;
    await _bersihkanFolderSementara();
  }

  /// Menutup koneksi database (cleanup saat aplikasi ditutup).
  ///
  /// **Reused in:** [main.dart] (dispose), [test/data_test.dart] (tearDownAll)
  /// **Calls:** [Database.close], [_bersihkanFolderSementara]
  static Future<void> tutup() async {
    await _db?.close();
    _db = null;
    await _bersihkanFolderSementara();
    await _sapuSisaFolder();
  }

  /// Menghapus folder sementara yang sebelumnya gagal dihapus.
  ///
  /// Dipanggil di akhir [tutup]. Saat `flutter test` berjalan paralel,
  /// penghapusan folder bisa balapan dengan proses lain yang sedang
  /// menghapus folder induk, dan kegagalan itu ditelan diam-diam. Menyapu
  /// ulang di akhir memberi kesempatan kedua saat folder induk sudah sunyi.
  ///
  /// Hanya menyentuh folder yang **proses ini** buat (`syllabind_uji_*`),
  /// tidak pernah folder lain. Aman dipanggil berkali-kali.
  ///
  /// **Calls:** [Directory.delete], [Directory.exists]
  static Future<void> _sapuSisaFolder() async {
    for (final dir in List<Directory>.from(_pernahDibuat)) {
      if (await _hapusFolder(dir)) _pernahDibuat.remove(dir);
    }
  }

  /// Menghapus folder sementara milik koneksi yang baru ditutup.
  ///
  /// Gagal menghapus **tidak** boleh menggagalkan pemanggil: di Windows berkas
  /// kadang masih terkunci sesaat setelah [Database.close]. Sisa folder tidak
  /// berbahaya (hanya makan ruang), sedangkan melempar error di sini akan
  /// membuat `tearDown` gagal dan menutupi hasil tes yang sebenarnya.
  ///
  /// **Calls:** [Directory.delete]
  static Future<void> _bersihkanFolderSementara() async {
    final dir = _folderSementara;
    _folderSementara = null;
    if (dir == null) return;
    if (await _hapusFolder(dir)) {
      _pernahDibuat.remove(dir);
    }
  }

  /// Mencoba menghapus satu folder sampai tiga kali.
  ///
  /// Satu percobaan tidak cukup di Windows: tepat setelah [Database.close],
  /// `syllabind.db` kadang masih dipegang sepersekian detik, dan
  /// `Directory.delete` langsung melempar. Dulu kegagalan itu ditelan begitu
  /// saja sehingga folder tertinggal (terbukti: 1 folder per suite run saat
  /// `flutter test` berjalan paralel, sedangkan `--concurrency=1` bersih).
  /// Jeda pendek memberi handle waktu lepas.
  ///
  /// Returns: `true` kalau folder benar-benar sudah tidak ada.
  ///
  /// **Calls:** [Directory.exists], [Directory.delete]
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
