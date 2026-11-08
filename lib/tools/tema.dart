import 'package:flutter/material.dart';
import 'package:syllabind/tools/tokens.dart';

/// Tema Syllabind — sederhana, bersih, mengikuti palet wireframe.
///
/// Aturan (SPESIFIKASI-FINAL.md §6):
///   - Tidak ada angka ajaib untuk status bar / bottom bar.
///     Keduanya diserahkan ke `SafeArea` dan `Scaffold` bawaan Flutter.
///   - Warna aksen bisa diubah dari Pengaturan.
///
/// **Reused in:** [main.dart] (build), [PengaturanPage._gantiTema], [PengaturanPage._gantiAksen], [komponen.dart] (BulatWarna, KartuMapel)
/// **Calls:** [ColorScheme.fromSeed], [ThemeData.copyWith]
class TemaApp {
  TemaApp._();

  /// Warna aksen bawaan — hijau teal tenang (#2F6F6B).
  ///
  /// **Reused in:** [dariHex] (fallback), [main.dart] (init), [PengaturanPage] (default)
  static const Color aksenDefault = Color(0xFF2F6F6B);

  static const Color _gelapBg = Color(0xFF11161A);
  static const Color _gelapSurface = Color(0xFF1A2127);

  /// Membangun tema terang dari warna aksen.
  ///
  /// **Reused in:** [main.dart] (build, saat temaMode != dark)
  /// **Calls:** [ColorScheme.fromSeed], [_dasar]
  static ThemeData terang(Color aksen) {
    final skema = ColorScheme.fromSeed(
      seedColor: aksen,
      brightness: Brightness.light,
    );
    return _dasar(skema);
  }

  /// Membangun tema gelap dari warna aksen.
  ///
  /// Override surface/background agar lebih gelap dari default Material3.
  ///
  /// **Reused in:** [main.dart] (build, saat temaMode == dark)
  /// **Calls:** [ColorScheme.fromSeed], [ColorScheme.copyWith], [_dasar], [ThemeData.copyWith]
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
  ///
  /// - Material3, CardTheme (elevation 0, border outlineVariant)
  /// - AppBarTheme (transparent, no elevation, no scrolledUnderElevation)
  /// - InputDecorationTheme (rounded, dense)
  /// - FilledButtonTheme (min height 48, rounded)
  /// - ListTileTheme (comfortable padding)
  /// - DividerTheme (thin, outlineVariant)
  ///
  /// **Reused in:** [terang], [gelap]
  /// **Calls:** [ThemeData], [CardThemeData], [AppBarTheme], [InputDecorationTheme], [FilledButtonThemeData], [ListTileThemeData], [DividerThemeData]
  static ThemeData _dasar(ColorScheme skema) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      // Padding bawaan kartu — tidak berisi angka tinggi status bar.
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
        // SystemUiOverlayStyle diserahkan ke AppBar bawaan;
        // jangan hardcode tinggi status bar.
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
      // Bilah navigasi bawah: tinggi ditulis eksplisit (nilainya sama dengan
      // bawaan Material 3, jadi tidak menggeser tata letak) supaya area bawah
      // tetap diurus framework, bukan dihitung manual di tiap halaman.
      navigationBarTheme: const NavigationBarThemeData(
        height: Ukuran.navTinggi,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // Tombol melayang: sudut dibulatkan ringan mengikuti bahasa bentuk
      // aplikasi (menyamai bentuk bawaan M3 agar tidak mengubah tampilan).
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

  /// Mengubah string hex ("#2F6F6B" atau "2F6F6B") menjadi [Color].
  ///
  /// Null / kosong / tidak valid → [cadangan] atau [aksenDefault].
  /// Dipakai saat load pengaturan & di color picker.
  ///
  /// **Reused in:** [main.dart] (init tema), [PengaturanPage._gantiAksen], [komponen.dart] (BulatWarna, KartuMapel), [tanyaTeks] (warnaAwal)
  /// **Calls:** [String.replaceAll], [int.tryParse], [Color]
  static Color dariHex(String? hex, {Color? cadangan}) {
    final fallback = cadangan ?? aksenDefault;
    if (hex == null) return fallback;
    var s = hex.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? fallback : Color(v);
  }

  /// Mengubah [Color] menjadi string hex "#2F6F6B" (untuk disimpan di Pengaturan).
  ///
  /// **Reused in:** [PengaturanPage._gantiAksen], [main.dart] (save tema)
  /// **Calls:** [Color.toARGB32], [int.toRadixString], [String.padLeft], [String.toUpperCase]
  static String keHex(Color c) {
    final a = c.toARGB32();
    return '#${(a & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Palet warna per mata pelajaran (12 warna).
  ///
  /// Dipakai color picker di form mapel. Terpisah dari [palet] (warna aksen
  /// aplikasi) supaya keduanya bisa berubah tanpa saling memengaruhi.
  ///
  /// **Reused in:** [komponen.dart] (tanyaTeks color picker wrap), [BulatWarna]
  static const List<String> paletMapel = [
    '#2F6F6B', '#2563EB', '#0284C7', '#7C3AED',
    '#C026D3', '#DB2777', '#DC2626', '#EA580C',
    '#D97706', '#16A34A', '#65A30D', '#475569',
  ];

  /// Palet pilihan warna aksen di Pengaturan (label → hex).
  ///
  /// **Reused in:** [PengaturanPage.build] (dropdown/segmented button)
  static const Map<String, String> palet = {
    'Hijau Teal': '#2F6F6B',
    'Biru': '#2563EB',
    'Ungu': '#7C3AED',
    'Jingga': '#EA580C',
    'Merah': '#DC2626',
    'Abu': '#475569',
  };
}