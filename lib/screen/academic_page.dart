import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';

/// Halaman 2 — Academic.
///
/// Di atas ada slider 3 tab: **[Mata Pelajaran | Catatan | Tugas]**.
/// Tab pertama (Mata Pelajaran) adalah tab yang terbuka saat pertama kali
/// pengguna pindah ke halaman ini. Kartu mapel bisa ditekan → Detail Mapel.
///
/// Tata letak mengikuti `syllabind-wireframe/ukom_mobile_layout_wireframe.drawio`
/// layar 2 & 3: kolom cari di atas daftar, kartu mapel berisi warna + nama +
/// keterangan + jumlah materi/tugas.
///
/// Seluruh teks diambil dari kamus [t]/[tp] — tidak ada literal berbahasa
/// Indonesia yang tertinggal di berkas ini, supaya mode Inggris benar-benar
/// Inggris di semua layar.
class HalamanAcademic extends StatefulWidget {
  const HalamanAcademic({super.key});

  @override
  State<HalamanAcademic> createState() => _HalamanAcademicState();
}

class _HalamanAcademicState extends State<HalamanAcademic> {
  late final MapelRepository _mapelRepo;

  /// Kendali kotak cari mapel. Disimpan di State supaya isinya tidak hilang
  /// setiap kali halaman dibangun ulang (`IndexedStack` menahan state tab).
  final _cari = TextEditingController();

  List<Mapel> _mapel = [];
  bool _muat = true;
  bool _modeSeleksi = false;
  final Set<int> _terpilih = {};

  @override
  void initState() {
    super.initState();
    _mapelRepo = MapelRepositoryImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar mata pelajaran dari database.
  ///
  /// Dipanggil saat initState, setelah tambah/edit/hapus mapel, dan
  /// setelah kembali dari HalamanDetailMapel.
  ///
  /// **Reused in:** [initState], [_tambahMapel], [_tabMapel.onTap callback]
  /// **Calls:** [MapelRepository.semua], [setState]
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await _mapelRepo.semua();
    if (!mounted) return;
    setState(() {
      _mapel = d;
      _muat = false;
    });
  }

  /// Menampilkan dialog tambah mapel lalu menyimpan ke database.
  ///
  /// Menggunakan [tanyaMapel] untuk input, lalu [MapelRepository.tambah].
  /// Setelah berhasil, memanggil [_segarkan] untuk refresh UI.
  ///
  /// **Reused in:** [_tabMapel FAB onPressed], [Kosong onTombol]
  /// **Calls:** [tanyaMapel], [MapelRepository.tambah], [_segarkan]
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

  /// Build utama halaman Academic dengan 3 tab: Mata Pelajaran, Catatan, Tugas.
  ///
  /// Tab 0 (Mata Pelajaran) adalah default. Setiap tab adalah widget stateful
  /// terpisah (_TabCatatan, _TabTugas) yang mengelola state & repo sendiri.
  ///
  /// **Reused in:** (entry point from NavigationBar in main.dart)
  /// **Calls:** [_tabMapel], [_TabCatatan], [_TabTugas], [DefaultTabController], [TabBar], [TabBarView], [t]
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      // initialIndex 0 = Mata Pelajaran → tab pertama yang dibuka.
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
              children: [
                _tabMapel(),
                const _TabCatatan(),
                const _TabTugas(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Mata Pelajaran ─────────────────────────────────
  /// Membangun konten tab Mata Pelajaran.
  ///
  /// Menampilkan: loading indicator, atau Kosong (jika belum ada mapel),
  /// atau ListView KartuMapel dengan RefreshIndicator.
  /// FAB hanya muncul di tab ini (letak di dalam Scaffold tab).
  ///
  /// **Reused in:** [build] (TabBarView children[0])
  /// **Calls:** [_KolomCari], [Kosong], [KartuMapel], [RefreshIndicator], [ListView.separated], [Navigator.push], [MaterialPageRoute], [HalamanDetailMapel], [_segarkan], [FloatingActionButton.extended], [_tambahMapel]
  Widget _tabMapel() {
    if (_muat) {
      return const Center(child: CircularProgressIndicator());
    }

    final tampil = _saring(_cari.text);

    return Scaffold(
      // FAB diletakkan di dalam tab supaya hanya muncul di tab ini.
      backgroundColor: Colors.transparent,
      body: _mapel.isEmpty
          ? Kosong(
              ikon: Icons.menu_book_outlined,
              judul: t('ak_kosong_mapel'),
              pesan: t('ak_kosong_mapel_pesan'),
              labelTombol: t('ak_kosong_mapel_tombol'),
              onTombol: _tambahMapel,
            )
          : Column(
              children: [
                if (!_modeSeleksi) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _toggleSeleksi,
                      child: Text(t('ak_mulai_pilih')),
                    ),
                  ),
                ],
                if (_modeSeleksi && tampil.isNotEmpty) ...[
                  _barSeleksi(tampil),
                  const SizedBox(height: Jarak.j4),
                ],
                // Kolom cari mapel — wireframe layar 3:
                // "[Q] Search subjects or instructors...".
                _KolomCari(
                  kendali: _cari,
                  petunjuk: t('ak_cari_mapel'),
                  onUbah: (_) => setState(() {}),
                ),
                Expanded(
                  child: tampil.isEmpty
                      ? Kosong(
                          ikon: Icons.search_off,
                          judul: t('ak_tidak_ditemukan'),
                          pesan: t('ak_coba_kata'),
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
                                terpilih:
                                    _modeSeleksi ? sudahDipilih : null,
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
      floatingActionButton: _modeSeleksi
          ? null
          : FloatingActionButton.extended(
              onPressed: _tambahMapel,
              icon: const Icon(Icons.add),
              label: Text(t('ak_mapel_fab')),
            ),
    );
  }

  /// Bar kontrol mode seleksi: jumlah terpilih, pilih semua/batal, dan tombol hapus.
  Widget _barSeleksi(List<Mapel> tampil) {
    final semuaTerpilih = tampil.isNotEmpty &&
        tampil.every((m) => m.id != null && _terpilih.contains(m.id!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Jarak.j14,
        Jarak.j4,
        Jarak.j14,
        Jarak.j4,
      ),
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

  /// Nyalakan/matikan mode seleksi. Saat dimatikan, kosongkan pilihan.
  void _toggleSeleksi() {
    setState(() {
      _modeSeleksi = !_modeSeleksi;
      if (!_modeSeleksi) _terpilih.clear();
    });
  }

  /// Tambah atau hapus [id] dari pilihan.
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
  void _pilihSemua() {
    setState(() {
      for (final m in _saring(_cari.text)) {
        if (m.id != null) _terpilih.add(m.id!);
      }
    });
  }

  /// Kosongkan semua pilihan dan keluar mode seleksi.
  void _batalPilihSemua() {
    setState(() {
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }

  /// Konfirmasi lalu hapus semua mapel terpilih ke Sampah (soft delete).
  ///
  /// Menggunakan [konfirmasiHitungMundur] dengan hitung mundur 5 detik
  /// supaya tombol Hapus terkunci selama hitung mundur. Tombol Batal
  /// bisa ditekan kapan saja untuk membatalkan tanpa perlu pilih apapun.
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
      mapelRepo: MapelRepositoryImpl(),
      materiRepo: MateriRepositoryImpl(),
      lampiranRepo: LampiranRepositoryImpl(),
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

  /// Menyaring daftar mapel berdasarkan kata kunci [kata].
  ///
  /// Pencocokan dilakukan pada nama dan keterangan mapel, tanpa membedakan
  /// huruf besar/kecil. Dijalankan di memori karena daftar mapel selalu
  /// dimuat utuh (jumlahnya kecil), jadi tidak perlu query tambahan.
  ///
  /// **Reused in:** [_tabMapel] (ValueListenableBuilder)
  /// **Calls:** [String.toLowerCase], [String.contains]
  List<Mapel> _saring(String kata) {
    final q = kata.trim().toLowerCase();
    if (q.isEmpty) return _mapel;
    return _mapel
        .where((m) =>
            m.nama.toLowerCase().contains(q) ||
            (m.deskripsi ?? '').toLowerCase().contains(q))
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────
// Kolom cari bersama
// ─────────────────────────────────────────────────────────────

/// Kotak pencarian dengan ikon kaca pembesar + padding dari token.
///
/// Dipakai di semua tab supaya jarak dan tinggi kotak cari seragam.
///
/// **Reused in:** [_HalamanAcademicState._tabMapel], [_TabCatatan.build], [_TabTugas.build]
/// **Calls:** [TextField], [Jarak] tokens
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

// ─────────────────────────────────────────────────────────────
// Tab 2 — Catatan (semua materi lintas mapel)
// ─────────────────────────────────────────────────────────────

/// Tab Catatan: menampilkan semua materi (catatan) lintas semua mapel.
/// Mendukung pencarian teks via TextField di header.
class _TabCatatan extends StatefulWidget {
  const _TabCatatan();

  @override
  State<_TabCatatan> createState() => _TabCatatanState();
}

class _TabCatatanState extends State<_TabCatatan> {
  late final MateriRepository _materiRepo;
  final _kunci = TextEditingController();

  List<Materi> _data = [];
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _materiRepo = MateriRepositoryImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _kunci.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar materi (catatan) dari database.
  ///
  /// Jika [_kunci] tidak kosong, memanggil [MateriRepository.cariKata];
  /// jika kosong, memanggil [MateriRepository.semua].
  /// Dipanggil saat initState dan setiap kali teks pencarian berubah.
  ///
  /// **Reused in:** [initState], [build.onChanged]
  /// **Calls:** [MateriRepository.semua], [MateriRepository.cariKata], [setState]
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

  /// Build tab Catatan: search field + list materi.
  ///
  /// Menampilkan: loading, Kosong (empty state), atau ListView Card materi.
  ///
  /// **Reused in:** [HalamanAcademic.build] (TabBarView children[1])
  /// **Calls:** [_KolomCari], [Kosong], [ListView.separated], [Card], [Tanda], [t], [Theme.of]
  @override
  Widget build(BuildContext context) {
    return Column(
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
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        Jarak.j14,
                        Jarak.j10,
                        Jarak.j14,
                        Jarak.j14 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: _data.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Jarak.j10),
                      itemBuilder: (_, i) {
                        final m = _data[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(Jarak.j14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        m.judul,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                const SizedBox(height: Jarak.j6),
                                Text(
                                  (m.isi ?? '').trim().isEmpty
                                      ? t('ak_belum_isi')
                                      : m.isi!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab 3 — Tugas (semua tugas lintas mapel)
// ─────────────────────────────────────────────────────────────

/// Tab Tugas: menampilkan semua tugas lintas semua mapel.
/// Mendukung filter status via SegmentedButton (Semua/Belum/Selesai).
class _TabTugas extends StatefulWidget {
  const _TabTugas();

  @override
  State<_TabTugas> createState() => _TabTugasState();
}

class _TabTugasState extends State<_TabTugas> {
  late final TugasRepository _repo;

  List<Tugas> _data = [];
  String? _saring;
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _repo = TugasRepositoryImpl();
    _segarkan();
  }

  /// Memuat ulang daftar tugas dari database dengan filter status opsional.
  ///
  /// [_saring] bisa null (semua), 'BELUM', atau 'SELESAI'.
  /// Dipanggil saat initState dan setiap kali filter berubah.
  ///
  /// **Reused in:** [initState], [build.onSelectionChanged]
  /// **Calls:** [TugasRepository.semua], [setState]
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await _repo.semua(status: _saring);
    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
    });
  }

  /// Build tab Tugas: filter SegmentedButton + list tugas.
  ///
  /// Menampilkan: loading, Kosong (empty state), atau ListView Card tugas
  /// dengan IconButton toggle status dan Tanda tenggat relatif.
  ///
  /// **Reused in:** [HalamanAcademic.build] (TabBarView children[2])
  /// **Calls:** [SegmentedButton], [Kosong], [ListView.separated], [Card], [ListTile], [IconButton], [Tanda], [tenggatRelatif], [TugasRepository.ubahStatus], [_segarkan], [t]
  @override
  Widget build(BuildContext context) {
    return Column(
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
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        Jarak.j14,
                        Jarak.j10,
                        Jarak.j14,
                        Jarak.j14 + MediaQuery.viewPaddingOf(context).bottom,
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
                                await _repo.ubahStatus(
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
                              g.namaMapel ?? t('home_tanpa_mapel'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Tanda(
                              teks: selesai
                                  ? t('ak_selesai')
                                  : tenggatRelatif(g.tenggat),
                              warna: selesai
                                  ? skema.outline
                                  : lewat
                                      ? skema.error
                                      : skema.primary,
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}