import 'package:flutter/material.dart';
import '../theme/theme_colors.dart';

/// Bir ekibin adam sayısını yatay çubuk olarak gösterir: çubuğun boyu
/// [enCok]'a oranlıdır, ucunda sayı, yanında ekibin adı yazar.
class EkipCubugu extends StatelessWidget {
  final int sayi;
  /// Tam boy çubuğa karşılık gelen değer (karşılaştırılan en büyük sayı).
  final int enCok;
  final Color renk;
  final String ad;

  const EkipCubugu({
    super.key,
    required this.sayi,
    required this.enCok,
    required this.renk,
    required this.ad,
  });

  /// Çubuğun yanındaki ekip adına ayrılan yer.
  static const double _etiketGenisligi = 58;

  @override
  Widget build(BuildContext context) {
    // Sayı çubuğun içine sığmalı: iki haneye kadar 28, sonrası hane başına büyür.
    final hane = '$sayi'.length;
    final double enDar = hane <= 2 ? 28 : 12 + 9.0 * hane;

    return LayoutBuilder(
      builder: (context, kutu) {
        final enGenis = (kutu.maxWidth - _etiketGenisligi).clamp(enDar, double.infinity);
        final oran = enCok <= 0 ? 0.0 : sayi / enCok;
        return Row(
          children: [
            Container(
              width: (enGenis * oran).clamp(enDar, enGenis),
              height: 20,
              padding: const EdgeInsets.only(right: 6),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(4)),
              child: Text('$sayi',
                  style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text(ad, style: TextStyle(color: ThemeColors.textSecondary(context), fontSize: 12)),
          ],
        );
      },
    );
  }
}
