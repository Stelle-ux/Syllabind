import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Penjaga i18n: tidak boleh ada teks Indonesia hardcode di layar.
///
/// **Kenapa tes ini ada.** Bug ini sudah tiga kali lolos:
///
/// 1. `komponen.dart` memuat `'$jumlahMateri materi'` -> mode Inggris tampil
///    "3 materi".
/// 2. `detail_mapel.dart` memuat ~20 literal (dialog, keadaan kosong).
/// 3. `detail_mapel.dart:132` memuat `Tab(text: 'Catatan')` yang **lolos**
///    audit sebelumnya karena kata "Tugas" cuma 5 huruf sementara ambang
///    audit manual saat itu 6 huruf.
///
/// Ketiganya tidak terdeteksi `flutter analyze` maupun tes lain, karena
/// literal yang sah secara sintaks selalu "hijau". Satu-satunya cara
/// menangkapnya adalah memeriksa isi berkas secara sengaja.
///
/// Cara kerja:
///   - Pindai setiap `.dart` di `lib/screen/` dan `lib/tools/` **kecuali** `bahasa.dart` (kamus
///     itu memang berisi kedua bahasa — itu sumbernya, bukan pelanggaran).
///   - Buang komentar dulu (dulu sempat ada `komponen.dart:24` yang dituduh
///     melanggar padahal hanya di dalam komentar).
///   - Tandai literal yang memuat kata Indonesia yang lazim muncul di layar.
///   - Abaikan nama kunci kamus (`huruf_kecil_bergaris_bawah`).
///
/// Kalau tes ini gagal: pindahkan teksnya ke `bahasa.dart` dan panggil `t()`
/// atau `tp()`. Jangan longgarkan daftar kata di bawah.
void main() {
  test('tidak ada teks Indonesia hardcode di lib/screen/ dan lib/tools/', () {
    final akarScreen = Directory('lib/screen');
    final akarTools = Directory('lib/tools');
    expect(akarScreen.existsSync(), isTrue, reason: 'tes harus dijalankan dari akar proyek');
    expect(akarTools.existsSync(), isTrue, reason: 'tes harus dijalankan dari akar proyek');

    /// Kata yang lazim muncul di antarmuka berbahasa Indonesia. Sengaja
    /// pendek-pendek supaya kata 5 huruf seperti "Tugas" ikut tertangkap.
    const kataId = [
      'yang', 'dan', 'atau', 'tidak', 'belum', 'sudah', 'dari', 'untuk',
      'dengan', 'pada', 'adalah', 'ini', 'itu', 'juga', 'akan', 'bisa',
      'tambah', 'hapus', 'simpan', 'batal', 'ubah', 'pilih', 'cari', 'lihat',
      'tugas', 'catatan', 'mapel', 'berkas', 'nama', 'ukuran', 'jumlah',
      'kosong', 'gagal', 'berhasil', 'selesai', 'hari', 'lagi', 'semua',
      'waktu', 'tanggal', 'pulihkan', 'sampah', 'lampiran', 'tenggat',
      'pelajaran', 'pengaturan', 'bahasa', 'tema', 'warna', 'hapus',
    ];
    final polaKata = RegExp(r'\b(' + kataId.join('|') + r')\b',
        caseSensitive: false);

    /// Nama kunci kamus: huruf kecil, angka, garis bawah saja.
    final polaKunci = RegExp(r'^[a-z0-9_]+$');

    /// Literal yang memang bukan teks layar. Dua kelompok:
    ///
    /// 1. **Path impor** (`'../bahasa.dart'`) - selalu berakhiran `.dart`.
    /// 2. **Nilai enum/kunci data yang disimpan di DB** - mis. `'SEMUA'`,
    ///    `'GAMBAR'`, `'FILE'` untuk filter Library; `'SELESAI'`/`'BELUM'`
    ///    untuk status tugas. Ini BUKAN teks yang dilihat user: labelnya
    ///    diambil dari kamus lewat `t()`. Menerjemahkannya akan merusak data.
    ///
    /// Memeriksa ini penting: kalau daftar ini terlalu longgar, tes jadi
    /// berisik dan orang mematikannya. Kalau terlalu ketat, pelanggaran nyata
    /// lolos (persis yang terjadi pada `Tab(text: 'Catatan')` dulu).
    const nilaiData = <String>{
      'SEMUA', 'GAMBAR', 'FILE', 'SELESAI', 'BELUM',
      'sistem', 'terang', 'gelap', 'id', 'en',
    };

    /// Literal yang mengandung `${...}` adalah interpolasi - isinya variabel
    /// dan kunci kamus, bukan teks tetap. Contoh: `'${r.belum}'`,
    /// `'${m.nama} ${m.deskripsi ?? ''}'`. Tidak mungkin diperiksa sebagai
    /// kalimat, jadi dilewati (nilai yang diinterpolasi tetap harus sudah
    /// diterjemahkan di sumbernya).
    final polaInterpolasi = RegExp(r'\$\{');

    final polaLiteral = RegExp(r"'((?:[^'\\\n]|\\.)*)'");

    final pelanggaran = <String>[];

    for (final akar in [akarScreen, akarTools]) {
      for (final entitas in akar.listSync(recursive: true)) {
        if (entitas is! File || !entitas.path.endsWith('.dart')) continue;
        // Kamus adalah sumber teks; ia memang berisi dua bahasa sekaligus.
        if (entitas.path.endsWith('bahasa.dart')) continue;

        var isi = entitas.readAsStringSync();
        // Buang komentar supaya kode yang salah tidak ikut tertuduh.
        isi = isi.split('\n').map((b) {
          final t = b.trimLeft();
          return (t.startsWith('//')) ? '' : b;
        }).join('\n');
        isi = isi.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

        final baris = isi.split('\n');
        for (var i = 0; i < baris.length; i++) {
          for (final m in polaLiteral.allMatches(baris[i])) {
            final lit = m.group(1)!;
            if (lit.isEmpty) continue;
            if (polaKunci.hasMatch(lit)) continue;      // kunci kamus
            if (nilaiData.contains(lit)) continue;      // nilai enum di DB
            if (lit.endsWith('.dart')) continue;        // path impor
            if (polaInterpolasi.hasMatch(lit)) continue; // interpolasi variabel
            if (!polaKata.hasMatch(lit)) continue;      // tak ada kata Indonesia
            pelanggaran.add('${entitas.path}:${i + 1}  "$lit"');
          }
        }
      }
    }

    expect(
      pelanggaran,
      isEmpty,
      reason: 'Teks Indonesia hardcode ditemukan. Pindahkan ke bahasa.dart '
          'lalu panggil t()/tp():\n  ${pelanggaran.join("\n  ")}',
    );
  });
}