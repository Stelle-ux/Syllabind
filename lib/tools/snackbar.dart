import 'package:flutter/material.dart';

import 'package:syllabind/tools/bahasa.dart';

/// Menampilkan SnackBar sukses (hijau/primary).
/// dipakai di HalamanAcademic._TabMapel._tambahMapel, HalamanAcademic._TabMapel._ubahMapel, HalamanDetailMapel._TabMateri._tambahMateri, HalamanDetailMapel._TabMateri._ubahMateri, HalamanDetailMapel._TabTugasMapel._tambahTugas, HalamanDetailMapel._TabTugasMapel._ubahTugas, HalamanDetailMapel._LembarLampiran._tambahLampiran, HalamanDetailMapel._LembarLampiran._ubahNamaLampiran, HalamanDetailMapel._TabMateri._eksporCatatan, HalamanPenyimpanan._tambahLampiran, HalamanPenyimpanan._ubahNamaLampiran, HalamanPengaturan._gantiTema, HalamanPengaturan._gantiBahasa, HalamanPengaturan._gantiAksen, HalamanPengaturan._LembarSampah._hapusPermanen, HalamanPengaturan._LembarSampah._bersihkanOtomatis, HalamanPengaturan._eksporSemua
void pesanSukses(BuildContext context, String teks) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(teks), behavior: SnackBarBehavior.floating),
  );
}

/// Menampilkan SnackBar gagal (merah/error).
/// dipakai di HalamanDetailMapel._LembarLampiran._tambahLampiran, HalamanDetailMapel._TabMateri._eksporCatatan, HalamanPenyimpanan._tambahLampiran, HalamanPengaturan._eksporSemua
void pesanGagal(BuildContext context, String teks) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(teks),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}