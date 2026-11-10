import 'package:flutter/material.dart';

import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';

/// Halaman 4 — Pengaturan (tema, bahasa, warna aksen, sampah, tentang).
/// dipakai di main.dart
class HalamanPengaturan extends StatefulWidget {
  /// Callback saat pengaturan berubah, memicu rebuild MaterialApp.
  /// dipakai di main.dart
  final VoidCallback? onDataBerubah;

  const HalamanPengaturan({super.key, this.onDataBerubah});

  @override
  State<HalamanPengaturan> createState() => _HalamanPengaturanState();
}

/// State untuk HalamanPengaturan.
/// dipakai di HalamanPengaturan.createState
class _HalamanPengaturanState extends State<HalamanPengaturan> {
  final _repo = PengaturanServiceImpl();
  final _mapelRepo = MapelServiceImpl();
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
      materiRepo: MateriServiceImpl(),
      tugasRepo: TugasServiceImpl(),
      lampiranRepo: LampiranServiceImpl(),
    );
    _muatkan();
  }

  /// Memuat pengaturan (tema, bahasa, aksen) dan jumlah sampah.
  /// dipakai di initState, _bukaLamanSampah
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
          padding: const EdgeInsets.fromLTRB(
            Jarak.j16,
            Jarak.j4,
            Jarak.j16,
            Jarak.j8,
          ),
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
  /// dipakai di build
  Widget _bagian(String judul) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Jarak.j16,
        Jarak.j14,
        Jarak.j16,
        Jarak.j6,
      ),
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
  /// dipakai di build
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
  /// dipakai di build
  Future<void> _ubahBahasa(String v) async {
    await _repo.setBahasa(v);
    if (!mounted) return;
    setState(() => _bahasa = v);
    widget.onDataBerubah?.call();
  }

  /// Mengubah mode tema (sistem/terang/gelap) dan memicu rebuild global.
  /// dipakai di build
  Future<void> _ubahMode(String? v) async {
    if (v == null) return;
    await _repo.setTema(v);
    if (!mounted) return;
    setState(() => _mode = v);
    widget.onDataBerubah?.call();
  }

  /// Membuka bottom sheet Sampah (isScrollControlled=true untuk full height).
  /// dipakai di build
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
/// dipakai di _HalamanPengaturanState._bukaLamanSampah
class _LembarSampah extends StatefulWidget {
  final LayananHapus hapus;
  final VoidCallback onBerubah;

  const _LembarSampah({required this.hapus, required this.onBerubah});

  @override
  State<_LembarSampah> createState() => _LembarSampahState();
}

/// State untuk _LembarSampah.
/// dipakai di _LembarSampah.createState
class _LembarSampahState extends State<_LembarSampah> {
  /// Daftar mapel di Sampah — disimpan di State (bukan Future) supaya tinggi
  /// tata letak terbatas dan tidak memicu "unbounded height" pada Column.
  /// dipakai di build, _barSeleksiSampah, _pilihSemuaSampah
  List<Mapel> _data = [];
  bool _muat = true;
  bool _modeSeleksi = false;
  final Set<int> _terpilih = {};

  @override
  void initState() {
    super.initState();
    _segarkan();
  }

  /// Memuat ulang daftar sampah (dipanggil setelah pulihkan/hapus permanen).
  /// dipakai di initState, build, _hapusPermanenTerpilih
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await widget.hapus.mapel.isiSampah();
    if (!mounted) return;
    setState(() {
      _data = d;
      _muat = false;
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        // Tinggi tetap (70% layar) supaya lembar tidak memenuhi seluruh layar,
        // tetapi daftar tetap bisa digulir saat isi Sampah banyak.
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Jarak.j16,
            0,
            Jarak.j16,
            Jarak.j16,
          ),
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
              Expanded(
                child: _muat
                    ? const Center(child: CircularProgressIndicator())
                    : _data.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Jarak.j24,
                        ),
                        child: Text(t('sampah_kosong')),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_modeSeleksi) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => _modeSeleksi = true),
                                child: Text(t('sampah_mulai_pilih')),
                              ),
                            ),
                            const SizedBox(height: Jarak.j8),
                          ],
                          if (_modeSeleksi) ...[
                            _barSeleksiSampah(_data),
                            const SizedBox(height: Jarak.j8),
                          ],
                          Expanded(
                            child: ListView.separated(
                              itemCount: _data.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: Jarak.j8),
                              itemBuilder: (_, i) {
                                final m = _data[i];
                                final sudahDipilih =
                                    m.id != null && _terpilih.contains(m.id);
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
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () async {
                                                  await widget.hapus.mapel
                                                      .pulihkan(m.id!);
                                                  if (!mounted) return;
                                                  await _segarkan();
                                                  widget.onBerubah();
                                                },
                                                child: Text(t('pulihkan')),
                                              ),
                                              IconButton(
                                                tooltip: t(
                                                  'sampah_hapus_permanen',
                                                ),
                                                icon: Icon(
                                                  Icons.delete_forever,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error,
                                                ),
                                                onPressed: () =>
                                                    _hapusPermanen(m),
                                              ),
                                            ],
                                          ),
                                    onTap: _modeSeleksi
                                        ? () =>
                                              _pilihSampah(m.id!, !sudahDipilih)
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Konfirmasi & hapus permanen mapel dari Sampah.
  /// dipakai di build:xxx
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
    await _segarkan();
    widget.onBerubah();
    pesanSukses(context, tp('sampah_berhasil', {'nama': m.nama}));
  }

  /// Bar kontrol mode seleksi Sampah: jumlah terpilih, pilih semua/batal, dan tombol hapus permanen.
  /// dipakai di build:xxx
  Widget _barSeleksiSampah(List<Mapel> data) {
    final semuaTerpilih =
        data.isNotEmpty &&
        data.every((m) => m.id != null && _terpilih.contains(m.id!));
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
  /// dipakai di build
  void _pilihSampah(int id, bool dipilih) {
    setState(() {
      if (dipilih) {
        _terpilih.add(id);
      } else {
        _terpilih.remove(id);
      }
    });
  }

  /// Pilih semua mapel di Sampah (dari data yang sudah dimuat).
  /// dipakai di _barSeleksiSampah
  void _pilihSemuaSampah() {
    setState(() {
      for (final m in _data) {
        if (m.id != null) _terpilih.add(m.id!);
      }
    });
  }

  /// Kosongkan semua pilihan Sampah dan keluar mode seleksi.
  /// dipakai di _barSeleksiSampah
  void _batalPilihSemuaSampah() {
    setState(() {
      _terpilih.clear();
      _modeSeleksi = false;
    });
  }

  /// Konfirmasi lalu hapus permanen semua mapel terpilih dari Sampah.
  ///
  /// Menggunakan [konfirmasiHitungMundur] dengan hitung mundur 5 detik.
  /// dipakai di _barSeleksiSampah
  Future<void> _hapusPermanenTerpilih() async {
    final lanjut = await konfirmasiHitungMundur(
      context,
      judul: tp('sampah_konfirmasi_hapus_permanen_banyak', {
        'n': '${_terpilih.length}',
      }),
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
    if (!mounted) return;
    await _segarkan();
    widget.onBerubah();
    if (!mounted) return;
    pesanSukses(
      context,
      tp('sampah_berhasil_hapus_permanen_banyak', {'n': jumlah.toString()}),
    );
  }
}
