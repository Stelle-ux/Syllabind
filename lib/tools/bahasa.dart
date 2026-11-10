import 'package:flutter/material.dart';

/// Pusat bahasa aplikasi: Indonesia (bawaan) dan Inggris.
/// dipakai di main.dart (ValueListenableBuilder), HalamanPengaturan._gantiBahasa, komponen.dart (t/tp calls everywhere), layanan_ekspor.dart (indirect via t/tp)
class Bahasa {
  Bahasa._();

  static const String id = 'id';
  static const String en = 'en';

  /// Bahasa yang sedang aktif.
  /// dipakai di main.dart (ValueListenableBuilder), HalamanPengaturan._gantiBahasa, t, tp, tanggalPendek, tenggatRelatif
  static final ValueNotifier<String> aktif = ValueNotifier<String>(id);

  /// true jika bahasa aktif adalah Inggris.
  /// dipakai di t, tp, tanggalPendek, tenggatRelatif, HalamanPengaturan.build (dropdown value)
  static bool get inggris => aktif.value == en;

  /// Menormalkan kode bahasa: apa pun selain en dianggap Indonesia.
  /// dipakai di set, HalamanPengaturan._gantiBahasa
  static String normal(String? kode) => kode == en ? en : id;

  /// Mengubah bahasa aktif & memicu rebuild MaterialApp via ValueNotifier.
  /// dipakai di HalamanPengaturan._gantiBahasa, main.dart (init)
  static void set(String kode) => aktif.value = normal(kode);
}

/// Mengambil teks sesuai bahasa aktif.
/// dipakai di EVERYWHERE (150+ call sites across all UI files)
String t(String kunci) {
  final baris = _kamus[kunci];
  if (baris == null) return kunci;
  return Bahasa.inggris ? baris[1] : baris[0];
}

/// Sama seperti t, tetapi mengganti penanda {nama} dengan nilai.
/// dipakai di komponen.dart (konfirmasiHitungMundur, tenggatRelatif), HalamanDetailMapel, HalamanHome, HalamanSampah, HalamanPengaturan
String tp(String kunci, Map<String, String> ganti) {
  var teks = t(kunci);
  for (final e in ganti.entries) {
    teks = teks.replaceAll('{${e.key}}', e.value);
  }
  return teks;
}

/// Tabel terjemahan.
/// dipakai di t (read-only lookup)
const Map<String, List<String>> _kamus = {
  // ── Navigasi & kerangka ──────────────────────────────────────
  'nav_home': ['Home', 'Home'],
  'nav_academic': ['Academic', 'Academic'],
  'nav_library': ['Library', 'Library'],
  'nav_pengaturan': ['Pengaturan', 'Settings'],
  'judul_app': ['Syllabind', 'Syllabind'],

  // ── Tombol umum ──────────────────────────────────────────────
  'simpan': ['Simpan', 'Save'],
  'batal': ['Batal', 'Cancel'],
  'hapus': ['Hapus', 'Delete'],
  'pulihkan': ['Pulihkan', 'Restore'],
  'tambah': ['Tambah', 'Add'],

  // ── Home / Hari Ini ─────────────────────────────────────────
  'home_belum': ['Belum selesai', 'Not done'],
  'home_selesai': ['Selesai', 'Done'],
  'home_lewat': ['Lewat tenggat', 'Overdue'],
  'home_kosong_judul': ['Belum ada mata pelajaran', 'No subjects yet'],
  'home_kosong_pesan': [
    'Tambahkan mapel dulu di tab Academic, lalu catatan dan tugasnya.',
    'Add a subject first in the Academic tab, then its notes and tasks.',
  ],
  'home_kosong_tombol': ['Buka Academic', 'Open Academic'],
  'home_lewat_judul': ['Lewat tenggat', 'Overdue'],
  'home_dekat_judul': ['Tenggat terdekat (7 hari)', 'Due soon (7 days)'],
  'home_tanpa_dekat': [
    'Tidak ada tugas yang mendekati tenggat.',
    'No tasks are due soon.',
  ],
  'k_warna': ['Warna mapel', 'Subject color'],
  'k_bersihkan': ['Bersihkan', 'Clear'],
  'k_pakai_tema': ['Pakai warna tema', 'Use theme color'],
  'k_warna_tema': ['Warna tema', 'Theme color'],
  'home_selesai_pesan': ['"{judul}" ditandai selesai.', '"{judul}" marked as done.'],
  'home_urungkan': ['Urungkan', 'Undo'],
  'home_tandai_ket': ['Ketuk untuk menandai selesai', 'Tap to mark as done'],
  'ak_ubah_mapel': ['Ubah Mata Pelajaran', 'Edit Subject'],
  'ak_mapel_tersimpan': ['Mata pelajaran diperbarui.', 'Subject updated.'],
  'home_tanpa_mapel': ['Tanpa mapel', 'No subject'],
  'home_fokus': ['Fokus hari ini', "Today's focus"],
  'home_fokus_pesan': [
    'Tugas terdekat yang belum selesai.',
    'Your nearest unfinished task.',
  ],
  'home_semua_beres': ['Semua tugas beres.', 'All tasks are done.'],
  'home_sapaan_pagi': ['Selamat pagi', 'Good morning'],
  'home_sapaan_siang': ['Selamat siang', 'Good afternoon'],
  'home_sapaan_sore': ['Selamat sore', 'Good evening'],
  'home_sapaan_malam': ['Selamat malam', 'Good evening'],
  'home_catatan_judul': ['Catatan terbaru', 'Recent notes'],
  'home_pada_tenggat': ['{tgl}', '{tgl}'],
  'home_subjek_judul': ['Mata pelajaran', 'Subjects'],
  'home_lihat_semua': ['Lihat semua', 'See all'],
  'home_cari': ['Cari catatan, tugas, atau mapel...', 'Search notes, tasks, or subjects...'],
  'home_hasil': ['{n} hasil untuk "{q}"', '{n} results for "{q}"'],

  // ── Library (dulu Penyimpanan) ──────────────────────────────
  'lib_gambar': ['Gambar', 'Images'],
  'lib_file': ['File', 'Files'],
  'lib_total': ['Total', 'Total'],
  'lib_semua': ['Semua', 'All'],
  'lib_cari': ['Cari berkas...', 'Search files...'],
  'lib_ekspor': [
    'Ekspor catatan & tugas (.txt)',
    'Export notes & tasks (.txt)',
  ],
  'lib_kosong_judul': ['Belum ada lampiran', 'No attachments yet'],
  'lib_kosong_pesan': [
    'Tekan tombol + untuk menambah gambar atau file.',
    'Tap the + button to add an image or file.',
  ],
  'lib_hapus_tooltip': ['Hapus dari Library', 'Remove from Library'],
  'lib_hapus_judul': ['Hapus "{nama}"?', 'Remove "{nama}"?'],
  'lib_hapus_pesan': [
    'Salinan di dalam aplikasi akan dihapus. '
        'File asli di perangkat tetap aman dan tidak diubah.',
    'The copy inside the app will be deleted. '
        'The original file on your device stays untouched.',
  ],
  'lib_tambah': ['Tambah lampiran', 'Add attachment'],
  'lib_pilih_gambar': ['Pilih gambar', 'Pick an image'],
  'lib_pilih_file': ['Pilih file', 'Pick a file'],
  'lib_pilih_mapel': ['Simpan ke mata pelajaran', 'Save to subject'],
  'lib_pilih_mapel_pesan': [
    'Lampiran selalu menempel pada sebuah mapel. Pilih mapel tujuannya.',
    'Every attachment belongs to a subject. Choose the destination subject.',
  ],
  'lib_mapel_kosong': [
    'Belum ada mata pelajaran. Tambahkan dulu di tab Academic.',
    'No subjects yet. Add one in the Academic tab first.',
  ],
  'lib_berhasil': ['Ditambahkan: {nama}', 'Added: {nama}'],
  'lib_gagal': ['Gagal menambah lampiran: {e}', 'Failed to add attachment: {e}'],
  'lib_keterangan': [
    'Lampiran dikelompokkan di bawah catatan "Lampiran" pada mapel yang '
        'dipilih, dan bisa dibuka dari sana.',
    'Attachments are grouped under an "Attachments" note of the chosen '
        'subject, and can be opened from there.',
  ],

  // ── Pengaturan ──────────────────────────────────────────────
  'set_tampilan': ['TAMPILAN', 'APPEARANCE'],
  'set_bahasa': ['BAHASA', 'LANGUAGE'],
  'set_warna': ['WARNA AKSEN', 'ACCENT COLOR'],
  'set_data': ['DATA', 'DATA'],
  'set_pemulihan': ['PEMULIHAN', 'RECOVERY'],
  'set_tentang': ['TENTANG', 'ABOUT'],
  'set_ikuti_sistem': ['Ikuti sistem', 'Follow system'],
  'set_ikuti_sistem_sub': [
    'Mengikuti pengaturan perangkat',
    'Follows your device setting',
  ],
  'set_terang': ['Terang', 'Light'],
  'set_gelap': ['Gelap', 'Dark'],
  'set_bahasa_judul': ['Bahasa aplikasi', 'App language'],
  'set_bahasa_sub': [
    'Ubah bahasa aplikasi.',
    'Change the app language.',
  ],
  'set_bahasa_id': ['Indonesia', 'Indonesian'],
  'set_bahasa_en': ['Inggris', 'English'],
  'set_sampah': ['Sampah', 'Trash'],
  'set_sampah_kosong': ['Tidak ada mapel terhapus', 'No deleted subjects'],
  'set_sampah_isi': [
    '{n} mapel bisa dipulihkan',
    '{n} subjects can be restored',
  ],
  'set_ekspor': ['Ekspor data (.txt)', 'Export data (.txt)'],
  'set_ekspor_sub': [
    'Catatan dan tugas dari semua mapel',
    'Notes and tasks from every subject',
  ],
  'set_versi': ['Versi 1.0.0 · Offline', 'Version 1.0.0 · Offline'],

  // ── Sampah ──────────────────────────────────────────────────
  'sampah_ket': [
    'Mapel di sini sudah hilang dari daftar, tapi belum benar-benar dihapus. '
        'Pulihkan kapan saja, atau hapus permanen kalau sudah yakin. '
        'Setelah 30 hari, Sampah dibersihkan otomatis.',
    'Subjects here are hidden from the list but not truly deleted. Restore '
        'them anytime, or delete permanently once you are sure. After 30 '
        'days, Trash is cleaned automatically.',
  ],
  'sampah_kosong': ['Sampah kosong.', 'Trash is empty.'],
  'sampah_dihapus': ['Dihapus', 'Deleted'],
  'sampah_dihapus_pada': ['Dihapus {tgl}', 'Deleted {tgl}'],
  'sampah_hapus_permanen': ['Hapus permanen', 'Delete permanently'],
  'sampah_konfirmasi_judul': [
    'Hapus permanen "{nama}"?',
    'Permanently delete "{nama}"?',
  ],
  'sampah_konfirmasi_pesan': [
    'Semua catatan, tugas, dan lampiran di dalamnya akan ikut terhapus '
        'beserta file-nya. TIDAK bisa dipulihkan lagi.',
    'All notes, tasks, and attachments inside will be deleted along with '
        'their files. This CANNOT be undone.',
  ],
  'sampah_berhasil': [
    '"{nama}" dihapus permanen.',
    '"{nama}" was permanently deleted.',
  ],

  // ── Academic ────────────────────────────────────────────────
  'ak_tab_mapel': ['Mata Pelajaran', 'Subjects'],
  'ak_tab_catatan': ['Catatan', 'Notes'],
  'ak_tab_tugas': ['Tugas', 'Tasks'],
  'ak_tambah_mapel': ['Tambah Mata Pelajaran', 'Add Subject'],
  'ak_nama_mapel': ['Nama mapel', 'Subject name'],
  'ak_keterangan': ['Keterangan (opsional)', 'Description (optional)'],
  'ak_kosong_mapel': ['Belum ada mata pelajaran', 'No subjects yet'],
  'ak_kosong_mapel_pesan': [
    'Tekan tombol Mapel untuk menambah mapel pertama.',
    'Tap the Subject button to add your first subject.',
  ],
  'ak_kosong_mapel_tombol': ['Tambah Mapel', 'Add Subject'],
  'ak_mapel_fab': ['Mapel', 'Subject'],
  'ak_cari_catatan': ['Cari catatan...', 'Search notes...'],
  'ak_kosong_catatan': ['Belum ada catatan', 'No notes yet'],
  'ak_kosong_catatan_pesan': [
    'Catatan ditambahkan dari dalam Detail Mapel → Catatan.',
    'Notes are added inside Subject Detail → Notes.',
  ],
  'ak_tidak_ditemukan': ['Tidak ditemukan', 'Nothing found'],
  'ak_coba_kata': ['Coba kata kunci lain.', 'Try another keyword.'],
  'ak_cari_mapel': ['Cari mapel...', 'Search subjects...'],
  'ak_belum_isi': ['(belum ada isi)', '(no content yet)'],
  'ak_semua': ['Semua', 'All'],
  'ak_belum': ['Belum', 'Not done'],
  'ak_selesai': ['Selesai', 'Done'],
  'ak_tidak_ada_tugas': ['Tidak ada tugas', 'No tasks'],
  'ak_tidak_ada_tugas_pesan': [
    'Tugas ditambahkan dari dalam Detail Mapel → Tugas.',
    'Tasks are added inside Subject Detail → Tasks.',
  ],

  // ── Detail Mapel ────────────────────────────────────────────
  'dm_hapus_mapel': ['Hapus mapel', 'Delete subject'],
  'dm_hapus_mapel_judul': ['Hapus "{judul}"?', 'Delete "{judul}"?'],
  'dm_tab_catatan': ['Catatan', 'Notes'],
  'dm_tab_tugas': ['Tugas', 'Tasks'],
  'dm_kosong_catatan': ['Belum ada catatan', 'No notes yet'],
  'dm_kosong_catatan_pesan': [
    'Tambahkan materi atau catatan untuk mapel ini.',
    'Add a note or material for this subject.',
  ],
  'dm_tambah_catatan': ['Tambah Catatan', 'Add Note'],
  'dm_tambah_tugas': ['Tambah Tugas', 'Add Task'],
  'dm_judul_materi': ['Judul materi', 'Note title'],
  'dm_cari_catatan': ['Cari catatan...', 'Search notes...'],
  'dm_cari_tugas': ['Cari tugas...', 'Search tasks...'],
  'dm_isi_catatan': ['Isi catatan (opsional)', 'Note body (optional)'],
  'dm_judul_tugas': ['Judul tugas', 'Task title'],
  'dm_deskripsi_opsional': ['Deskripsi (opsional)', 'Description (optional)'],
  'dm_lampiran': ['Lampiran', 'Attachments'],
  'dm_kosong_tugas': ['Belum ada tugas', 'No tasks yet'],
  'dm_kosong_tugas_pesan': [
    'Tambahkan tugas dengan tenggat agar muncul di Home.',
    'Add a task with a due date so it shows up on Home.',
  ],
  'dm_tenggat': ['Tenggat: {tgl}', 'Due: {tgl}'],
  'dm_tandai_selesai': ['Tandai selesai', 'Mark as done'],
  'dm_tandai_belum': ['Tandai belum selesai', 'Mark as not done'],
  'dm_hapus_catatan': ['Hapus catatan "{judul}"?', 'Delete note "{judul}"?'],
  'dm_hapus_catatan_pesan': [
    'Catatan ini akan dihapus.',
    'This note will be deleted.',
  ],
  'dm_hapus_tugas': ['Hapus tugas "{judul}"?', 'Delete task "{judul}"?'],
  'dm_hapus_tugas_pesan': [
    'Tugas ini akan dihapus.',
    'This task will be deleted.',
  ],
  'dm_lampiran_ket': [
    'Gambar dan file disalin ke penyimpanan aplikasi. '
        'File asli di perangkat tidak diubah.',
    'Images and files are copied into app storage. '
        'The originals on your device are untouched.',
  ],
  'dm_belum_lampiran': ['Belum ada lampiran.', 'No attachments yet.'],
  'dm_tambah_gambar': ['Tambah gambar', 'Add image'],
  'dm_tambah_file': ['Tambah file', 'Add file'],
  'dm_gagal_lampiran': [
    'Gagal menambah lampiran: {e}',
    'Failed to add attachment: {e}',
  ],
  'dm_hapus_lampiran_judul': ['Hapus "{nama}"?', 'Delete "{nama}"?'],
  'dm_hapus_lampiran_pesan': [
    'Salinan di aplikasi akan dihapus. '
        'File asli di perangkat tetap aman.',
    'The copy inside the app will be deleted. '
        'The original file on your device stays safe.',
  ],
  'dm_aksi_lampiran': [
    'Catatan ditambahkan. Mau lampirkan gambar atau file?',
    'Note added. Attach an image or file?',
  ],
  'dm_catatan_tersimpan': ['Catatan ditambahkan.', 'Note added.'],
  'dm_tugas_tersimpan': ['Tugas ditambahkan.', 'Task added.'],
  'dm_tugas_diubah': ['Perubahan tugas disimpan.', 'Task changes saved.'],
  'dm_kategori_tugas': ['Kategori tugas', 'Task category'],
  'dm_kategori_kelompok': ['Kelompok', 'Group'],
  'dm_kategori_individu': ['Individu', 'Individual'],
  'dm_prioritas_tinggi': ['Prioritas: Tinggi', 'Priority: High'],
  'dm_prioritas_sedang': ['Prioritas: Sedang', 'Priority: Medium'],
  'dm_prioritas_rendah': ['Prioritas: Rendah', 'Priority: Low'],
  'dm_prioritas_tidak_ada': ['Prioritas: —', 'Priority: —'],
  'dm_lampiran_ditambah': ['Lampiran ditambahkan.', 'Attachment added.'],
  'dm_rincian_catatan': [
    'Seluruh catatan (materi) di dalamnya',
    'Every note (material) inside it',
  ],
  'dm_rincian_tugas': [
    'Seluruh tugas beserta tenggat dan status',
    'Every task with its due date and status',
  ],
  'dm_rincian_lampiran': [
    'Seluruh lampiran (gambar & file)',
    'Every attachment (images & files)',
  ],
  'dm_dipindah_sampah': [
    '"{nama}" dipindahkan ke Sampah.',
    '"{nama}" was moved to Trash.',
  ],

  'ak_pilih_semua': ['Pilih semua', 'Select all'],
  'ak_batal_pilih': ['Batal pilih', 'Cancel selection'],
  'ak_hapus_terpilih': ['Hapus terpilih', 'Delete selected'],
  'ak_konfirmasi_hapus_banyak': ['Hapus {n} mapel terpilih?', 'Delete {n} selected subjects?'],
  'ak_konfirmasi_hapus_banyak_pesan': ['Semua catatan, tugas, dan lampiran di dalamnya akan ikut masuk Sampah.', 'All notes, tasks, and attachments inside will also go to Trash.'],
  'ak_berhasil_hapus_banyak': ['{n} mapel dipindahkan ke Sampah.', '{n} subjects moved to Trash.'],
  'ak_terpilih': ['{n} terpilih', '{n} selected'],
  'ak_mulai_pilih': ['Mulai pilih', 'Start selection'],

  'sampah_mulai_pilih': ['Mulai pilih', 'Start selection'],
  'sampah_pilih_semua': ['Pilih semua', 'Select all'],
  'sampah_batal_pilih': ['Batal pilih', 'Cancel selection'],
  'sampah_hapus_permanen_terpilih': ['Hapus permanen terpilih', 'Delete selected permanently'],
  'sampah_terpilih': ['{n} terpilih', '{n} selected'],
  'sampah_konfirmasi_hapus_permanen_banyak': ['Hapus permanen {n} mapel terpilih?', 'Permanently delete {n} selected subjects?'],
  'sampah_konfirmasi_hapus_permanen_banyak_pesan': ['Semua catatan, tugas, lampiran, dan file di dalamnya akan ikut terhapus. TIDAK bisa dipulihkan lagi.', 'All notes, tasks, attachments, and files inside will also be deleted. This CANNOT be undone.'],
  'sampah_berhasil_hapus_permanen_banyak': ['{n} mapel dihapus permanen.', '{n} subjects permanently deleted.'],

  // ── Komponen bersama ────────────────────────────────────────
  'k_tidak_kosong': ['Tidak boleh kosong', 'Cannot be empty'],
  'k_pilih_tenggat': ['Pilih tenggat (opsional)', 'Pick a due date (optional)'],
  'k_tenggat': ['Tenggat: {tgl}', 'Due: {tgl}'],
  'k_bisa_dipulihkan': [
    'Bisa dipulihkan dari Pengaturan → Sampah.',
    'Can be restored from Settings → Trash.',
  ],
  'k_hapus_tenggat': ['Hapus tenggat', 'Clear due date'],
  'k_yang_ikut': [
    'Yang ikut terhapus dan masuk Sampah:',
    'These are removed too and go to Trash:',
  ],
  'k_tunggu': ['Tunggu {n} dtk', 'Wait {n}s'],
  'k_hari_ini': ['Hari ini', 'Today'],
  'k_besok': ['Besok', 'Tomorrow'],
  'k_n_hari_lagi': ['{n} hari lagi', 'in {n} days'],
  'k_lewat_n': ['Lewat {n} hari', '{n} days late'],
  'k_tanpa_tenggat': ['Tanpa tenggat', 'No due date'],
  'k_n_materi': ['{n} materi', '{n} notes'],
  'k_n_tugas': ['{n} tugas', '{n} tasks'],
  'k_lampiran_opsional': [
    'Lampiran (opsional) — catatan tetap bisa disimpan tanpa berkas.',
    'Attachment (optional) — the note saves fine without a file.',
  ],
  'k_hapus_tooltip': ['Hapus', 'Delete'],

  // ── Aksi CRUD & opsi per-item (2026-10-31) ──────────────────
  'k_ubah': ['Ubah', 'Edit'],
  'k_ubah_tooltip': ['Ubah', 'Edit'],
  'k_ekspor_tooltip': ['Ekspor catatan (.txt)', 'Export note (.txt)'],
  'k_lihat': ['Lihat', 'View'],
  'k_rename': ['Ganti nama', 'Rename'],
  'k_lampiran_tooltip': ['Lampiran', 'Attachments'],
  'dm_ubah_catatan': ['Ubah Catatan', 'Edit Note'],
  'dm_ubah_tugas': ['Ubah Tugas', 'Edit Task'],
  'dm_ekspor_sukses': ['Catatan diekspor ke: {path}', 'Note exported to: {path}'],
  'dm_ekspor_gagal': ['Gagal mengekspor: {e}', 'Export failed: {e}'],
  // Pesan simpan khusus EDIT — 'dm_catatan_tersimpan' yang lama berisi
  // "Catatan ditambahkan." (untuk tambah), jadi jangan dipakai ulang di sini.
  'dm_catatan_diubah': ['Perubahan catatan disimpan.', 'Note changes saved.'],
  'lib_ubah_nama_judul': ['Ganti nama lampiran', 'Rename attachment'],
  'lib_ubah_nama_label': ['Nama baru', 'New name'],
  'lib_ubah_nama_sukses': ['Nama diperbarui.', 'Name updated.'],
  'lib_buka_gagal': ['Tidak bisa membuka berkas: {e}', 'Cannot open file: {e}'],
};
