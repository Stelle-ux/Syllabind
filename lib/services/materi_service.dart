import 'package:syllabind/function/materi.dart';

/// Contract untuk service Materi Pembelajaran.
abstract class MateriService {
  Future<int> tambah(Materi materi);
  Future<List<Materi>> perMapel(int mapelId, {bool termasukSampah = false});
  Future<List<Materi>> semua({bool hanyaDenganCatatan = false});
  Future<Materi?> cari(int id);
  Future<int> ubah(Materi materi);
  Future<int> hapusLembut(int id);
  Future<int> hapusMateri(int id);
  /// Alias singkat untuk [hapusLembut] — digunakan oleh UI yang ingin API sederhana.
  Future<int> hapus(int id);
  Future<int> pulihkan(int id);
  Future<int> hapusPermanen(int id);
  Future<int> hapusPermanenTugas(int id);
  Future<List<Materi>> cariKata(String kata);
}