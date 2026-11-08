import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Kartu Mapel pada daftar Academic.
///
/// Menampilkan: warna penanda, nama, deskripsi (opsional), jumlah materi & tugas,
/// tombol hapus (opsional), atau chevron navigasi.
class KartuMapel extends StatelessWidget {
  final String nama;
  final String? deskripsi;
  final String? warnaHex;
  final int jumlahMateri;
  final int jumlahTugas;
  final VoidCallback onTap;
  final VoidCallback? onHapus;
  final bool? terpilih;
  final ValueChanged<bool?>? onDipilih;

  const KartuMapel({
    super.key,
    required this.nama,
    this.deskripsi,
    this.warnaHex,
    this.jumlahMateri = 0,
    this.jumlahTugas = 0,
    required this.onTap,
    this.onHapus,
    this.terpilih,
    this.onDipilih,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = warnaHex == null
        ? skema.primary
        : Color(
            int.parse('FF${warnaHex!.replaceAll('#', '')}', radix: 16),
          );

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Sudut.r14),
        child: Padding(
          padding: const EdgeInsets.all(Jarak.j14),
          child: Row(
            children: [
              // Penanda warna mapel.
              Container(
                width: Ukuran.kotakMapel,
                height: Ukuran.kotakMapel,
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: Opasitas.lembut),
                  borderRadius: BorderRadius.circular(Sudut.r10),
                ),
                child: Icon(Icons.menu_book, color: warna, size: Ikon.md),
              ),
              const SizedBox(width: Jarak.j12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (deskripsi != null && deskripsi!.trim().isNotEmpty) ...[
                      const SizedBox(height: Jarak.j2),
                      Text(
                        deskripsi!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: skema.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: Jarak.j6),
                    Row(
                      children: [
                        _chip(context, Icons.description_outlined,
                            tp('k_n_materi', {'n': '$jumlahMateri'})),
                        const SizedBox(width: Jarak.j12),
                        _chip(context, Icons.checklist_outlined,
                            tp('k_n_tugas', {'n': '$jumlahTugas'})),
                      ],
                    ),
                  ],
                ),
              ),
              if (terpilih != null)
                Checkbox(
                  value: terpilih,
                  onChanged: onDipilih,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              else if (onHapus != null)
                IconButton(
                  tooltip: t('k_hapus_tooltip'),
                  icon: Icon(Icons.delete_outline, color: skema.error),
                  onPressed: onHapus,
                )
              else
                Icon(Icons.chevron_right, color: skema.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun chip kecil (ikon + teks) untuk statistik materi/tugas.
  Widget _chip(BuildContext c, IconData ikon, String teks) {
    final skema = Theme.of(c).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: Ikon.xs, color: skema.onSurfaceVariant),
        const SizedBox(width: Jarak.j4),
        Text(
          teks,
          style: Theme.of(c).textTheme.labelSmall?.copyWith(
                color: skema.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}