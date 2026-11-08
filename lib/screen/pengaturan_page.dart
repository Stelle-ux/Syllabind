import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';

/// Halaman 4 — Pengaturan.
///
/// 5 kelompok (bukan halaman kosong):
///   1. Tampilan  — tema terang/gelap/ikuti sistem
///   2. Warna     — warna aksen aplikasi
///   3. Data      — ekspor .txt
///   4. Pemulihan — Sampah (lihat & pulihkan yang terhapus)
///   5. Tentang   — nama app, versi, mata ujian
///
/// **Reused in:** [main.dart] (NavigationBar index 3)
/// **Calls:** [_HalamanPengaturanState]
class HalamanPengaturan extends StatefulWidget {
  /// Callback opsional dipanggil saat data berubah (tema, bahasa, aksen, sampah).
  /// Digunakan oleh [main.dart] untuk memicu rebuild MaterialApp.
  final VoidCallback? onDataBerubah;

  const HalamanPengaturan({super.key, this.onDataBerubah});

  @override
  State<HalamanPengaturan> createState() => _HalamanPengaturanState();
}

/// State untuk [HalamanPengaturan].
///
/// Mengelola:
/// - Pengaturan tema (_mode: sistem/terang/gelap) via [PengaturanRepository]
/// - Warna aksen (_aksen) via [PengaturanRepository] + [TemaApp.palet]
/// - Bahasa (_bahasa) via [PengaturanRepository] + [Bahasa]
/// - Jumlah item di Sampah (_jumlahSampah) via [MapelRepository.isiSampah]
/// - 5 section UI: Tampilan, Bahasa, Warna, Pemulihan, Tentang
/// - Bottom sheet Sampah ([_LembarSampah]) dengan pulihkan/hapus permanen
///
/// **Reused in:** [HalamanPengaturan.createState]
/// **Calls:** [PengaturanRepository], [MapelRepository], [LayananHapus], [TemaApp], [Bahasa], [_LembarSampah], [konfirmasi], [pesanSukses], [t], [tp], [tanggalPendek]
class _HalamanPengaturanState extends State<HalamanPengaturan> {
  final _repo = PengaturanRepositoryImpl();
  final _mapelRepo = MapelRepositoryImpl();
  late final LayananHapus _hapus;

  String _mode = 'sistem';
  String _aksen = '#2F6F6B';
  String _bahasa = Bahasa.id;
  int _jumlahSampah = 0;
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _hapus = LayananHapus(
      mapelRepo: _mapelRepo,
      materiRepo: MateriRepositoryImpl(),
      lampiranRepo: LampiranRepositoryImpl(),
    );
    _muatkan();
  }

  /// Memuat semua pengaturan dari repo + hitung sampah.
  ///
  /// Dipanggil di initState dan setelah aksi di Sampah (pulihkan/hapus permanen).
  ///
  /// **Reused in:** [initState], [_bukaLamanSampah] (after bottom sheet closes)
  /// **Calls:** [PengaturanRepository.tema], [PengaturanRepository.warnaAksen], [PengaturanRepository.bahasa], [MapelRepository.isiSampah], [setState]
  Future<void> _muatkan() async {
    final mode = await _repo.tema();
    final aksen = await _repo.warnaAksen();
    final sampah = await _mapelRepo.isiSampah();
    final bahasa = await _repo.bahasa();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _aksen = aksen;
      _bahasa = bahasa;
      _jumlahSampah = sampah.length;
      _muat = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_muat) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.only(
        bottom: Jarak.j16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        // 1. Tampilan
        _bagian(t('set_tampilan')),
        // Sejak Flutter 3.32, `groupValue`/`onChanged` pada RadioListTile
        // sudah usang: nilainya dipindah ke satu pembungkus `RadioGroup`.
        // Perilakunya sama; hanya lokasi nilainya yang berpindah.
        RadioGroup<String>(
          groupValue: _mode,
          onChanged: _ubahMode,
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'sistem',
                title: Text(t('set_ikuti_sistem')),
                subtitle: Text(t('set_ikuti_sistem_sub')),
              ),
              RadioListTile<String>(
                value: 'terang',
                title: Text(t('set_terang')),
              ),
              RadioListTile<String>(
                value: 'gelap',
                title: Text(t('set_gelap')),
              ),
            ],
          ),
        ),

        const Divider(height: Jarak.j24),

        // 2. Bahasa
        _bagian(t('set_bahasa')),
        ListTile(
          leading: const Icon(Icons.translate),
          title: Text(t('set_bahasa_judul')),
          subtitle: Text(t('set_bahasa_sub')),
          trailing: DropdownButton<String>(
            value: _bahasa,
            underline: const SizedBox.shrink(),
            onChanged: (v) {
              if (v != null) _ubahBahasa(v);
            },
            items: [
              DropdownMenuItem(
                value: Bahasa.id,
                child: Text(t('set_bahasa_id')),
              ),
              DropdownMenuItem(
                value: Bahasa.en,
                child: Text(t('set_bahasa_en')),
              ),
            ],
          ),
        ),

        const Divider(height: Jarak.j24),

        // 3. Warna aksen
        _bagian(t('set_warna')),
        Padding(
          padding: const EdgeInsets.fromLTRB(Jarak.j16, Jarak.j4, Jarak.j16, Jarak.j8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in TemaApp.palet.entries)
                _bulatWarna(e.key, e.value),
            ],
          ),
        ),

        const Divider(height: Jarak.j24),

        // 4. Pemulihan — Sampah
        _bagian(t('set_pemulihan')),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text(t('set_sampah')),
          subtitle: Text(
            _jumlahSampah == 0
                ? t('set_sampah_kosong')
                : tp('set_sampah_isi', {'n': '$_jumlahSampah'}),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _bukaLamanSampah,
        ),

        const Divider(height: Jarak.j24),

        // 5. Tentang
        _bagian(t('set_tentang')),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Syllabind'),
          subtitle: Text('Versi 1.0.0 · Offline'),
        ),
      ],
    );
  }

  /// Widget header section (judul uppercase dengan styling konsisten).
  ///
  /// **Reused in:** [build] (5x untuk setiap section)
  /// **Calls:** [Text], [Theme.of], [TextStyle.copyWith]
  Widget _bagian(String judul) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Jarak.j16, Jarak.j14, Jarak.j16, Jarak.j6),
      child: Text(
        judul.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
      ),
    );
  }

  /// Bulat warna aksen untuk grid pilihan warna.
  ///
  /// Menampilkan lingkaran 46dp dengan border tebal saat aktif,
  /// ikon check putih di tengah. onTap → simpan ke repo + setState + callback.
  ///
  /// **Reused in:** [build] (Wrap children dari TemaApp.palet.entries)
  /// **Calls:** [Tooltip], [InkWell], [PengaturanRepository.setWarnaAksen], [setState], [widget.onDataBerubah], [TemaApp.dariHex], [Theme.of]
  Widget _bulatWarna(String label, String hex) {
    final aktif = _aksen.toUpperCase() == hex.toUpperCase();
    final warna = TemaApp.dariHex(hex);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () async {
          await _repo.setWarnaAksen(hex);
          if (!mounted) return;
          setState(() => _aksen = hex);
          widget.onDataBerubah?.call();
        },
        borderRadius: BorderRadius.circular(Sudut.r30),
        child: Container(
          width: Ukuran.bulatWarna,
          height: Ukuran.bulatWarna,
          decoration: BoxDecoration(
            color: warna,
            shape: BoxShape.circle,
            border: Border.all(
              color: aktif
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: Ukuran.cincin,
            ),
          ),
          child: aktif
              ? const Icon(Icons.check, color: Colors.white, size: Ikon.cek)
              : null,
        ),
      ),
    );
  }

  /// Mengubah bahasa aplikasi dan memicu rebuild global.
  ///
  /// Simpan ke [PengaturanRepository.setBahasa], update state lokal,
  /// panggil [widget.onDataBerubah] supaya [main.dart] rebuild MaterialApp
  /// dengan [Bahasa.notifier] value baru.
  ///
  /// **Reused in:** [build] (DropdownButton onChanged)
  /// **Calls:** [PengaturanRepository.setBahasa], [setState], [widget.onDataBerubah]
  Future<void> _ubahBahasa(String v) async {
    await _repo.setBahasa(v);
    if (!mounted) return;
    setState(() => _bahasa = v);
    // Beri tahu kerangka aplikasi supaya seluruh teks langsung berganti.
    widget.onDataBerubah?.call();
  }

  /// Mengubah mode tema (sistem/terang/gelap) dan memicu rebuild global.
  ///
  /// Simpan ke [PengaturanRepository.setTema], update state lokal,
  /// panggil [widget.onDataBerubah] supaya [main.dart] rebuild MaterialApp
  /// dengan [TemaApp] yang sesuai.
  ///
  /// **Reused in:** [build] (RadioListTile onChanged x3)
  /// **Calls:** [PengaturanRepository.setTema], [setState], [widget.onDataBerubah]
  Future<void> _ubahMode(String? v) async {
    if (v == null) return;
    await _repo.setTema(v);
    if (!mounted) return;
    setState(() => _mode = v);
    widget.onDataBerubah?.call();
  }

  /// Membuka bottom sheet Sampah (isScrollControlled=true untuk full height).
  ///
  /// Meneruskan [LayananHapus] dan callback refresh ke [_LembarSampah].
  /// Setelah tutup, panggil [_muatkan] untuk update jumlah sampah.
  ///
  /// **Reused in:** [build] (ListTile onTap Sampah)
  /// **Calls:** [showModalBottomSheet], [_LembarSampah], [_muatkan]
  Future<void> _bukaLamanSampah() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LembarSampah(
        hapus: _hapus,
        onBerubah: () {
          _muatkan();
          widget.onDataBerubah?.call();
        },
      ),
    );
    await _muatkan();
  }
}

// ─────────────────────────────────────────────────────────────
// Lembar Sampah
// ─────────────────────────────────────────────────────────────

/// Bottom sheet untuk mengelola Sampah (mapel terhapus lunak).
///
/// Menampilkan daftar mapel di sampah dengan tombol:
/// - Pulihkan → [LayananHapus.mapel.pulihkan]
/// - Hapus permanen → [LayananHapus.mapelPermanen] (dengan konfirmasi)
///
/// Auto-refresh setelah aksi via callback [onBerubah].
///
/// **Reused in:** [_HalamanPengaturanState._bukaLamanSampah]
/// **Calls:** [LayananHapus.mapel.isiSampah], [LayananHapus.mapel.pulihkan], [LayananHapus.mapelPermanen], [konfirmasi], [pesanSukses], [tanggalPendek], [t]
class _LembarSampah extends StatefulWidget {
  final LayananHapus hapus;
  final VoidCallback onBerubah;

  const _LembarSampah({required this.hapus, required this.onBerubah});

  @override
  State<_LembarSampah> createState() => _LembarSampahState();
}

/// State untuk [_LembarSampah].
///
/// Mengelola:
/// - Future daftar sampah (_future) yang disegarkan setelah aksi
/// - ListView dengan Card per mapel (nama, tanggal dihapus, 2 tombol aksi)
///
/// **Reused in:** [_LembarSampah.createState]
/// **Calls:** [LayananHapus.mapel.isiSampah], [LayananHapus.mapel.pulihkan], [LayananHapus.mapelPermanen], [konfirmasi], [pesanSukses], [tanggalPendek], [setState]
class _LembarSampahState extends State<_LembarSampah> {
  late Future<List<Mapel>> _future;
  bool _modeSeleksi = false;
  final Set<int> _terpilih = {};

  @override
  void initState() {
    super.initState();
    _future = widget.hapus.mapel.isiSampah();
  }

  /// Memuat ulang daftar sampah (dipanggil setelah pulihkan/hapus permanen).
  ///
  /// **Reused in:** [build] (TextButton onPressed Pulihkan, IconButton onPressed Hapus permanen)
  /// **Calls:** [LayasanHapus.mapel.isiSampah], [setState]
  void _segarkan() {
    setState(() {
      _future = widget.hapus.mapel.isiSampah();
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Jarak.j16, 0, Jarak.j16, Jarak.j16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('set_sampah'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Jarak.j4),
            Text(
              t('sampah_ket'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Jarak.j14),
            FutureBuilder<List<Mapel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(Jarak.j24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snap.data ?? [];
                if (data.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Jarak.j24),
                    child: Text(t('sampah_kosong')),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_modeSeleksi) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() => _modeSeleksi = true),
                          child: Text(t('sampah_mulai_pilih')),
                        ),
                      ),
                      const SizedBox(height: Jarak.j8),
                    ],
                    if (_modeSeleksi) ...[
                      _barSeleksiSampah(data),
                      const SizedBox(height: Jarak.j8),
                    ],
                    Expanded(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: data.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Jarak.j8),
                        itemBuilder: (_, i) {
                          final m = data[i];
                          final sudahDipilih = _terpilih.contains(m.id);
                          return Card(
                            child: ListTile(
                              title: Text(m.nama),
                              subtitle: Text(
                                m.deletedAt == null
                                    ? 'Dihapus'
                                    : 'Dihapus ${tanggalPendek(m.deletedAt!)}',
                              ),
                              trailing: _modeSeleksi
                                  ? Checkbox(
                                      value: sudahDipilih,
                                      onChanged: (v) =>
                                          _pilihSampah(m.id!, v ?? false),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(
                                          onPressed: () async {
                                            await widget.hapus.mapel
                                                .pulihkan(m.id!);
                                            _segarkan();
                                            widget.onBerubah();
                                          },
                                          child: Text(t('pulihkan')),
                                        ),
                                        IconButton(
                                          tooltip: t('sampah_hapus_permanen'),
                                          icon: Icon(
                                            Icons.delete_forever,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          onPressed: () => _hapusPermanen(m),
                                        ),
                                      ],
                                    ),
                              onTap: _modeSeleksi
                                  ? () => _pilihSampah(m.id!, !sudahDipilih)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Konfirmasi & hapus permanen mapel dari Sampah.
  ///
  /// Menampilkan dialog [konfirmasi] dengan peringatan detail:
  /// semua catatan, tugas, lampiran + file ikut terhapus, TIDAK bisa pulihkan.
  /// Panggil [LayananHapus.mapelPermanen] (file-first lalu DB via CASCADE).
  /// Tampilkan [pesanSukses], segarkan, callback [onBerubah].
  ///
  /// **Reused in:** [build] (IconButton onPressed Hapus permanen)
  /// **Calls:** [konfirmasi], [LayananHapus.mapelPermanen], [_segarkan], [widget.onBerubah], [pesanSukses]
  Future<void> _hapusPermanen(Mapel m) async {
    final ya = await konfirmasi(
      context,
      judul: tp('sampah_konfirmasi_judul', {'nama': m.nama}),
      pesan: t('sampah_konfirmasi_pesan'),
      labelYa: t('sampah_hapus_permanen'),
    );
    if (ya != true) return;

    await widget.hapus.mapelPermanen(m.id!);
    if (!mounted) return;
    _segarkan();
    widget.onBerubah();
    pesanSukses(context, tp('sampah_berhasil', {'nama': m.nama}));
  }

  /// Bar kontrol mode seleksi Sampah: jumlah terpilih, pilih semua/batal, dan tombol hapus permanen.
  Widget _barSeleksiSampah(List<Mapel> data) {
    final semuaTerpilih = data.isNotEmpty &&
        data.every((m) => m.id != null && _terpilih.contains(m.id!));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Jarak.j14, Jarak.j4, Jarak.j14, Jarak.j4),
      child: Wrap(
        spacing: Jarak.j8,
        runSpacing: Jarak.j8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tp('sampah_terpilih', {'n': '${_terpilih.length}'}),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: semuaTerpilih ? null : _pilihSemuaSampah,
                child: Text(t('sampah_pilih_semua')),
              ),
              const SizedBox(width: Jarak.j8),
              TextButton(
                onPressed: _batalPilihSemuaSampah,
                child: Text(t('sampah_batal_pilih')),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _terpilih.isEmpty ? null : _hapusPermanenTerpilih,
            icon: const Icon(Icons.delete_forever),
            label: Text(t('sampah_hapus_permanen_terpilih')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
        ],
      ),
    );
  }

  /// Tambah atau hapus [id] dari pilihan Sampah.
  void _pilihSampah(int id, bool dipilih) {
    setState(() {
      if (dipilih) {
        _terpilih.add(id);
      } else {
        _terpilih.remove(id);
      }
    });
  }

  /// Pilih semua mapel di Sampah.
  void _pilihSemuaSampah() {
    setState(() {
      _future = widget.hapus.mapel.isiSampah().then((semua) {
        for (final m in semua) {
          if (m.id != null) _terpilih.add(m.id!);
        }
        return semua;
      });
    });
  }

  /// Kosongkan semua pilihan Sampah dan keluar mode seleksi.
  void _batalPilihSemuaSampah() {
    setState(() {
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }

  /// Konfirmasi lalu hapus permanen semua mapel terpilih dari Sampah.
  ///
  /// Menggunakan [konfirmasiHitungMundur] dengan hitung mundur 5 detik.
  Future<void> _hapusPermanenTerpilih() async {
    final lanjut = await konfirmasiHitungMundur(
      context,
      judul: tp('sampah_konfirmasi_hapus_permanen_banyak',
          {'n': '${_terpilih.length}'}),
      rincian: [
        t('sampah_konfirmasi_hapus_permanen_banyak_pesan'),
        t('sampah_konfirmasi_pesan'),
      ],
    );
    if (lanjut != true) return;

    for (final id in _terpilih.toList()) {
      await widget.hapus.mapelPermanen(id);
    }
    final jumlah = _terpilih.length;
    _terpilih.clear();
    setState(() => _modeSeleksi = false);
    _segarkan();
    widget.onBerubah();
    if (!mounted) return;
    pesanSukses(
      context,
      tp('sampah_berhasil_hapus_permanen_banyak', {'n': jumlah.toString()}),
    );
  }
}