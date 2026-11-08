import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/function/ringkasan_tugas.dart';
import 'package:syllabind/services/mapel_repository.dart';
import 'package:syllabind/services/materi_repository.dart';
import 'package:syllabind/services/tugas_repository.dart';
import 'package:syllabind/services/lampiran_repository.dart';

/// Ekspor data ke `.txt` (satu-satunya format ekspor).
///
/// Berguna saat presentasi UKOM: bukti bahwa data benar-benar tersimpan dan
/// bisa dikeluarkan dari aplikasi. Format teks sederhana, readable tanpa tools khusus.
class ExportService {
  final MapelRepository _mapelRepo;
  final MateriRepository _materiRepo;
  final TugasRepository _tugasRepo;
  final LampiranRepository _lampiranRepo;

  /// Folder dasar ekspor; `null` = pakai folder dokumen aplikasi.
  ///
  /// Dipakai tes karena `getApplicationDocumentsDirectory()` butuh kanal
  /// platform yang tidak ada di Dart VM.
  static Directory? folderUji;

  ExportService({
    required MapelRepository mapelRepo,
    required MateriRepository materiRepo,
    required TugasRepository tugasRepo,
    required LampiranRepository lampiranRepo,
  })  : _mapelRepo = mapelRepo,
        _materiRepo = materiRepo,
        _tugasRepo = tugasRepo,
        _lampiranRepo = lampiranRepo;

  /// Folder dokumen aplikasi, atau [folderUji] saat tes.
  Future<Directory> _folderDasar() async =>
      folderUji ?? await getApplicationDocumentsDirectory();

  /// Membuat berkas ekspor `.txt` lengkap dan mengembalikan [File]-nya.
  ///
  /// Struktur ekspor:
  ///   - Header: judul app, timestamp
  ///   - Per Mapel: nama, deskripsi, catatan, tugas (dengan status & tenggat)
  ///   - Footer: ringkasan statistik
  ///
  /// Hanya mengekspor data AKTIF (deleted_at IS NULL). Data di Sampah tidak ikut.
  Future<File> eksporSemua() async {
    final sb = StringBuffer();
    final kini = DateTime.now();

    sb.writeln('=' * 60);
    sb.writeln('SYLLABIND — EKSPOR DATA');
    sb.writeln('Dibuat: ${_tanggal(kini)} ${_jam(kini)}');
    sb.writeln('=' * 60);
    sb.writeln();

    final daftarMapel = await _mapelRepo.semua();

    if (daftarMapel.isEmpty) {
      sb.writeln('(belum ada data)');
    }

    for (final m in daftarMapel) {
      sb.writeln('■ ${m.nama.toUpperCase()}');
      if (m.deskripsi != null && m.deskripsi!.trim().isNotEmpty) {
        sb.writeln('  ${m.deskripsi}');
      }
      sb.writeln();

      final daftarMateri = await _materiRepo.perMapel(m.id!, termasukSampah: false);

      if (daftarMateri.isNotEmpty) {
        sb.writeln('  CATATAN / MATERI');
        for (final x in daftarMateri) {
          sb.writeln('    - ${x.judul}');
          if (x.isi != null && x.isi!.trim().isNotEmpty) {
            for (final baris in x.isi!.split('\n')) {
              sb.writeln('        $baris');
            }
          }
        }
        sb.writeln();
      }

      final daftarTugas = await _tugasRepo.perMapel(m.id!, termasukSampah: false);

      if (daftarTugas.isNotEmpty) {
        sb.writeln('  TUGAS');
        for (final t in daftarTugas) {
          final tanda = t.selesai ? '[v]' : '[ ]';
          sb.writeln('    $tanda ${t.judul}');
          if (t.tenggat != null) {
            sb.writeln('         Tenggat: ${_tanggal(t.tenggat!)}');
          }
          if (t.deskripsi != null && t.deskripsi!.trim().isNotEmpty) {
            sb.writeln('         ${t.deskripsi}');
          }
        }
        sb.writeln();
      }

      sb.writeln('-' * 60);
      sb.writeln();
    }

    final ringkas = await _tugasRepo.ringkasan();
    sb.writeln('RINGKASAN');
    sb.writeln('  Mata pelajaran : ${daftarMapel.length}');
    sb.writeln('  Tugas belum    : ${ringkas.belum}');
    sb.writeln('  Tugas selesai  : ${ringkas.selesai}');
    sb.writeln('  Lewat tenggat  : ${ringkas.lewat}');
    sb.writeln('  Diekspor pada  : ${_tanggal(kini)} ${_jam(kini)}');

    final lokasi = await _lokasiEkspor();
    final f = File(lokasi);
    await f.writeAsString(sb.toString());
    return f;
  }

  /// Mengekspor SATU catatan (materi) ke berkas `.txt` tersendiri.
  ///
  /// Isi berkas: nama mapel, judul catatan, isi lengkap, daftar lampiran
  /// (nama + tipe + ukuran), dan timestamp.
  Future<File> eksporCatatan({
    required Materi catatan,
    required String namaMapel,
  }) async {
    final sb = StringBuffer();
    final kini = DateTime.now();

    sb.writeln('=' * 60);
    sb.writeln('SYLLABIND — CATATAN');
    sb.writeln('Dibuat: ${_tanggal(kini)} ${_jam(kini)}');
    sb.writeln('=' * 60);
    sb.writeln();
    sb.writeln('Mata pelajaran : $namaMapel');
    sb.writeln('Judul catatan  : ${catatan.judul}');
    sb.writeln('Dibuat pada    : ${_tanggal(catatan.createdAt)}');
    sb.writeln();
    sb.writeln('-' * 60);
    sb.writeln();

    final isi = (catatan.isi ?? '').trim();
    if (isi.isEmpty) {
      sb.writeln('(catatan ini belum punya isi)');
    } else {
      sb.writeln(isi);
    }
    sb.writeln();

    // Lampiran ikut dicatat sebagai daftar — berkas fisiknya tidak disalin.
    final daftarLampiran = await _lampiranRepo.perMateri(catatan.id!);
    if (daftarLampiran.isNotEmpty) {
      sb.writeln('-' * 60);
      sb.writeln('LAMPIRAN (${daftarLampiran.length})');
      for (final l in daftarLampiran) {
        final jenis = l.gambar ? 'Gambar' : 'File';
        sb.writeln('  - ${l.namaFile}  ($jenis · ${l.ukuranTerbaca})');
      }
      sb.writeln();
    }

    sb.writeln('=' * 60);
    sb.writeln('Diekspor pada : ${_tanggal(kini)} ${_jam(kini)}');

    final lokasi = await _lokasiEksporCatatan(catatan.judul);
    final f = File(lokasi);
    await f.writeAsString(sb.toString());
    return f;
  }

  /// Membersihkan judul catatan agar aman dipakai sebagai nama berkas.
  static String _namaBerkasAman(String judul) {
    final bersih = judul
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (bersih.isEmpty) return 'catatan';
    return bersih.length <= 60 ? bersih : bersih.substring(0, 60).trim();
  }

  /// Menghasilkan path unik untuk ekspor SATU catatan.
  Future<String> _lokasiEksporCatatan(String judul) async {
    final base = await _folderDasar();
    final dir = Directory(p.join(base.path, 'ekspor'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final kini = DateTime.now();
    final nama =
        '${_namaBerkasAman(judul)}_${kini.year}${_dua(kini.month)}${_dua(kini.day)}_'
        '${_dua(kini.hour)}${_dua(kini.minute)}${_dua(kini.second)}.txt';
    return p.join(dir.path, nama);
  }

  /// Menghasilkan path file ekspor unik di `<app_documents>/ekspor/`.
  Future<String> _lokasiEkspor() async {
    final base = await _folderDasar();
    final dir = Directory(p.join(base.path, 'ekspor'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final kini = DateTime.now();
    final nama =
        'syllabind_${kini.year}${_dua(kini.month)}${_dua(kini.day)}_'
        '${_dua(kini.hour)}${_dua(kini.minute)}${_dua(kini.second)}.txt';
    return p.join(dir.path, nama);
  }

  /// Format angka 2 digit (padding leading zero).
  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// Format tanggal: DD-MM-YYYY.
  static String _tanggal(DateTime d) => '${_dua(d.day)}-${_dua(d.month)}-${d.year}';

  /// Format jam: HH:MM (24 jam).
  static String _jam(DateTime d) => '${_dua(d.hour)}:${_dua(d.minute)}';
}