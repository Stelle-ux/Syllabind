import 'package:flutter/material.dart';

import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/hasil_bersih.dart';
import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/ringkasan_tugas.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/services/mapel_service_impl.dart';
import 'package:syllabind/services/materi_service_impl.dart';
import 'package:syllabind/services/tugas_service_impl.dart';
import 'package:syllabind/services/mapel_service.dart';
import 'package:syllabind/services/materi_service.dart';
import 'package:syllabind/services/tugas_service.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';
import 'package:syllabind/tools/tanggal.dart';
import 'package:syllabind/tools/kartu_mapel.dart';
import 'package:syllabind/tools/kosong.dart';
import 'package:syllabind/tools/tanda.dart';
import 'package:syllabind/tools/kosong.dart';
import 'package:syllabind/tools/tanda.dart';

/// Halaman 1 — Home / Hari Ini.
/// dipakai di main.dart:RumahAplikasi halaman[0]
class HalamanHome extends StatefulWidget {
  /// Waktu acuan untuk sapaan dan tanggal header; null = waktu perangkat.
  /// dipakai di tes golden agar tidak gagal karena waktu berjalan
  static DateTime? waktuUji;

  /// Callback navigasi ke tab Academic saat belum ada mapel.
  /// dipakai di _buildKosongTotal, _kepala (onLihatSemua)
  final VoidCallback onBukaAcademic;

  const HalamanHome({super.key, required this.onBukaAcademic});

  @override
  State<HalamanHome> createState() => _HalamanHomeState();
}

class _HalamanHomeState extends State<HalamanHome> {
  late final MapelService _mapelRepo;
  late final TugasService _tugasRepo;
  late final MateriService _materiRepo;

  /// Pengendali kotak cari. Perlu di-dispose agar tidak bocor.
  /// dipakai di build (TextField), dispose
  final _kendaliCari = TextEditingController();

  /// Kata kunci pencarian aktif (sudah dipangkas & dihuruf-kecilkan).
  /// dipakai di _saringTugas, _saringCatatan, _saringMapel, _hasilCari
  String _kata = '';

  RingkasanTugas? _ringkasan;
  List<Tugas> _dekat = [];

  /// Id tugas yang sedang diproses — mencegah klik ganda saat penyimpanan berjalan.
  /// dipakai di _tandai
  final Set<int> _sedangProses = {};
  List<Tugas> _lewat = [];
  List<Materi> _catatan = [];
  List<Mapel> _mapel = [];
  int _jumlahMapel = 0;
  bool _muat = true;

  @override
  void initState() {
    super.initState();
      _mapelRepo = MapelServiceImpl();
      _tugasRepo = TugasServiceImpl();
      _materiRepo = MateriServiceImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _kendaliCari.dispose();
    super.dispose();
  }

  /// Memuat ulang semua data dari service.
  /// dipakai di initState, _tandai (urungkan), build (RefreshIndicator.onRefresh)
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final r = await _tugasRepo.ringkasan();
    final d = await _tugasRepo.tenggatTerdekat(batasHari: 7);
    final l = await _tugasRepo.lewatTenggat();
    final j = await _mapelRepo.jumlah();
    final mp = await _mapelRepo.semua();
    final c = await _materiRepo.semua(hanyaDenganCatatan: true);
    if (!mounted) return;
    setState(() {
      _ringkasan = r;
      _dekat = d;
      _lewat = l;
      _jumlahMapel = j;
      _mapel = mp;
      _catatan = c;
      _muat = false;
    });
  }

  /// Daftar tenggat terdekat yang ditampilkan (langsung dari sumber data).
  /// Tugas yang sudah dicentang selesai dikeluarkan dari [_dekat] oleh [_tandai],
  /// jadi daftar tidak melompat ke seksi lain.
  /// dipakai di build (tenggat terdekat section), _kartuTugas, _hasilCari
  List<Tugas> get _tampilDekat => _dekat;

  /// Menandai tugas selesai / belum selesai dari Home, dengan tombol Urungkan.
  /// Setelah dicentang, tugas langsung dikeluarkan dari daftar (tidak bisa
  /// dicentang dua kali dan daftar tidak melompat ke seksi lain).
  /// dipakai di _kartuFokus, _kartuTugas, _barisTugas
  Future<void> _tandai(Tugas tg, {required bool selesai}) async {
    final id = tg.id;
    if (id == null) return;

    // Tolak klik ganda selama penyimpanan berjalan.
    if (!_sedangProses.add(id)) return;
    try {
      await _tugasRepo.ubahStatus(
        id,
        selesai ? SkemaDb.statusSelesai : SkemaDb.statusBelum,
      );
      if (!mounted) return;

      if (!selesai) {
        await _segarkan();
        return;
      }

      final sebelum = _ringkasan;
      setState(() {
        _dekat.removeWhere((x) => x.id == id);
        _lewat.removeWhere((x) => x.id == id);
        if (sebelum != null) {
          _ringkasan = RingkasanTugas(
            belum: _geser(sebelum.belum, -1),
            selesai: _geser(sebelum.selesai, 1),
            lewat: tg.lewatTenggat ? _geser(sebelum.lewat, -1) : sebelum.lewat,
          );
        }
      });

      final pesan = tp('home_selesai_pesan', {'judul': tg.judul});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesan),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: t('home_urungkan'),
            onPressed: () => _tandai(tg, selesai: false),
          ),
        ),
      );
    } finally {
      _sedangProses.remove(id);
    }
  }

  /// Geser angka ringkasan tanpa pernah membiarkannya negatif.
  /// dipakai di _tandai
  int _geser(int nilai, int delta) {
    final hasil = nilai + delta;
    return hasil < 0 ? 0 : hasil;
  }

  /// Waktu acuan: waktu uji bila dipatok tes, selain itu waktu perangkat.
  /// dipakai di _sapaan, build (tanggalPendek)
  DateTime get _kini => HalamanHome.waktuUji ?? DateTime.now();

  /// Sapaan sesuai jam acuan (pagi/siang/sore/malam).
  /// dipakai di build (sapaan text)
  String get _sapaan {
    final jam = _kini.hour;
    if (jam < 11) return t('home_sapaan_pagi');
    if (jam < 15) return t('home_sapaan_siang');
    if (jam < 19) return t('home_sapaan_sore');
    return t('home_sapaan_malam');
  }

  /// Tugas pertama yang belum selesai dari daftar terdekat — untuk kartu "Fokus hari ini".
  /// dipakai di build (fokus section)
  Tugas? get _fokus {
    for (final t in _dekat) {
      if (!t.selesai) return t;
    }
    return _lewat.isEmpty ? null : _lewat.first;
  }

  /// true bila tugas ini sudah selesai menurut data.
  /// dipakai di _kartuTugas, _barisTugas
  bool _selesaiDiLayar(Tugas tg) => tg.selesai;

  /// Menyaring daftar tugas dengan kata kunci aktif.
  /// dipakai di _hasilCari
  List<Tugas> _saringTugas(List<Tugas> sumber) {
    if (_kata.isEmpty) return sumber;
    return sumber.where((tg) {
      final teks = '${tg.judul} ${tg.deskripsi ?? ''} ${tg.namaMapel ?? ''}'
          .toLowerCase();
      return teks.contains(_kata);
    }).toList();
  }

  /// Menyaring daftar catatan dengan kata kunci aktif.
  /// dipakai di _hasilCari
  List<Materi> _saringCatatan(List<Materi> sumber) {
    if (_kata.isEmpty) return sumber;
    return sumber.where((m) {
      final teks = '${m.judul} ${m.isi ?? ''} ${m.namaMapel ?? ''}'
          .toLowerCase();
      return teks.contains(_kata);
    }).toList();
  }

  /// Menyaring daftar mapel dengan kata kunci aktif.
  /// dipakai di _hasilCari
  List<Mapel> _saringMapel(List<Mapel> sumber) {
    if (_kata.isEmpty) return sumber;
    return sumber.where((m) {
      final teks = '${m.nama} ${m.deskripsi ?? ''}'.toLowerCase();
      return teks.contains(_kata);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_muat) {
      return const Center(child: CircularProgressIndicator());
    }

    final r = _ringkasan!;
    final kosongTotal = _jumlahMapel == 0;
    final fokus = _fokus;

    return RefreshIndicator(
      onRefresh: _segarkan,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Jarak.j14,
          Jarak.j14,
          Jarak.j14,
          Jarak.j14 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          // ── 1. Sapaan + tanggal ────────────────────────────
          Text(
            _sapaan,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Jarak.j2),
          Text(
            tp('home_pada_tenggat', {'tgl': tanggalPendek(_kini)}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Jarak.j16),

          // ── 2. Kotak cari ──────────────────────────────────
          TextField(
            controller: _kendaliCari,
            onChanged: (v) => setState(() => _kata = v.trim().toLowerCase()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t('home_cari'),
              prefixIcon: const Icon(Icons.search, size: Ikon.sm),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: Jarak.j12,
                horizontal: Jarak.j12,
              ),
              suffixIcon: _kata.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: Ikon.sm),
                      tooltip: t('batal'),
                      onPressed: () {
                        _kendaliCari.clear();
                        setState(() => _kata = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: Jarak.j18),

          // ── 3. Ringkasan angka ─────────────────────────────
          Row(
            children: [
              _angka(
                context,
                '${r.belum}',
                t('home_belum'),
                Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: Jarak.j10),
              _angka(
                context,
                '${r.selesai}',
                t('home_selesai'),
                const Color(0xFF2E7D53),
              ),
              const SizedBox(width: Jarak.j10),
              _angka(
                context,
                '${r.lewat}',
                t('home_lewat'),
                Theme.of(context).colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: Jarak.j20),

          if (kosongTotal) ...[
            Kosong(
              ikon: Icons.auto_stories_outlined,
              judul: t('home_kosong_judul'),
              pesan: t('home_kosong_pesan'),
              labelTombol: t('home_kosong_tombol'),
              onTombol: widget.onBukaAcademic,
            ),
          ] else if (_kata.isNotEmpty) ...[
            _hasilCari(context),
          ] else ...[
            // ── 4. Fokus hari ini ────────────────────────────
            if (fokus != null) ...[
              _kepala(
                context,
                t('home_fokus'),
                Icons.local_fire_department_outlined,
                warna: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Jarak.j8),
              _kartuFokus(context, fokus),
              const SizedBox(height: Jarak.j18),
            ],

            // ── 5. Lewat tenggat ─────────────────────────────
            if (_lewat.isNotEmpty) ...[
              _kepala(
                context,
                t('home_lewat_judul'),
                Icons.warning_amber_rounded,
                warna: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: Jarak.j8),
              for (final t2 in _lewat.take(3))
                _barisTugas(context, t2, lewat: true),
              const SizedBox(height: Jarak.j18),
            ],

            // ── 6. Tenggat terdekat, dua kolom ───────────────
            _kepala(context, t('home_dekat_judul'), Icons.schedule_outlined),
            const SizedBox(height: Jarak.j8),
            if (_tampilDekat.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Jarak.j16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: Jarak.j10),
                      Expanded(child: Text(t('home_tanpa_dekat'))),
                    ],
                  ),
                ),
              )
            else
              ..._duaKolom([
                for (final t2 in _tampilDekat) _kartuTugas(context, t2),
              ]),

            // ── 7. Mata pelajaran 2×2 ────────────────────────
            const SizedBox(height: Jarak.j8),
            _kepala(
              context,
              t('home_subjek_judul'),
              Icons.menu_book_outlined,
              onLihatSemua: widget.onBukaAcademic,
            ),
            const SizedBox(height: Jarak.j8),
            ..._duaKolom([
              for (final m in _mapel.take(4)) _kartuMapel(context, m),
            ]),

            // ── 8. Catatan terbaru ───────────────────────────
            if (_catatan.isNotEmpty) ...[
              const SizedBox(height: Jarak.j8),
              _kepala(
                context,
                t('home_catatan_judul'),
                Icons.sticky_note_2_outlined,
                onLihatSemua: widget.onBukaAcademic,
              ),
              const SizedBox(height: Jarak.j8),
              for (final m in _catatan.take(3)) _kartuCatatan(context, m),
            ],
          ],
        ],
      ),
    );
  }

  /// Blok hasil pencarian: tugas dan catatan yang cocok dengan kata kunci.
  /// dipakai di build (saat _kata tidak kosong)
  Widget _hasilCari(BuildContext c) {
    final tugas = _saringTugas([..._tampilDekat, ..._lewat]);
    final catatan = _saringCatatan(_catatan);
    final mapel = _saringMapel(_mapel);

    if (tugas.isEmpty && catatan.isEmpty && mapel.isEmpty) {
      return Kosong(
        ikon: Icons.search_off,
        judul: t('ak_tidak_ditemukan'),
        pesan: t('ak_coba_kata'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kepala(c, t('home_hasil'), Icons.search),
        if (tugas.isNotEmpty) ...[
          const SizedBox(height: Jarak.j8),
          ..._duaKolom([for (final tg in tugas) _kartuTugas(c, tg)]),
        ],
        if (mapel.isNotEmpty) ...[
          const SizedBox(height: Jarak.j8),
          _kepala(c, t('home_subjek_judul'), Icons.menu_book_outlined),
          const SizedBox(height: Jarak.j8),
          ..._duaKolom([for (final m in mapel) _kartuMapel(c, m)]),
        ],
        if (catatan.isNotEmpty) ...[
          const SizedBox(height: Jarak.j8),
          _kepala(c, t('home_catatan_judul'), Icons.sticky_note_2_outlined),
          const SizedBox(height: Jarak.j8),
          for (final m in catatan.take(6)) _kartuCatatan(c, m),
        ],
      ],
    );
  }

  /// Membagi daftar kartu menjadi baris dua kolom dengan tinggi seragam.
  /// dipakai di build (dekat, subjects), _hasilCari
  List<Widget> _duaKolom(List<Widget> kartu) {
    final hasil = <Widget>[];
    for (var i = 0; i < kartu.length; i += 2) {
      final kiri = kartu[i];
      final kanan = i + 1 < kartu.length ? kartu[i + 1] : null;
      hasil.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kiri),
              const SizedBox(width: Jarak.j10),
              Expanded(child: kanan ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
      if (i + 2 < kartu.length) hasil.add(const SizedBox(height: Jarak.j10));
    }
    return hasil;
  }

  /// Judul seksi dengan ikon, dan tautan "Lihat semua" bila diminta.
  /// dipakai di build (6x: fokus, lewat, dekat, subjek, catatan), _hasilCari
  Widget _kepala(
    BuildContext c,
    String teks,
    IconData ikon, {
    Color? warna,
    VoidCallback? onLihatSemua,
  }) {
    final skema = Theme.of(c).colorScheme;
    return Row(
      children: [
        Icon(ikon, size: Ikon.sm, color: warna ?? skema.onSurfaceVariant),
        const SizedBox(width: Jarak.j8),
        Expanded(
          child: Text(
            teks,
            style: Theme.of(c).textTheme.titleSmall?.copyWith(
              color: warna ?? skema.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onLihatSemua != null)
          TextButton(
            onPressed: onLihatSemua,
            child: Text(t('home_lihat_semua')),
          ),
      ],
    );
  }

  /// Kartu besar untuk tugas paling mendesak ("Fokus hari ini").
  /// dipakai di build (fokus section)
  Widget _kartuFokus(BuildContext c, Tugas tg) {
    final skema = Theme.of(c).colorScheme;
    final lewat = tg.lewatTenggat;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Jarak.j16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tg.judul,
                    style: Theme.of(c).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Tanda(
                  teks: tenggatRelatif(tg.tenggat),
                  warna: lewat ? skema.error : skema.primary,
                ),
              ],
            ),
            const SizedBox(height: Jarak.j6),
            Text(
              tg.namaMapel ?? t('home_tanpa_mapel'),
              style: Theme.of(c).textTheme.bodySmall
                  ?.copyWith(color: skema.onSurfaceVariant),
            ),
            if ((tg.deskripsi ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: Jarak.j8),
              Text(
                tg.deskripsi!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: Jarak.j12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _tandai(tg, selesai: true),
                icon: const Icon(Icons.check, size: Ikon.sm),
                label: Text(t('dm_tandai_selesai')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu tugas dua kolom (wireframe "Upcoming").
  /// dipakai di build (tenggat terdekat), _hasilCari (hasil tugas)
  Widget _kartuTugas(BuildContext c, Tugas tg) {
    final skema = Theme.of(c).colorScheme;
    final selesai = _selesaiDiLayar(tg);
    final lewat = tg.lewatTenggat;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: tg.id == null ? null : () => _tandai(tg, selesai: !selesai),
        borderRadius: BorderRadius.circular(Sudut.r14),
        child: Padding(
          padding: const EdgeInsets.all(Jarak.j12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tg.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(c).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: selesai ? TextDecoration.lineThrough : null,
                        color: selesai ? skema.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: Jarak.j6),
                  Icon(
                    selesai ? Icons.check_circle : Icons.check_circle_outline,
                    size: Ikon.cek,
                    color: selesai ? skema.primary : skema.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: Jarak.j6),
              Text(
                tg.namaMapel ?? t('home_tanpa_mapel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c).textTheme.bodySmall
                    ?.copyWith(color: skema.onSurfaceVariant),
              ),
              const Spacer(),
              Tanda(
                teks: selesai ? t('home_selesai') : tenggatRelatif(tg.tenggat),
                warna: selesai
                    ? skema.primary
                    : (lewat ? skema.error : skema.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu mata pelajaran dua kolom (wireframe "Subjects").
  /// dipakai di build (subjects grid), _hasilCari
  Widget _kartuMapel(BuildContext c, Mapel m) {
    final skema = Theme.of(c).colorScheme;
    final warna = TemaApp.dariHex(m.warna, cadangan: skema.primary);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(
          c,
        ).push(MaterialPageRoute(builder: (_) => HalamanDetailMapel(mapel: m))),
        borderRadius: BorderRadius.circular(Sudut.r14),
        child: Padding(
          padding: const EdgeInsets.all(Jarak.j12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: Ikon.xs, color: warna),
                  const SizedBox(width: Jarak.j8),
                  Expanded(
                    child: Text(
                      m.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(c).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Jarak.j6),
              Text(
                '${tp('k_n_materi', {'n': '${m.jumlahMateri}'})} · '
                '${tp('k_n_tugas', {'n': '${m.jumlahTugas}'})}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c).textTheme.labelSmall
                    ?.copyWith(color: skema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu satu catatan terbaru (wireframe "Recent Notes").
  /// dipakai di build (catatan terbaru), _hasilCari
  Widget _kartuCatatan(BuildContext c, Materi m) {
    final skema = Theme.of(c).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: Jarak.j8),
      child: ListTile(
        leading: Container(
          width: Ukuran.kotakIkon,
          height: Ukuran.kotakIkon,
          decoration: BoxDecoration(
            color: skema.primary.withValues(alpha: Opasitas.lembut),
            borderRadius: BorderRadius.circular(Sudut.r10),
          ),
          child: Icon(
            Icons.article_outlined,
            size: Ukuran.kotakIkon / 2,
            color: skema.primary,
          ),
        ),
        title: Text(m.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          m.namaMapel ?? t('home_tanpa_mapel'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Kartu angka ringkasan (belum/selesai/lewat) — 3 kartu berdampingan.
  /// dipakai di build (3x: belum, selesai, lewat)
  Widget _angka(BuildContext c, String angka, String label, Color warna) {
    final skema = Theme.of(c).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Jarak.j14,
            horizontal: Jarak.j8,
          ),
          child: Column(
            children: [
              Text(
                angka,
                style: Theme.of(c).textTheme.headlineSmall
                    ?.copyWith(color: warna, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Jarak.j2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(c).textTheme.labelSmall
                    ?.copyWith(color: skema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Satu baris tugas dengan checkbox (dipakai blok lewat tenggat).
  /// dipakai di build (lewat tenggat section)
  Widget _barisTugas(BuildContext c, Tugas tg, {bool lewat = false}) {
    final skema = Theme.of(c).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: Jarak.j8),
      child: ListTile(
        onTap: tg.selesai ? null : () => _tandai(tg, selesai: true),
        leading: Checkbox(
          value: tg.selesai,
          onChanged: (v) => _tandai(tg, selesai: v ?? false),
        ),
        title: Text(
          tg.judul,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tg.selesai
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: skema.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Text(
          tg.namaMapel ?? t('home_tanpa_mapel'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: tg.selesai
            ? Tanda(teks: t('home_selesai'), warna: skema.primary)
            : Tanda(
                teks: tenggatRelatif(tg.tenggat),
                warna: lewat ? skema.error : skema.primary,
              ),
      ),
    );
  }
}
