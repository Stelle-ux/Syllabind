import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/services/skema_db.dart';

/// Membuktikan lampiran pada catatan bersifat **opsional**:
///   - catatan tanpa lampiran tetap tersimpan (jalur yang paling sering
///     dipakai, terutama catatan matematika yang cukup teks saja),
///   - catatan dengan lampiran menyalin berkasnya ke penyimpanan aplikasi,
///   - lampiran ikut terhapus saat catatannya dihapus.
void main() {
  late Directory akarUji;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  setUp(() async {
    await Db.reset();
    // Folder dokumen tiruan: getApplicationDocumentsDirectory() butuh kanal
    // platform yang tidak ada di Dart VM, jadi diarahkan ke folder proyek.
    akarUji = Directory(p.join(Directory.current.path, 'build', 'uji_tmp'));
    await akarUji.create(recursive: true);
    LampiranRepositoryImpl.folderUji = akarUji;
  });

  tearDown(() async {
    LampiranRepositoryImpl.folderUji = null;
    await Db.tutup();
  });

  final mapelRepo = MapelRepositoryImpl();
  final materiRepo = MateriRepositoryImpl();
  final lampiranRepo = LampiranRepositoryImpl();

  Future<int> buatMapel([String nama = 'Matematika']) =>
      mapelRepo.tambah(Mapel(nama: nama, warna: '#4C6FFF'));

  /// Berkas tiruan sebagai bahan lampiran.
  Future<File> berkasUji(String nama) async {
    final akar = Directory(p.join(Directory.current.path, 'build', 'uji_tmp'));
    await akar.create(recursive: true);
    final f = File(p.join(akar.path, nama));
    await f.writeAsBytes(List<int>.generate(64, (i) => i));
    return f;
  }

  group('Catatan tanpa lampiran', () {
    test('tetap tersimpan walau tidak ada lampiran', () async {
      final mapelId = await buatMapel();
      await materiRepo.tambah(Materi(
        mapelId: mapelId,
        judul: 'Rumus kuadrat',
        isi: 'x = (-b ± akar(b^2 - 4ac)) / 2a',
      ));

      final daftar = await materiRepo.perMapel(mapelId);
      expect(daftar, hasLength(1));
      expect(daftar.first.judul, 'Rumus kuadrat');
      expect(daftar.first.isi, contains('4ac'));

      // Inti dari "opsional": tidak ada lampiran yang dibuat diam-diam.
      expect(await lampiranRepo.perMateri(daftar.first.id!), isEmpty);
      expect(await lampiranRepo.totalUkuran(), 0);
    });

    test('sepuluh catatan teks murni tersimpan tanpa satu lampiran pun',
        () async {
      final mapelId = await buatMapel();
      for (var i = 1; i <= 10; i++) {
        await materiRepo.tambah(Materi(
          mapelId: mapelId,
          judul: 'Catatan $i',
          isi: 'Isi catatan nomor $i',
        ));
      }
      expect(await materiRepo.perMapel(mapelId), hasLength(10));
      expect(await lampiranRepo.totalUkuran(), 0);
    });
  });

  group('Catatan dengan lampiran', () {
    test('berkas disalin ke penyimpanan aplikasi', () async {
      final mapelId = await buatMapel();
      final materiId = await materiRepo.tambah(Materi(
        mapelId: mapelId,
        judul: 'Grafik parabola',
        isi: 'Catatan dengan gambar',
      ));

      final sumber = await berkasUji('grafik_parabola.png');
      final lampiranId = await lampiranRepo.tambahDariFile(
        materiId: materiId,
        sumber: sumber,
        tipe: Lampiran.tipeGambar,
      );

      final daftar = await lampiranRepo.perMateri(materiId);
      expect(daftar, hasLength(1));

      final l = daftar.first;
      expect(l.id, lampiranId);
      expect(l.tipe, Lampiran.tipeGambar);
      expect(l.gambar, isTrue);
      expect(l.namaFile, contains('grafik_parabola'));

      // Berkas benar-benar ada di penyimpanan aplikasi...
      expect(File(l.lokasiFile).existsSync(), isTrue);
      // ...dan letaknya berbeda dari berkas asli (disalin, bukan dirujuk).
      expect(p.normalize(l.lokasiFile), isNot(p.normalize(sumber.path)));
      // Berkas asli tidak disentuh.
      expect(sumber.existsSync(), isTrue);
    });

    test('lampiran file dan gambar dibedakan tipenya', () async {
      final mapelId = await buatMapel();
      final materiId = await materiRepo.tambah(Materi(
        mapelId: mapelId,
        judul: 'Campuran',
        isi: 'gambar + file',
      ));

      await lampiranRepo.tambahDariFile(
        materiId: materiId,
        sumber: await berkasUji('foto.png'),
        tipe: Lampiran.tipeGambar,
      );
      await lampiranRepo.tambahDariFile(
        materiId: materiId,
        sumber: await berkasUji('tugas.pdf'),
        tipe: Lampiran.tipeFile,
      );

      final semua = await lampiranRepo.perMateri(materiId);
      expect(semua, hasLength(2));
      expect(semua.where((l) => l.gambar), hasLength(1));
      expect(semua.where((l) => !l.gambar), hasLength(1));

      final hitung = await lampiranRepo.jumlahPerTipe();
      expect(hitung[Lampiran.tipeGambar], 1);
      expect(hitung[Lampiran.tipeFile], 1);
    });

    test('hapus lunak menyembunyikan catatan, lampiran ikut tersembunyi',
        () async {
      final mapelId = await buatMapel();
      final materiId = await materiRepo.tambah(Materi(
        mapelId: mapelId,
        judul: 'Catatan',
        isi: 'isi',
      ));
      await lampiranRepo.tambahDariFile(
        materiId: materiId,
        sumber: await berkasUji('lampiran.txt'),
        tipe: Lampiran.tipeFile,
      );
      expect(await lampiranRepo.perMateri(materiId), hasLength(1));
      expect(await lampiranRepo.semua(), hasLength(1));

      await materiRepo.hapus(materiId);

      // Aturan §4: hapus catatan = hapus lunak. Catatan hilang dari daftar
      // biasa, lampirannya ikut tidak tampil, dan masih bisa dipulihkan.
      expect(await materiRepo.perMapel(mapelId), isEmpty);
      expect(await lampiranRepo.semua(), isEmpty,
          reason: 'lampiran catatan terhapus tidak boleh ikut terdaftar');

      await materiRepo.pulihkan(materiId);
      expect(await materiRepo.perMapel(mapelId), hasLength(1));
      expect(await lampiranRepo.semua(), hasLength(1));
    });

    test('hapus permanen membuang baris lampiran lewat CASCADE', () async {
      final mapelId = await buatMapel();
      final materiId = await materiRepo.tambah(Materi(
        mapelId: mapelId,
        judul: 'Catatan',
        isi: 'isi',
      ));
      await lampiranRepo.tambahDariFile(
        materiId: materiId,
        sumber: await berkasUji('cascade.txt'),
        tipe: Lampiran.tipeFile,
      );
      expect(await lampiranRepo.perMateri(materiId), hasLength(1));

      await materiRepo.hapusPermanen(materiId);

      final db = await Db.instance();
      final sisa = await db.query(
        SkemaDb.tabelLampiran,
        where: 'materi_id = ?',
        whereArgs: [materiId],
      );
      expect(sisa, isEmpty, reason: 'ON DELETE CASCADE harus membuang baris');
    });
  });

  group('Lampiran di halaman Library', () {
    test('tambahKeMapel memakai catatan penampung untuk mapel', () async {
      final mapelId = await buatMapel('Fisika');

      final lampiranId = await lampiranRepo.tambahKeMapel(
        mapelId: mapelId,
        sumber: await berkasUji('materi_fisika.pdf'),
        tipe: Lampiran.tipeFile,
      );
      expect(lampiranId, greaterThan(0));

      // Lampiran menempel pada satu catatan penampung di mapel itu.
      final materi = await materiRepo.perMapel(mapelId);
      expect(materi, isNotEmpty);

      final lampiran = await lampiranRepo.perMateri(materi.first.id!);
      expect(lampiran, hasLength(1));
      expect(lampiran.first.materiId, materi.first.id);
      expect(lampiran.first.tipe, Lampiran.tipeFile);

      // Panggilan kedua tidak membuat catatan penampung baru.
      await lampiranRepo.tambahKeMapel(
        mapelId: mapelId,
        sumber: await berkasUji('materi_fisika_2.pdf'),
        tipe: Lampiran.tipeFile,
      );
      expect(await materiRepo.perMapel(mapelId), hasLength(1),
          reason: 'penampung harus dipakai ulang, bukan dibuat lagi');
      expect(await lampiranRepo.perMateri(materi.first.id!), hasLength(2));
    });

    test('semua lampiran lintas mapel bisa ditampilkan', () async {
      final a = await buatMapel('Kimia');
      final b = await buatMapel('Biologi');

      await lampiranRepo.tambahKeMapel(
        mapelId: a,
        sumber: await berkasUji('kimia.png'),
        tipe: Lampiran.tipeGambar,
      );
      await lampiranRepo.tambahKeMapel(
        mapelId: b,
        sumber: await berkasUji('biologi.pdf'),
        tipe: Lampiran.tipeFile,
      );

      final semua = await lampiranRepo.semua();
      expect(semua, hasLength(2));

      final hanyaGambar = await lampiranRepo.semua(tipe: Lampiran.tipeGambar);
      expect(hanyaGambar, hasLength(1));
      expect(hanyaGambar.first.namaFile, contains('kimia'));

      expect(await lampiranRepo.totalUkuran(), greaterThan(0));
    });
  });
}
