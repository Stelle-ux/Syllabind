import 'package:flutter/material.dart';

import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Keadaan kosong yang seragam (empty state).
/// dipakai di HalamanAcademic._TabCatatan, HalamanAcademic._TabTugas, HalamanDetailMapel._TabMateri, HalamanDetailMapel._TabTugasMapel, HalamanPengaturan._LembarSampah, HalamanPenyimpanan
class Kosong extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String pesan;
  final String? labelTombol;
  final VoidCallback? onTombol;

  const Kosong({
    super.key,
    required this.ikon,
    required this.judul,
    required this.pesan,
    this.labelTombol,
    this.onTombol,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, batas) {
        final sempit = batas.maxHeight.isFinite && batas.maxHeight < 260;
        final pad = sempit ? Jarak.j16 : Jarak.j32;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: batas.maxHeight.isFinite ? batas.maxHeight : 0,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ikon, size: Ikon.kosong, color: skema.onSurfaceVariant),
                    const SizedBox(height: Jarak.j14),
                    Text(
                      judul,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Jarak.j6),
                    Text(
                      pesan,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: skema.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    if (labelTombol != null) ...[
                      const SizedBox(height: Jarak.j18),
                      FilledButton.tonal(
                        onPressed: onTombol,
                        child: Text(labelTombol!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}