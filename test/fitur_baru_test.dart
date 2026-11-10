import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/index.dart';
import 'package:syllabind/tools/tema.dart';

/// Menguji dua fitur yang ditambahkan setelah APK pertama:
///   1. Color picker per mata pelajaran
///   2. Checkbox tandai-selesai di Home
///
/// Yang dibuktikan bukan sekadar \"tombolnya ada\", melainkan bahwa warna dan
/// status benar-benar tersimpan ke database dan terbaca kembali.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
    await Db.tutup();
  });

  setUp(() async {
    // Database bersih untuk setiap tes supaya hitungan tidak saling ganggu.
    final db = await Db.instance();
    await db.delete(SkemaDb.tabelLampiran);
    await db.delete(SkemaDb.tabelTugas);
    await db.delete(SkemaDb.tabelMateri);
    await db.delete(SkemaDb.tabelMapel);
    Bahasa.set(Bahasa.id);
  });

  // ── 1. Color picker ────────────────────────────────────────

  group('Warna mata pelajaran', () {
    test('palet warna mapel berisi hex yang valid', () {
      expect(TemaApp.paletMapel, isNotEmpty);
      for (final hex in TemaApp.paletMapel) {
        expect(hex, startsWith('#'));
        expect(hex.length, 7, reason: '$hex bukan format #RRGGBB');
        expect(
          int.tryParse(hex.substring(1), radix: 16),
          isNotNull,
          reason: '$hex tidak bisa dibaca sebagai angka hex',
        );
      }
    });

    test('warna tersimpan saat mapel ditambah dan terbaca lagi', () async {
          final repo = MapelServiceImpl();
      final id = await repo.tambah(
        Mapel(nama: 'Matematika', warna: '#7C3AED'),
      );

      final lagi = await repo.cari(id);
      expect(lagi, isNotNull);
      expect(lagi!.warna, '#7C3AED');

      // Dan warna itu benar-benar dipakai untuk menggambar.
      expect(TemaApp.dariHex(lagi.warna).toARGB32(),
          TemaApp.dariHex('#7C3AED').toARGB32());
    });

    test('mapel tanpa warna memakai warna tema', () async {
          final repo = MapelServiceImpl();
      final id = await repo.tambah(Mapel(nama: 'Fisika'));

      final lagi = await repo.cari(id);
      expect(lagi!.warna, isNull);
      // dariHex(null) harus jatuh ke aksen bawaan, bukan null/transparan.
      expect(
        TemaApp.dariHex(lagi.warna).toARGB32(),
        TemaApp.aksenDefault.toARGB32(),
      );
    });

    test('warna bisa diganti lewat ubah()', () async {
          final repo = MapelServiceImpl();
      final id = await repo.tambah(
        Mapel(nama: 'Kimia', warna: '#2563EB'),
      );

      final awal = await repo.cari(id);
      await repo.ubah(awal!.copyWith(warna: '#DC2626'));

      final baru = await repo.cari(id);
      expect(baru!.warna, '#DC2626');
    });

    test('hapusTandaWarna mengosongkan warna kembali ke tema', () async {
          final repo = MapelServiceImpl();
      final id = await repo.tambah(
        Mapel(nama: 'Biologi', warna: '#16A34A'),
      );

      final awal = await repo.cari(id);
      expect(awal!.warna, '#16A34A');

      // copyWith(warna: null) TIDAK boleh menghapus — null berarti
      // \"tidak diubah\". Harus lewat penanda khusus.
      final tanpaPenanda = awal.copyWith(warna: null);
      expect(tanpaPenanda.warna, '#16A34A',
          reason: 'null seharusnya berarti tidak diubah');

      await repo.ubah(awal.copyWith(hapusTandaWarna: true));
      final sesudah = await repo.cari(id);
      expect(sesudah!.warna, isNull);
    });

    test('ubah nama tidak menghilangkan warna', () async {
          final repo = MapelServiceImpl();
      final id = await repo.tambah(
        Mapel(nama: 'Sejarah', warna: '#D97706'),
      );

      final awal = await repo.cari(id);
      await repo.ubah(awal!.copyWith(nama: 'Sejarah Indonesia'));

      final baru = await repo.cari(id);
      expect(baru!.nama, 'Sejarah Indonesia');
      expect(baru.warna, '#D97706', reason: 'warna ikut hilang saat ganti nama');
    });
  });

  // ── 2. Checkbox selesai di Home ────────────────────────────

  group('Tandai selesai dari Home', () {
    Future<Tugas> siapkanTugas() async {
          final mapelId = await MapelServiceImpl().tambah(Mapel(nama: 'Matematika'));
          final repo = TugasServiceImpl();
      final id = await repo.tambah(
        Tugas(
          mapelId: mapelId,
          judul: 'Latihan integral',
          tenggat: DateTime.now().add(const Duration(days: 2)),
        ),
      );
      return (await repo.cari(id))!;
    }

    test('tugas baru berstatus belum selesai', () async {
      final tg = await siapkanTugas();
      expect(tg.status, SkemaDb.statusBelum);
      expect(tg.selesai, isFalse);
    });

    test('ubahStatus menandai selesai dan bertahan di database', () async {
      final tg = await siapkanTugas();
          await TugasServiceImpl().ubahStatus(tg.id!, SkemaDb.statusSelesai);

          final lagi = await TugasServiceImpl().cari(tg.id!);
      expect(lagi!.selesai, isTrue);
      expect(lagi.status, SkemaDb.statusSelesai);
    });

    test('tanda selesai bisa diurungkan', () async {
      final tg = await siapkanTugas();
          final repo = TugasServiceImpl();

      await repo.ubahStatus(tg.id!, SkemaDb.statusSelesai);
      expect((await repo.cari(tg.id!))!.selesai, isTrue);

      await repo.ubahStatus(tg.id!, SkemaDb.statusBelum);
      expect((await repo.cari(tg.id!))!.selesai, isFalse);
    });

    test('tugas selesai keluar dari daftar tenggat terdekat Home', () async {
      final tg = await siapkanTugas();
          final repo = TugasServiceImpl();

      expect((await repo.tenggatTerdekat()).length, 1);

      await repo.ubahStatus(tg.id!, SkemaDb.statusSelesai);

      // Inilah alasan Home menyimpan penanda sendiri: baris yang baru
      // dicentang hilang dari query, jadi harus ditahan di layar sebentar
      // supaya tombol Urungkan sempat dipakai.
      expect((await repo.tenggatTerdekat()).length, 0);
    });

    test('ringkasan Home ikut bergeser setelah ditandai selesai', () async {
      final tg = await siapkanTugas();
          final repo = TugasServiceImpl();

      var r = await repo.ringkasan();
      expect(r.belum, 1);
      expect(r.selesai, 0);

      await repo.ubahStatus(tg.id!, SkemaDb.statusSelesai);

      r = await repo.ringkasan();
      expect(r.belum, 0);
      expect(r.selesai, 1);
      expect(r.lewat, 0);
    });

    test('tugas lewat tenggat yang ditandai selesai tidak lagi dihitung lewat',
        () async {
          final mapelId = await MapelServiceImpl().tambah(Mapel(nama: 'Fisika'));
          final repo = TugasServiceImpl();
      final id = await repo.tambah(
        Tugas(
          mapelId: mapelId,
          judul: 'Laporan praktikum',
          tenggat: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      var r = await repo.ringkasan();
      expect(r.lewat, 1, reason: 'tugas lewat tenggat belum terhitung');

      await repo.ubahStatus(id, SkemaDb.statusSelesai);

      r = await repo.ringkasan();
      expect(r.lewat, 0, reason: 'yang sudah selesai tidak dihitung lewat');
      expect(r.selesai, 1);
    });
  });

  // ── 3. Widget: checkbox benar-benar dirender ───────────────

  group('Tampilan checkbox', () {
    testWidgets('dialog warna menampilkan bulatan dan bisa dipilih',
        (tester) async {
      String? terpilih;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final hasil = await tanyaTeks(
                  context,
                  judul: 'Tambah Mata Pelajaran',
                  labelJudul: 'Nama mapel',
                  denganWarna: true,
                );
                terpilih = hasil?['warna'] as String?;
              },
              child: const Text('buka'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      // Color picker ada, dan jumlah bulatan sesuai palet.
      expect(find.byType(BulatWarna), findsNWidgets(TemaApp.paletMapel.length));
      expect(find.text(t('k_warna')), findsOneWidget);

      // Pilih warna pertama, isi nama, lalu simpan.
      await tester.tap(find.byType(BulatWarna).first);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).first, 'Matematika');
      await tester.tap(find.text(t('simpan')));
      await tester.pumpAndSettle();

      expect(terpilih, TemaApp.paletMapel.first);
    });

    testWidgets('warna awal mapel yang diubah sudah terpilih',
        (tester) async {
      String? terpilih;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final hasil = await tanyaMapel(
                  context,
                  awal: Mapel(nama: 'Kimia', warna: '#DC2626'),
                );
                terpilih = hasil?['warna'] as String?;
              },
              child: const Text('ubah'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ubah'));
      await tester.pumpAndSettle();

      // Tanpa menyentuh apa pun, warna lama harus terbawa saat disimpan.
      await tester.tap(find.text(t('simpan')));
      await tester.pumpAndSettle();

      expect(terpilih, '#DC2626');
    });

    testWidgets('form tanpa denganWarna tidak menampilkan color picker',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => tanyaTeks(
                context,
                judul: 'Tambah Catatan',
                labelJudul: 'Judul',
              ),
              child: const Text('catatan'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('catatan'));
      await tester.pumpAndSettle();

      // Catatan tetap sederhana — tidak ada palet warna di sana.
      expect(find.byType(BulatWarna), findsNothing);
      expect(find.text(t('k_warna')), findsNothing);
    });
  });
}