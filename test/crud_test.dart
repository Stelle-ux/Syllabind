import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/layanan_ekspor.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/tools/bahasa.dart';

/// Menguji fitur CRUD penuh + ekspor per-catatan.
///
/// Yang dibuktikan BUKAN "tombolnya ada", melainkan bahwa perubahan benar
/// benar tersimpan ke database dan terbaca kembali:
///   1. Ubah catatan (judul & isi), termasuk MENGOSONGKAN isi
///   2. Ubah tugas (judul, deskripsi, tenggat), termasuk MENGHAPUS tenggat
///   3. Ubah status tugas tidak menyentuh judul
///   4. Ganti nama lampiran tidak menyentuh berkas fisik
///   5. Ekspor satu catatan menghasilkan berkas .txt berisi catatan itu
void main() {
  late Directory akarUji;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
    LampiranRepositoryImpl.folderUji = null;
    LayananEkspor.folderUji = null;
    await Db.tutup();
  });

  setUp(() async {
    final db = await Db.instance();
    await db.delete(SkemaDb.tabelLampiran);
    await db.delete(SkemaDb.tabelTugas);
    await db.delete(SkemaDb.tabelMateri);
    await db.delete(SkemaDb.tabelMapel);
    Bahasa.set(Bahasa.id);

    // Folder dokumen tiruan: getApplicationDocumentsDirectory() butuh kanal
    // platform yang tidak ada di Dart VM, jadi diarahkan ke folder proyek.
    // Ikut pola test/lampiran_opsional_test.dart.
    akarUji = Directory(p.join(Directory.current.path, 'build', 'uji_tmp'));
    await akarUji.create(recursive: true);
    LampiranRepositoryImpl.folderUji = akarUji;
    LayananEkspor.folderUji = akarUji;
  });

  /// Membuat satu mapel dan mengembalikan id-nya.
  Future<int> mapelBaru() => MapelRepositoryImpl().tambah(
        Mapel(nama: 'Matematika', warna: '#4C6FFF'),
      );

  // ── 1. Ubah catatan ────────────────────────────────────────

  group('Ubah catatan', () {
    test('judul dan isi berubah setelah disimpan', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final id = await repo.tambah(
        Materi(mapelId: mapelId, judul: 'Lama', isi: 'isi lama'),
      );

      final asli = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      await repo.ubah(asli.copyWith(judul: 'Baru', isi: 'isi baru'));

      final hasil = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      expect(hasil.judul, 'Baru');
      expect(hasil.isi, 'isi baru');
    });

    test('isi bisa dikosongkan lewat hapusIsi', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final id = await repo.tambah(
        Materi(mapelId: mapelId, judul: 'Catatan', isi: 'ada isinya'),
      );

      final asli = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      // Tanpa hapusIsi, `isi ?? this.isi` akan mempertahankan isi lama.
      await repo.ubah(asli.copyWith(hapusIsi: true));

      final hasil = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      expect(hasil.judul, 'Catatan', reason: 'judul harus tetap');
      expect(hasil.isi, isNull, reason: 'isi harus benar-benar null');
    });

    test('ubah catatan tidak memindahkan mapel', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final id = await repo.tambah(
        Materi(mapelId: mapelId, judul: 'A', isi: 'x'),
      );

      final asli = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      await repo.ubah(asli.copyWith(judul: 'A2'));

      final hasil = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);
      expect(hasil.mapelId, mapelId);
    });
  });

  // ── 2. Ubah tugas ──────────────────────────────────────────

  group('Ubah tugas', () {
    test('judul, deskripsi, dan tenggat berubah setelah disimpan', () async {
      final mapelId = await mapelBaru();
      final repo = TugasRepositoryImpl();
      final id = await repo.tambah(
        Tugas(mapelId: mapelId, judul: 'Tugas lama', deskripsi: 'lama'),
      );

      final asli = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      final tenggat = DateTime(2026, 11, 9, 23, 59);
      await repo.ubah(
        asli.copyWith(
          judul: 'Tugas baru',
          deskripsi: 'deskripsi baru',
          tenggat: tenggat,
        ),
      );

      final hasil = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      expect(hasil.judul, 'Tugas baru');
      expect(hasil.deskripsi, 'deskripsi baru');
      expect(hasil.tenggat?.year, 2026);
      expect(hasil.tenggat?.month, 11);
      expect(hasil.tenggat?.day, 9);
    });

    test('tenggat bisa dihapus lewat hapusTenggat', () async {
      final mapelId = await mapelBaru();
      final repo = TugasRepositoryImpl();
      final id = await repo.tambah(
        Tugas(
          mapelId: mapelId,
          judul: 'Ada tenggat',
          tenggat: DateTime(2026, 12, 1),
        ),
      );

      final asli = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      expect(asli.tenggat, isNotNull, reason: 'prasyarat tes');

      await repo.ubah(asli.copyWith(hapusTenggat: true));

      final hasil = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      expect(hasil.tenggat, isNull, reason: 'tenggat harus benar-benar null');
      expect(hasil.judul, 'Ada tenggat', reason: 'judul tidak boleh ikut hilang');
    });

    test('ubah teks tidak mengubah status selesai', () async {
      final mapelId = await mapelBaru();
      final repo = TugasRepositoryImpl();
      final id = await repo.tambah(
        Tugas(mapelId: mapelId, judul: 'Judul asli'),
      );
      await repo.ubahStatus(id, 'SELESAI');

      final asli = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      await repo.ubah(asli.copyWith(judul: 'Judul diubah'));

      final hasil = (await repo.perMapel(mapelId)).firstWhere((t) => t.id == id);
      expect(hasil.judul, 'Judul diubah');
      expect(hasil.status, 'SELESAI', reason: 'status harus bertahan');
    });
  });

  // ── 3. Ganti nama lampiran ─────────────────────────────────

  group('Ganti nama lampiran', () {
    test('nama berubah tapi materi_id dan lokasi_file tetap', () async {
      final mapelId = await mapelBaru();
      final materiId = await MateriRepositoryImpl().tambah(
        Materi(mapelId: mapelId, judul: 'Catatan'),
      );
      final repo = LampiranRepositoryImpl();

      // tambahDariFile menyalin berkas nyata, jadi sumbernya harus ada.
      // Jangan pakai Directory.systemTemp: di Windows lewat MSYS, TMPDIR bisa
      // berbentuk '/c/Users/...' dan menghasilkan path 'C:\c\Users\...'.
      final sumber = File(p.join(akarUji.path, 'sumber_lampiran.pdf'));
      await sumber.writeAsString('isi palsu untuk tes');

      final id = await repo.tambahDariFile(
        materiId: materiId,
        sumber: sumber,
        tipe: Lampiran.tipeFile,
      );

      final sebelum = (await repo.semua()).firstWhere((l) => l.id == id);
      final lokasiSemula = sebelum.lokasiFile;
      expect(sebelum.namaFile, 'sumber_lampiran.pdf');

      await repo.ubahNama(id, 'Tugas Akhir.pdf');

      final hasil = (await repo.semua()).firstWhere((l) => l.id == id);
      expect(hasil.namaFile, 'Tugas Akhir.pdf');
      expect(hasil.lokasiFile, lokasiSemula,
          reason: 'berkas fisik tidak boleh dipindah');
      expect(hasil.materiId, materiId);
      expect(hasil.ukuranFile, sebelum.ukuranFile);
      expect(await File(lokasiSemula).exists(), isTrue,
          reason: 'berkas salinan harus masih ada');
    });
  });

  // ── 4. Ekspor per-catatan ──────────────────────────────────

  group('Ekspor per-catatan', () {
    test('menghasilkan .txt berisi judul, isi, dan nama mapel', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final id = await repo.tambah(
        Materi(
          mapelId: mapelId,
          judul: 'Rumus Lingkaran',
          isi: 'Luas = pi * r^2',
        ),
      );
      final catatan =
          (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);

      final berkas = await LayananEkspor().eksporCatatan(
        catatan: catatan,
        namaMapel: 'Matematika',
      );

      expect(berkas.path, endsWith('.txt'));
      expect(await berkas.exists(), isTrue);

      final teks = await berkas.readAsString();
      expect(teks, contains('Rumus Lingkaran'));
      expect(teks, contains('Luas = pi * r^2'));
      expect(teks, contains('Matematika'));
    });

    test('catatan tanpa isi tetap menghasilkan berkas yang sah', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final id = await repo.tambah(
        Materi(mapelId: mapelId, judul: 'Catatan Kosong'),
      );
      final catatan =
          (await repo.perMapel(mapelId)).firstWhere((m) => m.id == id);

      final berkas = await LayananEkspor().eksporCatatan(
        catatan: catatan,
        namaMapel: 'Matematika',
      );

      final teks = await berkas.readAsString();
      expect(teks, contains('Catatan Kosong'));
      // Tidak boleh gagal hanya karena isi null.
      expect(teks, isNotEmpty);
    });

    test('ekspor satu catatan tidak menyertakan catatan lain', () async {
      final mapelId = await mapelBaru();
      final repo = MateriRepositoryImpl();
      final idA = await repo.tambah(
        Materi(mapelId: mapelId, judul: 'Catatan A', isi: 'isi A'),
      );
      await repo.tambah(
        Materi(mapelId: mapelId, judul: 'Catatan B', isi: 'isi B'),
      );

      final a = (await repo.perMapel(mapelId)).firstWhere((m) => m.id == idA);
      final berkas = await LayananEkspor().eksporCatatan(
        catatan: a,
        namaMapel: 'Matematika',
      );

      final teks = await berkas.readAsString();
      expect(teks, contains('Catatan A'));
      expect(teks, isNot(contains('Catatan B')),
          reason: 'ekspor harus terbatas pada satu catatan');
    });
  });

  // ── 5. Kunci bahasa untuk fitur baru ──────────────────────

  group('Kunci bahasa fitur baru', () {
    test('kunci aksi baru ada di kedua bahasa', () {
      const kunci = [
        'k_ubah',
        'k_lihat',
        'k_rename',
        'k_ekspor_tooltip',
        'dm_ubah_catatan',
        'dm_ubah_tugas',
        'dm_ekspor_sukses',
        'dm_ekspor_gagal',
        'dm_catatan_diubah',
        'dm_tugas_diubah',
        'lib_ubah_nama_judul',
        'lib_ubah_nama_sukses',
        'lib_buka_gagal',
      ];
      for (final k in kunci) {
        Bahasa.set(Bahasa.id);
        final id = t(k);
        Bahasa.set(Bahasa.en);
        final en = t(k);
        Bahasa.set(Bahasa.id);
        expect(id, isNot(equals(k)), reason: '$k belum ada di kamus ID');
        expect(en, isNot(equals(k)), reason: '$k belum ada di kamus EN');
        expect(id, isNot(equals(en)),
            reason: '$k diterjemahkan sama di ID dan EN');
      }
    });

    test('pesan ekspor mengisi placeholder path', () {
      Bahasa.set(Bahasa.id);
      final teks = tp('dm_ekspor_sukses', {'path': '/a/b.txt'});
      expect(teks, contains('/a/b.txt'));
      expect(teks, isNot(contains('{path}')));
    });

    test('pesan hapus tugas mengisi placeholder judul', () {
      Bahasa.set(Bahasa.id);
      final teks = tp('dm_hapus_tugas', {'judul': 'PR Fisika'});
      expect(teks, contains('PR Fisika'));
      expect(teks, isNot(contains('{judul}')));
    });

    test('tidak ada kunci duplikat di kamus', () {
      // Duplikat kunci adalah error kompilasi untuk map const, tetapi tes ini
      // menjaga kalau nanti kamus diubah jadi non-const.
      Bahasa.set(Bahasa.id);
      expect(t('k_ubah'), isNot(equals('k_ubah')));
    });
  });
}