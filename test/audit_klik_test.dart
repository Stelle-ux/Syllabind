// AUDIT KLIK — berkas buatan LUMINOIR (2026-11-01).
//
// Berkas ini SENGAJA memakai print() sebagai laporan audit:
// tiap langkah mencetak bukti [OK]/[GAGAL] ke log. Karena itu
// peringatan avoid_print dimatikan khusus di berkas ini.
// ignore_for_file: avoid_print
//
// Membuktikan tiap LAYAR, tiap ELEMEN YANG DIKLIK, dan tiap POPUP benar-benar
// berfungsi — bukan cuma "ada di kode". Tiap langkah mencetak satu baris
// [OK]/[GAGAL] beserta buktinya, lalu ringkasan di akhir.
//
// ATURAN MAIN — semua ditemukan lewat percobaan nyata, bukan tebakan:
//
//   1. `testWidgets` menjalankan body di zona FAKE-ASYNC. Di sana
//      `Future.delayed` memakai jam palsu sehingga tidak pernah berbunyi, dan
//      Future sqflite tidak pernah selesai → tes menggantung.
//   2. Karena itu SETIAP langkah dibungkus SATU `tester.runAsync`; di dalamnya
//      timer nyata dan I/O benar-benar berjalan. Innilah pola 140 tes yang
//      sudah lulus.
//   3. `runAsync` TIDAK BOLEH bersarang ("Reentrant call to runAsync denied").
//      Jadi helper (tekan/baca/tunggu) tidak pernah memanggilnya sendiri.
//   4. Kegagalan ditangkap DI DALAM callback `runAsync`: ia memasang
//      `handleUncaughtError` sendiri, sehingga error yang lolos keluar ditelan
//      framework dan label [OK]/[GAGAL] jadi berbohong.
//   5. Finder harus berdasar teks yang BENAR-BENAR dirender. Label tab juga
//      muncul di isi TabBarView, jadi untuk tab dipakai `descendant(of: TabBar)`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/layanan_ekspor.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/main.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/screen/academic_page.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';
import 'package:syllabind/screen/home_page.dart';
import 'package:syllabind/screen/pengaturan_page.dart';
import 'package:syllabind/screen/penyimpanan_page.dart';
import 'package:syllabind/tools/tema.dart';

int _ok = 0;
int _gagal = 0;
int _dilewati = 0;

/// Melempar [StateError] biasa yang selalu tertangkap oleh [jalankan].
void pastikan(bool syarat, String pesan) {
  if (!syarat) throw StateError(pesan);
}

void catat(String label, bool lulus, String bukti) {
  if (lulus) {
    _ok++;
    print('[OK]    $label :: $bukti');
  } else {
    _gagal++;
    print('[GAGAL] $label :: $bukti');
  }
}

void lewati(String label, String alasan) {
  _dilewati++;
  print('[LEWAT] $label :: $alasan');
}

/// Menjalankan satu langkah audit di dalam SATU zona async nyata.
///
/// Kegagalan ditangkap di dalam callback karena `runAsync` memasang
/// `handleUncaughtError` sendiri — error yang lolos keluar akan ditelan
/// framework dan langkahnya tercatat "lulus" padahal gagal.
Future<void> jalankan(
  WidgetTester tester,
  String label,
  Future<void> Function() aksi, {
  String Function()? bukti,
}) async {
  Object? galat;
  await tester.runAsync(() async {
    try {
      await aksi();
    } catch (e) {
      galat = e;
    }
  });
  if (galat == null) {
    catat(label, true, bukti?.call() ?? 'berhasil tanpa error');
  } else {
    catat(label, false, galat.toString().split('\n').first);
  }
}

void main() {
  late Directory akarUji;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  tearDownAll(() async {
      LampiranServiceImpl.folderUji = null;
    LayananEkspor.folderUji = null;
    await Db.tutup();
    print('');
    print('══════════════════════════════════════════════════');
    print('  RINGKASAN AUDIT KLIK: $_ok lulus · $_gagal gagal · $_dilewati dilewati');
    print('══════════════════════════════════════════════════');
  });

  setUp(() async {
    await Db.reset();
    akarUji = Directory(p.join(Directory.current.path, 'build', 'uji_klik'));
    await akarUji.create(recursive: true);
      LampiranServiceImpl.folderUji = akarUji;
    // Tanpa ini ekspor menulis ke folder dokumen aplikasi yang tak ada di VM.
    LayananEkspor.folderUji = akarUji;
    Bahasa.set(Bahasa.id);
  });

  // ── Helper: dipakai HANYA di dalam callback `runAsync` ────────
  bool ada(Finder f) => f.evaluate().isNotEmpty;

  Finder diDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  /// Menunggu pekerjaan DB/berkas yang dipicu widget.
  Future<void> tungguIO(WidgetTester tester, [int ms = 500]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    // Pompa berulang: animasi perpindahan tab, dialog, dan SnackBar butuh
    // beberapa frame untuk selesai. Ini pengganti `pumpAndSettle` yang aman —
    // jumlahnya dibatasi sehingga tidak mungkin menggantung.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Jeda nyata + satu ronde pompa lagi.
    //
    // Terbukti lewat percobaan: tanpa jeda ini, FAB pada tab kedua BELUM bisa
    // ditekan (hitTestable == 0) walaupun render box-nya sudah ada — tab
    // belum sepenuhnya menjadi halaman aktif. Satu ronde tambahan membuatnya
    // bisa ditekan pada percobaan pertama.
    await Future<void>.delayed(Duration(milliseconds: ms < 300 ? 300 : 120));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Ketuk elemen, lalu beri jeda nyata supaya I/O yang terpicu selesai.
  Future<void> tekan(WidgetTester tester, Finder f,
      {String? apa, int jeda = 450}) async {
    pastikan(ada(f), 'elemen tidak ditemukan: ${apa ?? 'elemen'}');
    await tester.tap(f.first, warnIfMissed: false);
    await tungguIO(tester, jeda);
  }

  /// Menekan FAB yang benar-benar bisa ditekan.
  ///
  /// Tiap tab di halaman detail punya Scaffold + FAB sendiri, dan FAB tab lain
  /// masih ada di pohon widget (offstage). `.last` belum tentu milik tab aktif,
  /// sedangkan `.hitTestable()` kosong kalau transisi belum selesai — jadi
  /// dipakai berurutan: yang bisa ditekan dulu, baru cadangan `.last`.
  Future<void> tekanFab(WidgetTester tester, {String? apa, int jeda = 700}) async {
    // SnackBar menutupi FAB.
    //
    // Terbukti lewat percobaan: setelah aksi yang memunculkan SnackBar (mis.
    // ekspor catatan), FAB di bawah layar jadi tidak bisa ditekan
    // (hitTestable == 0) sampai SnackBar hilang. Jadi tunggu sampai hilang.
    // SnackBar yang dikirim dari zona async NYATA memakai Timer nyata, jadi
    // jam palsu di `pump(Duration)` TIDAK menghilangkannya. SnackBar duduk di
    // atas FAB dan membuatnya tidak bisa ditekan (hitTestable == 0).
    // Menutupnya secara eksplisit = pengguna menunggu notifikasi hilang.
    if (ada(find.byType(SnackBar))) {
      final messenger = find.byType(ScaffoldMessenger);
      if (messenger.evaluate().isNotEmpty) {
        tester
            .state<ScaffoldMessengerState>(messenger.first)
            .clearSnackBars();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    final bisa = find.byType(FloatingActionButton).hitTestable();
    final target =
        bisa.evaluate().isNotEmpty ? bisa.last : find.byType(FloatingActionButton).last;
    await tekan(tester, target, apa: apa, jeda: jeda);
  }

  /// Pindah ke tab ke-[i] pada TabBar, lalu tunggu sampai benar-benar aktif.
  ///
  /// Menekan Tab saja belum cukup: halaman tab baru baru menjadi aktif setelah
  /// animasi. Terbukti lewat percobaan — tanpa jeda nyata + pompa tambahan,
  /// FAB pada tab tujuan belum bisa ditekan (hitTestable == 0).
  Future<void> pindahTab(WidgetTester tester, int i) async {
    final tab = find
        .descendant(of: find.byType(TabBar), matching: find.byType(Tab))
        .at(i);
    pastikan(ada(tab), 'tab ke-$i tidak ditemukan');
    await tester.tap(tab, warnIfMissed: false);
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Menunggu hitung mundur 5 detik yang sungguhan berjalan.
  Future<void> tungguHitungMundur(WidgetTester tester) =>
      tungguIO(tester, 5800);

  /// Membuka satu layar dan menunggu pembacaan database selesai.
  Future<void> buka(WidgetTester tester, Widget isi) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.terang(TemaApp.aksenDefault),
        home: isi,
      ),
    );
    await tungguIO(tester, 700);
  }

  Future<int> semai({bool denganTugas = true, bool lewat = false}) async {
      final idMapel = await MapelServiceImpl().tambah(
      Mapel(nama: 'Fisika', deskripsi: 'Bab gerak', warna: '#2F6F6B'),
    );
      final idMateri = await MateriServiceImpl().tambah(
      Materi(mapelId: idMapel, judul: 'Catatan Gerak', isi: 'Isi catatan uji'),
    );
    if (denganTugas) {
        await TugasServiceImpl().tambah(
        Tugas(
          mapelId: idMapel,
          judul: 'Tugas Laporan',
          deskripsi: 'Kumpulkan',
          tenggat: lewat
              ? DateTime.now().subtract(const Duration(days: 2))
              : DateTime.now().add(const Duration(days: 2)),
        ),
      );
    }
    final sumber = File(p.join(akarUji.path, 'laporan.pdf'));
    await sumber.writeAsString('pdf palsu untuk audit');
      await LampiranServiceImpl().tambahDariFile(
      materiId: idMateri,
      sumber: sumber,
      tipe: Lampiran.tipeFile,
    );
    return idMapel;
  }

  // ═══════════════════════════════════════════════════════════════
  // A. KERANGKA APLIKASI
  // ═══════════════════════════════════════════════════════════════
  group('A. Kerangka aplikasi', () {
    testWidgets('A: 4 destinasi NavigationBar + AppBar', (tester) async {
          await tester.runAsync(semai);
          await jalankan(tester, 'A0 muat kerangka aplikasi', () async {
            await buka(tester, RumahAplikasi(onDataBerubah: () {}));
          }, bukti: () => 'kerangka dimuat');

      catat(
        'A1 boot aplikasi',
        ada(find.byType(NavigationBar)),
        ada(find.byType(NavigationBar))
            ? 'NavigationBar dirender'
            : 'NavigationBar TIDAK ada',
      );

      final jumlah = tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .length;
      catat('A2 jumlah destinasi', jumlah == 4, '$jumlah destinasi');

      for (final (label, judul) in [
        (t('nav_home'), t('judul_app')),
        (t('nav_academic'), t('nav_academic')),
        (t('nav_library'), t('nav_library')),
        (t('nav_pengaturan'), t('nav_pengaturan')),
      ]) {
        await jalankan(tester, 'A3 pindah destinasi → $label', () async {
          final sel = find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          );
          await tekan(tester, sel, apa: 'destinasi $label');
          await tungguIO(tester);
          pastikan(
            ada(find.descendant(
              of: find.byType(AppBar),
              matching: find.text(judul),
            )),
            'AppBar harus menampilkan "$judul"',
          );
        }, bukti: () => 'AppBar berubah ke "$judul"');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // B. LAYAR HOME
  // ═══════════════════════════════════════════════════════════════
  group('B. Layar Home', () {
    testWidgets('Home: cari, tandai selesai, urungkan, lewat tenggat',
        (tester) async {
      // Home hanya menampilkan tugas yang PUNYA tenggat (<=7 hari) atau
      // yang sudah lewat. Tugas tanpa tenggat tidak pernah muncul di sana.
      await tester.runAsync(() => semai(lewat: true));
      await jalankan(tester, 'B0 muat layar Home', () async {
        await buka(tester, Scaffold(body: HalamanHome(onBukaAcademic: () {})));
      }, bukti: () => 'layar Home dimuat');

      // B1 — kotak cari
      await jalankan(tester, 'B1 ketik di kotak cari', () async {
        await tester.enterText(find.byType(TextField).first, 'Fisika');
        await tungguIO(tester, 400);
        pastikan(ada(find.text('Fisika')), 'hasil pencarian harus dirender');
      }, bukti: () => 'hasil pencarian untuk "Fisika" dirender');

      // B2 — bersihkan kotak cari
      await jalankan(tester, 'B2 bersihkan kotak cari', () async {
        await tester.enterText(find.byType(TextField).first, '');
        await tungguIO(tester, 400);
        final isi = tester
            .widget<TextField>(find.byType(TextField).first)
            .controller
            ?.text;
        pastikan((isi ?? '').isEmpty, 'kotak cari harus kosong lagi');
      }, bukti: () => 'kotak cari kembali kosong');

      // B3 — kartu tugas: tandai selesai
      await jalankan(tester, 'B3 kartu fokus → "${t('dm_tandai_selesai')}"',
          () async {
        // Ketukan pada teks judul TIDAK mengubah apa pun: yang bisa ditekan
        // adalah tombol "Tandai selesai" pada kartu fokus (atau Checkbox pada
        // baris "Lewat tenggat").
        final kartu = find.text('Tugas Laporan');
        pastikan(ada(kartu), 'kartu tugas harus tampil di beranda');
        final tombol = find.text(t('dm_tandai_selesai'));
        pastikan(ada(tombol), 'tombol "Tandai selesai" harus ada');
        await tekan(tester, tombol, apa: 'tombol Tandai selesai', jeda: 700);
        final t2 = await TugasServiceImpl().semua();
        pastikan(t2.first.status == 'SELESAI', 'status harus jadi SELESAI');
      }, bukti: () => 'status tugas jadi SELESAI di database');

      // B4 — SnackBar Urungkan
      if (ada(find.text(t('home_urungkan')))) {
        await jalankan(tester, 'B4 SnackBar → ${t('home_urungkan')}', () async {
          await tekan(tester, find.text(t('home_urungkan')),
              apa: 'Urungkan', jeda: 700);
                  final t2 = await TugasServiceImpl().semua();
          pastikan(t2.first.status == 'BELUM', 'status harus kembali BELUM');
        }, bukti: () => 'status tugas kembali BELUM di database');
      } else {
        lewati('B4 SnackBar Urungkan', 'SnackBar tidak muncul');
      }

      // B5 — blok "Lewat tenggat"
      await jalankan(tester, 'B5 blok "${t('home_lewat_judul')}"', () async {
        pastikan(ada(find.text(t('home_lewat_judul'))),
            'blok lewat tenggat harus muncul untuk tugas kedaluwarsa');
      }, bukti: () => 'tugas lewat tenggat tampil di blok tersendiri');

      // B6 — pull to refresh
      await jalankan(tester, 'B6 pull-to-refresh', () async {
        pastikan(ada(find.byType(RefreshIndicator)), 'RefreshIndicator harus ada');
        await tester.fling(find.byType(RefreshIndicator).first,
            const Offset(0, 320), 1200);
        await tester.pump();
        await tungguIO(tester, 900);
        pastikan(ada(find.text('Fisika')), 'halaman harus tetap utuh');
      }, bukti: () => 'halaman dimuat ulang tanpa error');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // C. LAYAR ACADEMIC
  // ═══════════════════════════════════════════════════════════════
  group('C. Layar Academic', () {
    testWidgets('Academic: 3 tab, FAB, cari, seleksi, hapus massal',
        (tester) async {
      await tester.runAsync(semai);
      await jalankan(tester, 'C0 muat layar Academic', () async {
        await buka(tester, const Scaffold(body: HalamanAcademic()));
      }, bukti: () => 'layar Academic dimuat');

      catat(
        'C1 tiga tab terpasang',
        find.byType(Tab).evaluate().length == 3,
        '${find.byType(Tab).evaluate().length} tab',
      );

      // C2 — FAB tambah mapel
      await jalankan(tester, 'C2 FAB → dialog → Simpan', () async {
        await tekan(tester, find.byType(FloatingActionButton), apa: 'FAB');
        pastikan(ada(find.text(t('ak_tambah_mapel'))), 'dialog harus terbuka');
        await tester.enterText(
            diDialog(find.byType(TextFormField)).first, 'Biologi');
        await tester.pump();
        await tekan(tester, find.text(t('simpan')), apa: 'Simpan', jeda: 700);
              final daftar = await MapelServiceImpl().semua();
        pastikan(daftar.any((m) => m.nama == 'Biologi'),
            'mapel baru harus tersimpan');
      }, bukti: () => 'mapel "Biologi" tersimpan di database');

      // C3 — batal
      await jalankan(tester, 'C3 dialog tambah → Batal', () async {
              final sebelum = (await MapelServiceImpl().semua()).length;
        await tekan(tester, find.byType(FloatingActionButton), apa: 'FAB');
        await tekan(tester, find.text(t('batal')), apa: 'tombol Batal');
              final sesudah = (await MapelServiceImpl().semua()).length;
        pastikan(sesudah == sebelum, 'jumlah mapel tidak boleh berubah');
      }, bukti: () => 'jumlah mapel tidak berubah');

      // C4 — cari mapel
      await jalankan(tester, 'C4 kotak cari mapel', () async {
        final kolom = find.byType(TextField).first;
        await tester.enterText(kolom, 'zzz');
        await tungguIO(tester, 400);
        pastikan(ada(find.text(t('ak_tidak_ditemukan'))),
            'harus menampilkan "tidak ditemukan"');
        await tester.enterText(kolom, '');
        await tungguIO(tester, 400);
      }, bukti: () => 'kata tak ada → "Tidak ditemukan", lalu dipulihkan');

      // C5 — mode seleksi
      await jalankan(tester, 'C5 "${t('ak_mulai_pilih')}" → mode seleksi',
          () async {
        await tekan(tester, find.text(t('ak_mulai_pilih')));
        pastikan(ada(find.byType(Checkbox)), 'checkbox harus muncul');
        pastikan(ada(find.text(t('ak_pilih_semua'))),
            'tombol pilih semua harus ada');
      }, bukti: () => 'checkbox + bar seleksi muncul');

      // C6 — hapus massal + hitung mundur
      await jalankan(tester, 'C6 hapus massal + hitung mundur 5 detik', () async {
        await tekan(tester, find.byType(Checkbox).first, apa: 'checkbox pertama');
        await tekan(tester, find.text(t('ak_pilih_semua')), apa: 'pilih semua');

        final hapus = find.byIcon(Icons.delete_outline);
        pastikan(ada(hapus), 'tombol hapus massal harus ada');
        await tekan(tester, hapus, apa: 'tombol hapus massal');

        pastikan(ada(find.byType(AlertDialog)),
            'dialog konfirmasi hitung mundur harus terbuka');

        final tombol = diDialog(find.byType(FilledButton));
        pastikan(ada(tombol), 'tombol hapus di dialog harus ada');

        final terkunci =
            tester.widget<FilledButton>(tombol.first).onPressed == null;
        catat('C6a tombol Hapus terkunci saat hitung mundur', terkunci,
            terkunci ? 'onPressed == null (benar)' : 'sudah aktif (salah)');

        await tungguHitungMundur(tester);
        final aktif =
            tester.widget<FilledButton>(tombol.first).onPressed != null;
        catat('C6b tombol Hapus aktif setelah 5 detik', aktif,
            aktif ? 'onPressed != null (benar)' : 'masih terkunci');

        await tekan(tester, tombol, apa: 'tombol Hapus di dialog', jeda: 700);
                final sisa = await MapelServiceImpl().semua();
        pastikan(sisa.isEmpty, 'semua mapel harus terhapus lunak');
      }, bukti: () => 'semua mapel pindah ke Sampah (daftar utama kosong)');

      // C7 — tab Catatan
      await jalankan(tester, 'C7 tab ke-2 (Catatan)', () async {
        await pindahTab(tester, 1);
        pastikan(ada(find.text(t('ak_cari_catatan'))),
            'kotak cari catatan harus ada');
      }, bukti: () => 'kotak cari catatan dirender');

      // C8 — tab Tugas + filter
      await jalankan(tester, 'C8 tab ke-3 (Tugas) + filter', () async {
        await pindahTab(tester, 2);
        pastikan(ada(find.byType(SegmentedButton<String?>)),
            'SegmentedButton filter harus ada');
        await tekan(tester, find.text(t('ak_selesai')), apa: 'filter Selesai');
        await tekan(tester, find.text(t('ak_belum')), apa: 'filter Belum');
        await tekan(tester, find.text(t('ak_semua')), apa: 'filter Semua');
      }, bukti: () => 'filter Semua/Belum/Selesai dapat ditekan');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // D. DETAIL MAPEL
  // ═══════════════════════════════════════════════════════════════
  group('D. Detail Mapel', () {
    testWidgets('Detail: menu AppBar, catatan, tugas, lampiran, hapus',
        (tester) async {
      late int idMapel;
      await tester.runAsync(() async {
        idMapel = await semai();
      });
      await jalankan(tester, 'D0 muat layar Detail Mapel', () async {
                final m = await MapelServiceImpl().cari(idMapel);
        await buka(tester, HalamanDetailMapel(mapel: m!));
      }, bukti: () => 'layar Detail Mapel dimuat');

      catat(
        'D1 dua tab detail',
        find.byType(Tab).evaluate().length == 2,
        '${find.byType(Tab).evaluate().length} tab',
      );

      // D2 — menu AppBar → Ubah mapel
      await jalankan(tester, 'D2 menu AppBar → "${t('ak_ubah_mapel')}"',
          () async {
        // Popup AppBar berada di AppBar dan dirender TERAKHIR; popup per-item
        // ada lebih dulu. Mengambil `.first` akan menekan popup catatan.
        await tekan(tester, find.byType(PopupMenuButton<String>).last,
            apa: 'menu AppBar');
        final item = find.text(t('ak_ubah_mapel'));
        pastikan(ada(item), 'item ubah mapel harus muncul');
        await tekan(tester, item, apa: 'item ubah mapel');
        pastikan(ada(find.text(t('ak_ubah_mapel'))),
            'dialog ubah mapel harus terbuka');
        await tekan(tester, find.text(t('batal')), apa: 'tombol Batal');
      }, bukti: () => 'dialog ubah mapel terbuka, lalu dibatalkan');

      // D3 — FAB tambah catatan
      await jalankan(tester, 'D3 FAB → tambah catatan → Simpan', () async {
        await tekanFab(tester, apa: 'FAB catatan');
        pastikan(ada(find.text(t('dm_judul_materi'))),
            'dialog catatan harus terbuka');
        await tester.enterText(
            diDialog(find.byType(TextFormField)).first, 'Catatan Baru');
        await tester.pump();
        await tekan(tester, find.text(t('simpan')), apa: 'Simpan', jeda: 700);
        final materi = await MateriServiceImpl().perMapel(idMapel);
        pastikan(materi.any((x) => x.judul == 'Catatan Baru'),
            'catatan baru harus tersimpan');
      }, bukti: () => 'catatan "Catatan Baru" tersimpan');

      // D4 — popup catatan → Ubah
      await jalankan(tester, 'D4 popup catatan → "${t('k_ubah')}"', () async {
        // Popup catatan = popup pertama (AppBar yang terakhir).
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup catatan');
        final item = find.text(t('k_ubah'));
        pastikan(ada(item), 'item Ubah harus muncul');
        await tekan(tester, item, apa: 'item Ubah');
        pastikan(ada(find.text(t('dm_ubah_catatan'))),
            'dialog ubah catatan harus terbuka');
        await tekan(tester, find.text(t('batal')), apa: 'Batal');
      }, bukti: () => 'dialog ubah catatan terbuka');

      // D5 — popup catatan → Ekspor .txt
      await jalankan(tester, 'D5 popup catatan → "${t('k_ekspor_tooltip')}"',
          () async {
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup catatan');
        final item = find.text(t('k_ekspor_tooltip'));
        pastikan(ada(item), 'item ekspor harus muncul');
        await tekan(tester, item, apa: 'item ekspor', jeda: 900);
        // Ekspor menyimpan berkas di subfolder `ekspor/`, jadi pemindaian
        // harus rekursif — bukan hanya lapisan teratas.
        final txt = akarUji
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.txt'))
            .toList();
        pastikan(txt.isNotEmpty, 'berkas .txt harus benar-benar dibuat');
        pastikan(txt.first.lengthSync() > 0, 'berkas ekspor tidak boleh kosong');
      }, bukti: () => 'berkas .txt benar-benar dibuat di disk');

      // D6 — popup catatan → Hapus
      await jalankan(tester, 'D6 popup catatan → "${t('k_hapus_tooltip')}"',
          () async {
              final sebelum = (await MateriServiceImpl().perMapel(idMapel)).length;
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup catatan');
        final item = find.text(t('k_hapus_tooltip'));
        pastikan(ada(item), 'item Hapus harus muncul');
        await tekan(tester, item, apa: 'item Hapus');
        final konfirmasi = find.widgetWithText(FilledButton, t('hapus'));
        pastikan(ada(konfirmasi), 'dialog konfirmasi harus muncul');
        await tekan(tester, konfirmasi, apa: 'Hapus', jeda: 700);
              final sesudah = (await MateriServiceImpl().perMapel(idMapel)).length;
        pastikan(sesudah == sebelum - 1, 'satu catatan harus terhapus');
      }, bukti: () => 'satu catatan terhapus dari database');

      // D7 — tab Tugas
      await jalankan(tester, 'D7 tab ke-2 (Tugas)', () async {
        await pindahTab(tester, 1);
        pastikan(ada(find.text('Tugas Laporan')), 'daftar tugas harus dirender');
      }, bukti: () => 'daftar tugas mapel dirender');

      // D8 — FAB tambah tugas
      await jalankan(tester, 'D8 FAB → tambah tugas → Simpan', () async {
        // Tiap tab di detail punya Scaffold + FAB sendiri, jadi
        // `find.byType(FloatingActionButton).first` bisa menunjuk FAB tab
        // Catatan yang sudah tidak terlihat. Ambil yang benar-benar terlihat.
        await tekanFab(tester, apa: 'FAB tugas');
        pastikan(ada(find.text(t('dm_tambah_tugas'))),
            'dialog tambah tugas harus terbuka');
        await tester.enterText(
            diDialog(find.byType(TextFormField)).first, 'Tugas Baru');
        await tester.pump();
        await tekan(tester, find.text(t('simpan')), apa: 'Simpan', jeda: 700);
              final tugas = await TugasServiceImpl().perMapel(idMapel);
        pastikan(tugas.any((x) => x.judul == 'Tugas Baru'),
            'tugas baru harus tersimpan');
      }, bukti: () => 'tugas "Tugas Baru" tersimpan');

      // D9 — popup tugas → Ubah
      await jalankan(tester, 'D9 popup tugas → "${t('k_ubah')}"', () async {
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup tugas');
        final item = find.text(t('k_ubah'));
        pastikan(ada(item), 'item Ubah harus muncul');
        await tekan(tester, item, apa: 'item Ubah');
        pastikan(ada(find.text(t('dm_ubah_tugas'))),
            'dialog ubah tugas harus terbuka');
        await tekan(tester, find.text(t('batal')), apa: 'Batal');
      }, bukti: () => 'dialog ubah tugas terbuka');

      // D10 — tab Catatan → ikon lampiran → bottom sheet
      await jalankan(
          tester, 'D10 tab Catatan → ikon lampiran → bottom sheet', () async {
        await pindahTab(tester, 0);
        final ikon = find.byIcon(Icons.attach_file);
        pastikan(ada(ikon), 'ikon lampiran harus ada di kartu catatan');
        await tekan(tester, ikon, apa: 'ikon lampiran', jeda: 700);
        pastikan(ada(find.text(t('dm_lampiran'))),
            'lembar lampiran harus terbuka');
      }, bukti: () => 'lembar lampiran terbuka');

      // D11 — menu AppBar → Hapus mapel (hitung mundur)
      await jalankan(tester, 'D11 menu AppBar → "${t('dm_hapus_mapel')}"',
          () async {
        await tester.tapAt(const Offset(20, 20)); // tutup bottom sheet
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await tester.pump();

        await tekan(tester, find.byType(PopupMenuButton<String>).last,
            apa: 'menu AppBar');
        final item = find.text(t('dm_hapus_mapel'));
        pastikan(ada(item), 'item hapus mapel harus muncul');
        await tekan(tester, item, apa: 'item Hapus mapel');
        pastikan(ada(find.byType(AlertDialog)),
            'dialog hitung mundur harus terbuka');
        await tungguHitungMundur(tester);
        await tekan(tester, diDialog(find.byType(FilledButton)),
            apa: 'Hapus', jeda: 700);
        final sampah = await MapelServiceImpl().isiSampah();
        pastikan(sampah.any((x) => x.id == idMapel), 'mapel harus ada di Sampah');
      }, bukti: () => 'mapel pindah ke Sampah setelah hitung mundur');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // E. LAYAR LIBRARY
  // ═══════════════════════════════════════════════════════════════
  group('E. Layar Library', () {
    testWidgets('Library: filter, cari, popup lihat/rename/hapus',
        (tester) async {
      await tester.runAsync(semai);
      await jalankan(tester, 'E0 muat layar Library', () async {
        await buka(tester, const Scaffold(body: HalamanPenyimpanan()));
      }, bukti: () => 'layar Library dimuat');

      catat(
        'E1 berkas tampil di daftar',
        ada(find.text('laporan.pdf')),
        ada(find.text('laporan.pdf')) ? 'laporan.pdf terlihat' : 'tidak tampil',
      );

      // E2 — filter tipe
      await jalankan(
          tester,
          'E2 filter ${t('lib_semua')}/${t('lib_gambar')}/${t('lib_file')}',
          () async {
        final seg = find.byType(SegmentedButton<String>);
        pastikan(ada(seg), 'SegmentedButton filter harus ada');
        // Label "Gambar" juga dipakai kartu statistik, jadi targetkan yang
        // benar-benar berada di dalam kontrol filter.
        final diFilter = find.descendant(
          of: seg,
          matching: find.text(t('lib_gambar')),
        );
        await tekan(tester, diFilter, apa: 'filter Gambar', jeda: 700);
        pastikan(!ada(find.text('laporan.pdf')),
            'filter Gambar harus menyembunyikan berkas FILE');
        await tekan(tester,
            find.descendant(of: seg, matching: find.text(t('lib_semua'))),
            apa: 'filter Semua', jeda: 700);
        pastikan(ada(find.text('laporan.pdf')),
            'filter Semua harus memunculkannya lagi');
      }, bukti: () => 'filter tipe bekerja dua arah');

      // E3 — cari berkas
      await jalankan(tester, 'E3 kotak cari berkas', () async {
        final kolom = find.byType(TextField).first;
        await tester.enterText(kolom, 'laporan');
        await tungguIO(tester, 400);
        pastikan(ada(find.text('laporan.pdf')), 'berkas harus tetap tampil');
        await tester.enterText(kolom, 'zzz');
        await tungguIO(tester, 400);
        pastikan(!ada(find.text('laporan.pdf')),
            'kata tak cocok harus menyaring habis');
        await tester.enterText(kolom, '');
        await tungguIO(tester, 400);
      }, bukti: () => 'penyaringan berkas bekerja');

      // E4 — popup → Lihat
      await jalankan(tester, 'E4 popup berkas → "${t('k_lihat')}"', () async {
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup berkas');
        final item = find.text(t('k_lihat'));
        pastikan(ada(item), 'item Lihat harus muncul');
        await tekan(tester, item, apa: 'item Lihat', jeda: 700);
      }, bukti: () => 'aksi buka berkas dijalankan (tanpa crash)');

      // E5 — popup → Ganti nama
      await jalankan(tester, 'E5 popup berkas → "${t('k_rename')}" → Simpan',
          () async {
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup berkas');
        final item = find.text(t('k_rename'));
        pastikan(ada(item), 'item Ganti nama harus muncul');
        await tekan(tester, item, apa: 'item Ganti nama');
        pastikan(ada(find.text(t('lib_ubah_nama_judul'))),
            'dialog ganti nama harus terbuka');
        await tester.enterText(
            diDialog(find.byType(TextField)).first, 'namabaru.pdf');
        await tester.pump();
        await tekan(tester, find.text(t('simpan')), apa: 'Simpan', jeda: 700);
              final semua = await LampiranServiceImpl().semua();
        pastikan(semua.any((l) => l.namaFile == 'namabaru.pdf'),
            'nama berkas harus berubah di database');
      }, bukti: () => 'nama berkas di database berubah jadi namabaru.pdf');

      // E6 — popup → Hapus
      await jalankan(tester, 'E6 popup berkas → "${t('k_hapus_tooltip')}"',
          () async {
        await tekan(tester, find.byType(PopupMenuButton<String>).first,
            apa: 'popup berkas');
        final item = find.text(t('k_hapus_tooltip'));
        pastikan(ada(item), 'item Hapus harus muncul');
        await tekan(tester, item, apa: 'item Hapus');
        final konfirmasi = find.widgetWithText(FilledButton, t('hapus'));
        pastikan(ada(konfirmasi), 'dialog konfirmasi harus muncul');
        await tekan(tester, konfirmasi, apa: 'Hapus', jeda: 700);
              final sisa = await LampiranServiceImpl().semua();
        pastikan(sisa.isEmpty, 'berkas harus terhapus dari database');
      }, bukti: () => 'berkas terhapus dari database');

      // E7 — keadaan kosong
      await jalankan(tester, 'E7 keadaan kosong', () async {
        await tungguIO(tester, 700);
        pastikan(ada(find.text(t('lib_kosong_judul'))),
            'keadaan kosong harus tampil setelah berkas terhapus');
      }, bukti: () => 'keadaan kosong tampil');

      // E8 — tombol tambah pada keadaan kosong
      await jalankan(tester, 'E8 tombol tambah pada keadaan kosong', () async {
        final tambah = find.text(t('lib_tambah'));
        pastikan(ada(tambah), 'tombol tambah harus ada');
        await tekan(tester, tambah, apa: 'tombol tambah', jeda: 700);
        pastikan(ada(find.text(t('lib_pilih_gambar'))),
            'lembar pilih sumber harus terbuka');
      }, bukti: () => 'lembar pilih sumber (gambar/file) terbuka');
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // F. LAYAR PENGATURAN
  // ═══════════════════════════════════════════════════════════════
  group('F. Layar Pengaturan', () {
    testWidgets('Pengaturan: tema, bahasa', (tester) async {
      await tester.runAsync(semai);
      await jalankan(tester, 'F0 muat layar Pengaturan', () async {
        // HalamanPengaturan mengembalikan ListView (bukan Scaffold), jadi
        // harus dibungkus Scaffold supaya Material/overlay tersedia.
        await buka(tester, const Scaffold(body: HalamanPengaturan()));
      }, bukti: () => 'layar Pengaturan dimuat');

      for (final (label, nilai) in [
        (t('set_gelap'), 'gelap'),
        (t('set_terang'), 'terang'),
        (t('set_ikuti_sistem'), 'sistem'),
      ]) {
        await jalankan(tester, 'F radio tema → $label', () async {
          await tekan(tester, find.text(label), apa: 'radio "$label"', jeda: 700);
          final mode = await PengaturanServiceImpl().tema();
          pastikan(mode == nilai, 'tema tersimpan harus "$nilai", dapat "$mode"');
        }, bukti: () => 'pengaturan tema tersimpan = $nilai');
      }

      // F4 — dropdown bahasa → Inggris
      await jalankan(tester, 'F4 dropdown bahasa → ${t('set_bahasa_en')}',
          () async {
        await tekan(tester, find.byType(DropdownButton<String>),
            apa: 'dropdown bahasa');
        final pilihan = find.text(t('set_bahasa_en'));
        pastikan(ada(pilihan), 'menu bahasa harus terbuka');
        await tekan(tester, pilihan.last, apa: 'pilihan Inggris', jeda: 700);
        final b = await PengaturanServiceImpl().bahasa();
        pastikan(b == 'en', 'bahasa tersimpan harus en, dapat $b');
      }, bukti: () => 'bahasa tersimpan = en');
    });
  });
}