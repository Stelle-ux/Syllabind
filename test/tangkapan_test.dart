import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/main.dart';
import 'package:syllabind/screen/home_page.dart';

/// Membuat tangkapan layar nyata (golden) untuk bukti hasil eksekusi —
/// dipakai pada laporan UKOM poin 11 "Hasil Eksekusi".
///
/// Jalankan dengan:
///   flutter test test/tangkapan_test.dart --update-goldens
///
/// Hasil berupa PNG beresolusi HP di `test/goldens/`.
///
/// Catatan: font Windows dimuat manual. Tanpa itu, Flutter test memakai
/// font bawaan tanpa glyph sehingga semua teks tampil sebagai kotak hitam.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;

    await _muatFont();
  });

  tearDownAll(() async {
    await Db.tutup();
  });

  /// Ukuran layar HP (Pixel-ish): 411 x 914 dp.
  const ukuranHp = Size(411, 914);

  Future<void> isiDataContoh() async {
    await Db.reset();

    final mapelRepo = MapelRepositoryImpl();
    final materiRepo = MateriRepositoryImpl();
    final tugasRepo = TugasRepositoryImpl();
    final pengaturan = PengaturanRepositoryImpl();

    await pengaturan.setTema('terang');
    await pengaturan.setWarnaAksen('#2F6F6B');

    final matematika = await mapelRepo.tambah(
      Mapel(nama: 'Matematika', deskripsi: 'Kelas XI IPA 2', warna: '#2563EB'),
    );
    final fisika = await mapelRepo.tambah(
      Mapel(nama: 'Fisika', deskripsi: 'Kelas XI IPA 2', warna: '#7C3AED'),
    );
    final pemrograman = await mapelRepo.tambah(
      Mapel(
        nama: 'Pemrograman Dasar',
        deskripsi: 'Produktif RPL',
        warna: '#EA580C',
      ),
    );

    final kini = DateTime.now();

    await materiRepo.tambah(
      Materi(
        mapelId: matematika,
        judul: 'Turunan Fungsi Aljabar',
        isi: "Aturan turunan: d/dx x^n = n·x^(n-1). "
            "Contoh: f(x) = 3x^2 maka f'(x) = 6x.",
      ),
    );
    await materiRepo.tambah(
      Materi(
        mapelId: fisika,
        judul: 'Hukum Newton II',
        isi: 'Gaya total = massa x percepatan. '
            'Gaya berbanding lurus dengan percepatan benda.',
      ),
    );
    await materiRepo.tambah(
      Materi(
        mapelId: pemrograman,
        judul: 'Perulangan (Looping)',
        isi: 'for, while, dan do-while. Gunakan for bila jumlah '
            'perulangan sudah diketahui sebelumnya.',
      ),
    );

    await tugasRepo.tambah(
      Tugas(
        mapelId: matematika,
        judul: 'Latihan soal turunan',
        deskripsi: 'Halaman 84 nomor 1 sampai 15.',
        tenggat: kini.add(const Duration(days: 2)),
      ),
    );
    await tugasRepo.tambah(
      Tugas(
        mapelId: fisika,
        judul: 'Laporan praktikum gaya',
        tenggat: kini.add(const Duration(days: 5)),
      ),
    );
    await tugasRepo.tambah(
      Tugas(
        mapelId: pemrograman,
        judul: 'Program kasir sederhana',
        deskripsi: 'Gunakan perulangan dan percabangan.',
        tenggat: kini.subtract(const Duration(days: 1)),
      ),
    );
    final selesai = await tugasRepo.tambah(
      Tugas(
        mapelId: matematika,
        judul: 'Kuis limit fungsi',
        tenggat: kini.subtract(const Duration(days: 3)),
      ),
    );
    await tugasRepo.ubahStatus(selesai, 'SELESAI');
  }

  Future<void> buka(WidgetTester tester) async {
    tester.view.physicalSize = ukuranHp * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await tester.pumpWidget(const Syllabind());
      await Future<void>.delayed(const Duration(milliseconds: 700));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pindah(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label).last);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> ketukTab(WidgetTester tester, String label) async {
    // 1) Ketuk tab.
    await tester.tap(find.text(label).last);

    // 2) Selesaikan animasi TabBarView supaya anak tab benar-benar dibangun.
    //    `initState` anak tab baru berjalan SETELAH langkah ini.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 3) Beri jendela async nyata untuk query database anak tab.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    });

    // 4) Render hasil setState-nya.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('01 — Home / Hari Ini', (tester) async {
    // Jam dipatok: sapaan ("Selamat pagi/siang/sore/malam") bergantung jam
    // berjalan, jadi tanpa ini golden gagal setiap beberapa jam sekali.
    // Waktu dipatok penuh: sapaan DAN tanggal header keduanya ikut waktu.
    // Tanggal tetap (bukan `kini`) supaya golden tidak gugur saat hari berganti.
    HalamanHome.waktuUji = DateTime(2026, 10, 31, 9);
    addTearDown(() => HalamanHome.waktuUji = null);
    await tester.runAsync(isiDataContoh);
    await buka(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01-home.png'),
    );
  });

  testWidgets('02 — Academic: tab Mata Pelajaran', (tester) async {
    await tester.runAsync(isiDataContoh);
    await buka(tester);
    await pindah(tester, 'Academic');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02-academic-mapel.png'),
    );
  });

  testWidgets('03 — Academic: tab Catatan', (tester) async {
    await tester.runAsync(isiDataContoh);
    await buka(tester);
    await pindah(tester, 'Academic');
    await ketukTab(tester, 'Catatan');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03-academic-catatan.png'),
    );
  });

  testWidgets('04 — Academic: tab Tugas', (tester) async {
    await tester.runAsync(isiDataContoh);
    await buka(tester);
    await pindah(tester, 'Academic');
    await ketukTab(tester, 'Tugas');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04-academic-tugas.png'),
    );
  });

  testWidgets('05 — Penyimpanan', (tester) async {
    await tester.runAsync(isiDataContoh);
    await buka(tester);
    await pindah(tester, 'Library');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05-penyimpanan.png'),
    );
  });

  testWidgets('06 — Pengaturan', (tester) async {
    await tester.runAsync(isiDataContoh);
    await buka(tester);
    await pindah(tester, 'Pengaturan');

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06-pengaturan.png'),
    );
  });
}

/// Memuat font TrueType Windows dan ikon Material ke Flutter test.
///
/// Tanpa ini, `flutter test` memakai "Ahem" — font kotak yang membuat
/// seluruh teks dan ikon jadi balok hitam, sehingga screenshot tidak
/// berguna sebagai bukti hasil eksekusi.
Future<void> _muatFont() async {
  // 1) Font teks dari Windows.
  final folder = Directory(r'C:\Windows\Fonts');
  if (folder.existsSync()) {
    final berkas = {
      'Roboto': 'segoeui.ttf',
      'RobotoBold': 'segoeuib.ttf',
      'RobotoItalic': 'segoeuii.ttf',
    };

    for (final e in berkas.entries) {
      final f = File('${folder.path}\\${e.value}');
      if (!f.existsSync()) continue;
      try {
        final bytes = await f.readAsBytes();
        final loader = FontLoader(e.key)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      } on FileSystemException {
        // Font tidak terbaca — lewati, bukan kegagalan fatal.
      }
    }
  }

  // 2) Font ikon Material dari hasil build web.
  //
  // Ikon pada screenshot adalah glyph font, bukan gambar. Kalau font-nya
  // tidak dimuat, semua ikon tampil sebagai kotak kosong.
  final kandidat = [
    File('build/web/assets/fonts/MaterialIcons-Regular.otf'),
    File(
      r'C:\flutter_windows_3.32.8-stable\flutter\bin\cache\artifacts'
      r'\material_fonts\MaterialIcons-Regular.otf',
    ),
  ];

  for (final f in kandidat) {
    if (!f.existsSync()) continue;
    try {
      final bytes = await f.readAsBytes();
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      break;
    } on FileSystemException {
      // Coba kandidat berikutnya.
    }
  }
}