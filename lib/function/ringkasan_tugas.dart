/// Hasil ringkasan tugas untuk halaman Home.
/// Bukan entitas tabel — dihitung oleh RepoTugas.ringkasan via query agregat.
/// dipakai di HalamanHome._segarkan, HalamanHome._angka
class RingkasanTugas {
  final int belum;
  final int selesai;
  final int lewat;

  const RingkasanTugas({
    this.belum = 0,
    this.selesai = 0,
    this.lewat = 0,
  });

  /// Total tugas aktif (belum + selesai).
  /// dipakai di HalamanHome._angka
  int get total => belum + selesai;
}
