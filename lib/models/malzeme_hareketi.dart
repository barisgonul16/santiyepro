import 'json_utils.dart';

/// Hareketin türü. Saklanmaz; nereden/nereye alanlarından çıkarılır, böylece
/// ikisi birbirini tutmayan bir kayıt olamaz.
enum HareketTuru { geldi, gitti, aktarma }

/// Şantiyeye gelen, şantiyeden giden ya da şantiyeden şantiyeye taşınan
/// malzeme (pano, dikme, kontrplak, demir...). Her kayıt tek bir taşımadır;
/// şantiyede şu an ne olduğu bu kayıtlardan hesaplanır ([MalzemeStoku]).
///
/// - [hedefProjeId] dolu, [kaynakProjeId] boş: dışarıdan şantiyeye geldi.
/// - [kaynakProjeId] dolu, [hedefProjeId] boş: şantiyeden dışarı gitti (iade,
///   depo).
/// - İkisi de dolu: şantiyeden şantiyeye aktarma.
///
/// [disYer] şantiye olmayan uç: tedarikçi, kiralama firması, depo.
class MalzemeHareketi {
  final String id;
  final DateTime tarih;
  final String malzeme;
  final double miktar;
  final String birim;
  final String kaynakProjeId;
  final String hedefProjeId;
  final String disYer;
  final String irsaliyeNo;
  final String not;
  /// Yalnızca çekildiği cihazda bulunan fotoğrafın yolu (buluta gitmez).
  final String fotoYolu;
  /// "uygulama" ya da "claude" (claude.ai'den onayla eklendi).
  final String kaynak;
  /// Aletler sekmesinde aletin şantiyesi değiştirilince oluşan harekette
  /// aletin kimliği (aletin geçmişi bununla bulunur); diğerlerinde boş.
  final String aletId;

  const MalzemeHareketi({
    required this.id,
    required this.tarih,
    required this.malzeme,
    required this.miktar,
    required this.birim,
    this.kaynakProjeId = '',
    this.hedefProjeId = '',
    this.disYer = '',
    this.irsaliyeNo = '',
    this.not = '',
    this.fotoYolu = '',
    this.kaynak = 'uygulama',
    this.aletId = '',
  });

  HareketTuru get tur {
    if (kaynakProjeId.isNotEmpty && hedefProjeId.isNotEmpty) return HareketTuru.aktarma;
    if (kaynakProjeId.isNotEmpty) return HareketTuru.gitti;
    return HareketTuru.geldi;
  }

  /// Bu hareket verilen şantiyeyi ilgilendiriyor mu.
  bool ilgili(String projeId) => kaynakProjeId == projeId || hedefProjeId == projeId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tarih': tarih.toIso8601String(),
        'malzeme': malzeme,
        'miktar': miktar,
        'birim': birim,
        'kaynakProjeId': kaynakProjeId,
        'hedefProjeId': hedefProjeId,
        'disYer': disYer,
        'irsaliyeNo': irsaliyeNo,
        'not': not,
        'fotoYolu': fotoYolu,
        'kaynak': kaynak,
        if (aletId.isNotEmpty) 'aletId': aletId,
      };

  factory MalzemeHareketi.fromJson(Map<String, dynamic> json) => MalzemeHareketi(
        id: jsonKimlik(json['id']),
        tarih: jsonTarih(json['tarih'], 'tarih'),
        malzeme: jsonMetin(json['malzeme'], 'İsimsiz malzeme'),
        miktar: jsonOndalik(json['miktar']),
        birim: jsonMetin(json['birim'], 'adet'),
        kaynakProjeId: jsonMetin(json['kaynakProjeId']),
        hedefProjeId: jsonMetin(json['hedefProjeId']),
        disYer: jsonMetin(json['disYer']),
        irsaliyeNo: jsonMetin(json['irsaliyeNo']),
        not: jsonMetin(json['not']),
        fotoYolu: jsonMetin(json['fotoYolu']),
        kaynak: jsonMetin(json['kaynak'], 'uygulama'),
        aletId: jsonMetin(json['aletId']),
      );

  MalzemeHareketi kopya({String? fotoYolu}) => MalzemeHareketi(
        id: id,
        tarih: tarih,
        malzeme: malzeme,
        miktar: miktar,
        birim: birim,
        kaynakProjeId: kaynakProjeId,
        hedefProjeId: hedefProjeId,
        disYer: disYer,
        irsaliyeNo: irsaliyeNo,
        not: not,
        fotoYolu: fotoYolu ?? this.fotoYolu,
        kaynak: kaynak,
        aletId: aletId,
      );
}

/// Bir şantiyede bir malzemenin hesaplanan durumu.
class MalzemeStoku {
  final String malzeme;
  final String birim;
  final double gelen;
  final double giden;
  final DateTime sonHareket;

  const MalzemeStoku({
    required this.malzeme,
    required this.birim,
    required this.gelen,
    required this.giden,
    required this.sonHareket,
  });

  double get kalan => gelen - giden;
}

/// Türkçe harf ve büyük/küçük harf farkı gözetmeyen anahtar ("Trio Pano" ile
/// "trio pano" aynı malzeme sayılır).
String malzemeAnahtari(String metin) {
  const harf = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'â': 'a', 'î': 'i', 'û': 'u'};
  final kucuk = metin.trim().replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  final b = StringBuffer();
  for (final r in kucuk.split('')) {
    b.write(harf[r] ?? r);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Şantiyedeki malzemeler (gelen − giden), malzeme + birim bazında; adına göre
/// sıralı. Tümü gitmiş (kalan 0) malzemeler de döner, ekran ayırır.
/// Alet hareketleri ([MalzemeHareketi.aletId]) sayılmaz: aletin yeri
/// Aletler listesindeki şantiyesidir (silinen alet şantiyede kalmış görünmesin).
List<MalzemeStoku> santiyeStoku(Iterable<MalzemeHareketi> hareketler, String projeId) {
  final gruplar = <String, (String, String, double, double, DateTime)>{};
  for (final h in hareketler) {
    if (!h.ilgili(projeId) || h.aletId.isNotEmpty) continue;
    final anahtar = '${malzemeAnahtari(h.malzeme)}|${malzemeAnahtari(h.birim)}';
    final eski = gruplar[anahtar];
    final gelen = (eski?.$3 ?? 0) + (h.hedefProjeId == projeId ? h.miktar : 0);
    final giden = (eski?.$4 ?? 0) + (h.kaynakProjeId == projeId ? h.miktar : 0);
    final son = eski == null || h.tarih.isAfter(eski.$5) ? h.tarih : eski.$5;
    gruplar[anahtar] = (eski?.$1 ?? h.malzeme.trim(), eski?.$2 ?? h.birim.trim(), gelen, giden, son);
  }
  final liste = [
    for (final g in gruplar.values)
      MalzemeStoku(malzeme: g.$1, birim: g.$2, gelen: g.$3, giden: g.$4, sonHareket: g.$5),
  ];
  liste.sort((a, b) => malzemeAnahtari(a.malzeme).compareTo(malzemeAnahtari(b.malzeme)));
  return liste;
}

/// Miktarı gereksiz ".0" olmadan, Türkçe ondalıkla yazar (6.5 → "6,5").
String miktarMetni(double m) {
  final yuvarlak = (m * 1000).round() / 1000;
  if (yuvarlak == yuvarlak.roundToDouble()) return yuvarlak.toInt().toString();
  return yuvarlak.toString().replaceAll('.', ',');
}
