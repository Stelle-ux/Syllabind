// Wrapper LayananHapus — bungkus DeleteService dengan API yang dipakai UI.
// Nama 'LayananHapus' dipakai di layar Academic, DetailMapel, Pengaturan, Penyimpanan.

export 'package:syllabind/services/delete_service.dart' show DeleteService;
export 'package:syllabind/services/mapel_service.dart' show MapelService;
export 'package:syllabind/services/materi_service.dart' show MateriService;
export 'package:syllabind/services/tugas_service.dart' show TugasService;
export 'package:syllabind/services/lampiran_service.dart' show LampiranService;
export 'package:syllabind/function/hasil_bersih.dart' show HasilBersih;

import 'package:syllabind/services/delete_service.dart';
import 'package:syllabind/services/mapel_service.dart';
import 'package:syllabind/services/materi_service.dart';
import 'package:syllabind/services/tugas_service.dart';
import 'package:syllabind/services/lampiran_service.dart';
import 'package:syllabind/function/hasil_bersih.dart';
import 'package:syllabind/function/mapel.dart';

/// Wrapper LayananHapus — bungkus DeleteService dengan API yang dipakai UI.
/// dipakai di HalamanAcademic, HalamanDetailMapel, HalamanPengaturan, HalamanPenyimpanan
class LayananHapus {
  final DeleteService _service;
  final MapelService _mapelRepo;
  final MateriService _materiRepo;
  final TugasService _tugasRepo;
  final LampiranService _lampiranRepo;

  LayananHapus({
    required MapelService mapelRepo,
    required MateriService materiRepo,
    required TugasService tugasRepo,
    required LampiranService lampiranRepo,
  })  : _mapelRepo = mapelRepo,
        _materiRepo = materiRepo,
        _tugasRepo = tugasRepo,
        _lampiranRepo = lampiranRepo,
        _service = DeleteService(
          mapelRepo: mapelRepo,
          materiRepo: materiRepo,
          tugasRepo: tugasRepo,
          lampiranRepo: lampiranRepo,
        );

  /// Service mapel (akses langsung untuk isiSampah, pulihkan, dll).
  /// dipakai di HalamanPengaturan._LembarSampah
  MapelService get mapel => _mapelRepo;

  /// Hapus lunak mapel (soft delete → masuk Sampah).
  /// dipakai di HalamanAcademic._hapusMapel, HalamanDetailMapel._hapusMapel
  Future<int> hapusMapelLunak(int id) => _service.hapusLembutMapel(id);

  /// Hapus permanen mapel + file fisik (purge dari Sampah).
  /// dipakai di HalamanPengaturan._LembarSampah._hapusPermanen
  Future<int> hapusPermanenMapel(int id) => _service.hapusPermanenMapel(id);

  /// Alias untuk hapusPermanenMapel (dipakai di Pengaturan).
  /// dipakai di HalamanPengaturan._LembarSampah._hapusPermanen
  Future<int> mapelPermanen(int id) => _service.hapusPermanenMapel(id);

  /// Hapus permanen materi + file fisik.
  /// dipakai di HalamanDetailMapel._TabMateri._hapusMateri
  Future<int> hapusPermanenMateri(int id) => _service.hapusPermanenMateri(id);

  /// Bersihkan otomatis mapel di Sampah > hari hari.
  /// dipakai di HalamanPengaturan._LembarSampah._bersihkanOtomatis
  Future<HasilBersih> bersihkanSampah({int hari = 30}) => _service.bersihkanSampah(hari: hari);

  /// Hapus permanen satu tugas.
  /// dipakai di HalamanDetailMapel._TabTugasMapel._hapusTugas
  Future<int> hapusPermanenTugas(int id) => _service.hapusPermanenTugas(id);
}