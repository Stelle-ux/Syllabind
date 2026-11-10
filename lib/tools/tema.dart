import 'package:flutter/material.dart';
import 'package:syllabind/tools/tokens.dart';

/// Tema Syllabind — sederhana, bersih, mengikuti palet wireframe.
/// dipakai di main.dart (build), HalamanPengaturan._gantiTema, HalamanPengaturan._gantiAksen, komponen.dart (BulatWarna, KartuMapel)
class TemaApp {
  TemaApp._();

  /// Warna aksen bawaan — hijau teal tenang (#2F6F6B).
  /// dipakai di dariHex (fallback), main.dart (init), HalamanPengaturan (default)
  static const Color aksenDefault = Color(0xFF2F6F6B);

  static const Color _gelapBg = Color(0xFF11161A);
  static const Color _gelapSurface = Color(0xFF1A2127);

  /// Membangun tema terang dari warna aksen.
  /// dipakai di main.dart (build, saat temaMode != dark)
  static ThemeData terang(Color aksen) {
    final skema = ColorScheme.fromSeed(
      seedColor: aksen,
      brightness: Brightness.light,
    );
    return _dasar(skema);
  }

  /// Membangun tema gelap dari warna aksen.
  /// dipakai di main.dart (build, saat temaMode == dark)
  static ThemeData gelap(Color aksen) {
    final skema = ColorScheme.fromSeed(
      seedColor: aksen,
      brightness: Brightness.dark,
    ).copyWith(
      surface: _gelapSurface,
    );
    return _dasar(skema).copyWith(
      scaffoldBackgroundColor: _gelapBg,
    );
  }

  /// Konfigurasi tema dasar (shared light/dark).
  /// dipakai di terang, gelap
  static ThemeData _dasar(ColorScheme skema) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sudut.r14),
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: skema.surface,
        foregroundColor: skema.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sudut.r12),
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Ukuran.tombolMin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Sudut.r12),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: Ukuran.navTinggi,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ukuran.fabRadius),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: Jarak.j14, vertical: Jarak.j2),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: skema.outlineVariant,
      ),
    );
  }

  /// Mengubah string hex ("#2F6F6B" atau "2F6F6B") menjadi Color.
  /// dipakai di main.dart (init tema), HalamanPengaturan._gantiAksen, komponen.dart (BulatWarna, KartuMapel), tanyaTeks (warnaAwal)
  static Color dariHex(String? hex, {Color? cadangan}) {
    final fallback = cadangan ?? aksenDefault;
    if (hex == null) return fallback;
    var s = hex.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? fallback : Color(v);
  }

  /// Mengubah Color menjadi string hex "#2F6F6B" (untuk disimpan di Pengaturan).
  /// dipakai di HalamanPengaturan._gantiAksen, main.dart (save tema)
  static String keHex(Color c) {
    final a = c.toARGB32();
    return '#${(a & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Palet warna per mata pelajaran (12 warna).
  /// dipakai di komponen.dart (tanyaTeks color picker wrap), BulatWarna
  static const List<String> paletMapel = [
    '#2F6F6B', '#2563EB', '#0284C7', '#7C3AED',
    '#C026D3', '#DB2777', '#DC2626', '#EA580C',
    '#D97706', '#16A34A', '#65A30D', '#475569',
  ];

  /// Palet pilihan warna aksen di Pengaturan (label → hex).
  /// dipakai di HalamanPengaturan.build (dropdown/segmented button)
  static const Map<String, String> palet = {
    'Hijau Teal': '#2F6F6B',
    'Biru': '#2563EB',
    'Ungu': '#7C3AED',
    'Jingga': '#EA580C',
    'Merah': '#DC2626',
    'Abu': '#475569',
  };
}