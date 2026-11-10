import 'package:flutter/material.dart';

import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';

/// Dialog konfirmasi hapus dengan hitung mundur 5 detik.
/// dipakai di HalamanAcademic._hapusMapel, HalamanDetailMapel._hapusMapel
Future<bool> konfirmasiHitungMundur(
  BuildContext context, {
  required String judul,
  required List<String> rincian,
}) async {
  final hasil = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogHitungMundur(judul: judul, rincian: rincian),
  );
  return hasil ?? false;
}

/// Internal stateful dialog untuk hitung mundur 5 detik.
class _DialogHitungMundur extends StatefulWidget {
  final String judul;
  final List<String> rincian;

  const _DialogHitungMundur({required this.judul, required this.rincian});

  @override
  State<_DialogHitungMundur> createState() => _DialogHitungMundurState();
}

class _DialogHitungMundurState extends State<_DialogHitungMundur> {
  int _detik = 5;
  bool _boleh = false;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  /// Menjalankan hitung mundur 5 detik lalu mengaktifkan tombol Hapus.
  Future<void> _mulai() async {
    for (var i = 5; i > 0; i--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _detik = i - 1);
    }
    if (!mounted) return;
    setState(() => _boleh = true);
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.judul),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('k_yang_ikut')),
          const SizedBox(height: Jarak.j8),
          for (final r in widget.rincian)
            Padding(
              padding: const EdgeInsets.only(bottom: Jarak.j2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      r,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Jarak.j12),
          Container(
            padding: const EdgeInsets.all(Jarak.j10),
            decoration: BoxDecoration(
              color: skema.errorContainer.withValues(alpha: Opasitas.peringatan),
              borderRadius: BorderRadius.circular(Sudut.r10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: Ikon.sm, color: skema.onErrorContainer),
                const SizedBox(width: Jarak.j8),
                Expanded(
                  child: Text(
                    t('k_bisa_dipulihkan'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t('batal')),
        ),
        FilledButton(
          onPressed: _boleh ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: skema.error,
            foregroundColor: skema.onError,
          ),
          child: Text(
            _boleh ? t('hapus') : tp('k_tunggu', {'n': '$_detik'}),
          ),
        ),
      ],
    );
  }
}