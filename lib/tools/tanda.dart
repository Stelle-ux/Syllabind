import 'package:flutter/material.dart';

import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Tanda status kecil (mis. "Lewat tenggat", "Selesai").
/// dipakai di HalamanHome._buildTugasItem, HalamanDetailMapel._TabTugasMapel._buildItem
class Tanda extends StatelessWidget {
  final String teks;
  final Color warna;

  const Tanda({super.key, required this.teks, required this.warna});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Jarak.j8, vertical: Jarak.j2),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: Opasitas.lembut),
        borderRadius: BorderRadius.circular(Sudut.r20),
      ),
      child: Text(
        teks,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warna,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}