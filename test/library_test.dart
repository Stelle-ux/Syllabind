import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/screen/penyimpanan_page.dart';

/// Menguji perilaku Library setelah diubah menjadi "hanya lampiran".
///
/// Yang dibuktikan: tombol per-item benar-benar BERFUNGSI, bukan sekadar ada.
///   1. Tiap lampiran punya menu aksi (lihat / ganti nama / hapus).
///   2. Tidak ada lagi tombol ekspor massal di Library.
///   3. Ganti nama dari menu benar-benar mengubah nama di database.
///   4. Hapus dari menu benar-benar menghilangkan lampiran dari daftar.
void main() {
  late Directory akarUji;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
    LampiranRepositoryImpl.folderUji = null;
    await Db.tutup();
  });

  setUp(() async {
    await Db.reset();
    akarUji = Directory(p.join(Directory.current.path, 'build', 'uji_tmp'));
    await akarUji.create(recursive: true);
    LampiranRepositoryImpl.folderUji = akarUji;
    Bahasa.set(Bahasa.id);
  });

  /// Menyiapkan satu mapel + materi + lampiran, mengembalikan mapel id.
  Future<int> siapkanLampiran(String namaBerkas) async {
    final mapelRepo = MapelRepositoryImpl();
    final mapelId = await mapelRepo.tambah(Mapel(nama: 'Fisika'));

    final materiRepo = MateriRepositoryImpl();
    final materiId = await materiRepo.tambah(
      Materi(mapelId: mapelId, judul: 'Catatan Fisika'),
    );

    final sumber = File(p.join(akarUji.path, namaBerkas));
    await sumber.writeAsString('isi uji ${DateTime.now().microsecondsSinceEpoch}');
    await LampiranRepositoryImpl().tambahDariFile(
      materiId: materiId,
      sumber: sumber,
      tipe: Lampiran.tipeFile,
    );
    return mapelId;
  }

  /// Membuka halaman Library dan menunggu pembacaan database selesai.
  Future<void> bukaLibrary(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HalamanPenyimpanan())),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('lampiran punya menu aksi per-item', (tester) async {
    await tester.runAsync(() => siapkanLampiran('laporan.pdf'));
    await bukaLibrary(tester);

    expect(find.text('laporan.pdf'), findsOneWidget,
        reason: 'lampiran harus tampil di daftar');
    expect(find.byType(PopupMenuButton<String>), findsOneWidget,
        reason: 'tiap lampiran harus punya menu aksi');
  });

  testWidgets('Library tidak punya tombol ekspor', (tester) async {
    await tester.runAsync(() => siapkanLampiran('laporan.pdf'));
    await bukaLibrary(tester);

    // Ekspor sekarang per-catatan, jadi tidak boleh ada tombol massal.
    expect(find.textContaining('Ekspor'), findsNothing);
  });

  testWidgets('menu ganti nama benar-benar mengubah nama', (tester) async {
    await tester.runAsync(() => siapkanLampiran('lama.pdf'));
    await bukaLibrary(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t('k_rename')).last);
    await tester.pumpAndSettle();

    expect(find.text(t('lib_ubah_nama_judul')), findsOneWidget,
        reason: 'dialog ganti nama harus terbuka');

    // Targetkan kolom di dalam dialog, bukan "TextField pertama di layar".
    // Sejak Library punya kotak pencarian sendiri, `.first` menunjuk ke
    // kotak cari itu dan pengetikan tidak pernah sampai ke dialog.
    final kolomDialog = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(kolomDialog.first, 'baru.pdf');
    // Bungkus runAsync: penulisan DB nyata tidak jalan di zona fake-async.
    await tester.runAsync(() async {
      await tester.tap(find.text(t('simpan')));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    final sesudah = await tester.runAsync(() => LampiranRepositoryImpl().semua());
    expect(sesudah!.map((l) => l.namaFile), contains('baru.pdf'));
    expect(sesudah.map((l) => l.namaFile), isNot(contains('lama.pdf')));
  });

  testWidgets('menu hapus benar-benar menghilangkan lampiran', (tester) async {
    await tester.runAsync(() => siapkanLampiran('buang.pdf'));
    await bukaLibrary(tester);

    expect(find.text('buang.pdf'), findsOneWidget);

    // Seluruh interaksi dalam SATU zona async nyata: rantai hapus menyentuh
    // berkas fisik (File.delete), dan I/O nyata tidak selesai kalau separuh
    // rantai berjalan di zona async-palsu milik widget test.
    await tester.runAsync(() async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Item menu dicari lewat ikonnya, bukan teks: labelnya tooltip dan
      // teks "Hapus" muncul tiga kali (tooltip, item menu, tombol dialog).
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(t('lib_hapus_pesan')), findsOneWidget,
          reason: 'konfirmasi hapus harus muncul sebelum data dibuang');

      await tester.tap(find.widgetWithText(FilledButton, t('hapus')));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    // Data di DB adalah bukti utama; tampilan menyusul setelah frame biasa.
    final sesudah = await tester.runAsync(() => LampiranRepositoryImpl().semua());
    expect(sesudah!.map((l) => l.namaFile), isNot(contains('buang.pdf')));

    await tester.pumpAndSettle();
    expect(find.text('buang.pdf'), findsNothing,
        reason: 'daftar Library harus ikut bersih setelah hapus');
  });
}
