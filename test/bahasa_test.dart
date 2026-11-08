import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/main.dart';
import 'package:syllabind/tools/bahasa.dart';

/// Menguji lapisan bahasa: kamus, penggantian penanda, dan pergantian
/// langsung di antarmuka.
///
/// Yang dibuktikan di sini bukan sekadar "ada tombol bahasa", melainkan
/// bahwa **teks di layar benar-benar berubah** saat bahasa diganti, dan
/// bahwa pilihannya bertahan setelah halaman dibangun ulang.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
    await Db.tutup();
  });

  group('Kamus bahasa', () {
    tearDown(() => Bahasa.set(Bahasa.id));

    test('kunci yang tidak dikenal dikembalikan apa adanya', () {
      expect(t('kunci_karangan_yang_tidak_ada'), 'kunci_karangan_yang_tidak_ada');
    });

    test('kunci umum tersedia di kedua bahasa dan berbeda', () {
      for (final kunci in [
        'nav_library',
        'nav_pengaturan',
        'set_bahasa',
        'lib_tambah',
        'lib_gambar',
      ]) {
        Bahasa.set(Bahasa.id);
        final indo = t(kunci);
        Bahasa.set(Bahasa.en);
        final ing = t(kunci);

        expect(indo, isNotEmpty, reason: 'kunci $kunci kosong di ID');
        expect(ing, isNotEmpty, reason: 'kunci $kunci kosong di EN');
        // Label navigasi sengaja sama di kedua bahasa ("Library"), jadi
        // yang diuji hanya kunci yang memang berbeda.
        if (kunci != 'nav_library') {
          expect(ing, isNot(indo), reason: 'kunci $kunci tidak diterjemahkan');
        }
      }
    });

    test('tp mengganti penanda dengan nilai', () {
      Bahasa.set(Bahasa.id);
      expect(tp('lib_berhasil', {'nama': 'foto.png'}), contains('foto.png'));
    });

    test('nilai bahasa yang aneh dinormalkan ke Indonesia', () {
      Bahasa.set('klingon');
      expect(Bahasa.aktif.value, Bahasa.id);
      expect(Bahasa.inggris, isFalse);
    });
  });

  testWidgets('mengganti bahasa di Pengaturan mengubah teks di layar',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const Syllabind());
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Kondisi awal: Indonesia.
    Bahasa.set(Bahasa.id);
    await tester.pump();
    expect(find.text('Pengaturan'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Home'), findsWidgets);

    // Ganti ke Inggris seperti menekan dropdown di halaman Pengaturan.
    await tester.runAsync(() async {
      Bahasa.set(Bahasa.en);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Settings'), findsWidgets,
        reason: 'label tab bawah harus berubah ke Inggris');
    expect(find.text('Pengaturan'), findsNothing,
        reason: 'teks Indonesia harus hilang setelah ganti bahasa');
    // Teks di dalam halaman Home juga harus ikut berganti — dulu tidak,
    // karena halaman dibuat `const` di dalam IndexedStack.
    // (Kartu "Fokus hari ini" hanya muncul kalau sudah ada tugas, jadi yang
    // diperiksa adalah teks keadaan kosong yang selalu dirender.)
    expect(find.text('No subjects yet'), findsWidgets);
    expect(find.text('Belum ada mata pelajaran'), findsNothing);

    // Kembalikan supaya tes lain tidak terpengaruh.
    await tester.runAsync(() async {
      Bahasa.set(Bahasa.id);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('halaman Library punya tombol tambah lampiran', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const Syllabind());
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.runAsync(() async {
      await tester.tap(find.text('Library').last);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Tombol "tambah" harus ada di dua tempat: bilah aksi dan keadaan kosong.
    expect(find.text('Tambah lampiran'), findsWidgets);
    expect(find.byIcon(Icons.add), findsWidgets);

    // Ganti bahasa saat halaman Library sedang terbuka: label di dalam
    // halaman harus ikut berubah, bukan hanya judul di AppBar.
    await tester.runAsync(() async {
      Bahasa.set(Bahasa.en);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add attachment'), findsWidgets);
    expect(find.text('Tambah lampiran'), findsNothing);
    expect(find.text('No attachments yet'), findsWidgets);

    await tester.runAsync(() async {
      Bahasa.set(Bahasa.id);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
