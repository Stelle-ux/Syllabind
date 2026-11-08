import 'package:flutter/material.dart';

import 'package:syllabind/tools/bahasa.dart';

/// Menampilkan SnackBar sukses (hijau/primary).
void pesanSukses(BuildContext context, String teks) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(teks), behavior: SnackBarBehavior.floating),
  );
}

/// Menampilkan SnackBar gagal (merah/error).
void pesanGagal(BuildContext context, String teks) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(teks),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}