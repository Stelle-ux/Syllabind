import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';

/// Halaman Detail Mapel (pembelajaran per mata pelajaran).
///
/// Di atas ada 2 tab: **[Catatan | Tugas]** (SPESIFIKASI-FINAL.md §5).
/// Lampiran tidak punya tab sendiri: ia menempel pada catatan dan dibuka
/// lewat ikon [Icons.attach_file] di kartu catatan.
///
/// Mengikuti `syllabind-wireframe/ukom_mobile_layout_wireframe.drawio` layar 4.
///
/// Setiap tab mengelola state & repo sendiri. Tab Catatan punya FAB tambah,
/// Tab Tugas punya FAB tambah. Menu AppBar memuat **Ubah** dan **Hapus**
/// mata pelajaran.
///
/// Seluruh teks via [t]/[tp]; tidak ada hardcode bahasa.
class HalamanDetailMapel extends StatefulWidget {
  final Mapel mapel;

  const HalamanDetailMapel({super.key, required this.mapel});

  @override
  State<HalamanDetailMapel> createState() => _HalamanDetailMapelState();
}

class _HalamanDetailMapelState extends State<HalamanDetailMapel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// Salinan mapel yang bisa diperbarui setelah "Ubah" di menu AppBar.
  ///
  /// [Mapel] bersifat immutable, jadi perubahan disimpan di sini lalu state
  /// dibangun ulang — bukan dengan mengubah field milik widget.
  late Mapel _mapel = widget.mapel;

  late final MapelRepository _mapelRepo;
  late final MateriRepository _materiRepo;
  late final TugasRepository _tugasRepo;
  late final LampiranRepository _lampiranRepo;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _mapelRepo = MapelRepositoryImpl();
    _materiRepo = MateriRepositoryImpl();
    _tugasRepo = TugasRepositoryImpl();
    _lampiranRepo = LampiranRepositoryImpl();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Mengubah nama/deskripsi/warna mapel lewat dialog yang sama dengan
  /// halaman Academic.
  Future<void> _ubahMapel() async {
    final hasil = await tanyaMapel(context, awal: _mapel);
    if (hasil == null) return;
    await _mapelRepo.ubah(
      _mapel.copyWith(
        nama: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        warna: hasil['warna'] as String?,
        hapusTandaWarna: hasil['warna'] == null,
      ),
    );
    // Ambil ulang dari DB supaya yang ditampilkan benar-benar nilai tersimpan.
    final baru = await _mapelRepo.cari(widget.mapel.id!);
    if (!mounted) return;
    if (baru != null) setState(() => _mapel = baru);
    pesanSukses(context, t('ak_mapel_tersimpan'));
  }

  /// Memindahkan mapel ke Sampah (soft delete) setelah hitung mundur 5 detik.
  Future<void> _hapusMapel() async {
    final ok = await konfirmasiHitungMundur(
      context,
      judul: tp('dm_hapus_mapel_judul', {'judul': _mapel.nama}),
      rincian: [
        t('dm_rincian_catatan'),
        t('dm_rincian_tugas'),
        t('dm_rincian_lampiran'),
      ],
    );
    if (!ok) return;

    final hapus = LayananHapus(
      mapelRepo: _mapelRepo,
      materiRepo: _materiRepo,
      lampiranRepo: _lampiranRepo,
    );
    await hapus.hapusMapelLunak(_mapel.id!);
    if (!mounted) return;
    // Kembali ke daftar mapel; SnackBar ditampilkan lewat messenger yang
    // ditangkap SEBELUM pop (context halaman ini sudah tidak dipakai).
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(tp('dm_dipindah_sampah', {'nama': _mapel.nama})),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final warna = TemaApp.dariHex(_mapel.warna, cadangan: skema.primary);

    return Scaffold(
      appBar: AppBar(
        title: Text(_mapel.nama),
        backgroundColor: warna,
        foregroundColor: Colors.white,
        actions: [
          // Popup ini sengaja SATU-SATUNYA di AppBar; popup per-item ada di
          // dalam daftar tiap tab.
          PopupMenuButton<String>(
            tooltip: '',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              if (v == 'ubah') await _ubahMapel();
              if (v == 'hapus') await _hapusMapel();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'ubah',
                child: Row(children: [
                  const Icon(Icons.edit_outlined, size: Ikon.sm),
                  const SizedBox(width: Jarak.j8),
                  Flexible(child: Text(t('ak_ubah_mapel'))),
                ]),
              ),
              PopupMenuItem(
                value: 'hapus',
                child: Row(children: [
                  const Icon(Icons.delete_outline,
                      size: Ikon.sm, color: Colors.red),
                  const SizedBox(width: Jarak.j8),
                  Flexible(
                    child: Text(t('dm_hapus_mapel'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: t('dm_tab_catatan')),
            Tab(text: t('dm_tab_tugas')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabMateri(
            mapel: _mapel,
            materiRepo: _materiRepo,
            tugasRepo: _tugasRepo,
            lampiranRepo: _lampiranRepo,
            mapelRepo: _mapelRepo,
          ),
          _TabTugasMapel(
            mapel: _mapel,
            tugasRepo: _tugasRepo,
            mapelRepo: _mapelRepo,
            materiRepo: _materiRepo,
            lampiranRepo: _lampiranRepo,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 1 — Catatan (Materi) di dalam satu mapel
// ─────────────────────────────────────────────────────────────

/// Tab Catatan: daftar catatan/materi untuk satu mapel.
/// FAB → dialog tambah catatan ([tanyaTeks]).
class _TabMateri extends StatefulWidget {
  final Mapel mapel;
  final MateriRepository materiRepo;
  final TugasRepository tugasRepo;
  final LampiranRepository lampiranRepo;
  final MapelRepository mapelRepo;

  const _TabMateri({
    required this.mapel,
    required this.materiRepo,
    required this.tugasRepo,
    required this.lampiranRepo,
    required this.mapelRepo,
  });

  @override
  State<_TabMateri> createState() => _TabMateriState();
}

class _TabMateriState extends State<_TabMateri> {
  final _cari = TextEditingController();
  List<Materi> _data = [];
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _segarkan();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final kata = _cari.text.trim();
    final d = kata.isEmpty
        ? await widget.materiRepo.perMapel(widget.mapel.id!,
            termasukSampah: false)
        : await widget.materiRepo.cariKata(kata);
    if (!mounted) return;
    setState(() {
      _data = d.where((m) => m.mapelId == widget.mapel.id).toList();
      _muat = false;
    });
  }

  Future<void> _tambahMateri() async {
    final hasil = await tanyaTeks(
      context,
      judul: t('dm_tambah_catatan'),
      labelJudul: t('dm_judul_materi'),
      labelIsi: t('dm_isi_catatan'),
      banyakBaris: true,
      denganLampiran: true,
    );
    if (hasil == null) return;
    final idBaru = await widget.materiRepo.tambah(
      Materi(
        mapelId: widget.mapel.id!,
        judul: hasil['judul']! as String,
        isi: hasil['isi'] as String?,
      ),
    );
    if (hasil['lampiran'] != null) {
      await widget.lampiranRepo.tambahDariFile(
        materiId: idBaru,
        sumber: hasil['lampiran']! as File,
        tipe: hasil['lampiranTipe']! as String,
      );
    }
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_catatan_tersimpan'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _muat
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _KolomCari(
                  kendali: _cari,
                  petunjuk: t('dm_cari_catatan'),
                  onUbah: (_) => _segarkan(),
                ),
                Expanded(
                  child: _data.isEmpty
                      ? Kosong(
                          ikon: Icons.description_outlined,
                          judul: t('dm_kosong_catatan'),
                          pesan: t('dm_kosong_catatan_pesan'),
                          labelTombol: t('dm_tambah_catatan'),
                          onTombol: _tambahMateri,
                        )
                      : RefreshIndicator(
                          onRefresh: _segarkan,
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              Jarak.j14,
                              Jarak.j4,
                              Jarak.j14,
                              Ukuran.bebasFAB +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            itemCount: _data.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: Jarak.j10),
                            itemBuilder: (_, i) {
                              final m = _data[i];
                              return Card(
                                child: ListTile(
                                  leading: Container(
                                    width: Ukuran.kotakIkon,
                                    height: Ukuran.kotakIkon,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: Opasitas.lembut),
                                      borderRadius:
                                          BorderRadius.circular(Sudut.r10),
                                    ),
                                    child: Icon(
                                      Icons.article_outlined,
                                      size: Ukuran.kotakIkon / 2,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  title: Text(
                                    m.judul,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    (m.isi ?? '').trim().isEmpty
                                        ? t('ak_belum_isi')
                                        : m.isi!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Lampiran menempel pada catatan, jadi
                                      // pintu masuknya di sini — bukan tab
                                      // tersendiri.
                                      IconButton(
                                        tooltip: t('k_lampiran_tooltip'),
                                        icon: const Icon(Icons.attach_file,
                                            size: Ikon.sm),
                                        onPressed: () =>
                                            _lempaLampiran(context, m),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          if (v == 'ubah') {
                                            await _editMateri(m);
                                          }
                                          if (v == 'ekspor') {
                                            await _eksporMateri(m);
                                          }
                                          if (v == 'hapus') {
                                            await _hapusMateri(m);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'ubah',
                                            child: Row(children: [
                                              const Icon(Icons.edit_outlined,
                                                  size: Ikon.sm),
                                              const SizedBox(width: Jarak.j8),
                                              Flexible(child: Text(t('k_ubah'))),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'ekspor',
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.download_outlined,
                                                  size: Ikon.sm),
                                              const SizedBox(width: Jarak.j8),
                                              Flexible(
                                                  child:
                                                      Text(t('k_ekspor_tooltip')),
                                                  ),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'hapus',
                                            child: Row(children: [
                                              const Icon(Icons.delete_outline,
                                                  size: Ikon.sm,
                                                  color: Colors.red),
                                              const SizedBox(width: Jarak.j8),
                                              Flexible(
                                                child: Text(t('k_hapus_tooltip'),
                                                    style: const TextStyle(
                                                        color: Colors.red)),
                                              ),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await _editMateri(m);
                                    await _segarkan();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahMateri,
        icon: const Icon(Icons.add),
        label: Text(t('dm_tambah_catatan')),
      ),
    );
  }

  /// Lembar bawah berisi lampiran milik satu catatan.
  Future<void> _lempaLampiran(BuildContext context, Materi m) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => _LembarLampiran(
        materi: m,
        lampiranRepo: widget.lampiranRepo,
      ),
    );
    if (!mounted) return;
    await _segarkan();
  }

  Future<void> _editMateri(Materi m) async {
    final hasil = await tanyaTeks(
      context,
      judul: t('dm_ubah_catatan'),
      labelJudul: t('dm_judul_materi'),
      nilaiJudul: m.judul,
      labelIsi: t('dm_isi_catatan'),
      nilaiIsi: m.isi,
      banyakBaris: true,
      denganLampiran: true,
    );
    if (hasil == null) return;
    await widget.materiRepo.ubah(
      Materi(
        id: m.id,
        mapelId: m.mapelId,
        judul: hasil['judul']! as String,
        isi: hasil['isi'] as String?,
      ),
    );
    if (hasil['lampiran'] != null) {
      await widget.lampiranRepo.tambahDariFile(
        materiId: m.id!,
        sumber: hasil['lampiran']! as File,
        tipe: hasil['lampiranTipe']! as String,
      );
    }
    if (!mounted) return;
    pesanSukses(context, t('dm_catatan_diubah'));
  }

  Future<void> _eksporMateri(Materi m) async {
    final ekspor = LayananEkspor(
      mapelRepo: widget.mapelRepo,
      materiRepo: widget.materiRepo,
      tugasRepo: widget.tugasRepo,
      lampiranRepo: widget.lampiranRepo,
    );
    try {
      final f = await ekspor.eksporCatatan(
        catatan: m,
        namaMapel: widget.mapel.nama,
      );
      if (!mounted) return;
      pesanSukses(context, tp('dm_ekspor_sukses', {'path': f.path}));
    } catch (e) {
      if (!mounted) return;
      pesanGagal(context, tp('dm_ekspor_gagal', {'e': '$e'}));
    }
  }

  Future<void> _hapusMateri(Materi m) async {
    final ok = await konfirmasi(
      context,
      judul: tp('dm_hapus_catatan', {'judul': m.judul}),
      pesan: t('dm_hapus_catatan_pesan'),
    );
    if (!ok) return;
    final hapus = LayananHapus(
      mapelRepo: widget.mapelRepo,
      materiRepo: widget.materiRepo,
      lampiranRepo: widget.lampiranRepo,
    );
    await hapus.hapusPermanenMateri(m.id!);
    await _segarkan();
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 2 — Tugas di dalam satu mapel
// ─────────────────────────────────────────────────────────────

/// Tab Tugas: daftar tugas untuk satu mapel.
/// FAB → dialog tambah tugas ([tanyaTeks] dengan denganTenggat=true).
class _TabTugasMapel extends StatefulWidget {
  final Mapel mapel;
  final TugasRepository tugasRepo;
  final MapelRepository mapelRepo;
  final MateriRepository materiRepo;
  final LampiranRepository lampiranRepo;

  const _TabTugasMapel({
    required this.mapel,
    required this.tugasRepo,
    required this.mapelRepo,
    required this.materiRepo,
    required this.lampiranRepo,
  });

  @override
  State<_TabTugasMapel> createState() => _TabTugasMapelState();
}

class _TabTugasMapelState extends State<_TabTugasMapel> {
  final _cari = TextEditingController();
  List<Tugas> _data = [];
  String? _filter;
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _segarkan();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final kata = _cari.text.trim();
    final semua = await widget.tugasRepo.perMapel(widget.mapel.id!,
        termasukSampah: false);
    var d = kata.isEmpty
        ? semua
        : semua
            .where((t) =>
                t.judul.toLowerCase().contains(kata) ||
                (t.deskripsi ?? '').toLowerCase().contains(kata))
            .toList();

    if (_filter != null) {
      d = d.where((t) => t.status == _filter).toList();
    }

    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
    });
  }

  Future<void> _tambahTugas() async {
    final hasil = await tanyaTeks(
      context,
      judul: t('dm_tambah_tugas'),
      labelJudul: t('dm_judul_tugas'),
      labelIsi: t('dm_deskripsi_opsional'),
      banyakBaris: true,
      denganTenggat: true,
      denganLampiran: true,
    );
    if (hasil == null) return;
    await widget.tugasRepo.tambah(
      Tugas(
        mapelId: widget.mapel.id!,
        judul: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        tenggat: hasil['tenggat'] as DateTime?,
      ),
    );
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_tugas_tersimpan'));
  }

  Future<void> _ubahTugas(Tugas g) async {
    final hasil = await tanyaTeks(
      context,
      judul: t('dm_ubah_tugas'),
      labelJudul: t('dm_judul_tugas'),
      nilaiJudul: g.judul,
      labelIsi: t('dm_deskripsi_opsional'),
      nilaiIsi: g.deskripsi,
      banyakBaris: true,
      denganTenggat: true,
      tenggatAwal: g.tenggat,
      denganLampiran: true,
    );
    if (hasil == null) return;
    await widget.tugasRepo.ubah(
      Tugas(
        id: g.id,
        mapelId: g.mapelId,
        judul: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        tenggat: hasil['tenggat'] as DateTime?,
        status: g.status,
      ),
    );
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_tugas_diubah'));
  }

  Future<void> _hapusTugas(Tugas g) async {
    final ok = await konfirmasi(
      context,
      judul: tp('dm_hapus_tugas', {'judul': g.judul}),
      pesan: t('dm_hapus_tugas_pesan'),
    );
    if (!ok) return;
    final hapus = LayananHapus(
      mapelRepo: widget.mapelRepo,
      materiRepo: widget.materiRepo,
      lampiranRepo: widget.lampiranRepo,
    );
    await hapus.hapusPermanenMateri(g.id!);
    await _segarkan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _KolomCari(
            kendali: _cari,
            petunjuk: t('dm_cari_tugas'),
            onUbah: (_) => _segarkan(),
          ),
          if (_data.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Jarak.j14,
                Jarak.j4,
                Jarak.j14,
                Jarak.j4,
              ),
              child: SegmentedButton<String?>(
                segments: [
                  ButtonSegment(value: null, label: Text(t('ak_semua'))),
                  ButtonSegment(value: 'BELUM', label: Text(t('ak_belum'))),
                  ButtonSegment(value: 'SELESAI', label: Text(t('ak_selesai'))),
                ],
                selected: {_filter},
                onSelectionChanged: (s) {
                  setState(() => _filter = s.first);
                  _segarkan();
                },
              ),
            ),
          Expanded(
            child: _muat
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                    ? Kosong(
                        ikon: Icons.checklist_outlined,
                        judul: t('dm_kosong_tugas'),
                        pesan: t('dm_kosong_tugas_pesan'),
                        labelTombol: t('dm_tambah_tugas'),
                        onTombol: _tambahTugas,
                      )
                    : RefreshIndicator(
                        onRefresh: _segarkan,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            Jarak.j14,
                            Jarak.j4,
                            Jarak.j14,
                            Ukuran.bebasFAB +
                                MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          itemCount: _data.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Jarak.j10),
                          itemBuilder: (_, i) {
                            final g = _data[i];
                            final selesai = g.selesai;
                            final lewat = g.lewatTenggat;
                            final skema = Theme.of(context).colorScheme;

                            return Card(
                              child: ListTile(
                                leading: IconButton(
                                  tooltip: selesai
                                      ? t('dm_tandai_belum')
                                      : t('dm_tandai_selesai'),
                                  icon: Icon(
                                    selesai
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: selesai ? skema.primary : null,
                                  ),
                                  onPressed: () async {
                                    await widget.tugasRepo.ubahStatus(
                                      g.id!,
                                      selesai ? 'BELUM' : 'SELESAI',
                                    );
                                    await _segarkan();
                                  },
                                ),
                                title: Text(
                                  g.judul,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    decoration: selesai
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  g.deskripsi ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tanda(
                                      teks: selesai
                                          ? t('ak_selesai')
                                          : tenggatRelatif(g.tenggat),
                                      warna: selesai
                                          ? skema.outline
                                          : lewat
                                              ? skema.error
                                              : skema.primary,
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'ubah') await _ubahTugas(g);
                                        if (v == 'hapus') await _hapusTugas(g);
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'ubah',
                                          child: Row(children: [
                                            const Icon(Icons.edit_outlined,
                                                size: Ikon.sm),
                                            const SizedBox(width: Jarak.j8),
                                            Flexible(child: Text(t('k_ubah'))),
                                          ]),
                                        ),
                                        PopupMenuItem(
                                          value: 'hapus',
                                          child: Row(children: [
                                            const Icon(Icons.delete_outline,
                                                size: Ikon.sm,
                                                color: Colors.red),
                                            const SizedBox(width: Jarak.j8),
                                            Flexible(child: Text(t('k_hapus_tooltip'),
                                                style: const TextStyle(
                                                    color: Colors.red))),
                                          ]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await _ubahTugas(g);
                                  await _segarkan();
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahTugas,
        icon: const Icon(Icons.add),
        label: Text(t('dm_tambah_tugas')),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lembar bawah — Lampiran milik satu catatan
// ─────────────────────────────────────────────────────────────

/// Daftar lampiran (gambar & file) untuk satu catatan, plus tombol tambah.
///
/// Lampiran selalu menempel pada sebuah catatan ([Lampiran.materiId] NOT NULL),
/// jadi ia dikelola di sini — bukan sebagai tab tingkat mapel.
class _LembarLampiran extends StatefulWidget {
  final Materi materi;
  final LampiranRepository lampiranRepo;

  const _LembarLampiran({
    required this.materi,
    required this.lampiranRepo,
  });

  @override
  State<_LembarLampiran> createState() => _LembarLampiranState();
}

class _LembarLampiranState extends State<_LembarLampiran> {
  List<Lampiran> _data = [];
  bool _muat = true;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _segarkan();
  }

  Future<void> _segarkan() async {
    final d = await widget.lampiranRepo.perMateri(widget.materi.id!);
    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
    });
  }

  /// Menyalin gambar/galeri atau file pilihan ke penyimpanan aplikasi.
  Future<void> _tambah(String tipe) async {
    setState(() => _sibuk = true);
    try {
      final String? path = tipe == Lampiran.tipeGambar
          ? (await ImagePicker().pickImage(source: ImageSource.gallery))?.path
          : (await FilePicker.platform.pickFiles())?.files.single.path;
      if (path == null) return;
      await widget.lampiranRepo.tambahDariFile(
        materiId: widget.materi.id!,
        sumber: File(path),
        tipe: tipe,
      );
      await _segarkan();
      if (!mounted) return;
      pesanSukses(context, t('dm_lampiran_ditambah'));
    } catch (e) {
      if (!mounted) return;
      pesanGagal(context, tp('dm_gagal_lampiran', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _buka(Lampiran l) async {
    final f = File(l.lokasiFile);
    if (!await f.exists()) {
      if (!mounted) return;
      pesanGagal(context, tp('lib_buka_gagal', {'e': l.lokasiFile}));
      return;
    }
    await OpenFilex.open(l.lokasiFile);
  }

  Future<void> _hapus(Lampiran l) async {
    final ok = await konfirmasi(
      context,
      judul: tp('dm_hapus_lampiran_judul', {'nama': l.namaFile}),
      pesan: t('dm_hapus_lampiran_pesan'),
    );
    if (!ok) return;
    await widget.lampiranRepo.hapus(l.id!);
    await _segarkan();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Jarak.j16, Jarak.j14, Jarak.j16, Jarak.j16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('dm_lampiran'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Jarak.j4),
            Text(
              t('dm_lampiran_ket'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Jarak.j14),
            if (_muat)
              const Center(child: CircularProgressIndicator())
            else if (_data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Jarak.j10),
                child: Text(t('dm_belum_lampiran')),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in _data)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          l.gambar
                              ? Icons.image_outlined
                              : Icons.insert_drive_file_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          l.namaFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${l.gambar ? t('lib_gambar') : t('lib_file')}'
                          ' · ${l.ukuranTerbaca}',
                        ),
                        onTap: () => _buka(l),
                        trailing: IconButton(
                          tooltip: t('k_hapus_tooltip'),
                          icon: const Icon(Icons.delete_outline,
                              size: Ikon.sm, color: Colors.red),
                          onPressed: () => _hapus(l),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Jarak.j14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sibuk ? null : () => _tambah(Lampiran.tipeGambar),
                    icon: const Icon(Icons.image_outlined, size: Ikon.sm),
                    label: Text(t('dm_tambah_gambar')),
                  ),
                ),
                const SizedBox(width: Jarak.j8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sibuk ? null : () => _tambah(Lampiran.tipeFile),
                    icon: const Icon(Icons.insert_drive_file_outlined,
                        size: Ikon.sm),
                    label: Text(t('dm_tambah_file')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Kolom cari bersama (duplicate dari academic_page — tetap di sini
// supaya detail_mapel_page.dart self-contained; nanti bisa dipindah
// ke tools kalau dipakai >2 kali).
// ─────────────────────────────────────────────────────────────

class _KolomCari extends StatelessWidget {
  final TextEditingController kendali;
  final String petunjuk;
  final ValueChanged<String> onUbah;

  const _KolomCari({
    required this.kendali,
    required this.petunjuk,
    required this.onUbah,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Jarak.j14,
        Jarak.j12,
        Jarak.j14,
        Jarak.j4,
      ),
      child: TextField(
        controller: kendali,
        decoration: InputDecoration(
          hintText: petunjuk,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: onUbah,
      ),
    );
  }
}
