import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_log.dart';
import 'gorusme_motoru.dart';

/// Telefonun kendi sesiyle konuşur (ücretsiz, internetsiz) ve Türkçe ses
/// tanımayla dinler. Ekranda yazılan cevap da dinlenen cevap yerine geçer.
class CihazSesi implements SesArayuzu {
  /// Android'in kendi metin okuma motoru (MainActivity.kt). Başka sistemlerde
  /// sorular yalnızca ekranda görünür.
  static const MethodChannel _okuma = MethodChannel('santiyepro/seslendirme');
  final SpeechToText _stt = SpeechToText();

  bool _hazir = false;
  String? _turkce;

  /// Telefonda Türkçe okuma sesi yoksa false; sorular yalnızca ekranda görünür.
  bool turkceSesVar = true;

  /// Ses tanıma açılamadıysa nedeni (mikrofon izni yok gibi).
  String? sesTanimaHatasi;

  Completer<String?>? _dinleme;
  String _duyulan = '';
  /// Soru okunurken yazılan cevap; sıradaki dinlemede hemen verilir.
  String? _bekleyenYazi;
  DateTime _dinlemeBasi = DateTime(2000);

  Future<void> hazirla() async {
    if (_hazir) return;
    _hazir = true;
    try {
      turkceSesVar = Platform.isAndroid && (await _okuma.invokeMethod<bool>('hazirla')) == true;
    } catch (e) {
      turkceSesVar = false;
      appLog('Metin okuma açılamadı: $e');
    }
    try {
      final acildi = await _stt.initialize(
        onStatus: (durum) {
          // Bir önceki dinlemeden geç gelen "bitti" bildirimi yeni dinlemeyi
          // hemen bitirmesin.
          final gecen = DateTime.now().difference(_dinlemeBasi);
          if ((durum == 'done' || durum == 'notListening') &&
              (gecen > const Duration(milliseconds: 800) || _duyulan.isNotEmpty)) {
            _dinlemeBitti();
          }
        },
        onError: (_) => _dinlemeBitti(),
      );
      if (!acildi) {
        sesTanimaHatasi = 'Ses tanıma açılamadı. Mikrofon iznini kontrol et.';
      } else {
        final diller = await _stt.locales();
        _turkce = diller.where((l) => l.localeId.toLowerCase().startsWith('tr')).map((l) => l.localeId).firstOrNull;
      }
    } catch (e) {
      sesTanimaHatasi = 'Ses tanıma açılamadı: $e';
    }
  }

  void _dinlemeBitti() {
    final d = _dinleme;
    if (d != null && !d.isCompleted) {
      final metin = _duyulan.trim();
      d.complete(metin.isEmpty ? null : metin);
    }
  }

  @override
  Future<void> konus(String metin) async {
    await hazirla();
    if (!turkceSesVar) {
      // Ses yoksa soruyu okuyacak kadar bekle; soru ekranda yazılı.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }
    try {
      // Bazı cihazlarda bitiş bildirimi gelmez; metnin uzunluğuna göre sınır.
      await _okuma
          .invokeMethod<void>('konus', {'metin': metin})
          .timeout(Duration(seconds: 6 + metin.length ~/ 8), onTimeout: () {});
    } catch (e) {
      appLog('Okunamadı: $e');
    }
    // Kendi sesini duymasın diye kısa bir ara.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<String?> dinle() async {
    await hazirla();
    final yazi = _bekleyenYazi;
    if (yazi != null) {
      _bekleyenYazi = null;
      return yazi;
    }
    final d = _dinleme = Completer<String?>();
    _duyulan = '';
    _dinlemeBasi = DateTime.now();
    if (sesTanimaHatasi == null) {
      try {
        await _stt.listen(
          onResult: (SpeechRecognitionResult sonuc) {
            _duyulan = sonuc.recognizedWords;
            if (sonuc.finalResult) _dinlemeBitti();
          },
          listenOptions: SpeechListenOptions(
            // Listede Türkçe görünmese de Türkçe istenir (yoksa İngilizceye düşüyor).
            localeId: _turkce ?? 'tr_TR',
            listenFor: const Duration(seconds: 60),
            // Konuşma bitince fazla beklemeden sıradaki soruya geçilir.
            pauseFor: const Duration(seconds: 2),
            partialResults: true,
            cancelOnError: true,
          ),
        );
      } catch (e) {
        appLog('Dinleme başlatılamadı: $e');
        _dinlemeBitti();
      }
    }
    // Ses tanıma yoksa yalnızca ekrandan yazılan cevap beklenir.
    return d.future.timeout(Duration(seconds: sesTanimaHatasi == null ? 70 : 600), onTimeout: () {
      _stt.stop();
      final metin = _duyulan.trim();
      return metin.isEmpty ? null : metin;
    });
  }

  /// Ekranda yazılan cevap: dinlemeyi bitirir ve bu metni cevap sayar.
  @override
  void yaziylaCevapla(String metin) {
    final temiz = metin.trim();
    if (temiz.isEmpty) return;
    final d = _dinleme;
    if (d == null || d.isCompleted) {
      _bekleyenYazi = temiz;
      return;
    }
    _stt.cancel();
    d.complete(temiz);
  }

  @override
  Future<void> durdur() async {
    try {
      if (Platform.isAndroid) await _okuma.invokeMethod<void>('durdur');
    } catch (_) {
      // okuma zaten bitmiş olabilir
    }
    try {
      await _stt.cancel();
    } catch (_) {
      // dinleme zaten bitmiş olabilir
    }
    final d = _dinleme;
    if (d != null && !d.isCompleted) d.complete(null);
  }
}
