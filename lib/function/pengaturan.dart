/// Entitas Pengaturan (Key-Value store).
/// Tabel: pengaturan (SkemaDb.tabelPengaturan). Kunci tetap: tema (system/terang/gelap), warna_aksen (hex), versi_skema, dibuat_pada.
/// dipakai di RepoPengaturan
class Pengaturan {
  final String kunci;
  final String nilai;

  Pengaturan({required this.kunci, required this.nilai});

  /// Mengubah ke Map untuk INSERT/REPLACE ke SQLite.
  /// dipakai di RepoPengaturan.set
  Map<String, Object?> toMap() => {'kunci': kunci, 'nilai': nilai};

  /// Membuat [Pengaturan] dari baris hasil query SQLite.
  /// dipakai di RepoPengaturan.get, RepoPengaturan.semua
  factory Pengaturan.fromMap(Map<String, Object?> m) => Pengaturan(
        kunci: m['kunci'] as String,
        nilai: m['nilai'] as String,
      );
}
