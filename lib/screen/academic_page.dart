import 'dart:io';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';

/// Halaman Academic: 3 tab (Mata Pelajaran, Catatan, Tugas).
/// dipakai di main.dart:RumahAplikasi halaman[1]
class HalamanAcademic extends StatefulWidget {
  const HalamanAcademic({super.key});

  @override
  State<HalamanAcademic> createState() => _HalamanAcademicState();
}

class _HalamanAcademicState extends State<HalamanAcademic> {
  late final MapelService _mapelRepo;

  /// Controller pencarian mapel, disimpan di State agar tidak hilang saat rebuild (IndexedStack).
  /// dipakai di _tabMapel, _saring, dispose
  final _cari = TextEditingController();

  List<Mapel> _mapel = [];
  bool _muat = true;
  bool _modeSeleksi = false;
  final Set<int> _terpilih = {};

  @override
  void initState() {
    super.initState();
    _mapelRepo = MapelServiceImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar mata pelajaran dari database.
  /// dipakai di initState, _tambahMapel, _tabMapel.onTap callback
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await _mapelRepo.semua();
    if (!mounted) return;
    setState(() {
      _mapel = d;
      _muat = false;
    });
  }

  /// Menampilkan dialog tambah mapel lalu simpan ke database.
  /// dipakai di _tabMapel FAB onPressed, Kosong onTombol
  Future<void> _tambahMapel() async {
    final hasil = await tanyaMapel(context);
    if (hasil == null) return;
    await _mapelRepo.tambah(
      Mapel(
        nama: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        warna: hasil['warna'] as String?,
      ),
    );
    await _segarkan();
  }

  /// Build utama: 3 tab (Mata Pelajaran, Catatan, Tugas).
  /// dipakai di main.dart:NavigationBar halaman[1]
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: t('ak_tab_mapel')),
              Tab(text: t('ak_tab_catatan')),
              Tab(text: t('ak_tab_tugas')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_tabMapel(), const _TabCatatan(), const _TabTugas()],
            ),
          ),
        ],
      ),
    );
  }

  /// Menyaring daftar mapel berdasarkan kata kunci [kata].
  /// dipakai di _tabMapel (ValueListenableBuilder), _pilihSemua
  List<Mapel> _saring(String kata) {
    final q = kata.trim().toLowerCase();
    if (q.isEmpty) return _mapel;
    return _mapel
        .where(
          (m) =>
              m.nama.toLowerCase().contains(q) ||
              (m.deskripsi ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  /// Build tab Mata Pelajaran: kotak cari + tombol "Mulai pilih" + daftar kartu.
  /// FAB "Tambah Mata Pelajaran" jadi aksi utama (create).
  /// dipakai di HalamanAcademic.build (TabBarView children[0])
  Widget _tabMapel() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _cari,
      builder: (_, val, __) {
        final tampil = _saring(val.text);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              _KolomCari(
                kendali: _cari,
                petunjuk: t('ak_cari_mapel'),
                onUbah: (_) {},
              ),
              if (!_modeSeleksi && tampil.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Jarak.j14,
                    0,
                    Jarak.j14,
                    Jarak.j4,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _toggleSeleksi,
                      icon: const Icon(Icons.checklist, size: Ikon.sm),
                      label: Text(t('ak_mulai_pilih')),
                    ),
                  ),
                ),
              if (_modeSeleksi)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Jarak.j4),
                  child: _barSeleksi(tampil),
                ),
              Expanded(
                child: _muat
                    ? const Center(child: CircularProgressIndicator())
                    : tampil.isEmpty
                    ? Kosong(
                        ikon: Icons.book_outlined,
                        judul: val.text.isEmpty
                            ? t('ak_kosong_mapel')
                            : t('ak_tidak_ditemukan'),
                        pesan: val.text.isEmpty
                            ? t('ak_kosong_mapel_pesan')
                            : t('ak_coba_kata'),
                        labelTombol: val.text.isEmpty
                            ? t('ak_mapel_fab')
                            : null,
                        onTombol: val.text.isEmpty ? _tambahMapel : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _segarkan,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            Jarak.j14,
                            Jarak.j10,
                            Jarak.j14,
                            Ukuran.bebasFAB +
                                MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          itemCount: tampil.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: Jarak.j10),
                          itemBuilder: (_, i) {
                            final m = tampil[i];
                            final sudahDipilih = _terpilih.contains(m.id);
                            return KartuMapel(
                              nama: m.nama,
                              deskripsi: m.deskripsi,
                              warnaHex: m.warna,
                              jumlahMateri: m.jumlahMateri,
                              jumlahTugas: m.jumlahTugas,
                              terpilih: _modeSeleksi ? sudahDipilih : null,
                              onDipilih: _modeSeleksi
                                  ? (v) => _pilih(m.id!, v ?? false)
                                  : null,
                              onTap: _modeSeleksi
                                  ? () => _pilih(m.id!, !sudahDipilih)
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              HalamanDetailMapel(mapel: m),
                                        ),
                                      );
                                      await _segarkan();
                                    },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: tampil.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: _tambahMapel,
                  icon: const Icon(Icons.add),
                  label: Text(t('ak_tambah_mapel')),
                ),
        );
      },
    );
  }

  /// Bar kontrol mode seleksi: jumlah terpilih, pilih semua/batal, tombol hapus.
  /// dipakai di _tabMapel
  Widget _barSeleksi(List<Mapel> tampil) {
    final semuaTerpilih =
        tampil.isNotEmpty &&
        tampil.every((m) => m.id != null && _terpilih.contains(m.id!));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Jarak.j14),
      child: Wrap(
        spacing: Jarak.j8,
        runSpacing: Jarak.j8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tp('ak_terpilih', {'n': '${_terpilih.length}'}),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: semuaTerpilih ? null : _pilihSemua,
                child: Text(t('ak_pilih_semua')),
              ),
              const SizedBox(width: Jarak.j8),
              TextButton(
                onPressed: _batalPilihSemua,
                child: Text(t('ak_batal_pilih')),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _terpilih.isEmpty ? null : _hapusTerpilih,
            icon: const Icon(Icons.delete_outline),
            label: Text(t('ak_hapus_terpilih')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi lalu hapus semua mapel terpilih ke Sampah (soft delete).
  /// dipakai di _barSeleksi (ElevatedButton.icon onPressed)
  Future<void> _hapusTerpilih() async {
    final lanjut = await konfirmasiHitungMundur(
      context,
      judul: tp('ak_konfirmasi_hapus_banyak', {'n': '${_terpilih.length}'}),
      rincian: [
        tp('ak_konfirmasi_hapus_banyak_pesan', {'n': '${_terpilih.length}'}),
        t('dm_rincian_catatan'),
        t('dm_rincian_tugas'),
        t('dm_rincian_lampiran'),
      ],
    );
    if (lanjut != true) return;

    final hapus = LayananHapus(
      mapelRepo: MapelServiceImpl(),
      materiRepo: MateriServiceImpl(),
      tugasRepo: TugasServiceImpl(),
      lampiranRepo: LampiranServiceImpl(),
    );
    final jumlah = _terpilih.length;
    for (final id in _terpilih.toList()) {
      await hapus.hapusMapelLunak(id);
    }
    _terpilih.clear();
    setState(() => _modeSeleksi = false);
    await _segarkan();
    if (!mounted) return;
    pesanSukses(
      context,
      tp('ak_berhasil_hapus_banyak', {'n': jumlah.toString()}),
    );
  }

  /// Nyalakan/matikan mode seleksi. Saat dimatikan, kosongkan pilihan.
  /// dipakai di _tabMapel (TextButton onPressed)
  void _toggleSeleksi() {
    setState(() {
      _modeSeleksi = !_modeSeleksi;
      if (!_modeSeleksi) _terpilih.clear();
    });
  }

  /// Tambah atau hapus [id] dari pilihan.
  /// dipakai di _tabMapel (KartuMapel onDipilih, onTap)
  void _pilih(int id, bool dipilih) {
    setState(() {
      if (dipilih) {
        _terpilih.add(id);
      } else {
        _terpilih.remove(id);
      }
    });
  }

  /// Pilih semua mapel yang sedang ditampilkan.
  /// dipakai di _barSeleksi (TextButton onPressed)
  void _pilihSemua() {
    setState(() {
      for (final m in _saring(_cari.text)) {
        if (m.id != null) _terpilih.add(m.id!);
      }
    });
  }

  /// Kosongkan semua pilihan dan keluar mode seleksi.
  /// dipakai di _barSeleksi (TextButton onPressed)
  void _batalPilihSemua() {
    setState(() {
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Kolom cari bersama
// ─────────────────────────────────────────────────────────────

/// Kotak pencarian dengan ikon kaca pembesar + padding dari token.
/// dipakai di _HalamanAcademicState._tabMapel, _TabCatatan.build, _TabTugas.build
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

/// Lembar bawah untuk memilih satu mata pelajaran tujuan saat menambah
/// catatan/tugas langsung dari halaman Academic.
/// dipakai di _TabCatatanState._tambahCatatan, _TabTugasState._tambahTugas
Future<int?> _pilihMapelTujuan(BuildContext context, List<Mapel> daftar) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Jarak.j16,
              0,
              Jarak.j16,
              Jarak.j4,
            ),
            child: Text(
              t('lib_pilih_mapel'),
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Jarak.j16,
              0,
              Jarak.j16,
              Jarak.j8,
            ),
            child: Text(
              t('lib_pilih_mapel_pesan'),
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          for (final m in daftar)
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(m.nama),
              onTap: () => Navigator.pop(ctx, m.id),
            ),
          const SizedBox(height: Jarak.j8),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Tab 2 — Catatan (semua materi lintas mapel)
// ─────────────────────────────────────────────────────────────

/// Tab Catatan: menampilkan semua materi (catatan) lintas semua mapel.
/// Aksi: cari, tambah (pilih mapel), ubah, ekspor, hapus.
/// dipakai di HalamanAcademic.build (TabBarView children[1])
class _TabCatatan extends StatefulWidget {
  const _TabCatatan();

  @override
  State<_TabCatatan> createState() => _TabCatatanState();
}

class _TabCatatanState extends State<_TabCatatan> {
  late final MateriService _materiRepo;
  late final MapelService _mapelRepo;
  late final TugasService _tugasRepo;
  late final LampiranService _lampiranRepo;
  final _kunci = TextEditingController();

  List<Materi> _data = [];
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _materiRepo = MateriServiceImpl();
    _mapelRepo = MapelServiceImpl();
    _tugasRepo = TugasServiceImpl();
    _lampiranRepo = LampiranServiceImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _kunci.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar materi (catatan) dari database.
  /// dipakai di initState, build.onChanged, _tambahCatatan, _ubahCatatan, _hapusCatatan
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final kata = _kunci.text.trim();
    final d = kata.isEmpty
        ? await _materiRepo.semua()
        : await _materiRepo.cariKata(kata);
    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
    });
  }

  /// Pilih mapel lalu isi dialog; simpan catatan baru + lampiran opsional.
  /// dipakai di build (FAB onPressed, Kosong onTombol)
  Future<void> _tambahCatatan() async {
    final daftar = await _mapelRepo.semua();
    if (!mounted) return;
    if (daftar.isEmpty) {
      pesanGagal(context, t('lib_mapel_kosong'));
      return;
    }
    final mapelId = await _pilihMapelTujuan(context, daftar);
    if (mapelId == null || !mounted) return;

    final hasil = await tanyaTeks(
      context,
      judul: t('dm_tambah_catatan'),
      labelJudul: t('dm_judul_materi'),
      labelIsi: t('dm_isi_catatan'),
      banyakBaris: true,
      denganLampiran: true,
    );
    if (hasil == null) return;

    final idBaru = await _materiRepo.tambah(
      Materi(
        mapelId: mapelId,
        judul: hasil['judul']! as String,
        isi: hasil['isi'] as String?,
      ),
    );
    if (hasil['lampiran'] != null) {
      await _lampiranRepo.tambahDariFile(
        materiId: idBaru,
        sumber: hasil['lampiran']! as File,
        tipe: hasil['lampiranTipe']! as String,
      );
    }
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_catatan_tersimpan'));
  }

  /// Ubah judul/isi catatan lewat dialog tanyaTeks.
  /// dipakai di build (ListTile onTap, menu Ubah)
  Future<void> _ubahCatatan(Materi m) async {
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
    final isi = hasil['isi'] as String?;
    await _materiRepo.ubah(
      m.copyWith(
        judul: hasil['judul']! as String,
        isi: isi,
        hapusIsi: isi == null,
      ),
    );
    if (hasil['lampiran'] != null) {
      await _lampiranRepo.tambahDariFile(
        materiId: m.id!,
        sumber: hasil['lampiran']! as File,
        tipe: hasil['lampiranTipe']! as String,
      );
    }
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_catatan_diubah'));
  }

  /// Ekspor satu catatan ke berkas teks.
  /// dipakai di build (menu Ekspor)
  Future<void> _eksporCatatan(Materi m) async {
    final ekspor = LayananEkspor(
      mapelRepo: _mapelRepo,
      materiRepo: _materiRepo,
      tugasRepo: _tugasRepo,
      lampiranRepo: _lampiranRepo,
    );
    try {
      final f = await ekspor.eksporCatatan(
        catatan: m,
        namaMapel: m.namaMapel ?? '',
      );
      if (!mounted) return;
      pesanSukses(context, tp('dm_ekspor_sukses', {'path': f.path}));
    } catch (e) {
      if (!mounted) return;
      pesanGagal(context, tp('dm_ekspor_gagal', {'e': '$e'}));
    }
  }

  /// Hapus permanen satu catatan (setelah konfirmasi).
  /// dipakai di build (menu Hapus)
  Future<void> _hapusCatatan(Materi m) async {
    final ok = await konfirmasi(
      context,
      judul: tp('dm_hapus_catatan', {'judul': m.judul}),
      pesan: t('dm_hapus_catatan_pesan'),
    );
    if (!ok) return;
    final hapus = LayananHapus(
      mapelRepo: _mapelRepo,
      materiRepo: _materiRepo,
      tugasRepo: _tugasRepo,
      lampiranRepo: _lampiranRepo,
    );
    await hapus.hapusPermanenMateri(m.id!);
    await _segarkan();
  }

  /// Build tab Catatan: kotak cari + daftar materi + FAB tambah.
  /// dipakai di HalamanAcademic.build (TabBarView children[1])
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _KolomCari(
            kendali: _kunci,
            petunjuk: t('ak_cari_catatan'),
            onUbah: (_) => _segarkan(),
          ),
          Expanded(
            child: _muat
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                ? Kosong(
                    ikon: Icons.description_outlined,
                    judul: _kunci.text.isEmpty
                        ? t('ak_kosong_catatan')
                        : t('ak_tidak_ditemukan'),
                    pesan: _kunci.text.isEmpty
                        ? t('ak_kosong_catatan_pesan')
                        : t('ak_coba_kata'),
                    labelTombol: _kunci.text.isEmpty
                        ? t('dm_tambah_catatan')
                        : null,
                    onTombol: _kunci.text.isEmpty ? _tambahCatatan : null,
                  )
                : RefreshIndicator(
                    onRefresh: _segarkan,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        Jarak.j14,
                        Jarak.j10,
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
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    m.judul,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                ),
                                if (m.namaMapel != null)
                                  Tanda(
                                    teks: m.namaMapel!,
                                    warna: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: Jarak.j6),
                              child: Text(
                                (m.isi ?? '').trim().isEmpty
                                    ? t('ak_belum_isi')
                                    : m.isi!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'ubah') await _ubahCatatan(m);
                                if (v == 'ekspor') await _eksporCatatan(m);
                                if (v == 'hapus') await _hapusCatatan(m);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'ubah',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: Ikon.sm,
                                      ),
                                      const SizedBox(width: Jarak.j8),
                                      Flexible(child: Text(t('k_ubah'))),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'ekspor',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.download_outlined,
                                        size: Ikon.sm,
                                      ),
                                      const SizedBox(width: Jarak.j8),
                                      Flexible(
                                        child: Text(t('k_ekspor_tooltip')),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'hapus',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete_outline,
                                        size: Ikon.sm,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: Jarak.j8),
                                      Flexible(
                                        child: Text(
                                          t('k_hapus_tooltip'),
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _ubahCatatan(m),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _data.isEmpty && _kunci.text.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _tambahCatatan,
              icon: const Icon(Icons.add),
              label: Text(t('dm_tambah_catatan')),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 3 — Tugas (semua tugas lintas mapel)
// ─────────────────────────────────────────────────────────────

/// Tab Tugas: menampilkan semua tugas lintas semua mapel.
/// Aksi: filter status, tambah (pilih mapel), ubah, hapus, tandai selesai.
/// dipakai di HalamanAcademic.build (TabBarView children[2])
class _TabTugas extends StatefulWidget {
  const _TabTugas();

  @override
  State<_TabTugas> createState() => _TabTugasState();
}

class _TabTugasState extends State<_TabTugas> {
  late final TugasService _repo;
  late final MapelService _mapelRepo;
  late final MateriService _materiRepo;
  late final LampiranService _lampiranRepo;

  List<Tugas> _data = [];
  String? _saring;
  bool _muat = true;

  /// Id tugas yang sedang diproses — mencegah klik ganda saat penyimpanan berjalan.
  /// dipakai di _tandaiSelesai, itemBuilder
  final Set<int> _sedangProses = {};

  /// Controller untuk animasi confetti saat tugas diselesaikan.
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _repo = TugasServiceImpl();
    _mapelRepo = MapelServiceImpl();
    _materiRepo = MateriServiceImpl();
    _lampiranRepo = LampiranServiceImpl();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _segarkan();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar tugas dari database dengan filter status opsional.
  /// dipakai di initState, build.onSelectionChanged, _ubahTugas, _hapusTugas
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await _repo.semua(status: _saring);
    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
    });
  }

  /// Pilih mapel lalu isi dialog; simpan tugas baru (dengan tenggat & kategori opsional).
  /// dipakai di build (FAB onPressed, Kosong onTombol)
  Future<void> _tambahTugas() async {
    final daftar = await _mapelRepo.semua();
    if (!mounted) return;
    if (daftar.isEmpty) {
      pesanGagal(context, t('lib_mapel_kosong'));
      return;
    }
    final mapelId = await _pilihMapelTujuan(context, daftar);
    if (mapelId == null || !mounted) return;

    final hasil = await tanyaTeks(
      context,
      judul: t('dm_tambah_tugas'),
      labelJudul: t('dm_judul_tugas'),
      labelIsi: t('dm_deskripsi_opsional'),
      banyakBaris: true,
      denganTenggat: true,
      denganKategori: true,
    );
    if (hasil == null) return;

    await _repo.tambah(
      Tugas(
        mapelId: mapelId,
        judul: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        tenggat: hasil['tenggat'] as DateTime?,
        kategori: hasil['kategori'] as String?,
      ),
    );
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_tugas_tersimpan'));
  }

  /// Ubah judul/deskripsi/tenggat/kategori tugas lewat dialog tanyaTeks.
  /// dipakai di build (ListTile onTap, menu Ubah)
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
      denganKategori: true,
      kategoriAwal: g.kategori,
    );
    if (hasil == null) return;
    final tenggat = hasil['tenggat'] as DateTime?;
    await _repo.ubah(
      g.copyWith(
        judul: hasil['judul']! as String,
        deskripsi: hasil['isi'] as String?,
        tenggat: tenggat,
        hapusTenggat: tenggat == null,
        kategori: hasil['kategori'] as String?,
      ),
    );
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('dm_tugas_diubah'));
  }

  /// Hapus permanen satu tugas (setelah konfirmasi).
  /// dipakai di build (menu Hapus)
  Future<void> _hapusTugas(Tugas g) async {
    final ok = await konfirmasi(
      context,
      judul: tp('dm_hapus_tugas', {'judul': g.judul}),
      pesan: t('dm_hapus_tugas_pesan'),
    );
    if (!ok) return;
    final hapus = LayananHapus(
      mapelRepo: _mapelRepo,
      materiRepo: _materiRepo,
      tugasRepo: _repo,
      lampiranRepo: _lampiranRepo,
    );
    await hapus.hapusPermanenTugas(g.id!);
    await _segarkan();
  }

  /// Ubah status tugas dari daftar: BELUM → SELESAI, atau sebaliknya.
  /// Segarkan daftar agar filter (Semua/Belum/Selesai) menentukan visibilitas.
  /// Saat ditandai selesai, sediakan "Urungkan" lewat SnackBar.
  /// dipakai di build (Checkbox onChanged)
  Future<void> _tandaiSelesai(Tugas g) async {
    final id = g.id;
    if (id == null || !_sedangProses.add(id)) return;
    final jadiSelesai = !g.selesai;
    try {
      await _repo.ubahStatus(id, jadiSelesai ? 'SELESAI' : 'BELUM');
      if (!mounted) return;
      await _segarkan();
      if (!jadiSelesai) return;
      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tp('home_selesai_pesan', {'judul': g.judul})),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: t('home_urungkan'),
            onPressed: () async {
              await _repo.ubahStatus(id, 'BELUM');
              await _segarkan();
            },
          ),
        ),
      );
    } finally {
      _sedangProses.remove(id);
    }
  }

  /// Build tab Tugas: SegmentedButton filter + daftar tugas + FAB tambah.
  /// dipakai di HalamanAcademic.build (TabBarView children[2])
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Jarak.j14,
                  Jarak.j12,
                  Jarak.j14,
                  Jarak.j4,
                ),
                child: SegmentedButton<String?>(
                  segments: [
                    ButtonSegment(value: null, label: Text(t('ak_semua'))),
                    ButtonSegment(value: 'BELUM', label: Text(t('ak_belum'))),
                    ButtonSegment(value: 'SELESAI', label: Text(t('ak_selesai'))),
                  ],
                  selected: {_saring},
                  onSelectionChanged: (s) {
                    setState(() => _saring = s.first);
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
                        judul: t('ak_tidak_ada_tugas'),
                        pesan: t('ak_tidak_ada_tugas_pesan'),
                        labelTombol: t('dm_tambah_tugas'),
                        onTombol: _tambahTugas,
                      )
                    : RefreshIndicator(
                        onRefresh: _segarkan,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            Jarak.j14,
                            Jarak.j10,
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
                            final diproses =
                                g.id != null && _sedangProses.contains(g.id);

                            // Prioritas badge
                            Widget? prioritasBadge;
                            if (g.prioritas != null) {
                              final prioritas = g.prioritas!;
                              Color warnaPrioritas;
                              String labelPrioritas;
                              switch (prioritas) {
                                case 'tinggi':
                                  warnaPrioritas = skema.error;
                                  labelPrioritas = t('dm_prioritas_tinggi');
                                  break;
                                case 'sedang':
                                  warnaPrioritas = Colors.orange;
                                  labelPrioritas = t('dm_prioritas_sedang');
                                  break;
                                case 'rendah':
                                  warnaPrioritas = Colors.green;
                                  labelPrioritas = t('dm_prioritas_rendah');
                                  break;
                                default:
                                  warnaPrioritas = skema.outline;
                                  labelPrioritas = prioritas;
                              }
                              prioritasBadge = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Jarak.j6,
                                  vertical: Jarak.j2,
                                ),
                                decoration: BoxDecoration(
                                  color: warnaPrioritas.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(Jarak.j4),
                                  border: Border.all(color: warnaPrioritas),
                                ),
                                child: Text(
                                  labelPrioritas,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: warnaPrioritas,
                                  ),
                                ),
                              );
                            }

                            return Card(
                              child: ListTile(
                                leading: Checkbox(
                                  value: selesai,
                                  onChanged: diproses
                                      ? null
                                      : (v) => _tandaiSelesai(g),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                title: Text(
                                  g.judul,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    decoration: selesai
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.namaMapel ?? t('home_tanpa_mapel'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (prioritasBadge != null) ...[
                                      const SizedBox(height: Jarak.j4),
                                      prioritasBadge,
                                    ],
                                  ],
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
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.edit_outlined,
                                                size: Ikon.sm,
                                              ),
                                              const SizedBox(width: Jarak.j8),
                                              Flexible(child: Text(t('k_ubah'))),
                                            ],
                                          ),
                                        ),
                                    PopupMenuItem(
                                      value: 'hapus',
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete_outline,
                                            size: Ikon.sm,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: Jarak.j8),
                                          Flexible(
                                            child: Text(
                                              t('k_hapus_tooltip'),
                                              style: const TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _ubahTugas(g),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            // Confetti animation overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -3.14 / 2, // Upwards
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 30,
                maxBlastForce: 10,
                minBlastForce: 5,
                gravity: 0.3,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.pink,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      floatingActionButton: _data.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _tambahTugas,
              icon: const Icon(Icons.add),
              label: Text(t('dm_tambah_tugas')),
            ),
    );
  }
}
