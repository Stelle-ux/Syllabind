import 'package:syllabind/function/mapel.dart';

/// Contract untuk repository Mata Pelajaran.
///
/// Implementasi konkret: [MapelRepositoryImpl] di services.
abstract class MapelRepository {
  /// Menambah mata pelajaran baru. Returns id baris baru.
  Future<int> tambah(Mapel mapel);

  /// Semua mapel aktif, lengkap dengan jumlah materi & tugas.
  /// [termasukSampah] true untuk ambil semua (termasuk terhapus).
  Future<List<Mapel>> semua({bool termasukSampah = false});

  /// Hanya mapel di Sampah (deleted_at IS NOT NULL), urut terbaru dulu.
  Future<List<Mapel>> isiSampah();

  /// Cari mapel by ID (termasuk yang di Sampah).
  Future<Mapel?> cari(int id);

  /// Ubah data mapel (nama, deskripsi, warna). Auto update updated_at.
  Future<int> ubah(Mapel mapel);

  /// Soft delete: isi deleted_at. Mapel hilang dari daftar, muncul di Sampah.
  Future<int> hapusLembut(int id);

  /// Batal soft delete: kosongkan deleted_at. Mapel kembali ke daftar.
  Future<int> pulihkan(int id);

  /// Hapus permanen (purge). CASCADE hapus materi, tugas, lampiran.
  /// Pemanggil HARUS hapus file fisik lampiran SEBELUM memanggil ini.
  Future<int> hapusPermanen(int id);

  /// Jumlah mapel aktif.
  Future<int> jumlah();
}