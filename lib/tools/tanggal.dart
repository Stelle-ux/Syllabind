import 'package:syllabind/tools/bahasa.dart';

/// Format tanggal pendek: "30 Okt 2026" (ID) / "30 Oct 2026" (EN).
String tanggalPendek(DateTime d) {
  const bulanId = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  const bulanEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final l = d.toLocal();
  final bulan = Bahasa.inggris ? bulanEn : bulanId;
  return '${l.day} ${bulan[l.month - 1]} ${l.year}';
}

/// Format tenggat relatif: "Hari ini" / "Besok" / "3 hari lagi" / "Lewat 2 hari".
String tenggatRelatif(DateTime? d) {
  if (d == null) return t('k_tanpa_tenggat');
  final kini = DateTime.now();
  final hariIni = DateTime(kini.year, kini.month, kini.day);
  final target = DateTime(d.year, d.month, d.day);
  final selisih = target.difference(hariIni).inDays;

  if (selisih < 0) return tp('k_lewat_n', {'n': '${-selisih}'});
  if (selisih == 0) return t('k_hari_ini');
  if (selisih == 1) return t('k_besok');
  return tp('k_n_hari_lagi', {'n': '$selisih'});
}