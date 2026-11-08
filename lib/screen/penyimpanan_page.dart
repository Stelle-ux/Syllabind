import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'package:syllabind/function/lampiran.dart';
import 'package:syllabind/function/mapel.dart';
import 'package:syllabind/services/index.dart';
import 'package:syllabind/tools/index.dart';

/// Halaman 3 — **Library** (dulu bernama "Penyimpanan").
///
/// Berisi **hanya Lampiran** (Gambar + File) dari seluruh mapel, rekapitulasi
/// ukuran, tombol **+ Tambah** untuk memasukkan gambar/file langsung dari
/// halaman ini, dan opsi per-item: **Lihat**, **Ganti nama**, **Hapus**.
///
/// Ekspor `.txt` sengaja TIDAK ada di sini lagi — ekspor dilakukan
/// per-catatan dari halaman Detail Mapel, karena Library ini soal berkas,
/// bukan soal catatan.
///
/// Nama kelas tetap `HalamanPenyimpanan` supaya tidak memaksa perubahan di
/// `main.dart` dan berkas tes; yang berubah hanya label yang dilihat pengguna.
///
/// **Reused in:** [main.dart] (NavigationBar index 2)
/// **Calls:** [_HalamanPenyimpananState]
class HalamanPenyimpanan extends StatefulWidget {
  const HalamanPenyimpanan({super.key});

  @override
  State<HalamanPenyimpanan> createState() => _HalamanPenyimpananState();
}

/// State untuk [HalamanPenyimpanan].
///
/// Mengelola:
/// - Daftar semua lampiran (_data) + loading (_muat)
/// - Filter tipe (_saring: SEMUA/GAMBAR/FILE)
/// - Total ukuran (_totalByte)
/// - Tambah lampiran via galeri/file picker (_tambahLampiran)
/// - Pilih mapel tujuan (_pilihMapel)
/// - Ambil berkas dari perangkat (_ambilBerkas)
/// - Hapus lampiran (_konfirmasiHapus)
/// - Buka lampiran dengan aplikasi luar (_buka)
/// - Ganti nama lampiran (_ubahNamaLampiran)
/// - Statistik kartu (_statistik) + format ukuran (_ukuran)
///
/// **Reused in:** [HalamanPenyimpanan.createState]
/// **Calls:** [LampiranRepo], [MapelRepo], [ImagePicker], [FilePicker], [OpenFilex], [Kosong], [konfirmasi], [pesanSukses], [pesanGagal], [t], [tp]
class _HalamanPenyimpananState extends State<HalamanPenyimpanan> {
  final _repo = LampiranRepositoryImpl();
  final _mapelRepo = MapelRepositoryImpl();

  /// Kendali kotak pencarian berkas (wireframe layar 6). Disimpan di State
  /// supaya isinya tidak hilang saat daftar disegarkan.
  final _cariCtrl = TextEditingController();

  List<Lampiran> _data = [];
  bool _muat = true;
  String _saring = 'SEMUA';
  String _kata = '';
  bool _sibuk = false;

  /// Angka rekapitulasi, dihitung database — bukan dihitung ulang dari daftar
  /// yang sudah dimuat. [LampiranRepo.jumlahPerTipe] dan
  /// [LampiranRepo.totalUkuran] memakai klausa saring yang sama dengan
  /// [LampiranRepo.semua], jadi hasilnya identik; bedanya hanya satu tempat
  /// yang menghitung.
  int _jumlahGambar = 0;
  int _jumlahFile = 0;
  int _totalByte = 0;

  @override
  void initState() {
    super.initState();
    _cariCtrl.addListener(() {
      final kata = _cariCtrl.text.trim().toLowerCase();
      if (kata == _kata) return;
      setState(() => _kata = kata);
    });
    _segarkan();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  /// Memuat ulang daftar semua lampiran dari database.
  ///
  /// Dipanggil di initState dan setelah setiap mutasi (tambah/hapus/ubah nama).
  ///
  /// **Reused in:** [initState], [_tambahLampiran], [_konfirmasiHapus], [build] (RefreshIndicator onRefresh)
  /// **Calls:** [LampiranRepo.semua], [setState]
  Future<void> _segarkan() async {
    setState(() => _muat = true);
    final d = await _repo.semua();
    final perTipe = await _repo.jumlahPerTipe();
    final total = await _repo.totalUkuran();
    if (!mounted) return;
    setState(() {
      _data = d;
      _jumlahGambar = perTipe[Lampiran.tipeGambar] ?? 0;
      _jumlahFile = perTipe[Lampiran.tipeFile] ?? 0;
      _totalByte = total;
      _muat = false;
    });
  }

  /// Daftar lampiran yang sudah difilter sesuai [_saring].
  ///
  /// - 'SEMUA': semua lampiran
  /// - 'GAMBAR': hanya lampiran.gambar == true
  /// - 'FILE': hanya lampiran.gambar == false
  ///
  /// **Reused in:** [build] (itemCount, isEmpty check, _totalByte)
  /// **Calls:** [_data.where]
  List<Lampiran> get _tampil {
    Iterable<Lampiran> hasil = _data;
    if (_saring == 'GAMBAR') {
      hasil = hasil.where((l) => l.gambar);
    } else if (_saring == 'FILE') {
      hasil = hasil.where((l) => !l.gambar);
    }
    if (_kata.isNotEmpty) {
      hasil = hasil.where((l) => l.namaFile.toLowerCase().contains(_kata));
    }
    return hasil.toList();
  }

  /// Membuka lampiran memakai aplikasi bawaan perangkat.
  ///
  /// Gambar/file diserahkan ke aplikasi lain lewat [OpenFilex]; kalau tidak
  /// ada aplikasi yang bisa menangani, pengguna diberi tahu alih-alih
  /// aplikasi diam saja.
  ///
  /// **Reused in:** [build] (PopupMenuButton onSelected 'lihat')
  /// **Calls:** [OpenFilex.open], [tp], [pesanGagal]
  Future<void> _buka(Lampiran l) async {
    try {
      final hasil = await OpenFilex.open(l.lokasiFile);
      if (!mounted) return;
      // 'done' = berkas berhasil diserahkan ke aplikasi lain.
      if (hasil.type != ResultType.done) {
        pesanGagal(context, tp('lib_buka_gagal', {'e': hasil.message}));
      }
    } catch (e) {
      if (!mounted) return;
      pesanGagal(context, tp('lib_buka_gagal', {'e': '$e'}));
    }
  }

  /// Mengganti nama tampilan lampiran (nama di database, bukan nama di disk).
  ///
  /// Berkas fisik sengaja TIDAK di-rename supaya tautan ke berkas tetap sah
  /// walau penggantian nama gagal di tengah jalan.
  ///
  /// **Reused in:** [build] (PopupMenuButton onSelected 'rename')
  /// **Calls:** [tanyaTeks], [LampiranRepo.ubahNama], [_segarkan], [pesanSukses]
  Future<void> _ubahNamaLampiran(Lampiran l) async {
    final hasil = await tanyaTeks(
      context,
      judul: t('lib_ubah_nama_judul'),
      labelJudul: t('lib_ubah_nama_label'),
      nilaiJudul: l.namaFile,
    );
    if (hasil == null) return;
    final namaBaru = (hasil['judul'] as String?)?.trim();
    if (namaBaru == null || namaBaru.isEmpty) return;
    await _repo.ubahNama(l.id!, namaBaru);
    await _segarkan();
    if (!mounted) return;
    pesanSukses(context, t('lib_ubah_nama_sukses'));
  }

  // ───────────────────────────────────────────────────────────
  // Tambah lampiran
  // ───────────────────────────────────────────────────────────

  /// Menampilkan pilihan sumber: gambar (galeri) atau file dokumen.
  ///
  /// Alur:
  /// 1. Bottom sheet pilih sumber (gambar/file)
  /// 2. Validasi ada mapel (via [MapelRepo.semua])
  /// 3. Bottom sheet pilih mapel tujuan ([_pilihMapel])
  /// 4. Ambil berkas dari perangkat ([_ambilBerkas])
  /// 5. Simpan via [LampiranRepo.tambahKeMapel]
  /// 6. Segarkan daftar & tampilkan pesan sukses/gagal
  ///
  /// **Reused in:** [build] (FilledButton onPressed, Kosong onTombol)
  /// **Calls:** [showModalBottomSheet], [MapelRepo.semua], [_pilihMapel], [_ambilBerkas], [LampiranRepo.tambahKeMapel], [_segarkan], [pesanSukses], [pesanGagal], [tp], [t], [Platform.pathSeparator]
  Future<void> _tambahLampiran() async {
    final sumber = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.j16, 0, Jarak.j16, Jarak.j4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t('lib_tambah'),
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(t('lib_pilih_gambar')),
              onTap: () => Navigator.pop(ctx, 'gambar'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(t('lib_pilih_file')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: Jarak.j8),
          ],
        ),
      ),
    );
    if (sumber == null || !mounted) return;

    // Lampiran selalu menempel pada sebuah mapel.
    final mapelList = await _mapelRepo.semua();
    if (!mounted) return;
    if (mapelList.isEmpty) {
      pesanGagal(context, t('lib_mapel_kosong'));
      return;
    }

    final mapelId = await _pilihMapel(mapelList);
    if (mapelId == null || !mounted) return;

    final berkas = await _ambilBerkas(sumber);
    if (berkas == null || !mounted) return;

    setState(() => _sibuk = true);
    try {
      await _repo.tambahKeMapel(
        mapelId: mapelId,
        sumber: berkas,
        tipe: sumber == 'gambar'
            ? Lampiran.tipeGambar
            : Lampiran.tipeFile,
      );
      await _segarkan();
      if (!mounted) return;
      pesanSukses(
        context,
        tp('lib_berhasil', {'nama': berkas.path.split(Platform.pathSeparator).last}),
      );
    } catch (e) {
      if (!mounted) return;
      pesanGagal(context, tp('lib_gagal', {'e': '$e'}));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Lembar pilih mapel tujuan. Null bila pengguna membatalkan.
  ///
  /// Menampilkan daftar mapel sebagai ListTile, mengembalikan mapel.id
  /// saat ditekan, atau null jika dibatalkan (back/outside tap).
  ///
  /// **Reused in:** [_tambahLampiran]
  /// **Calls:** [showModalBottomSheet], [Navigator.pop]
  Future<int?> _pilihMapel(List<Mapel> daftar) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.j16, 0, Jarak.j16, Jarak.j4),
              child: Text(
                t('lib_pilih_mapel'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Jarak.j16, 0, Jarak.j16, Jarak.j8),
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

  /// Mengambil berkas dari perangkat sesuai pilihan sumber.
  ///
  /// - 'gambar': [ImagePicker.pickImage] dari galeri
  /// - 'file': [FilePicker.platform.pickFiles] dokumen
  ///
  /// Mengembalikan File atau null jika dibatalkan.
  ///
  /// **Reused in:** [_tambahLampiran]
  /// **Calls:** [ImagePicker.pickImage], [FilePicker.platform.pickFiles], [File]
  Future<File?> _ambilBerkas(String sumber) async {
    if (sumber == 'gambar') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      return picked == null ? null : File(picked.path);
    }
    final hasil = await FilePicker.platform.pickFiles();
    final path = hasil?.files.single.path;
    return path == null ? null : File(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Rekapitulasi penyimpanan.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(Jarak.j16, Jarak.j14, Jarak.j16, Jarak.j14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: _statistik(
                    context,
                    t('lib_gambar'),
                    '$_jumlahGambar',
                    Icons.image_outlined,
                  ),
                ),
                Expanded(
                  child: _statistik(
                    context,
                    t('lib_file'),
                    '$_jumlahFile',
                    Icons.insert_drive_file_outlined,
                  ),
                ),
                Expanded(
                  child: _statistik(
                    context,
                    t('lib_total'),
                    _ukuran(_totalByte),
                    Icons.sd_storage_outlined,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Jarak.j14,
              Jarak.j12,
              Jarak.j14,
              0,
            ),
            child: _KotakCariBerkas(ctrl: _cariCtrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Jarak.j14, Jarak.j12, Jarak.j14, Jarak.j4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'SEMUA', label: Text(t('lib_semua'))),
                  ButtonSegment(value: 'GAMBAR', label: Text(t('lib_gambar'))),
                  ButtonSegment(value: 'FILE', label: Text(t('lib_file'))),
                ],
                selected: {_saring},
                onSelectionChanged: (s) => setState(() => _saring = s.first),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Jarak.j14, Jarak.j6, Jarak.j14, Jarak.j4),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sibuk ? null : _tambahLampiran,
                    icon: _sibuk
                        ? const SizedBox(
                            width: Ukuran.pemuat,
                            height: Ukuran.pemuat,
                            child: CircularProgressIndicator(strokeWidth: Ukuran.pemuatTebal),
                          )
                        : const Icon(Icons.add, size: Ikon.sm),
                    label: Text(t('lib_tambah')),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _muat
                ? const Center(child: CircularProgressIndicator())
                : _tampil.isEmpty
                    ? Kosong(
                        ikon: Icons.folder_open_outlined,
                        judul: t('lib_kosong_judul'),
                        pesan: t('lib_kosong_pesan'),
                        labelTombol: t('lib_tambah'),
                        onTombol: _tambahLampiran,
                      )
                    : RefreshIndicator(
                        onRefresh: _segarkan,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            Jarak.j14,
                            Jarak.j10,
                            Jarak.j14,
                            Jarak.j14 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          itemCount: _tampil.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Jarak.j10),
                          itemBuilder: (_, i) {
                            final l = _tampil[i];
                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  l.gambar
                                      ? Icons.image_outlined
                                      : Icons.insert_drive_file_outlined,
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
                                // Ketuk baris = buka berkas (aksi utama).
                                onTap: () => _buka(l),
                                trailing: PopupMenuButton<String>(
                                  tooltip: t('k_ubah_tooltip'),
                                  onSelected: (v) {
                                    if (v == 'lihat') _buka(l);
                                    if (v == 'rename') _ubahNamaLampiran(l);
                                    if (v == 'hapus') _konfirmasiHapus(l);
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'lihat',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                        title: Text(t('k_lihat')),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.drive_file_rename_outline,
                                        ),
                                        title: Text(t('k_rename')),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'hapus',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.delete_outline,
                                        ),
                                        title: Text(t('k_hapus_tooltip')),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// Konfirmasi hapus lampiran lalu hapus dari repo & segarkan.
  ///
  /// Menampilkan dialog via [konfirmasi] dengan nama file.
  /// File asli di perangkat tidak terhapus (hanya salinan internal).
  ///
  /// **Reused in:** [build] (ListTile trailing IconButton onPressed)
  /// **Calls:** [konfirmasi], [tp], [LampiranRepo.hapus], [_segarkan]
  Future<void> _konfirmasiHapus(Lampiran l) async {
    final ya = await konfirmasi(
      context,
      judul: tp('lib_hapus_judul', {'nama': l.namaFile}),
      pesan: t('lib_hapus_pesan'),
    );
    if (ya != true) return;
    await _repo.hapus(l.id!);
    await _segarkan();
  }

  /// Kartu statistik kecil untuk header (jumlah gambar, file, total ukuran).
  ///
  /// **Reused in:** [build] (3x di Row header)
  /// **Calls:** [Icon], [Text], [Theme.of]
  Widget _statistik(
    BuildContext c,
    String label,
    String nilai,
    IconData ikon,
  ) {
    return Column(
      children: [
        Icon(ikon, size: Ikon.sm, color: Theme.of(c).colorScheme.primary),
        const SizedBox(height: Jarak.j4),
        Text(nilai, style: Theme.of(c).textTheme.titleMedium),
        Text(label, style: Theme.of(c).textTheme.labelSmall),
      ],
    );
  }

  /// Format ukuran byte ke string human-readable (B, KB, MB).
  ///
  /// Static method, tidak bergantung state.
  ///
  /// **Reused in:** [build] (_statistik untuk total), [_totalByte getter]
  /// **Calls:** (none - pure computation)
  static String _ukuran(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Kotak cari berkas di halaman Library.
///
/// Menyaring **daftar yang sudah dimuat** saja (di dalam memori), bukan
/// query baru ke database — daftar lampiran biasanya kecil dan hasilnya
/// langsung terasa saat mengetik.
///
/// **Reused in:** [HalamanPenyimpanan.build]
/// **Calls:** [TextField], [t]
class _KotakCariBerkas extends StatelessWidget {
  const _KotakCariBerkas({required this.ctrl});

  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t('lib_cari'),
        prefixIcon: const Icon(Icons.search, size: Ikon.sm),
        isDense: true,
        suffixIcon: ctrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: t('k_bersihkan'),
                icon: const Icon(Icons.close, size: Ikon.sm),
                onPressed: ctrl.clear,
              ),
      ),
    );
  }
}