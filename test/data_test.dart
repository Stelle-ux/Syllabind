import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/services/skema_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  setUp(() async {
    await Db.reset();
  });

  tearDown(() async {
    await Db.tutup();
  });

  final mapelRepo = MapelServiceImpl();
    final materiRepo = MateriServiceImpl();
    final tugasRepo = TugasServiceImpl();
    final pengaturanRepo = PengaturanServiceImpl();

  group('Skema database', () {
    test('membuat 5 tabel yang benar', () async {
      final db = await Db.instance();
      final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' "
        "ORDER BY name",
      );
      final nama = r.map((e) => e['name'] as String).toList();
      expect(nama, containsAll([
        SkemaDb.tabelMapel,
        SkemaDb.tabelMateri,
        SkemaDb.tabelTugas,
        SkemaDb.tabelLampiran,
        SkemaDb.tabelPengaturan,
      ]));
      expect(nama.length, 5);
    });

    test('foreign key aktif', () async {
      final db = await Db.instance();
      final r = await db.rawQuery('PRAGMA foreign_keys');
      expect(r.first.values.first, 1);
    });

    test('pengaturan awal terisi', () async {
      final semua = await pengaturanRepo.semua();
      expect(semua.containsKey('tema'), isTrue);
      expect(semua.containsKey('warna_aksen'), isTrue);
      expect(await pengaturanRepo.tema(), 'system');
    });
  });

  group('Mata Pelajaran — CRUD', () {
    test('tambah dan baca', () async {
      final id = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final m = await mapelRepo.cari(id);
      expect(m, isNotNull);
      expect(m!.nama, 'Fisika');
      expect(m.terhapus, isFalse);
    });

    test('ubah nama', () async {
      final id = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final m = await mapelRepo.cari(id);
      await mapelRepo.ubah(m!.copyWith(nama: 'Fisika Dasar'));
      expect((await mapelRepo.cari(id))!.nama, 'Fisika Dasar');
    });

    test('daftar diurutkan berdasarkan nama', () async {
      await mapelRepo.tambah(Mapel(nama: 'Kimia'));
      await mapelRepo.tambah(Mapel(nama: 'Bahasa'));
      await mapelRepo.tambah(Mapel(nama: 'Akuntansi'));
      final d = await mapelRepo.semua();
      expect(d.map((e) => e.nama).toList(), ['Akuntansi', 'Bahasa', 'Kimia']);
    });

    test('jumlah hanya menghitung yang aktif', () async {
      final a = await mapelRepo.tambah(Mapel(nama: 'A'));
      await mapelRepo.tambah(Mapel(nama: 'B'));
      await mapelRepo.hapusLembut(a);
      expect(await mapelRepo.jumlah(), 1);
    });
  });

  group('Mata Pelajaran — soft delete & Sampah', () {
    test('hapus lunak menyembunyikan dari daftar', () async {
      final id = await mapelRepo.tambah(Mapel(nama: 'Sejarah'));
      await mapelRepo.hapusLembut(id);
      expect(await mapelRepo.semua(), isEmpty);
      expect((await mapelRepo.semua(termasukSampah: true)).length, 1);
      expect((await mapelRepo.isiSampah()).length, 1);
    });

    test('pulihkan mengembalikan ke daftar', () async {
      final id = await mapelRepo.tambah(Mapel(nama: 'Sejarah'));
      await mapelRepo.hapusLembut(id);
      await mapelRepo.pulihkan(id);
      expect((await mapelRepo.semua()).length, 1);
      expect(await mapelRepo.isiSampah(), isEmpty);
      expect((await mapelRepo.cari(id))!.deletedAt, isNull);
    });

    test('data isi mapel tidak hilang saat dihapus lunak', () async {
      final id = await mapelRepo.tambah(Mapel(nama: 'Biologi'));
      await materiRepo.tambah(Materi(mapelId: id, judul: 'Sel', isi: 'Isi sel'));
      await mapelRepo.hapusLembut(id);

      // Setelah dipulihkan, isinya harus masih ada.
      await mapelRepo.pulihkan(id);
      final d = await materiRepo.perMapel(id);
      expect(d.length, 1);
      expect(d.first.isi, 'Isi sel');
    });
  });

  group('Materi — CRUD', () {
    test('tambah materi ke mapel', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Hukum Newton', isi: 'F = m.a'),
      );
      final d = await materiRepo.perMapel(mid);
      expect(d.length, 1);
      expect(d.first.judul, 'Hukum Newton');
      expect(d.first.isi, 'F = m.a');
    });

    test('materi terpisah per mapel', () async {
      final a = await mapelRepo.tambah(Mapel(nama: 'A'));
      final b = await mapelRepo.tambah(Mapel(nama: 'B'));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'Materi A'));
      await materiRepo.tambah(Materi(mapelId: b, judul: 'Materi B'));
      expect((await materiRepo.perMapel(a)).single.judul, 'Materi A');
      expect((await materiRepo.perMapel(b)).single.judul, 'Materi B');
    });

    test('cari materi berdasarkan kata', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Hukum Newton', isi: 'gaya massa'),
      );
      await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Termodinamika', isi: 'kalor suhu'),
      );
      expect((await materiRepo.cariKata('Newton')).length, 1);
      expect((await materiRepo.cariKata('kalor')).length, 1);
      expect((await materiRepo.cariKata('zzz')).length, 0);
    });

    test('semua materi lintas mapel (tab Notes)', () async {
      final a = await mapelRepo.tambah(Mapel(nama: 'A'));
      final b = await mapelRepo.tambah(Mapel(nama: 'B'));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'X', isi: 'catatan x'));
      await materiRepo.tambah(Materi(mapelId: b, judul: 'Y', isi: 'catatan y'));
      expect((await materiRepo.semua()).length, 2);
    });

    test('filter hanya yang punya catatan', () async {
      final a = await mapelRepo.tambah(Mapel(nama: 'A'));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'Ada', isi: 'isi'));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'Kosong', isi: '   '));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'Null'));
      expect((await materiRepo.semua(hanyaDenganCatatan: true)).length, 1);
    });
  });

  group('Tugas — CRUD & status', () {
    test('tambah tugas tanpa tenggat', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final id = await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'PR 1'));
      final t = await tugasRepo.cari(id);
      expect(t!.judul, 'PR 1');
      expect(t.status, SkemaDb.statusBelum);
      expect(t.tenggat, isNull);
      expect(t.sisaHari, isNull);
    });

    test('tambah tugas dengan tenggat', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final besok = DateTime.now().add(const Duration(days: 1));
      final id = await tugasRepo.tambah(
        Tugas(mapelId: mid, judul: 'PR 2', tenggat: besok),
      );
      final t = await tugasRepo.cari(id);
      expect(t!.sisaHari, 1);
      expect(t.lewatTenggat, isFalse);
    });

    test('tenggat terdekat', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Besok',
          tenggat: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Jauh',
          tenggat: DateTime.now().add(const Duration(days: 60)),
        ),
      );
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Tidak ada tenggat',
        ),
      );
      final d = await tugasRepo.tenggatTerdekat(batasHari: 7);
      expect(d.length, 1);
      expect(d.first.judul, 'Besok');
    });

    test('tenggat lewat', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Kemarin',
          tenggat: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      expect((await tugasRepo.lewatTenggat()).length, 1);
    });

    test('tenggat lewat tidak dihitung kalau sudah selesai', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final id = await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Kemarin',
          tenggat: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await tugasRepo.ubahStatus(id, SkemaDb.statusSelesai);
      expect(await tugasRepo.lewatTenggat(), isEmpty);
      expect((await tugasRepo.cari(id))!.selesai, isTrue);
    });

    test('filter tugas berdasarkan status', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final a = await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'A'));
      await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'B'));
      await tugasRepo.ubahStatus(a, SkemaDb.statusSelesai);
      expect((await tugasRepo.semua(status: SkemaDb.statusSelesai)).length, 1);
      expect((await tugasRepo.semua(status: SkemaDb.statusBelum)).length, 1);
      expect((await tugasRepo.semua()).length, 2);
    });

    test('ringkasan tugas', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final a = await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'A'));
      await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'B'));
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Lewat',
          tenggat: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );
      await tugasRepo.ubahStatus(a, SkemaDb.statusSelesai);

      final r = await tugasRepo.ringkasan();
      expect(r.selesai, 1);
      expect(r.belum, 2);
      expect(r.lewat, 1);
    });

    test('tugas tanpa tenggat diurutkan paling akhir', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'Tanpa tenggat'));
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Ada tenggat',
          tenggat: DateTime.now().add(const Duration(days: 5)),
        ),
      );
      final d = await tugasRepo.perMapel(mid);
      expect(d.first.judul, 'Ada tenggat');
      expect(d.last.judul, 'Tanpa tenggat');
    });
  });

  group('CASCADE — hapus permanen', () {
    test('hapus mapel permanen menghapus materi & tugasnya', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await materiRepo.tambah(Materi(mapelId: mid, judul: 'Materi'));
      await tugasRepo.tambah(Tugas(mapelId: mid, judul: 'Tugas'));

      await mapelRepo.hapusPermanen(mid);

      expect(await materiRepo.perMapel(mid), isEmpty);
      expect(await tugasRepo.perMapel(mid), isEmpty);
      expect(await mapelRepo.cari(mid), isNull);
    });

    test('mapel lain tidak ikut terhapus', () async {
      final a = await mapelRepo.tambah(Mapel(nama: 'A'));
      final b = await mapelRepo.tambah(Mapel(nama: 'B'));
      await materiRepo.tambah(Materi(mapelId: a, judul: 'Materi A'));
      await materiRepo.tambah(Materi(mapelId: b, judul: 'Materi B'));

      await mapelRepo.hapusPermanen(a);

      expect(await materiRepo.perMapel(a), isEmpty);
      expect((await materiRepo.perMapel(b)).length, 1);
    });

    test('soft delete TIDAK menghapus materi (bisa dipulihkan)', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await materiRepo.tambah(Materi(mapelId: mid, judul: 'Materi'));
      await mapelRepo.hapusLembut(mid);
      expect((await materiRepo.perMapel(mid)).length, 1);
    });

    test('hapus materi permanen menghapus lampirannya', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final matId = await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Materi'),
      );
      final db = await Db.instance();
      await db.insert(SkemaDb.tabelLampiran, {
        'materi_id': matId,
        'tipe': SkemaDb.tipeGambar,
        'nama_file': 'foto.jpg',
        'lokasi_file': '/tmp/foto.jpg',
        'ukuran_file': 1024,
        'created_at': DateTime.now().toIso8601String(),
      });

      await materiRepo.hapusPermanen(matId);

      final sisa = await db.query(SkemaDb.tabelLampiran);
      expect(sisa, isEmpty);
    });

    test('FK menolak lampiran dengan materi yang tidak ada', () async {
      final db = await Db.instance();
      expect(
        () => db.insert(SkemaDb.tabelLampiran, {
          'materi_id': 99999,
          'tipe': SkemaDb.tipeGambar,
          'nama_file': 'x.jpg',
          'lokasi_file': '/tmp/x.jpg',
          'ukuran_file': 1,
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('tipe lampiran dibatasi GAMBAR atau FILE', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final matId = await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Materi'),
      );
      final db = await Db.instance();
      expect(
        () => db.insert(SkemaDb.tabelLampiran, {
          'materi_id': matId,
          'tipe': 'VIDEO',
          'nama_file': 'x.mp4',
          'lokasi_file': '/tmp/x.mp4',
          'ukuran_file': 1,
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Lampiran — model', () {
    test('ukuran terbaca', () {
      expect(Lampiran(
        materiId: 1,
        tipe: Lampiran.tipeFile,
        namaFile: 'a',
        lokasiFile: '/a',
        ukuranFile: 500,
      ).ukuranTerbaca, '500 B');

      expect(Lampiran(
        materiId: 1,
        tipe: Lampiran.tipeFile,
        namaFile: 'a',
        lokasiFile: '/a',
        ukuranFile: 2048,
      ).ukuranTerbaca, '2.0 KB');

      expect(Lampiran(
        materiId: 1,
        tipe: Lampiran.tipeGambar,
        namaFile: 'a',
        lokasiFile: '/a',
        ukuranFile: 3 * 1024 * 1024,
      ).ukuranTerbaca, '3.0 MB');
    });

    test('penanda gambar', () {
      expect(
        Lampiran(
          materiId: 1,
          tipe: Lampiran.tipeGambar,
          namaFile: 'a',
          lokasiFile: '/a',
        ).gambar,
        isTrue,
      );
      expect(
        Lampiran(
          materiId: 1,
          tipe: Lampiran.tipeFile,
          namaFile: 'a',
          lokasiFile: '/a',
        ).gambar,
        isFalse,
      );
    });
  });

  group('Pengaturan', () {
    test('simpan dan baca', () async {
      await pengaturanRepo.setTema('gelap');
      expect(await pengaturanRepo.tema(), 'gelap');
    });

    test('simpan menimpa nilai lama', () async {
      await pengaturanRepo.setWarnaAksen('#111111');
      await pengaturanRepo.setWarnaAksen('#222222');
      expect(await pengaturanRepo.warnaAksen(), '#222222');
    });
  });

  group('Alur nyata — kasus manusia', () {
    test('KASUS 1: hapus mapel lalu pulihkan, data utuh', () async {
      // Siswa menghapus "Fisika" karena semester selesai.
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final matId = await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Hukum Newton', isi: 'F = m.a'),
      );
      final tugasId = await tugasRepo.tambah(
        Tugas(mapelId: mid, judul: 'PR Bab 3'),
      );

      await mapelRepo.hapusLembut(mid);
      expect(await mapelRepo.semua(), isEmpty);

      // Dua minggu kemudian mau review ujian — dipulihkan.
      await mapelRepo.pulihkan(mid);

      final d = await mapelRepo.semua();
      expect(d.length, 1);
      expect((await materiRepo.cari(matId))!.isi, 'F = m.a');
      expect((await tugasRepo.cari(tugasId))!.judul, 'PR Bab 3');
    });

    test('KASUS 2: salah tap hapus, langsung pulihkan', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Kimia'));
      await mapelRepo.hapusLembut(mid);
      expect(await mapelRepo.isiSampah(), hasLength(1));

      await mapelRepo.pulihkan(mid);
      expect(await mapelRepo.isiSampah(), isEmpty);
      expect(await mapelRepo.jumlah(), 1);
    });

    test('KASUS 3: hapus permanen dari Sampah benar-benar membuang', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      await materiRepo.tambah(Materi(mapelId: mid, judul: 'Materi'));
      await mapelRepo.hapusLembut(mid);
      await mapelRepo.hapusPermanen(mid);

      expect(await mapelRepo.isiSampah(), isEmpty);
      expect(await mapelRepo.cari(mid), isNull);
      expect(await materiRepo.perMapel(mid, termasukSampah: true), isEmpty);
    });

    test('KASUS 4: mapel kosong tetap bisa dihapus', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Mapel Kosong'));
      expect(await mapelRepo.hapusPermanen(mid), 1);
    });

    test('KASUS 5: banyak mapel, hapus satu tidak mengganggu yang lain',
        () async {
      final ids = <int>[];
      for (final n in ['A', 'B', 'C', 'D']) {
        ids.add(await mapelRepo.tambah(Mapel(nama: n)));
      }
      for (final id in ids) {
        await materiRepo.tambah(Materi(mapelId: id, judul: 'Materi $id'));
        await tugasRepo.tambah(Tugas(mapelId: id, judul: 'Tugas $id'));
      }

      await mapelRepo.hapusPermanen(ids[1]);

      expect(await mapelRepo.jumlah(), 3);
      expect((await materiRepo.perMapel(ids[0])).length, 1);
      expect((await materiRepo.perMapel(ids[2])).length, 1);
      expect(await materiRepo.perMapel(ids[1]), isEmpty);
      expect(await tugasRepo.ringkasan().then((r) => r.belum), 3);
    });

    test('KASUS 6: mapel tanpa materi & tugas tetap tampil', () async {
      await mapelRepo.tambah(Mapel(nama: 'Mapel Baru'));
      final d = await mapelRepo.semua();
      expect(d.length, 1);
      expect(await materiRepo.perMapel(d.first.id!), isEmpty);
      expect(await tugasRepo.perMapel(d.first.id!), isEmpty);
    });

    test('KASUS 7: catatan panjang tidak terpotong', () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final panjang = 'Baris catatan.\n' * 500;
      final id = await materiRepo.tambah(
        Materi(mapelId: mid, judul: 'Catatan Panjang', isi: panjang),
      );
      final m = await materiRepo.cari(id);
      expect(m!.isi!.length, panjang.length);
      expect(m.isi, panjang);
    });

    test('KASUS 8: karakter khusus & tanda kutip aman', () async {
      final mid = await mapelRepo.tambah(
        Mapel(nama: "Buku O'Brien & \"Rekayasa\" 100%"),
      );
      final m = await mapelRepo.cari(mid);
      expect(m!.nama, "Buku O'Brien & \"Rekayasa\" 100%");

      await materiRepo.tambah(
        Materi(mapelId: mid, judul: "Rumus 5' -> 3'", isi: 'a; DROP TABLE x;--'),
      );
      final d = await materiRepo.perMapel(mid);
      expect(d.first.isi, 'a; DROP TABLE x;--');
      // Tabel masih ada — tidak kena SQL injection.
      expect(await mapelRepo.jumlah(), 1);
    });

    test('KASUS 9: nama mapel kosong ditolak database', () async {
      final db = await Db.instance();
      expect(
        () => db.insert(SkemaDb.tabelMapel, {
          'nama': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('KASUS 10: mapel duplikat diizinkan (kelas berbeda)', () async {
      await mapelRepo.tambah(Mapel(nama: 'Matematika', deskripsi: 'Kelas X'));
      await mapelRepo.tambah(Mapel(nama: 'Matematika', deskripsi: 'Kelas XI'));
      expect(await mapelRepo.jumlah(), 2);
    });

    test('KASUS 11: tugas lewat tenggat TIDAK muncul di "tenggat terdekat"',
        () async {
      final mid = await mapelRepo.tambah(Mapel(nama: 'Fisika'));
      final kini = DateTime.now();

      // Satu tugas lewat 1 hari, satu tugas 2 hari ke depan.
      final lewat = await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Sudah lewat',
          tenggat: kini.subtract(const Duration(days: 1)),
        ),
      );
      await tugasRepo.tambah(
        Tugas(
          mapelId: mid,
          judul: 'Masih jauh',
          tenggat: kini.add(const Duration(days: 2)),
        ),
      );
      expect(lewat, greaterThan(0));

      final dekat = await tugasRepo.tenggatTerdekat();
      final judulDekat = dekat.map((t) => t.judul).toList();

      // Bug yang pernah terjadi: tugas lewat muncul di dua bagian sekaligus.
      expect(judulDekat, contains('Masih jauh'));
      expect(judulDekat, isNot(contains('Sudah lewat')));

      // Tugas lewat hanya boleh muncul di daftar "lewat tenggat".
      final terlambat = await tugasRepo.lewatTenggat();
      expect(terlambat.map((t) => t.judul), contains('Sudah lewat'));

      // Pantulan: keduanya tidak boleh beririsan.
      final irisan = dekat
          .map((t) => t.id)
          .toSet()
          .intersection(terlambat.map((t) => t.id).toSet());
      expect(irisan, isEmpty);
    });
  });
}