import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/hasil_bersih.dart';
import 'package:syllabind/services/mapel_repository.dart';
import 'package:syllabind/services/materi_repository.dart';
import 'package:syllabind/services/lampiran_repository.dart';

/// Layanan penghapusan — mengatur urutan operasi antara database dan file.
///
/// Kenapa dipisah? Karena urutannya penting dan mudah salah:
///
/// Saat menghapus mapel permanen:
///   1. Kumpulkan + hapus FILE FISIK dulu (via [LampiranRepository]).
///   2. Baru hapus baris DB (CASCADE akan menghapus materi → lampiran).
///
/// Kalau dibalik, baris lampiran hilang duluan, lokasi file tidak bisa
/// dilacak lagi, dan file menjadi sampah tak terlihat di penyimpanan.
class DeleteService {
  final MapelRepository _mapelRepo;
  final MateriRepository _materiRepo;
  final LampiranRepository _lampiranRepo;

  DeleteService({
    required MapelRepository mapelRepo,
    required MateriRepository materiRepo,
    required LampiranRepository lampiranRepo,
  })  : _mapelRepo = mapelRepo,
        _materiRepo = materiRepo,
        _lampiranRepo = lampiranRepo;

  /// Hapus **lunak** satu mapel — masuk Sampah, bisa dipulihkan.
  ///
  /// File fisik TIDAK disentuh di sini. File baru dihapus saat
  /// [hapusPermanenMapel] dipanggil dari halaman Sampah.
  Future<int> hapusLembutMapel(int mapelId) => _mapelRepo.hapusLembut(mapelId);

  /// Hapus permanen satu mapel beserta seluruh isinya (purge dari Sampah).
  ///
  /// Urutan Kritis:
  ///   1. Hapus SEMUA file fisik lampiran milik mapel ini.
  ///   2. Hapus baris mapel di DB → CASCADE hapus materi → CASCADE hapus lampiran.
  ///
  /// Mengembalikan jumlah file fisik yang berhasil dihapus.
  Future<int> hapusPermanenMapel(int mapelId) async {
    final fileDihapus = await _lampiranRepo.hapusFileMilikMapel(mapelId);
    await _mapelRepo.hapusPermanen(mapelId);
    return fileDihapus;
  }

  /// Hapus permanen satu materi beserta lampirannya.
  ///
  /// Urutan:
  ///   1. Hapus file fisik lampiran milik materi ini.
  ///   2. Hapus baris materi di DB → CASCADE hapus lampiran.
  Future<int> hapusPermanenMateri(int materiId) async {
    final fileDihapus = await _lampiranRepo.hapusFileMilikMateri(materiId);
    await _materiRepo.hapusPermanen(materiId);
    return fileDihapus;
  }

  /// Membersihkan Sampah otomatis: hapus permanen semua mapel yang soft-deleted
  /// lebih dari [hari] hari lalu (default 30 hari).
  ///
  /// Iterasi semua mapel di Sampah, cek `deleted_at`, panggil [hapusPermanenMapel]
  /// untuk yang sudah lewat batas.
  Future<HasilBersih> bersihkanSampah({int hari = 30}) async {
    final semua = await _mapelRepo.isiSampah();
    final batas = DateTime.now().subtract(Duration(days: hari));

    var jumlahMapel = 0;
    var jumlahFile = 0;

    for (final m in semua) {
      if (m.id == null) continue;
      final kapan = m.deletedAt;
      if (kapan == null) continue;
      if (kapan.isBefore(batas)) {
        jumlahFile += await hapusPermanenMapel(m.id!);
        jumlahMapel++;
      }
    }

    return HasilBersih(jumlahMapel: jumlahMapel, jumlahFile: jumlahFile);
  }
}