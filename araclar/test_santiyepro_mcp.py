"""santiyepro_mcp.py testleri: python -m unittest araclar/test_santiyepro_mcp.py"""
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import santiyepro_mcp as m  # noqa: E402


class Testler(unittest.TestCase):
    def setUp(self):
        self.klasor = tempfile.mkdtemp()
        os.environ['SANTIYEPRO_VERI'] = self.klasor
        self.yaz('projects', [
            {'id': 'g', 'ad': 'Gera makina', 'aciklama': 'Yapı donanım', 'durum': 'Devam Ediyor',
             'baslangicTarihi': '2026-01-05T00:00:00.000', 'toplamGun': 300, 'kahvaltiVar': True},
            {'id': 'k', 'ad': 'KA Otomotiv', 'durum': 'Devam Ediyor', 'baslangicTarihi': '2026-03-01T00:00:00.000'},
            {'id': 'd', 'ad': 'Gera depo', 'durum': 'Tamamlandı'},
        ])
        self.yaz('project_logs', {
            'g': [
                {'tarih': '2026-11-03T00:00:00.000', 'kalipci': 4, 'demirci': 5, 'kalipciYapilanIs': 'Döşeme kalıp çakıldı',
                 'beton': 'Perde 40 m³', 'yemekKalipci': 4, 'yemekDemirci': 5, 'kahvaltiKalipci': 4,
                 'hakedisNotu': 'Bodrum perde ek kalıp 12 m²', 'hava': 'yagmur', 'havaMin': 8, 'havaMax': 14,
                 'vincler': [{'firmaAdi': 'Akın', 'baslangic': '08:00', 'bitis': '12:30', 'mola': 30, 'aciklama': ''}],
                 'yevmiyeler': [{'ekipAdi': 'Ali usta', 'miktar': 1.5, 'aciklama': 'iskele'}],
                 'fotografYollari': ['a.jpg', 'b.jpg']},
                {'tarih': '2026-11-04T00:00:00.000', 'kalipci': 3, 'havaDurdu': True, 'hava': 'kar'},
                {'tarih': '2026-10-28T00:00:00.000', 'kalipci': 2, 'notlar': 'Malzeme geç geldi',
                 'vincFirmaAdi': 'Eski vinç', 'vincBaslangic': '22:00', 'vincBitis': '02:00', 'vincMola': 0},
            ],
            'k': [{'tarih': '2026-11-03T00:00:00.000', 'demirci': 2, 'demirciYapilanIs': 'Temel filizi',
                   'hakedisNotu': 'Filiz ek demir'}],
        })
        self.yaz('hakedisler', [{'id': 'h1', 'projeId': 'g', 'baslangic': '2026-10-01T00:00:00.000',
                                 'bitis': '2026-10-31T00:00:00.000', 'not': '',
                                 'kalemler': [{'ad': 'Kalıp', 'birim': 'm²', 'miktar': 120, 'birimFiyat': 250, 'ekip': 'kalıpçı'},
                                              {'ad': 'Demir', 'birim': 'ton', 'miktar': 3.5, 'birimFiyat': 0, 'ekip': ''}]}])
        self.yaz('ekipler', ['Ali usta'])
        self.ilk_hali = self.dosyalar()

    def tearDown(self):
        # Sunucu hiçbir dosyaya yazmamalı.
        self.assertEqual(self.dosyalar(), self.ilk_hali)

    def dosyalar(self):
        icerik = {}
        for f in os.listdir(self.klasor):
            with open(os.path.join(self.klasor, f), 'rb') as d:
                icerik[f] = d.read()
        return icerik

    def yaz(self, ad, veri):
        with io.open(os.path.join(self.klasor, ad + '.json'), 'w', encoding='utf-8') as f:
            json.dump(veri, f, ensure_ascii=False)

    def cagir(self, ad, args=None):
        return m.arac_cagir(ad, args or {})

    def test_santiye_bulma(self):
        self.assertEqual(m.santiye_bul('gera makina')['id'], 'g')
        self.assertEqual(m.santiye_bul('KA')['id'], 'k')
        self.assertEqual(m.santiye_bul('otomotıv')['id'], 'k')  # Türkçe harf farkı
        with self.assertRaisesRegex(ValueError, 'birden çok'):
            m.santiye_bul('gera')
        with self.assertRaisesRegex(ValueError, 'şantiye yok'):
            m.santiye_bul('vatanpress')

    def test_santiyeler(self):
        s = self.cagir('santiyeler')
        g = s['santiyeler'][0]
        self.assertEqual((g['ad'], g['kayit_sayisi'], g['ilk_kayit'], g['son_kayit']), ('Gera makina', 3, '2026-10-28', '2026-11-04'))
        self.assertTrue(g['kahvalti_var'])
        self.assertEqual(s['ekipler'], ['Ali usta'])
        self.assertIn('veri_tarihi', s)

    def test_gunluk_kayitlar_ve_suzme(self):
        s = self.cagir('gunluk_kayitlar', {'santiye': 'gera makina', 'ay': '2026-11'})
        self.assertEqual(s['kayit_sayisi'], 2)
        k = s['kayitlar'][0]
        self.assertEqual((k['tarih'], k['kalipci'], k['demirci']), ('2026-11-03', 4, 5))
        self.assertEqual(k['vincler'][0]['net_saat'], 4.0)
        self.assertEqual(k['yemek'], {'kahvalti': {'kalipci': 4, 'demirci': 0, 'diger': 0, 'toplam': 4},
                                      'ogle': {'kalipci': 4, 'demirci': 5, 'diger': 0, 'toplam': 9}})
        self.assertEqual(k['hava'], {'durum': 'yagmur', 'en_dusuk': 8, 'en_yuksek': 14, 'calisilamadi': False})
        self.assertEqual(k['fotograf_sayisi'], 2)
        self.assertNotIn('notlar', k)  # boş alanlar yazılmaz
        # Eski tek-vinç alanları ve gece yarısını geçen vinç.
        eski = self.cagir('gunluk_kayitlar', {'santiye': 'g', 'bitis': '2026-10-31'})['kayitlar'][0]
        self.assertEqual(eski['vincler'][0]['net_saat'], 4.0)
        # Sınır: en yeniler döner.
        son = self.cagir('gunluk_kayitlar', {'en_fazla': 1})
        self.assertTrue(son['kesildi'])
        self.assertEqual(son['kayitlar'][0]['tarih'], '2026-11-04')

    def test_ozet(self):
        s = self.cagir('ozet', {'ay': '2026-11'})
        g, k = s['santiyeler']
        self.assertEqual((g['santiye'], g['kayitli_gun'], g['kalipci_adam_gun'], g['demirci_adam_gun']), ('Gera makina', 2, 7, 5))
        self.assertEqual((g['vinc_saat'], g['vinc_gun'], g['yevmiye']), (4.0, 1, 1.5))
        self.assertEqual(g['yemek'], {'kahvalti': 4, 'ogle': 9, 'aksam': 0})
        self.assertEqual(g['hava_nedeniyle_durulan_gunler'], ['2026-11-04'])
        self.assertEqual(g['beton_gunleri'], [{'tarih': '2026-11-03', 'beton': 'Perde 40 m³'}])
        self.assertEqual(k['demirci_adam_gun'], 2)
        self.assertEqual(s['genel_toplam']['toplam_adam_gun'], 14)

    def test_ara(self):
        s = self.cagir('ara', {'metin': 'KALIP'})
        self.assertEqual(sorted(x['alan'] for x in s['sonuclar']), ['hakedis_hatirlatma', 'kalipci_isi'])
        self.assertEqual(self.cagir('ara', {'metin': 'akın'})['sonuclar'][0]['alan'], 'vinc')
        self.assertEqual(self.cagir('ara', {'metin': 'iskele'})['sonuclar'][0]['alan'], 'yevmiye')

    def test_hakedis(self):
        h = self.cagir('hakedis_hatirlatmalari', {'ay': '2026-11'})
        self.assertEqual([x['santiye'] for x in h['hatirlatmalar']], ['Gera makina', 'KA Otomotiv'])
        d = self.cagir('hakedisler', {'santiye': 'gera makina'})['hakedisler'][0]
        self.assertEqual((d['donem_bitis'], d['toplam_tutar']), ('2026-10-31', 30000.0))
        self.assertIsNone(d['kalemler'][1]['tutar'])

    def test_hatali_girdiler_hata_olarak_doner(self):
        y = m.isle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call',
                    'params': {'name': 'ozet', 'arguments': {'ay': 'kasım'}}})
        self.assertTrue(y['result']['isError'])
        self.assertIn('YYYY-MM', y['result']['content'][0]['text'])
        y = m.isle({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/call', 'params': {'name': 'yok'}})
        self.assertEqual(y['error']['code'], -32602)

    def test_protokol(self):
        giris = io.StringIO('\n'.join(json.dumps(x) for x in [
            {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-03-26'}},
            {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
            {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
            {'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call', 'params': {'name': 'santiyeler', 'arguments': {}}},
            {'jsonrpc': '2.0', 'id': 4, 'method': 'bilinmeyen'},
        ]) + '\nbozuk satır\n')
        cikis = io.StringIO()
        m.calistir(giris, cikis)
        yanitlar = [json.loads(s) for s in cikis.getvalue().splitlines()]
        self.assertEqual([y.get('id') for y in yanitlar], [1, 2, 3, 4, None])  # bildirime yanıt yok
        self.assertEqual(yanitlar[0]['result']['protocolVersion'], '2025-03-26')
        self.assertEqual(len(yanitlar[1]['result']['tools']), 6)
        self.assertNotIn('fonksiyon', yanitlar[1]['result']['tools'][0])
        self.assertIn('Gera makina', yanitlar[2]['result']['content'][0]['text'])
        self.assertEqual(yanitlar[3]['error']['code'], -32601)
        self.assertEqual(yanitlar[4]['error']['code'], -32700)


if __name__ == '__main__':
    unittest.main()
