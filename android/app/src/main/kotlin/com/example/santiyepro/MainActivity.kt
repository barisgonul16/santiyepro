package com.example.santiyepro

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Sesli görüşme için telefonun kendi metin okuma motoru (ücretsiz, internetsiz).
 * Kanal: "santiyepro/seslendirme"
 *   hazirla() -> Boolean   Türkçe ses varsa true
 *   konus(metin) -> null   okuma bitince (ya da durdurulunca) döner
 *   durdur() -> null
 */
class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var hazir = false
    private var turkce = false
    private val bekleyenHazirlik = mutableListOf<MethodChannel.Result>()
    private val bekleyenOkumalar = mutableMapOf<String, MethodChannel.Result>()
    private var sayac = 0
    private val ana = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "santiyepro/seslendirme")
            .setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "hazirla" -> hazirla(sonuc)
                    "konus" -> konus(cagri.argument<String>("metin") ?: "", sonuc)
                    "durdur" -> {
                        tts?.stop()
                        bekleyenleriBitir()
                        sonuc.success(null)
                    }
                    else -> sonuc.notImplemented()
                }
            }
    }

    private fun hazirla(sonuc: MethodChannel.Result) {
        if (hazir) {
            sonuc.success(turkce)
            return
        }
        bekleyenHazirlik.add(sonuc)
        if (tts != null) return
        tts = TextToSpeech(this) { durum ->
            if (durum == TextToSpeech.SUCCESS) {
                val dil = tts?.setLanguage(Locale("tr", "TR")) ?: TextToSpeech.LANG_NOT_SUPPORTED
                turkce = dil != TextToSpeech.LANG_MISSING_DATA && dil != TextToSpeech.LANG_NOT_SUPPORTED
                tts?.setSpeechRate(1.15f)
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) = bitir(utteranceId)
                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) = bitir(utteranceId)
                    override fun onStop(utteranceId: String?, interrupted: Boolean) = bitir(utteranceId)
                })
            }
            hazir = true
            ana.post {
                bekleyenHazirlik.forEach { it.success(turkce) }
                bekleyenHazirlik.clear()
            }
        }
    }

    private fun konus(metin: String, sonuc: MethodChannel.Result) {
        val motor = tts
        if (motor == null || !turkce) {
            sonuc.success(null)
            return
        }
        val kimlik = "okuma${sayac++}"
        bekleyenOkumalar[kimlik] = sonuc
        val durum = motor.speak(metin, TextToSpeech.QUEUE_FLUSH, Bundle(), kimlik)
        if (durum != TextToSpeech.SUCCESS) bitir(kimlik)
    }

    private fun bitir(kimlik: String?) {
        ana.post {
            bekleyenOkumalar.remove(kimlik ?: return@post)?.success(null)
        }
    }

    private fun bekleyenleriBitir() {
        ana.post {
            bekleyenOkumalar.values.forEach { it.success(null) }
            bekleyenOkumalar.clear()
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
