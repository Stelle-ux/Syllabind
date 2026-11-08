import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tanggal.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';
import 'package:syllabind/tools/dialog_mapel.dart';

/// Dialog isian teks serbaguna (judul / isi / opsional tenggat / warna / lampiran).
///
/// Digunakan untuk: tambah/ubah Mapel, Materi, Tugas — satu dialog untuk semua.
Future<Map<String, Object?>?> tanyaTeks(
  BuildContext context, {
  required String judul,
  String? labelJudul,
  String? nilaiJudul,
  String? labelIsi,
  String? nilaiIsi,
  bool banyakBaris = false,
  bool denganTenggat = false,
  bool isiWajib = true,
  bool denganLampiran = false,
  bool denganWarna = false,
  String? warnaAwal,
  DateTime? tenggatAwal,
}) async {
  final kJudul = TextEditingController(text: nilaiJudul ?? '');
  final kIsi = TextEditingController(text: nilaiIsi ?? '');
  final formKey = GlobalKey<FormState>();

  DateTime? tenggat = tenggatAwal;
  String? warna = warnaAwal;
  File? lampiran;
  String? lampiranTipe;

  final hasil = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: Text(judul),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (labelJudul != null)
                  TextFormField(
                    controller: kJudul,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: labelJudul),
                    validator: isiWajib
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? t('k_tidak_kosong')
                            : null
                        : null,
                  ),
                if (labelIsi != null) ...[
                  const SizedBox(height: Jarak.j12),
                  TextFormField(
                    controller: kIsi,
                    maxLines: banyakBaris ? 8 : 5,
                    minLines: banyakBaris ? 4 : 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: labelIsi),
                  ),
                ],
                if (denganTenggat) ...[
                  const SizedBox(height: Jarak.j14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final sekarang = DateTime.now();
                      final tgl = await showDatePicker(
                        context: ctx,
                        initialDate: tenggat ?? sekarang,
                        firstDate: DateTime(sekarang.year - 1),
                        lastDate: DateTime(sekarang.year + 5),
                      );
                      if (tgl == null) return;
                      setDialog(() => tenggat = tgl);
                    },
                    icon: const Icon(Icons.event, size: Ikon.sm),
                    label: Text(
                      tenggat == null
                          ? t('k_pilih_tenggat')
                          : tp('k_tenggat', {'tgl': tanggalPendek(tenggat!)}),
                    ),
                  ),
                  if (tenggat != null)
                    TextButton(
                      onPressed: () => setDialog(() => tenggat = null),
                      child: Text(t('k_hapus_tenggat')),
                    ),
                ],
                if (denganWarna) ...[
                  const SizedBox(height: Jarak.j14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t('k_warna'),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: Jarak.j8),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (final hex in TemaApp.paletMapel)
                        BulatWarna(
                          hex: hex,
                          terpilih: warna == hex,
                          onTap: () => setDialog(() => warna = hex),
                        ),
                    ],
                  ),
                  if (warna != null) ...[
                    const SizedBox(height: Jarak.j6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setDialog(() => warna = null),
                        icon: const Icon(Icons.format_color_reset, size: Ikon.sm),
                        label: Text(t('k_pakai_tema')),
                      ),
                    ),
                  ],
                ],
                if (denganLampiran) ...[
                  const SizedBox(height: Jarak.j14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t('k_lampiran_opsional'),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: Jarak.j6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pilih = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                            );
                            if (pilih == null) return;
                            setDialog(() {
                              lampiran = File(pilih.path);
                              lampiranTipe = Lampiran.tipeGambar;
                            });
                          },
                          icon: const Icon(Icons.image_outlined, size: Ikon.sm),
                          label: Text(t('dm_tambah_gambar')),
                        ),
                      ),
                      const SizedBox(width: Jarak.j8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final hasil = await FilePicker.platform.pickFiles();
                            final path = hasil?.files.single.path;
                            if (path == null) return;
                            setDialog(() {
                              lampiran = File(path);
                              lampiranTipe = Lampiran.tipeFile;
                            });
                          },
                          icon: const Icon(Icons.insert_drive_file_outlined,
                              size: 18),
                          label: Text(t('dm_tambah_file')),
                        ),
                      ),
                    ],
                  ),
                  if (lampiran != null) ...[
                    const SizedBox(height: Jarak.j6),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: Ikon.sm),
                        const SizedBox(width: Jarak.j6),
                        Expanded(
                          child: Text(
                            lampiran!.path.split(Platform.pathSeparator).last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setDialog(() {
                            lampiran = null;
                            lampiranTipe = null;
                          }),
                          child: Text(t('batal')),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('batal')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(t('simpan')),
          ),
        ],
      ),
    ),
  );

  if (hasil != true) return null;
  final isi = kIsi.text.trim();
  return {
    'judul': kJudul.text.trim(),
    'isi': isi.isEmpty ? null : isi,
    'tenggat': tenggat,
    'lampiran': lampiran,
    'lampiranTipe': lampiranTipe,
    'warna': warna,
  };
}