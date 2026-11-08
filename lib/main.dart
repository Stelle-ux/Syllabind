import 'package:flutter/material.dart';

import 'package:syllabind/services/db.dart';
import 'package:syllabind/services/pengaturan_repository_impl.dart';
import 'package:syllabind/services/pengaturan_repository.dart';
import 'package:syllabind/screen/home_page.dart';
import 'package:syllabind/screen/academic_page.dart';
import 'package:syllabind/screen/penyimpanan_page.dart';
import 'package:syllabind/screen/pengaturan_page.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';

void main() {
  runApp(const Syllabind());
}

/// Memetakan nilai pengaturan tema (string) ke [ThemeMode] enum.
///
/// - `'terang'` → [ThemeMode.light]
/// - `'gelap'` → [ThemeMode.dark]
/// - lainnya (termasuk `'sistem'`) → [ThemeMode.system]
///
/// **Reused in:** [_SyllabindState._muat]
/// **Calls:** [ThemeMode] enum
ThemeMode modeDari(String tema) => switch (tema) {
      'terang' => ThemeMode.light,
      'gelap' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// Root widget aplikasi Syllabind.
///
/// Menginisialisasi pengaturan (tema, warna aksen, bahasa) dari database
/// sebelum menampilkan UI. Menggunakan [ValueListenableBuilder] pada
/// [Bahasa.aktif] agar ganti bahasa memicu rebuild seluruh MaterialApp
/// tanpa restart aplikasi.
///
/// **Reused in:** [main] (runApp)
/// **Calls:** [PengaturanRepo.tema], [PengaturanRepo.warnaAksen], [PengaturanRepo.bahasa], [Bahasa.set], [TemaApp.dariHex], [modeDari], [ValueListenableBuilder], [MaterialApp], [TemaApp.terang], [TemaApp.gelap], [RumahAplikasi]
class Syllabind extends StatefulWidget {
  const Syllabind({super.key});

  @override
  State<Syllabind> createState() => _SyllabindState();
}

class _SyllabindState extends State<Syllabind> {
  late final PengaturanRepository _pengaturan;

  ThemeMode _mode = ThemeMode.system;
  Color _aksen = TemaApp.aksenDefault;
  bool _siap = false;

  @override
  void initState() {
    super.initState();
    _pengaturan = PengaturanRepositoryImpl();
    _muat();
  }

  /// Memuat preferensi dari database & set state.
  ///
  /// Dipanggil di initState dan juga via callback [RumahAplikasi.onDataBerubah]
  /// saat user mengubah tema/warna/bahasa di halaman Pengaturan.
  ///
  /// **Reused in:** [initState], [RumahAplikasi.onDataBerubah] (callback)
  /// **Calls:** [PengaturanRepo.tema], [PengaturanRepo.warnaAksen], [PengaturanRepo.bahasa], [Bahasa.set], [TemaApp.dariHex], [modeDari], [setState]
  Future<void> _muat() async {
    final tema = await _pengaturan.tema();
    final hex = await _pengaturan.warnaAksen();
    final bahasa = await _pengaturan.bahasa();
    Bahasa.set(bahasa);
    if (!mounted) return;
    setState(() {
      _mode = modeDari(tema);
      _aksen = TemaApp.dariHex(hex);
      _siap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // ValueListenableBuilder: begitu bahasa diganti di Pengaturan, seluruh
    // pohon widget dibangun ulang tanpa perlu menutup aplikasi.
    return ValueListenableBuilder<String>(
      valueListenable: Bahasa.aktif,
      builder: (context, _, _) => MaterialApp(
        title: 'Syllabind',
        debugShowCheckedModeBanner: false,
        theme: TemaApp.terang(_aksen),
        darkTheme: TemaApp.gelap(_aksen),
        themeMode: _mode,
        home: RumahAplikasi(onDataBerubah: _muat),
      ),
    );
  }
}

/// Navigasi utama (bottom bar) — 4 tab: Home, Academic, Library, Pengaturan.
///
/// Menggunakan [NavigationBar] (Material 3) + [SafeArea] di bawah.
/// Setiap halaman dibungkus [SafeArea] sendiri agar konten tidak tertutup
/// status bar / navigation bar / notch / island.
///
/// **Reused in:** [Syllabind.build] (MaterialApp.home)
/// **Calls:** [HalamanHome], [HalamanAcademic], [HalamanPenyimpanan], [HalamanPengaturan], [NavigationBar], [SafeArea], [NavigationDestination]
class RumahAplikasi extends StatefulWidget {
  final VoidCallback onDataBerubah;

  const RumahAplikasi({super.key, required this.onDataBerubah});

  @override
    State<RumahAplikasi> createState() => _RumahAplikasiState();
}

class _RumahAplikasiState extends State<RumahAplikasi> {
  int _idx = 0;

  /// Judul AppBar per destinasi, memakai kunci kamus supaya ikut berganti
  /// bahasa. Home memakai [judul_app] (nama aplikasi); tiga sisanya memakai
  /// label destinasi masing-masing.
  static const List<String> _kunciJudul = [
    'judul_app',
    'nav_academic',
    'nav_library',
    'nav_pengaturan',
  ];

  @override
  Widget build(BuildContext context) {
    // Halaman dibangun ULANG setiap build, bukan disimpan di `late final`.
    //
    // Dulu daftar ini adalah field `late final` yang dibuat sekali di awal,
    // sehingga teks di dalamnya terpatok pada bahasa saat itu: mengganti
    // bahasa hanya memengaruhi AppBar, bukan isi halaman. Daftar biasa di
    // dalam build() membuat setiap halaman ikut dibangun ulang saat bahasa
    // berganti, tanpa kehilangan state — posisi dan jenis widget di
    // IndexedStack tetap sama.
    final halaman = <Widget>[
      HalamanHome(onBukaAcademic: () => setState(() => _idx = 1)),
      HalamanAcademic(),
      HalamanPenyimpanan(),
      HalamanPengaturan(onDataBerubah: widget.onDataBerubah),
    ];

    return Scaffold(
      // AppBar dipakai (bukan padding manual) supaya area status bar
      // ditangani Flutter dan aman di perangkat dengan notch/punch-hole.
      appBar: AppBar(title: Text(t(_kunciJudul[_idx]))),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _idx,
          children: halaman,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t('nav_home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: t('nav_academic'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.library_books_outlined),
              selectedIcon: const Icon(Icons.library_books),
              label: t('nav_library'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: t('nav_pengaturan'),
            ),
          ],
        ),
      ),
    );
  }
}
