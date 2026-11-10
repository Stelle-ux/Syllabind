import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syllabind/services/db.dart';
import 'package:syllabind/function/index.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/screen/academic_page.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';
import 'package:syllabind/screen/home_page.dart';
import 'package:syllabind/screen/pengaturan_page.dart';
import 'package:syllabind/screen/penyimpanan_page.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Uji ketahanan tampilan (F8).
///
/// Tiga kondisi yang tidak pernah diuji dan justru paling sering merusak
/// aplikasi saat dipakai orang lain:
///
/// 1. **Mode gelap** - palet berbeda; tata letak bisa rusak walau warnanya lolos.
/// 2. **Layar sempit (320 dp)** - HP kecil; baris bisa meluber.
/// 3. **Huruf besar (textScale 1.5)** - aksesibilitas; teks bisa terpotong.
///
/// Setiap layar dirender di setiap kondisi, lalu diperiksa **tidak ada
/// exception** dan **tidak ada overflow**. Ini mengubah "sudah saya periksa"
/// menjadi bukti yang bisa dijalankan ulang kapan saja.
///
/// Dua jebakan harness yang sempat membuat tes ini gagal padahal **bukan** bug
/// produk - dicatat supaya tidak terulang:
///
/// 1. **Halaman-halaman ini bukan `Scaffold`.** Home, Academic, Library, dan
///    Pengaturan mengembalikan `ListView`/`Column`; `Scaffold`-nya milik
///    `main.dart`. Dipompa telanjang -> "No Material widget found".
///    Karena itu semuanya dibungkus `Scaffold(body: ...)` di sini.
/// 2. **`MediaQueryData(...)` kosong punya `size: Size.zero`.** Menyuntik
///    MediaQuery baru di luar `MaterialApp` menghapus ukuran layar asli dan
///    memunculkan "Null check operator used on a null value" yang menyesatkan.
///    Karena itu skala huruf diatur lewat `MaterialApp.builder` dengan
///    `copyWith` - ukuran dan sisanya diwarisi, hanya skala yang diubah.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    Db.modeUji = true;
  });

  // WAJIB: `Db.tutup()` bukan sekadar menutup koneksi - ia juga memanggil
  // `_bersihkanFolderSementara()`. Tanpa baris ini, setiap kali tes ini
  // dijalankan ia meninggalkan satu folder `build/uji_tmp/syllabind_uji_*`
  // (terbukti: 5 folder menumpuk setelah 5 kali jalan). Tes lain di proyek
  // ini sudah memakai pola yang sama.
  tearDownAll(() async {
    await Db.tutup();
  });

  /// Warna aksen default aplikasi (sama dengan nilai awal di PengaturanServiceImpl).
  const aksen = Color(0xFF2F6F6B);

  /// Kondisi yang diuji. `lebar` dalam dp; skala = textScaleFactor.
  const kondisi = <String, ({double lebar, Brightness terang, double skala})>{
    'gelap-normal': (lebar: 360, terang: Brightness.dark, skala: 1.0),
    'terang-normal': (lebar: 360, terang: Brightness.light, skala: 1.0),
    'gelap-sempit-320': (lebar: 320, terang: Brightness.dark, skala: 1.0),
    'terang-sempit-320': (lebar: 320, terang: Brightness.light, skala: 1.0),
    'gelap-huruf-1.5': (lebar: 360, terang: Brightness.dark, skala: 1.5),
    'terang-huruf-1.5': (lebar: 360, terang: Brightness.light, skala: 1.5),
    'sempit-huruf-1.5': (lebar: 320, terang: Brightness.light, skala: 1.5),
  };

  /// Merender satu layar pada satu kondisi dan mengembalikan daftar kesalahan.
  Future<List<String>> periksaLayar(
    WidgetTester tester,
    String nama,
    String kondisiNama,
    ({double lebar, Brightness terang, double skala}) k, {
    required Widget Function() bikin,
  }) async {
    tester.view.physicalSize = Size(k.lebar * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaApp.terang(aksen),
        darkTheme: TemaApp.gelap(aksen),
        themeMode:
            k.terang == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        // Skala huruf disuntik di sini, bukan dengan MediaQuery terpisah:
        // `copyWith` mewarisi ukuran layar asli dari tester.view.
        builder: (context, anak) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(k.skala)),
          child: anak!,
        ),
        // Keempat halaman utama bukan Scaffold - miliknya ada di main.dart.
        home: Scaffold(body: bikin()),
      ),
    );

    // Beri waktu pemuatan async (DB) selesai.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final galat = <String>[];
    Object? e;
    while ((e = tester.takeException()) != null) {
      galat.add(e.toString());
    }

    // Bersihkan pohon supaya timer layar ini tidak bocor ke layar berikutnya.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    return galat.map((g) => '[$nama / $kondisiNama] $g').toList();
  }

  for (final entri in kondisi.entries) {
    final nama = entri.key;
    final k = entri.value;

    testWidgets('Home - $nama', (tester) async {
      await tester.runAsync(() async {
        final g = await periksaLayar(tester, 'Home', nama, k,
            bikin: () => HalamanHome(onBukaAcademic: () {}));
        expect(g, isEmpty, reason: g.join('\n---\n'));
      });
    });

    testWidgets('Academic - $nama', (tester) async {
      await tester.runAsync(() async {
        final g = await periksaLayar(tester, 'Academic', nama, k,
            bikin: () => const HalamanAcademic());
        expect(g, isEmpty, reason: g.join('\n---\n'));
      });
    });

    testWidgets('Library - $nama', (tester) async {
      await tester.runAsync(() async {
        final g = await periksaLayar(tester, 'Library', nama, k,
            bikin: () => const HalamanPenyimpanan());
        expect(g, isEmpty, reason: g.join('\n---\n'));
      });
    });

    testWidgets('Pengaturan - $nama', (tester) async {
      await tester.runAsync(() async {
        final g = await periksaLayar(tester, 'Pengaturan', nama, k,
            bikin: () => const HalamanPengaturan());
        expect(g, isEmpty, reason: g.join('\n---\n'));
      });
    });

    testWidgets('Detail Mapel - $nama', (tester) async {
      await tester.runAsync(() async {
        final g = await periksaLayar(
          tester,
          'Detail Mapel',
          nama,
          k,
          // `HalamanDetailMapel` memanggil `_mapel.id!` untuk memuat data
          // dari DB, jadi Mapel tanpa id memang gagal di sini. Beri id nyata
          // supaya yang diuji tata letaknya, bukan jalur galat.
          bikin: () => HalamanDetailMapel(
            mapel: Mapel(
              id: 1,
              nama: 'Matematika',
              deskripsi: 'Aljabar dan geometri',
            ),
          ),
        );
        // Halaman ini punya Scaffold sendiri; dibungkus lagi oleh harness.
        // Exception "nested Scaffold" bukan cacat, jadi disaring keluar.
        final nyata = g.where((x) => !x.toLowerCase().contains('nested scaffold')).toList();
        expect(nyata, isEmpty, reason: g.join('\n---\n'));
      });
    });
  }


  group('Kontras teks badge (WCAG)', () {
    /// Luminance relatif sesuai WCAG 2.x.
    double lum(Color c) {
      double kanal(double v) {
        v = v / 255.0;
        return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      }
      // Color di Flutter kini menyimpan komponen float (0..1).
      return 0.2126 * kanal(c.r * 255) +
          0.7152 * kanal(c.g * 255) +
          0.0722 * kanal(c.b * 255);
    }

    double rasio(Color depan, Color belakang) {
      final a = lum(depan), b = lum(belakang);
      final terang = a > b ? a : b;
      final gelap = a > b ? b : a;
      return (terang + 0.05) / (gelap + 0.05);
    }

    /// Meniru cara `Tanda` menggambar: warna teks penuh di atas warna yang
    /// sama tapi beropasitas, di atas permukaan kartu.
    Color diAtas(Color atas, Color bawah) {
      final a = atas.a;
      return Color.from(
        alpha: 1.0,
        red: atas.r * a + bawah.r * (1 - a),
        green: atas.g * a + bawah.g * (1 - a),
        blue: atas.b * a + bawah.b * (1 - a),
      );
    }

    for (final gelap in [false, true]) {
      testWidgets('badge terbaca di ${gelap ? "mode gelap" : "mode terang"}',
          (tester) async {
        final tema = gelap ? TemaApp.gelap(aksen) : TemaApp.terang(aksen);
        final skema = tema.colorScheme;
        final permukaan = skema.surface;

        final kasus = <String, (Color, Color)>{
          'badge Lewat tenggat': (skema.error, diAtas(skema.error.withValues(alpha: Opasitas.lembut), permukaan)),
          'badge Selesai': (skema.primary, diAtas(skema.primary.withValues(alpha: Opasitas.lembut), permukaan)),
        };

        final laporan = <String>[];
        for (final e in kasus.entries) {
          final r = rasio(e.value.$1, e.value.$2);
          laporan.add('${e.key}: ${r.toStringAsFixed(2)}:1');
          // labelSmall = teks kecil -> ambang WCAG AA = 4.5:1
          expect(r, greaterThanOrEqualTo(4.5),
              reason: '${e.key} (${gelap ? "gelap" : "terang"}) hanya '
                  '${r.toStringAsFixed(2)}:1, di bawah ambang WCAG AA 4.5:1. '
                  'Warna: teks ${e.value.$1}, latar ${e.value.$2}');
        }
        debugPrint('KONTRAS ${gelap ? "gelap" : "terang"}: ${laporan.join(" | ")}');
      });
    }
  });

  testWidgets('Kamus: SETIAP kunci yang dipakai produksi ada di dua bahasa',
      (tester) async {
    // Kunci kamus yang tidak ada dirender apa adanya oleh t(), dan itu tidak
    // akan ketahuan dari analyze maupun tes lain - layar akan menampilkan teks
    // seperti "nav_library" ke user.
    //
    // Daftarnya SENGAJA dihasilkan dari kode produksi (semua `t('...')`/`tp('...')`
    // di lib/), bukan ditulis dari ingatan. Pelajaran dari bug nyata di proyek
    // ini: kunci yang "diingat" bisa tidak pernah ada, dan tes yang menuntut
    // kunci karangan akan gagal padahal produknya benar.
    const kunciWajib = <String>[
      'ak_belum', 'ak_belum_isi', 'ak_cari_catatan', 'ak_cari_mapel',
      'ak_coba_kata', 'ak_keterangan', 'ak_kosong_catatan', 'ak_kosong_catatan_pesan',
      'ak_kosong_mapel', 'ak_kosong_mapel_pesan', 'ak_kosong_mapel_tombol', 'ak_mapel_fab',
      'ak_mapel_tersimpan', 'ak_nama_mapel', 'ak_selesai', 'ak_semua',
      'ak_tab_catatan', 'ak_tab_mapel', 'ak_tab_tugas', 'ak_tambah_mapel',
      'ak_tidak_ada_tugas', 'ak_tidak_ada_tugas_pesan', 'ak_tidak_ditemukan', 'ak_ubah_mapel',
      'batal', 'dm_belum_lampiran', 'dm_catatan_diubah', 'dm_deskripsi_opsional',
      'dm_dipindah_sampah', 'dm_ekspor_gagal', 'dm_ekspor_sukses', 'dm_gagal_lampiran',
      'dm_hapus_catatan', 'dm_hapus_catatan_pesan', 'dm_hapus_lampiran_judul', 'dm_hapus_lampiran_pesan',
      'dm_hapus_mapel', 'dm_hapus_mapel_judul', 'dm_hapus_tugas', 'dm_hapus_tugas_pesan',
      'dm_isi_catatan', 'dm_judul_materi', 'dm_judul_tugas', 'dm_kosong_catatan',
      'dm_kosong_catatan_pesan', 'dm_kosong_tugas', 'dm_kosong_tugas_pesan', 'dm_lampiran',
      'dm_lampiran_ket', 'dm_rincian_catatan', 'dm_rincian_lampiran', 'dm_rincian_tugas',
      'dm_tambah_catatan', 'dm_tambah_file', 'dm_tambah_gambar', 'dm_tambah_tugas',
      'dm_tandai_belum', 'dm_tandai_selesai', 'dm_tenggat', 'dm_tugas_diubah',
      'dm_ubah_catatan', 'dm_ubah_tugas', 'hapus', 'home_belum',
      'home_cari', 'home_catatan_judul', 'home_dekat_judul', 'home_fokus',
      'home_hasil', 'home_kosong_judul', 'home_kosong_pesan', 'home_kosong_tombol',
      'home_lewat', 'home_lewat_judul', 'home_lihat_semua', 'home_pada_tenggat',
      'home_sapaan_malam', 'home_sapaan_pagi', 'home_sapaan_siang', 'home_sapaan_sore',
      'home_selesai', 'home_selesai_pesan', 'home_subjek_judul', 'home_tanpa_dekat',
      'home_tanpa_mapel', 'home_urungkan', 'judul_app', 'k_bersihkan',
      'k_besok', 'k_ekspor_tooltip', 'k_hapus_tenggat', 'k_hapus_tooltip',
      'k_hari_ini', 'k_lampiran_opsional', 'k_lampiran_tooltip', 'k_lewat_n',
      'k_lihat', 'k_n_hari_lagi', 'k_n_materi', 'k_n_tugas',
      'k_pakai_tema', 'k_pilih_tenggat', 'k_rename', 'k_tanpa_tenggat',
      'k_tidak_kosong', 'k_tunggu', 'k_ubah', 'k_ubah_tooltip',
      'k_warna', 'k_yang_ikut', 'lib_berhasil', 'lib_buka_gagal',
      'lib_cari', 'lib_file', 'lib_gagal', 'lib_gambar',
      'lib_hapus_judul', 'lib_hapus_pesan', 'lib_kosong_judul', 'lib_kosong_pesan',
      'lib_mapel_kosong', 'lib_pilih_file', 'lib_pilih_gambar', 'lib_pilih_mapel',
      'lib_pilih_mapel_pesan', 'lib_semua', 'lib_tambah', 'lib_total',
      'lib_ubah_nama_judul', 'lib_ubah_nama_label', 'lib_ubah_nama_sukses', 'nav_academic',
      'nav_home', 'nav_library', 'nav_pengaturan', 'pulihkan',
      'sampah_berhasil', 'sampah_hapus_permanen', 'sampah_ket', 'sampah_konfirmasi_judul',
      'sampah_konfirmasi_pesan', 'sampah_kosong', 'set_bahasa', 'set_bahasa_en',
      'set_bahasa_id', 'set_bahasa_judul', 'set_bahasa_sub', 'set_gelap',
      'set_ikuti_sistem', 'set_ikuti_sistem_sub', 'set_pemulihan', 'set_sampah',
      'set_sampah_isi', 'set_sampah_kosong', 'set_tampilan', 'set_tentang',
      'set_terang', 'set_warna', 'simpan',
    ];

    for (final b in [Bahasa.id, Bahasa.en]) {
      Bahasa.set(b);
      for (final kunci in kunciWajib) {
        final hasil = t(kunci);
        expect(hasil == kunci, isFalse,
            reason: 'kunci "$kunci" TIDAK ADA di kamus ($b) - '
                't() mengembalikan kunci mentah, layar akan menampilkan teks itu');
        expect(hasil.trim(), isNotEmpty, reason: 'kunci "$kunci" kosong di $b');
      }
    }
    Bahasa.set(Bahasa.id);
  });
}
