/// Hasil ringkasan tugas untuk halaman Home.
///
/// Bukan entitas tabel — dihitung oleh [TugasRepository.ringkasan] via query agregat.
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
  int get total => belum + selesai;
}
