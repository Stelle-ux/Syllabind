// Wrapper LayananHapus — bungkus DeleteService dengan API yang dipakai UI.
// Nama 'LayananHapus' dipakai di layar Academic, DetailMapel, Pengaturan, Penyimpanan.

export 'package:syllabind/services/delete_service.dart' show DeleteService;
export 'package:syllabind/services/mapel_repository.dart' show MapelRepository;
export 'package:syllabind/services/materi_repository.dart' show MateriRepository;
export 'package:syllabind/services/lampiran_repository.dart' show LampiranRepository;
export 'package:syllabind/function/hasil_bersih.dart' show HasilBersih;

import 'package:syllabind/services/delete_service.dart';
import 'package:syllabind/services/mapel_repository.dart';
import 'package:syllabind/services/materi_repository.dart';
import 'package:syllabind/services/lampiran_repository.dart';
import 'package:syllabind/function/hasil_bersih.dart';
import 'package:syllabind/function/mapel.dart';

class LayananHapus {
  final DeleteService _service;
  final MapelRepository _mapelRepo;
  final MateriRepository _materiRepo;
  final LampiranRepository _lampiranRepo;

  LayananHapus({
    required MapelRepository mapelRepo,
    required MateriRepository materiRepo,
    required LampiranRepository lampiranRepo,
  })  : _mapelRepo = mapelRepo,
        _materiRepo = materiRepo,
        _lampiranRepo = lampiranRepo,
        _service = DeleteService(
          mapelRepo: mapelRepo,
          materiRepo: materiRepo,
          lampiranRepo: lampiranRepo,
        );

  /// Repository mapel (akses langsung untuk isiSampah, pulihkan, dll).
  MapelRepository get mapel => _mapelRepo;

  /// Hapus lunak mapel (soft delete → masuk Sampah).
  Future<int> hapusMapelLunak(int id) => _service.hapusLembutMapel(id);

  /// Hapus permanen mapel + file fisik (purge dari Sampah).
  Future<int> hapusPermanenMapel(int id) => _service.hapusPermanenMapel(id);

  /// Alias untuk hapusPermanenMapel (dipakai di Pengaturan).
  Future<int> mapelPermanen(int id) => _service.hapusPermanenMapel(id);

  /// Hapus permanen materi + file fisik.
  Future<int> hapusPermanenMateri(int id) => _service.hapusPermanenMateri(id);

  /// Bersihkan otomatis mapel di Sampah > [hari] hari.
  Future<HasilBersih> bersihkanSampah({int hari = 30}) => _service.bersihkanSampah(hari: hari);
}