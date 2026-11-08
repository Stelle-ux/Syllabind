import 'package:sqflite/sqflite.dart';

/// Skema database Syllabind.
///
/// Sumber kebenaran: `SPESIFIKASI-FINAL.md` §3.
/// 5 tabel:
///   mata_pelajaran       — mapel yang diampu siswa
///   materi_pembelajaran  — materi/catatan di dalam mapel (kolom `isi` = catatan)
///   tugas                — tugas di dalam mapel (boleh punya tenggat & status)
///   lampiran             — SATU tabel untuk Gambar + File, dibedakan kolom `tipe`
///   pengaturan           — preferensi aplikasi
///
/// Aturan hapus (SPESIFIKASI-FINAL.md §4):
///   - Mata Pelajaran  : soft delete (`deleted_at`), CASCADE saat purge
///   - Materi          : soft delete, CASCADE ke lampiran saat purge
///   - Tugas           : soft delete
///   - Lampiran        : hard delete + hapus file fisik
///
/// Catatan: tabel memakai `deleted_at` (bukan `is_deleted`) supaya waktu
/// penghapusan tetap terekam dan bisa dipakai untuk pembersihan otomatis.
///
/// **Reused in:** [Db.init] (database initialization), [test/data_test.dart] (schema verification)
/// **Calls:** sqflite [Database.execute], [Database.insert]
class SkemaDb {
  SkemaDb._();

  /// Nama file database SQLite.
  ///
  /// **Reused in:** [Db.database] (path construction)
  static const String namaFile = 'syllabind.db';

  /// Versi skema database. Naikkan saat migrasi.
  ///
  /// **Reused in:** [Db.init] (onUpgrade callback)
  static const int versi = 1;

  /// Nama tabel mata pelajaran.
  ///
  /// **Reused in:** [RepoMapel], [RepoMateri], [RepoTugas], [LayananHapus], [SkemaDb.buat]
  static const String tabelMapel = 'mata_pelajaran';

  /// Nama tabel materi pembelajaran.
  ///
  /// **Reused in:** [RepoMateri], [RepoLampiran], [LayananHapus], [SkemaDb.buat]
  static const String tabelMateri = 'materi_pembelajaran';

  /// Nama tabel tugas.
  ///
  /// **Reused in:** [RepoTugas], [LayananHapus], [SkemaDb.buat]
  static const String tabelTugas = 'tugas';

  /// Nama tabel lampiran (gabungan gambar + file).
  ///
  /// **Reused in:** [RepoLampiran], [LayananHapus], [SkemaDb.buat]
  static const String tabelLampiran = 'lampiran';

  /// Nama tabel pengaturan (key-value).
  ///
  /// **Reused in:** [RepoPengaturan], [SkemaDb.buat]
  static const String tabelPengaturan = 'pengaturan';

  /// Tipe lampiran: Gambar. Disimpan sebagai teks supaya mudah dibaca di DB Browser.
  ///
  /// **Reused in:** [RepoLampiran.tambahDariFile], [RepoLampiran.semua], [Lampiran.tipe]
  static const String tipeGambar = 'GAMBAR';

  /// Tipe lampiran: File. Disimpan sebagai teks supaya mudah dibaca di DB Browser.
  ///
  /// **Reused in:** [RepoLampiran.tambahDariFile], [RepoLampiran.semua], [Lampiran.tipe]
  static const String tipeFile = 'FILE';

  /// Status tugas: Belum dikerjakan.
  ///
  /// **Reused in:** [RepoTugas.tambah], [RepoTugas.toggleStatus], [Tugas.status], [SkemaDb.buat]
  static const String statusBelum = 'BELUM';

  /// Status tugas: Selesai.
  ///
  /// **Reused in:** [RepoTugas.toggleStatus], [Tugas.status], [SkemaDb.buat]
  static const String statusSelesai = 'SELESAI';

  /// Membuat seluruh skema database: 5 tabel + indeks + pengaturan awal.
  ///
  /// Dipanggil sekali saat database pertama kali dibuat via [Db.init].
  /// Menggunakan `ON DELETE CASCADE` pada FK untuk memastikan konsistensi
  /// referensial saat Mapel/Materi dihapus permanen (purge).
  ///
  /// Parameter:
  ///   - [db]: Instance database sqflite yang baru dibuat.
  ///   - [versi]: Versi skema (harus sama dengan [SkemaDb.versi]).
  ///
  /// **Reused in:** [Db.init] (onCreate callback)
  /// **Calls:** [Database.execute] (5× CREATE TABLE + 4× CREATE INDEX), [Database.insert] (4× pengaturan awal)
  static Future<void> buat(Database db, int versi) async {
    await db.execute('''
      CREATE TABLE $tabelMapel (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nama        TEXT    NOT NULL,
        deskripsi   TEXT,
        warna       TEXT,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        deleted_at  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tabelMateri (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        mapel_id    INTEGER NOT NULL,
        judul       TEXT    NOT NULL,
        isi         TEXT,
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        deleted_at  TEXT,
        FOREIGN KEY (mapel_id) REFERENCES $tabelMapel (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tabelTugas (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        mapel_id    INTEGER NOT NULL,
        judul       TEXT    NOT NULL,
        deskripsi   TEXT,
        tenggat     TEXT,
        status      TEXT    NOT NULL DEFAULT '$statusBelum',
        created_at  TEXT    NOT NULL,
        updated_at  TEXT    NOT NULL,
        deleted_at  TEXT,
        FOREIGN KEY (mapel_id) REFERENCES $tabelMapel (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tabelLampiran (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        materi_id   INTEGER NOT NULL,
        tipe        TEXT    NOT NULL CHECK (tipe IN ('$tipeGambar', '$tipeFile')),
        nama_file   TEXT    NOT NULL,
        lokasi_file TEXT    NOT NULL,
        ukuran_file INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL,
        FOREIGN KEY (materi_id) REFERENCES $tabelMateri (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tabelPengaturan (
        kunci   TEXT PRIMARY KEY,
        nilai   TEXT NOT NULL
      )
    ''');

    // Indeks untuk query yang paling sering dipakai.
    await db.execute(
      'CREATE INDEX idx_materi_mapel ON $tabelMateri (mapel_id)',
    );
    await db.execute('CREATE INDEX idx_tugas_mapel ON $tabelTugas (mapel_id)');
    await db.execute(
      'CREATE INDEX idx_tugas_tenggat ON $tabelTugas (tenggat)',
    );
    await db.execute(
      'CREATE INDEX idx_lampiran_materi ON $tabelLampiran (materi_id)',
    );

    // Nilai awal pengaturan.
    final now = DateTime.now().toIso8601String();
    for (final kv in {
      'tema': 'system', // system | terang | gelap
      'warna_aksen': '#2F6F6B',
      'versi_skema': '1',
      'dibuat_pada': now,
    }.entries) {
      await db.insert(tabelPengaturan, {
        'kunci': kv.key,
        'nilai': kv.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}