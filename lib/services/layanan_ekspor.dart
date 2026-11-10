// Wrapper LayananEkspor — bungkus ExportService dengan API yang dipakai UI.
// Nama 'LayananEkspor' dipakai di layar DetailMapel.

export 'package:syllabind/services/export_service.dart' show ExportService;
export 'package:syllabind/services/mapel_service.dart' show MapelService;
export 'package:syllabind/services/materi_service.dart' show MateriService;
export 'package:syllabind/services/tugas_service.dart' show TugasService;
export 'package:syllabind/services/lampiran_service.dart' show LampiranService;

import 'dart:io';

import 'package:syllabind/services/export_service.dart';
import 'package:syllabind/services/mapel_service.dart';
import 'package:syllabind/services/mapel_service_impl.dart';
import 'package:syllabind/services/materi_service.dart';
import 'package:syllabind/services/materi_service_impl.dart';
import 'package:syllabind/services/tugas_service.dart';
import 'package:syllabind/services/tugas_service_impl.dart';
import 'package:syllabind/services/lampiran_service.dart';
import 'package:syllabind/services/lampiran_service_impl.dart';
import 'package:syllabind/function/materi.dart';

/// Wrapper LayananEkspor — bungkus ExportService dengan API yang dipakai UI.
/// dipakai di HalamanDetailMapel._TabMateri._eksporCatatan
class LayananEkspor {
  final ExportService _service;

  /// Folder alternatif saat berjalan di unit test.
  /// dipakai di test/export_service_test.dart
  static Directory? get folderUji => ExportService.folderUji;

  static set folderUji(Directory? nilai) => ExportService.folderUji = nilai;

  LayananEkspor({
    MapelService? mapelRepo,
    MateriService? materiRepo,
    TugasService? tugasRepo,
    LampiranService? lampiranRepo,
  }) : _service = ExportService(
          mapelRepo: mapelRepo ?? MapelServiceImpl(),
          materiRepo: materiRepo ?? MateriServiceImpl(),
          tugasRepo: tugasRepo ?? TugasServiceImpl(),
          lampiranRepo: lampiranRepo ?? LampiranServiceImpl(),
        );

  /// Ekspor semua data ke file .txt.
  /// dipakai di HalamanPengaturan._eksporSemua
  Future<File> eksporSemua() => _service.eksporSemua();

  /// Ekspor satu catatan (materi) ke file .txt.
  /// dipakai di HalamanDetailMapel._TabMateri._eksporCatatan
  Future<File> eksporCatatan({
    required Materi catatan,
    required String namaMapel,
  }) => _service.eksporCatatan(catatan: catatan, namaMapel: namaMapel);
}