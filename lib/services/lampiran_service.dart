import 'dart:io';

import 'package:syllabind/function/lampiran.dart';

/// Contract untuk service Lampiran (Attachments).
abstract class LampiranService {
  Future<int> tambahDariFile({
    required int materiId,
    required File sumber,
    required String tipe, // 'GAMBAR' | 'FILE'
  });
  Future<int> tambahKeMapel({
    required int mapelId,
    required File sumber,
    required String tipe,
  });
  Future<List<Lampiran>> perMateri(int materiId);
  Future<List<Lampiran>> semua({String? tipe});
  Future<Lampiran?> cari(int id);
  Future<void> hapus(int id);
  Future<int> ubahNama(int id, String namaBaru);
  Future<int> hapusFileMilikMapel(int mapelId);
  Future<int> hapusFileMilikMateri(int materiId);
  Future<int> totalUkuran();
  Future<Map<String, int>> jumlahPerTipe();
}