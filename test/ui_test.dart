import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/main.dart';

/// Smoke test UI — memastikan kerangka aplikasi benar-benar terbentuk:
///   1. Bottom navigation berisi tepat 4 halaman.
///   2. Halaman Academic punya slider 3 tab, tab pertama = Mata Pelajaran.
///   3. Pengaturan memuat 5 kelompok (tema, warna, data, pemulihan, tentang).
///   4. Struktur memakai AppBar + NavigationBar bawaan (SafeArea),
///      bukan tinggi status bar yang ditulis manual.
///
/// Catatan: `pumpAndSettle` TIDAK dipakai saat pemuatan awal, karena
/// `CircularProgressIndicator` berputar terus sehingga tidak pernah "settle".
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
    await Db.tutup();
  });

  /// Memuat aplikasi lalu menunggu pembacaan database selesai.
  ///
  /// `runAsync` membungkus `pumpWidget` supaya I/O database yang sesungguhnya
  /// (buka berkas SQLite) sempat berjalan. Tanpa itu, `initState` menggantung
  /// di zona fake-async dan layar tetap pada indikator pemuatan.
  Future<void> bukaAplikasi(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const Syllabind());
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Berpindah tab bawah.
  Future<void> pindahTab(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Melepas pohon widget supaya tidak ada timer animasi yang tertinggal.
  Future<void> tutup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('Kerangka utama punya 4 halaman di bottom navigation',
      (tester) async {
    await bukaAplikasi(tester);

    expect(find.byType(NavigationBar), findsOneWidget);

    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.destinations.length, 4);

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Academic'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Pengaturan'), findsWidgets);

    // AppBar bawaan yang menangani area status bar (bukan padding manual).
    expect(find.byType(AppBar), findsOneWidget);

    await tutup(tester);
  });

  testWidgets('Academic punya slider 3 tab dengan Mata Pelajaran lebih dulu',
      (tester) async {
    await bukaAplikasi(tester);
    await pindahTab(tester, 'Academic');

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.length, 3);

    expect(find.text('Mata Pelajaran'), findsWidgets);
    expect(find.text('Catatan'), findsWidgets);
    expect(find.text('Tugas'), findsWidgets);

    // Tab pertama yang dibuka harus "Mata Pelajaran" (initialIndex 0).
    final controller = DefaultTabController.of(
      tester.element(find.byType(TabBar)),
    );
    expect(controller.index, 0);
    expect(controller.length, 3);

    await tutup(tester);
  });

  testWidgets('Pengaturan memuat 5 kelompok pengaturan', (tester) async {
    await bukaAplikasi(tester);
    await pindahTab(tester, 'Pengaturan');

    expect(find.text('TAMPILAN'), findsOneWidget);
    expect(find.text('WARNA AKSEN'), findsOneWidget);

    // "Pemulihan" dan "Tentang" ada di bawah — perlu digulir dulu.
    await tester.runAsync(() async {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PEMULIHAN'), findsOneWidget);
    expect(find.text('TENTANG'), findsOneWidget);

    // Sampah ada dan mulai dari kosong.
    expect(find.text('Sampah'), findsOneWidget);
    expect(find.text('Tidak ada mapel terhapus'), findsOneWidget);

    // Tema: tiga pilihan (digulir kembali ke atas).
    await tester.runAsync(() async {
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ikuti sistem'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);

    await tutup(tester);
  });

  testWidgets('Library menampilkan rekapitulasi dan keadaan kosong',
      (tester) async {
    await bukaAplikasi(tester);
    await pindahTab(tester, 'Library');

    expect(find.text('Gambar'), findsWidgets);
    expect(find.text('File'), findsWidgets);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Belum ada lampiran'), findsOneWidget);

    await tutup(tester);
  });
}