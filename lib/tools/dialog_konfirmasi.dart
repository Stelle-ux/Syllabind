import 'package:flutter/material.dart';

import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Dialog konfirmasi sederhana (Ya/Tidak) untuk hapus item non-mapel.
///
/// Digunakan untuk: hapus materi, hapus tugas, hapus lampiran, kosongkan sampah.
/// Beda dengan [konfirmasiHitungMundur] yang dipakai untuk hapus Mapel (karena cascade).
Future<bool> konfirmasi(
  BuildContext context, {
  required String judul,
  required String pesan,
  String? labelYa,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final skema = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: Text(judul),
        content: Text(pesan),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: skema.error,
              foregroundColor: skema.onError,
            ),
            child: Text(labelYa ?? t('hapus')),
          ),
        ],
      );
    },
  );
  return hasil ?? false;
}