/// Token desain Syllabind — satu sumber kebenaran untuk jarak, sudut,
/// opasitas, ukuran ikon, dan ukuran komponen.
///
/// Alasan keberadaan berkas ini: sebelumnya nilai-nilai ini ditulis langsung
/// di widget (21 nilai jarak berbeda, 6 sudut, 7 ukuran ikon). Nilai yang sama
/// perannya sering ditulis berbeda — pemisah daftar sempat ditulis `9` di enam
/// tempat sementara celah ikon-teks ditulis `13` dan `12` untuk peran yang sama.
/// Selama nilai ditulis di widget, layar kelima akan menghasilkan set nilai
/// kelima pula. Token memutus itu.
///
/// **Aturan:** di `lib/ui/`, angka mentah untuk jarak/sudut/opasitas/ikon tidak
/// ditulis lagi — pakai token di bawah. Pengecualian: `0`, dan angka yang
/// memang bagian dari geometri setempat (mis. `width: 46` milik satu widget).
///
/// Skala jarak memakai basis 4 dengan langkah halus 2. Semua nilai yang dipakai
/// aplikasi masuk skala ini; nilai di luar skala sudah dinormalkan (selisih
/// ≤2px, tidak terlihat mata).
///
/// **Reused in:** seluruh `lib/ui/`
class Jarak {
  Jarak._();

  static const double j2 = 2.0;
  static const double j4 = 4.0;
  static const double j6 = 6.0;
  static const double j8 = 8.0;
  static const double j10 = 10.0;
  static const double j12 = 12.0;
  static const double j14 = 14.0;
  static const double j16 = 16.0;
  static const double j18 = 18.0;
  static const double j20 = 20.0;
  static const double j24 = 24.0;
  static const double j32 = 32.0;
}

/// Radius sudut. `r20` dan `r30` dipakai untuk bentuk pil (badge, area sentuh
/// bulat); sisanya untuk kartu, kolom isian, dan kotak ikon.
///
/// **Reused in:** [tema.dart] (CardTheme, InputDecorationTheme,
/// FilledButtonTheme), [komponen.dart], [halaman/home.dart],
/// [halaman/pengaturan.dart]
class Sudut {
  Sudut._();

  static const double r10 = 10.0;
  static const double r12 = 12.0;
  static const double r14 = 14.0;
  static const double r20 = 20.0;
  static const double r30 = 30.0;
}

/// Tingkat opasitas untuk warna yang ditumpuk di atas permukaan.
///
/// Dinamai menurut peran, bukan nilainya — supaya "seberapa lembut" bisa
/// disetel sekali untuk seluruh aplikasi.
///
/// **Reused in:** [komponen.dart] (chip, kotak mapel, bulat warna),
/// [halaman/home.dart], [halaman/detail_mapel.dart]
class Opasitas {
  Opasitas._();

  /// Latar samar untuk kotak ikon dan badge — warna aksen di atas permukaan.
  static const double lembut = 0.13;

  /// Nyaris tak terlihat; untuk bidang yang cuma memberi kesan kedalaman.
  static const double redup = 0.07;

  /// Cincin pilihan pada bulat warna.
  static const double cincin = 0.42;

  /// Latar kotak peringatan (varian `errorContainer`).
  static const double peringatan = 0.45;
}

/// Ukuran ikon menurut peran.
///
/// **Reused in:** [komponen.dart], [halaman/home.dart],
/// [halaman/penyimpanan.dart], [halaman/pengaturan.dart]
class Ikon {
  Ikon._();

  /// Ikon kecil di dalam chip label.
  static const double xs = 14.0;

  /// Ikon di dalam tombol dan baris daftar — ukuran paling umum.
  static const double sm = 18.0;

  /// Tanda centang di dalam bulat warna.
  static const double cek = 20.0;

  /// Ikon besar di kotak mata pelajaran.
  static const double md = 21.0;

  /// Ikon pada keadaan kosong (layar tanpa data).
  static const double kosong = 46.0;
}

/// Ukuran tetap milik komponen tertentu.
///
/// **Reused in:** [komponen.dart] (KartuMapel, BulatWarna),
/// [halaman/home.dart], [tema.dart]
class Ukuran {
  Ukuran._();

  /// Kotak ikon di baris daftar.
  static const double kotakIkon = 38.0;

  /// Kotak penanda warna pada kartu mata pelajaran.
  static const double kotakMapel = 42.0;

  /// Diameter bulat pilihan warna.
  static const double bulatWarna = 46.0;

  /// Tinggi minimum tombol utama — ambang sasaran sentuh yang nyaman.
  static const double tombolMin = 48.0;

  /// Ruang bebas di bawah daftar supaya isi terakhir tidak tertutup tombol
  /// melayang (FAB 56 + napas 32).
  static const double bebasFAB = 88.0;

  /// Kotak penampung indikator memuat (pengganti ikon tombol saat sibuk).
  static const double pemuat = 16.0;

  /// Tebal garis indikator memuat.
  static const double pemuatTebal = 2.0;

  /// Tebal cincin penanda pilihan pada bulat warna.
  static const double cincin = 3.0;

  /// Tinggi bilah navigasi bawah. Menyamai tinggi bawaan Material 3 supaya
  /// tidak ada pergeseran tata letak — ditulis eksplisit agar terlihat bahwa
  /// ini keputusan, bukan kebetulan bawaan.
  static const double navTinggi = 80.0;

  /// Radius tombol melayang (FAB). Menyamai bentuk bawaan Material 3.
  static const double fabRadius = 16.0;
}
