import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/dialog_tanya_teks.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Form tambah atau ubah mata pelajaran.
/// dipakai di HalamanAcademic._TabMapel._tambahMapel, HalamanDetailMapel._ubahMapel
Future<Map<String, Object?>?> tanyaMapel(
  BuildContext context, {
  Mapel? awal,
}) {
  return tanyaTeks(
    context,
    judul: awal == null ? t('ak_tambah_mapel') : t('ak_ubah_mapel'),
    labelJudul: t('ak_nama_mapel'),
    nilaiJudul: awal?.nama,
    labelIsi: t('ak_keterangan'),
    nilaiIsi: awal?.deskripsi,
    denganWarna: true,
    warnaAwal: awal?.warna,
  );
}

/// Satu bulatan pilihan warna pada color picker.
/// dipakai di tanyaTeks (color picker wrap)
class BulatWarna extends StatelessWidget {
  final String hex;
  final bool terpilih;
  final VoidCallback onTap;

  const BulatWarna({
    super.key,
    required this.hex,
    required this.terpilih,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final warna = TemaApp.dariHex(hex);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: Ukuran.kotakIkon,
        height: Ukuran.kotakIkon,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: warna,
          border: Border.all(
            color: terpilih ? warna : Colors.transparent,
            width: Ukuran.cincin,
          ),
          boxShadow: terpilih
              ? [
                  BoxShadow(
                    color: warna.withValues(alpha: Opasitas.cincin),
                    blurRadius: 0,
                    spreadRadius: Ukuran.cincin,
                  ),
                ]
              : null,
        ),
        child: terpilih
            ? const Icon(Icons.check, size: Ikon.sm, color: Colors.white)
            : null,
      ),
    );
  }
}