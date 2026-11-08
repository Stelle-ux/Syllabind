// Wrapper LayananEkspor — bungkus ExportService dengan API yang dipakai UI.
// Nama 'LayananEkspor' dipakai di layar DetailMapel.

export 'package:syllabind/services/export_service.dart' show ExportService;
export 'package:syllabind/services/mapel_repository.dart' show MapelRepository;
export 'package:syllabind/services/materi_repository.dart' show MateriRepository;
export 'package:syllabind/services/tugas_repository.dart' show TugasRepository;
export 'package:syllabind/services/lampiran_repository.dart' show LampiranRepository;

import 'dart:io';

import 'package:syllabind/services/export_service.dart';
import 'package:syllabind/services/mapel_repository.dart';
import 'package:syllabind/services/mapel_repository_impl.dart';
import 'package:syllabind/services/materi_repository.dart';
import 'package:syllabind/services/materi_repository_impl.dart';
import 'package:syllabind/services/tugas_repository.dart';
import 'package:syllabind/services/tugas_repository_impl.dart';
import 'package:syllabind/services/lampiran_repository.dart';
import 'package:syllabind/services/lampiran_repository_impl.dart';
import 'package:syllabind/function/materi.dart';

class LayananEkspor {
  final ExportService _service;

  /// Folder alternatif saat berjalan di unit test.
  ///
  /// `getApplicationDocumentsDirectory()` bergantung pada kanal platform
  /// yang tidak tersedia di Dart VM, sehingga tes yang benar-benar menulis
  /// berkas akan gagal sebelum sampai ke logika aplikasi. Kait ini dipakai
  /// hanya kalau diisi oleh tes.
  ///
  /// **Diteruskan ke [ExportService.folderUji].** Sebelumnya ini field
  /// tersendiri yang tidak pernah dibaca siapa pun: tes menyetel
  /// `LayananEkspor.folderUji`, sementara `ExportService` membaca field-nya
  /// sendiri yang tetap `null` — sehingga ekspor tetap memanggil
  /// `getApplicationDocumentsDirectory()` dan gagal dengan
  /// "Binding has not yet been initialized".
  static Directory? get folderUji => ExportService.folderUji;

  static set folderUji(Directory? nilai) => ExportService.folderUji = nilai;

  LayananEkspor({
    MapelRepository? mapelRepo,
    MateriRepository? materiRepo,
    TugasRepository? tugasRepo,
    LampiranRepository? lampiranRepo,
  }) : _service = ExportService(
          mapelRepo: mapelRepo ?? MapelRepositoryImpl(),
          materiRepo: materiRepo ?? MateriRepositoryImpl(),
          tugasRepo: tugasRepo ?? TugasRepositoryImpl(),
          lampiranRepo: lampiranRepo ?? LampiranRepositoryImpl(),
        );

  /// Ekspor semua data ke file .txt.
  Future<File> eksporSemua() => _service.eksporSemua();

  /// Ekspor satu catatan (materi) ke file .txt.
  Future<File> eksporCatatan({
    required Materi catatan,
    required String namaMapel,
  }) => _service.eksporCatatan(catatan: catatan, namaMapel: namaMapel);
}