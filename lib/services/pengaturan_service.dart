/// Contract untuk service Pengaturan (Key-Value store sederhana).
abstract class PengaturanService {
  /// Kunci pengaturan tema: `system` | `terang` | `gelap`.
  static const String kunciTema = 'tema';

  /// Kunci warna aksen (hex, mis. `#2F6F6B`).
  static const String kunciWarnaAksen = 'warna_aksen';

  /// Kunci untuk pilihan bahasa aplikasi: `id` (bawaan) atau `en`.
  static const String kunciBahasa = 'bahasa';

  /// Mengambil nilai mentah untuk [kunci].
  Future<String?> ambil(String kunci);

  /// Menyimpan/mengupdate nilai untuk [kunci] (REPLACE jika sudah ada).
  Future<void> simpan(String kunci, String nilai);

  /// Mengambil semua pengaturan sebagai Map kunci→nilai.
  Future<Map<String, String>> semua();

  /// Menghapus pengaturan by kunci.
  Future<void> hapus(String kunci);

  // ── Pembantu bertipe (typed helpers) ──────────────────────────────────────

  /// Tema aplikasi: `system` (default) | `terang` | `gelap`.
  Future<String> tema();

  /// Set tema aplikasi.
  Future<void> setTema(String nilai);

  /// Warna aksen hex (default `#2F6F6B` — teal).
  Future<String> warnaAksen();

  /// Set warna aksen.
  Future<void> setWarnaAksen(String hex);

  /// Bahasa aplikasi: `id` (bawaan) atau `en`.
  Future<String> bahasa();

  /// Set bahasa aplikasi.
  Future<void> setBahasa(String kode);
}