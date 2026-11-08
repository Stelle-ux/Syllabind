import 'package:flutter/material.dart';

import 'package:syllabind/services/skema_db.dart';
import 'package:syllabind/function/hasil_bersih.dart';
import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/function/materi.dart';
import 'package:syllabind/function/ringkasan_tugas.dart';
import 'package:syllabind/function/tugas.dart';
import 'package:syllabind/services/mapel_repository_impl.dart';
import 'package:syllabind/services/materi_repository_impl.dart';
import 'package:syllabind/services/tugas_repository_impl.dart';
import 'package:syllabind/services/mapel_repository.dart';
import 'package:syllabind/services/materi_repository.dart';
import 'package:syllabind/services/tugas_repository.dart';
import 'package:syllabind/screen/detail_mapel_page.dart';
import 'package:syllabind/tools/bahasa.dart';
import 'package:syllabind/tools/tema.dart';
import 'package:syllabind/tools/tokens.dart';
import 'package:syllabind/tools/tanggal.dart';
import 'package:syllabind/tools/kartu_mapel.dart';
import 'package:syllabind/tools/kosong.dart';
import 'package:syllabind/tools/tanda.dart';

/// Halaman 1 — Home / Hari Ini.
///
/// Susunan mengikuti `syllabind-wireframe/ukom_mobile_layout_wireframe.drawio`
/// (layar 1 "UKOM Mobile Dashboard"), dengan dua blok tambahan yang diminta
/// `SPESIFIKASI-FINAL.md` §2.1 poin 9 (lewat tenggat + tugas bertenggat dekat):
///
///   1. Sapaan + tanggal          (wireframe: "Alex / Today, Oct 24")
///   2. Kotak cari                (wireframe: "[Q] Search...")
///   3. Tiga angka ringkasan      (tambahan — sudah sesuai spesifikasi)
///   4. Fokus hari ini            (wireframe: "Today's Focus")
///   5. Lewat tenggat             (tambahan — spesifikasi §2.1 poin 9)
///   6. Tenggat terdekat          (wireframe: "Upcoming", 2 kolom)
///   7. Mata pelajaran 2×2        (wireframe: "Subjects" + View all)
///   8. Catatan terbaru           (wireframe: "Recent Notes" + View all)
///
/// Semua isi berasal dari repository — tidak ada data yang ditulis di layar.
///
/// **Reused in:** [main.dart] (RumahAplikasi halaman[0])
/// **Calls:** [MapelRepository], [TugasRepository], [MateriRepository], [Kosong], [Tanda], [HalamanDetailMapel], [_kepala], [_duaKolom], [_kartuFokus], [_kartuTugas], [_kartuMapel], [_barisTugas], [_angka], [t], [tp], [tanggalPendek], [tenggatRelatif]
class HalamanHome extends StatefulWidget {
  /// Waktu yang dipakai untuk sapaan dan tanggal header; `null` = waktu perangkat.
  ///
  /// Dipakai tes supaya tangkapan layar Golden Home tidak gagal hanya karena
  /// waktu berjalan. Dua hal ikut bergerak bersama waktu:
  ///   1. sapaan (pagi → siang → sore → malam), dan
  ///   2. tanggal header (berubah setiap pergantian hari).
  /// Memaketkan jam saja tidak cukup — golden tetap gagal esok hari.
  /// `addTearDown` di tes mengembalikannya ke `null` setelah selesai.
  static DateTime? waktuUji;

  /// Callback untuk navigasi ke tab Academic saat belum ada mapel.
  final VoidCallback onBukaAcademic;

  const HalamanHome({super.key, required this.onBukaAcademic});

  @override
  State<HalamanHome> createState() => _HalamanHomeState();
}

class _HalamanHomeState extends State<HalamanHome> {
  late final MapelRepository _mapelRepo;
  late final TugasRepository _tugasRepo;
  late final MateriRepository _materiRepo;

  /// Pengendali kotak cari. Perlu di-dispose agar tidak bocor.
  final _kendaliCari = TextEditingController();

  /// Kata kunci pencarian aktif (sudah dipangkas & dihuruf-kecilkan).
  String _kata = '';

  RingkasanTugas? _ringkasan;
  List<Tugas> _dekat = [];

  /// Tugas yang baru saja ditandai selesai dari layar ini.
  ///
  /// Penandaan bersifat optimistis — nilainya langsung berubah saat diketuk,
  /// tanpa menunggu halaman dibangun ulang. Id di sini yang membuat baris
  /// tetap tampil (tercoret) sampai penyegaran selesai, sehingga pengguna
  /// punya kesempatan menekan **Urungkan**.
  final Set<int> _pilihanSelesai = {};
  List<Tugas> _lewat = [];
  List<Materi> _catatan = [];
  List<Mapel> _mapel = [];
  int _jumlahMapel = 0;
  bool _muat = true;

  @override
  void initState() {
    super.initState();
    _mapelRepo = MapelRepositoryImpl();
    _tugasRepo = TugasRepositoryImpl();
    _materiRepo = MateriRepositoryImpl();
    _segarkan();
  }

  @override
  void dispose() {
    _kendaliCari.dispose();
    super.dispose();
  }

  /// Memuat ulang semua data dari repository.
  ///
  /// Dipanggil di initState, pull-to-refresh, dan setelah operasi CRUD.
  /// Query berurutan: ringkasan, tenggat terdekat, lewat tenggat, jumlah mapel,
  /// daftar mapel, catatan.
  ///
  /// **Reused in:** [initState], [_tandai] (saat urungkan), [build] (RefreshIndicator.onRefresh)
  /// **Calls:** [TugasRepository.ringkasan], [TugasRepository.tenggatTerdekat], [TugasRepository.lewatTenggat], [MapelRepository.jumlah], [MapelRepository.semua], [MateriRepository.semua], [setState]
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
      _pilihanSelesai.clear();
      _muat = false;
    });
  }

  /// Daftar tenggat terdekat — termasuk yang baru ditandai selesai dari Home.
  ///
  /// `TugasRepository.tenggatTerdekat` sengaja hanya mengembalikan tugas berstatus
  /// BELUM (dipakai juga untuk hitungan di tempat lain). Di Home, baris yang
  /// baru dicentang tetap ditampilkan sesaat supaya bisa diurungkan.
  ///
  /// **Reused in:** [build] (tenggat terdekat section)
  /// **Calls:** [_dekat], [_lewat], [_pilihanSelesai]
  List<Tugas> get _tampilDekat {
    if (_pilihanSelesai.isEmpty) return _dekat;
    final idTerpilih = _dekat.map((t) => t.id).toSet();
    final tambahan = _lewat.where(
      (t) => _pilihanSelesai.contains(t.id) && !idTerpilih.contains(t.id),
    );
    return [..._dekat, ...tambahan];
  }

  /// Menandai tugas selesai / belum selesai dari Home, dengan tombol Urungkan.
  ///
  /// Optimistic UI: update lokal dulu, lalu SnackBar dengan action "Urungkan"
  /// yang memanggil _tandai lagi dengan selesai=false.
  ///
  /// **Reused in:** [_kartuFokus] (FilledButton.tonalIcon), [_kartuTugas] (ketuk kartu), [_barisTugas] (Checkbox.onChanged, ListTile.onTap)
  /// **Calls:** [TugasRepository.ubahStatus], [SkemaDb.statusSelesai], [SkemaDb.statusBelum], [setState], [_geser], [tp], [ScaffoldMessenger.showSnackBar], [_segarkan]
  Future<void> _tandai(Tugas tg, {required bool selesai}) async {
    final id = tg.id;
    if (id == null) return;

    await _tugasRepo.ubahStatus(
      id,
      selesai ? SkemaDb.statusSelesai : SkemaDb.statusBelum,
    );
    if (!mounted) return;

    final sebelum = _ringkasan;
    setState(() {
      if (selesai) {
        _pilihanSelesai.add(id);
      } else {
        _pilihanSelesai.remove(id);
      }
      // Angka ringkasan digeser langsung supaya ketukan terasa seketika;
      // nilai sebenarnya tetap datang dari query saat penyegaran.
      if (sebelum != null) {
        _ringkasan = RingkasanTugas(
          belum: _geser(sebelum.belum, selesai ? -1 : 1),
          selesai: _geser(sebelum.selesai, selesai ? 1 : -1),
          lewat: tg.lewatTenggat ? _geser(sebelum.lewat, selesai ? -1 : 1) : sebelum.lewat,
        );
      }
    });

    if (!selesai) {
      _segarkan();
      return;
    }

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
  }

  /// Geser angka ringkasan tanpa pernah membiarkannya negatif.
  int _geser(int nilai, int delta) {
    final hasil = nilai + delta;
    return hasil < 0 ? 0 : hasil;
  }

  /// Waktu acuan: waktu uji bila dipatok tes, selain itu waktu perangkat.
  DateTime get _kini => HalamanHome.waktuUji ?? DateTime.now();

  /// Sapaan sesuai jam acuan (pagi/siang/sore/malam).
  String get _sapaan {
    final jam = _kini.hour;
    if (jam < 11) return t('home_sapaan_pagi');
    if (jam < 15) return t('home_sapaan_siang');
    if (jam < 19) return t('home_sapaan_sore');
    return t('home_sapaan_malam');
  }

  /// Tugas pertama yang belum selesai dari daftar terdekat — dipakai untuk
  /// kartu "Fokus hari ini". Bila tidak ada yang mendekat, ambil dari daftar
  /// yang lewat tenggat supaya kartu tidak pernah kosong saat ada tugas.
  Tugas? get _fokus {
    for (final t in _dekat) {
      if (!t.selesai) return t;
    }
    return _lewat.isEmpty ? null : _lewat.first;
  }

  /// `true` bila tugas ini dianggap selesai di layar (termasuk yang baru
  /// dicentang dan belum tersegarkan).
  bool _selesaiDiLayar(Tugas tg) =>
      tg.selesai || (tg.id != null && _pilihanSelesai.contains(tg.id));

  /// Menyaring daftar tugas dengan kata kunci aktif.
  List<Tugas> _saringTugas(List<Tugas> sumber) {
    if (_kata.isEmpty) return sumber;
    return sumber.where((tg) {
      final teks =
          '${tg.judul} ${tg.deskripsi ?? ''} ${tg.namaMapel ?? ''}'.toLowerCase();
      return teks.contains(_kata);
    }).toList();
  }

  /// Menyaring daftar catatan dengan kata kunci aktif.
  List<Materi> _saringCatatan(List<Materi> sumber) {
    if (_kata.isEmpty) return sumber;
    return sumber.where((m) {
      final teks = '${m.judul} ${m.isi ?? ''} ${m.namaMapel ?? ''}'.toLowerCase();
      return teks.contains(_kata);
    }).toList();
  }

  /// Menyaring daftar mapel dengan kata kunci aktif.
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
        // Padding bawah dari MediaQuery, bukan angka tetap.
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
              _angka(context, '${r.belum}', t('home_belum'),
                  Theme.of(context).colorScheme.primary),
              const SizedBox(width: Jarak.j10),
              _angka(context, '${r.selesai}', t('home_selesai'),
                  const Color(0xFF2E7D53)),
              const SizedBox(width: Jarak.j10),
              _angka(context, '${r.lewat}', t('home_lewat'),
                  Theme.of(context).colorScheme.error),
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
              _kepala(context, t('home_fokus'), Icons.local_fire_department_outlined,
                  warna: Theme.of(context).colorScheme.primary),
              const SizedBox(height: Jarak.j8),
              _kartuFokus(context, fokus),
              const SizedBox(height: Jarak.j18),
            ],

            // ── 5. Lewat tenggat ─────────────────────────────
            if (_lewat.isNotEmpty) ...[
              _kepala(context, t('home_lewat_judul'), Icons.warning_amber_rounded,
                  warna: Theme.of(context).colorScheme.error),
              const SizedBox(height: Jarak.j8),
              for (final t2 in _lewat
                  .where((x) => !_pilihanSelesai.contains(x.id))
                  .take(3))
                _barisTugas(context, t2, lewat: true),
              const SizedBox(height: Jarak.j18),
            ],

            // ── 6. Tenggat terdekat, dua kolom (wireframe: Upcoming)
            _kepala(context, t('home_dekat_judul'), Icons.schedule_outlined),
            const SizedBox(height: Jarak.j8),
            if (_tampilDekat.isEmpty)
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(Jarak.j16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: Jarak.j10),
                    Expanded(child: Text(t('home_tanpa_dekat'))),
                  ],
                ),
              ))
            else
              ..._duaKolom([
                for (final t2 in _tampilDekat) _kartuTugas(context, t2),
              ]),

            // ── 7. Mata pelajaran 2×2 (wireframe: Subjects) ──
            const SizedBox(height: Jarak.j8),
            _kepala(context, t('home_subjek_judul'), Icons.menu_book_outlined,
                onLihatSemua: widget.onBukaAcademic),
            const SizedBox(height: Jarak.j8),
            ..._duaKolom([
              for (final m in _mapel.take(4)) _kartuMapel(context, m),
            ]),

            // ── 8. Catatan terbaru (wireframe: Recent Notes) ─
            if (_catatan.isNotEmpty) ...[
              const SizedBox(height: Jarak.j8),
              _kepala(context, t('home_catatan_judul'),
                  Icons.sticky_note_2_outlined,
                  onLihatSemua: widget.onBukaAcademic),
              const SizedBox(height: Jarak.j8),
              for (final m in _catatan.take(3)) _kartuCatatan(context, m),
            ],
          ],
        ],
      ),
    );
  }

  /// Blok hasil pencarian: tugas dan catatan yang cocok dengan kata kunci.
  ///
  /// Dipakai saat kotak cari terisi. Bila tidak ada yang cocok, tampilkan
  /// keadaan kosong yang sudah ada (`ak_tidak_ditemukan`).
  ///
  /// **Reused in:** [build] (saat _kata tidak kosong)
  /// **Calls:** [_saringTugas], [_saringCatatan], [_saringMapel], [_kepala], [_kartuTugas], [_kartuCatatan], [_kartuMapel], [_duaKolom], [Kosong]
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
  ///
  /// Dipakai blok "Tenggat terdekat", "Mata pelajaran", dan hasil pencarian.
  /// Jumlah kartu sedikit (maksimal 6), jadi [IntrinsicHeight] aman dan
  /// membuat kedua kartu sebaris sama tinggi.
  ///
  /// **Reused in:** [build] (dekat, subjects), [_hasilCari]
  /// **Calls:** [IntrinsicHeight], [Row], [Expanded]
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
  ///
  /// **Reused in:** [build] (6x: fokus, lewat, dekat, subjek, catatan), [_hasilCari]
  /// **Calls:** [Theme.of], [Icon], [Text], [TextTheme.titleSmall], [TextButton]
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
  ///
  /// Menampilkan: judul, tenggat relatif (Tanda), nama mapel, deskripsi (opsional),
  /// tombol "Tandai selesai" yang memanggil [_tandai].
  ///
  /// **Reused in:** [build] (fokus section)
  /// **Calls:** [Tanda], [tenggatRelatif], [t], [FilledButton.tonalIcon], [_tandai]
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
                    style: Theme.of(c).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
              style: Theme.of(c).textTheme.bodySmall?.copyWith(
                    color: skema.onSurfaceVariant,
                  ),
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
  ///
  /// Ketuk kartu = tandai selesai; ketuk lagi (atau lewat **Urungkan** pada
  /// SnackBar) = kembalikan ke belum selesai.
  ///
  /// **Reused in:** [build] (tenggat terdekat), [_hasilCari] (hasil tugas)
  /// **Calls:** [Card], [InkWell], [Tanda], [tenggatRelatif], [_selesaiDiLayar], [_tandai]
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
                            decoration:
                                selesai ? TextDecoration.lineThrough : null,
                            color: selesai ? skema.onSurfaceVariant : null,
                          ),
                    ),
                  ),
                  const SizedBox(width: Jarak.j6),
                  Icon(
                    selesai
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
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
                style: Theme.of(c).textTheme.bodySmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
              ),
              // Spacer: judul boleh 1 atau 2 baris, tapi pil tenggat harus
              // rata bawah di kedua kartu sebaris. Tanpa ini pil kanan-kiri
              // berdiri di ketinggian berbeda (cacat tampilan, bukan bug data).
              const Spacer(),
              Tanda(
                teks: selesai
                    ? t('home_selesai')
                    : tenggatRelatif(tg.tenggat),
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
  ///
  /// Ketuk kartu = buka halaman detail mapel.
  ///
  /// **Reused in:** [build] (subjects grid), [_hasilCari]
  /// **Calls:** [TemaApp.dariHex], [tp], [HalamanDetailMapel], [Card], [InkWell]
  Widget _kartuMapel(BuildContext c, Mapel m) {
    final skema = Theme.of(c).colorScheme;
    final warna = TemaApp.dariHex(m.warna, cadangan: skema.primary);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(c).push(
          MaterialPageRoute(builder: (_) => HalamanDetailMapel(mapel: m)),
        ),
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
                      style: Theme.of(c).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Jarak.j6),
              Text(
                // Kunci kamus yang sudah ada — jangan hardcode "materi"/"tugas",
                // pengguna mode Inggris akan melihat teks Indonesia.
                '${tp('k_n_materi', {'n': '${m.jumlahMateri}'})} · '
                '${tp('k_n_tugas', {'n': '${m.jumlahTugas}'})}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c).textTheme.labelSmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kartu satu catatan terbaru (wireframe "Recent Notes").
  ///
  /// **Reused in:** [build] (catatan terbaru), [_hasilCari]
  /// **Calls:** [Card], [ListTile], [t]
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
        title: Text(
          m.judul,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          m.namaMapel ?? t('home_tanpa_mapel'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Kartu angka ringkasan (belum/selesai/lewat) — 3 kartu berdampingan.
  ///
  /// **Reused in:** [build] (3x: belum, selesai, lewat)
  /// **Calls:** [Theme.of], [Card], [Text], [TextTheme.headlineSmall], [TextTheme.labelSmall]
  Widget _angka(BuildContext c, String angka, String label, Color warna) {
    final skema = Theme.of(c).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Jarak.j14, horizontal: Jarak.j8),
          child: Column(
            children: [
              Text(
                angka,
                style: Theme.of(c).textTheme.headlineSmall?.copyWith(
                      color: warna,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: Jarak.j2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(c).textTheme.labelSmall?.copyWith(
                      color: skema.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Satu baris tugas dengan checkbox (dipakai blok lewat tenggat).
  ///
  /// Menandai selesai tidak langsung menghilangkan baris: tugas selesai tetap
  /// tampil (dengan judul dicoret) sampai daftar disegarkan, supaya pengguna
  /// sempat menekan **Urungkan** kalau salah ketuk.
  ///
  /// **Reused in:** [build] (lewat tenggat section)
  /// **Calls:** [Tanda], [tenggatRelatif], [t], [_tandai], [Checkbox], [ListTile]
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