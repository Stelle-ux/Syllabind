import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/function/ringkasan_tugas.dart';

/// Contract untuk repository Tugas.
abstract class TugasRepository {
  Future<int> tambah(Tugas tugas);
  Future<List<Tugas>> perMapel(int mapelId, {bool termasukSampah = false});
  Future<List<Tugas>> semua({String? status});
  Future<List<Tugas>> tenggatTerdekat({int batasHari = 7});
  Future<List<Tugas>> lewatTenggat();
  Future<Tugas?> cari(int id);
  Future<int> ubah(Tugas tugas);
  Future<int> ubahStatus(int id, String status);
  Future<int> hapusLembut(int id);
  Future<int> hapusTugas(int id);
  /// Alias singkat untuk [hapusLembut] — digunakan oleh UI yang ingin API sederhana.
  Future<int> hapus(int id);
  Future<int> pulihkan(int id);
  Future<int> hapusPermanen(int id);
  Future<RingkasanTugas> ringkasan();
}