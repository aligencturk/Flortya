import 'analysis_type.dart';

/// Farklı analiz türlerinden elde edilen birleştirilmiş sonuçları temsil eden model
class UnifiedAnalysisResult {
  /// İlişki uyum puanı (0-100)
  final int iliskiUyumPuani;
  
  /// Kategori bazında skorlar 
  final Map<String, int> kategoriSkorlari;
  
  /// Kullanıcıya sunulacak kişiselleştirilmiş tavsiyeler
  final List<String> kisisellestirilmisTavsiyeler;
  
  /// Analizlerin hangi türlerden elde edildiği
  final List<AnalysisType> analizTurleri;
  
  /// İlişki analizi için açıklama notu
  final String analizNotu;
  
  /// Oluşturulma tarih ve saati
  final DateTime olusturulmaTarihi;

  UnifiedAnalysisResult({
    required this.iliskiUyumPuani,
    required this.kategoriSkorlari,
    required this.kisisellestirilmisTavsiyeler,
    required this.analizTurleri,
    required this.analizNotu,
    required this.olusturulmaTarihi,
  });

  /// İki sonucu birleştiren factory metodu
  factory UnifiedAnalysisResult.combine(
    UnifiedAnalysisResult ilkSonuc,
    UnifiedAnalysisResult ikinciSonuc,
  ) {
    // Analiz türlerini birleştir
    final List<AnalysisType> birlesikTurler = [
      ...ilkSonuc.analizTurleri,
      ...ikinciSonuc.analizTurleri,
    ];

    // Kategori skorlarını ağırlıklı ortalama ile birleştir
    final Map<String, int> birlesikKategoriSkorlari = {};
    
    // Tüm kategori isimlerini topla
    final Set<String> tumKategoriler = {
      ...ilkSonuc.kategoriSkorlari.keys,
      ...ikinciSonuc.kategoriSkorlari.keys,
    };
    
    // Her kategori için ağırlıklı ortalama hesapla
    for (final kategori in tumKategoriler) {
      final int ilkPuan = ilkSonuc.kategoriSkorlari[kategori] ?? 0;
      final int ikinciPuan = ikinciSonuc.kategoriSkorlari[kategori] ?? 0;
      
      // Puanlar mevcutsa 1:1 ağırlıklı ortalama, yoksa tek bir puanı kullan
      if (ilkPuan > 0 && ikinciPuan > 0) {
        birlesikKategoriSkorlari[kategori] = (ilkPuan + ikinciPuan) ~/ 2;
      } else if (ilkPuan > 0) {
        birlesikKategoriSkorlari[kategori] = ilkPuan;
      } else {
        birlesikKategoriSkorlari[kategori] = ikinciPuan;
      }
    }
    
    // İlişki uyum puanını hesapla
    int birlesikIliskiPuani = 0;
    if (birlesikKategoriSkorlari.isNotEmpty) {
      // Kategori skorlarının ortalaması
      int toplamPuan = 0;
      birlesikKategoriSkorlari.forEach((_, puan) => toplamPuan += puan);
      birlesikIliskiPuani = toplamPuan ~/ birlesikKategoriSkorlari.length;
    } else {
      // Mevcut ilişki puanlarının ortalaması
      birlesikIliskiPuani = (ilkSonuc.iliskiUyumPuani + ikinciSonuc.iliskiUyumPuani) ~/ 2;
    }
    
    // Tavsiyeleri birleştir ve en iyi 5 tavsiyeyi seç
    final List<String> tumTavsiyeler = [
      ...ilkSonuc.kisisellestirilmisTavsiyeler,
      ...ikinciSonuc.kisisellestirilmisTavsiyeler,
    ];
    
    // Tavsiyeleri listeden benzersiz hale getir
    final Set<String> benzersizTavsiyeler = Set.from(tumTavsiyeler);
    final List<String> secilenTavsiyeler = benzersizTavsiyeler.take(5).toList();
    
    // Analiz notunu birleştir
    final String birlesikNot = "${ilkSonuc.analizNotu}\n\n${ikinciSonuc.analizNotu}";
    
    return UnifiedAnalysisResult(
      iliskiUyumPuani: birlesikIliskiPuani,
      kategoriSkorlari: birlesikKategoriSkorlari,
      kisisellestirilmisTavsiyeler: secilenTavsiyeler,
      analizTurleri: birlesikTurler,
      analizNotu: birlesikNot,
      olusturulmaTarihi: DateTime.now(),
    );
  }
  
  /// Tek bir analiz türü için sonuç oluşturan factory metodu
  factory UnifiedAnalysisResult.fromSingleAnalysis({
    required AnalysisType analizTuru,
    required Map<String, dynamic> analizSonucu,
  }) {
    // Her analiz türü için farklı işleme
    switch (analizTuru) {
      case AnalysisType.image:
      case AnalysisType.txtFile:
      case AnalysisType.consultation:
        // Kategori skorlarını çıkart
        final Map<String, int> kategoriSkorlari = _extractCategoryScores(analizSonucu);
        
        // İlişki uyum puanını hesapla
        int iliskiUyumPuani = 0;
        if (kategoriSkorlari.isNotEmpty) {
          int toplamPuan = 0;
          kategoriSkorlari.forEach((_, puan) => toplamPuan += puan);
          iliskiUyumPuani = toplamPuan ~/ kategoriSkorlari.length;
        } else {
          iliskiUyumPuani = 60; // Varsayılan değer
        }
        
        // Tavsiyeleri çıkart
        final List<String> tavsiyeler = _extractRecommendations(analizSonucu);
        
        return UnifiedAnalysisResult(
          iliskiUyumPuani: iliskiUyumPuani,
          kategoriSkorlari: kategoriSkorlari,
          kisisellestirilmisTavsiyeler: tavsiyeler,
          analizTurleri: [analizTuru],
          analizNotu: analizSonucu['messageComment'] ?? '',
          olusturulmaTarihi: DateTime.now(),
        );
      
      default:
        // Varsayılan sonuç oluştur
        return UnifiedAnalysisResult(
          iliskiUyumPuani: 60,
          kategoriSkorlari: {
            'destek': 60,
            'guven': 60,
            'iletisim': 60, 
            'saygi': 60,
            'uyum': 60,
          },
          kisisellestirilmisTavsiyeler: [
            'İletişim becerilerinizi geliştirin',
            'Birbirinize destek olun',
            'Güven inşa edin',
            'Saygılı davranın',
            'Uyum için çaba gösterin',
          ],
          analizTurleri: [analizTuru],
          analizNotu: 'Analiz sonucu bulunamadı.',
          olusturulmaTarihi: DateTime.now(),
        );
    }
  }

  /// Analiz yanıtından kategori puanlarını çıkarır
  static Map<String, int> _extractCategoryScores(Map<String, dynamic> analizSonucu) {
    try {
      final Map<String, int> kategoriler = {};
      
      // Metin analizinden duygu ve tonları değerlendir
      final String duygu = (analizSonucu['emotion'] ?? '').toLowerCase();
      final String ton = (analizSonucu['tone'] ?? '').toLowerCase();
      final String niyet = (analizSonucu['intent'] ?? '').toLowerCase();
      final String yorum = (analizSonucu['messageComment'] ?? '').toLowerCase();
      
      // Duyguya bağlı uyum puanı
      if (duygu.contains('olumlu') || duygu.contains('mutlu') || duygu.contains('samimi')) {
        kategoriler['uyum'] = 75;
      } else if (duygu.contains('olumsuz') || duygu.contains('üzgün') || duygu.contains('kızgın')) {
        kategoriler['uyum'] = 40;
      } else {
        kategoriler['uyum'] = 60;
      }
      
      // Ton analizi
      if (ton.contains('samimi') || ton.contains('sıcak') || ton.contains('pozitif')) {
        kategoriler['iletisim'] = 80;
      } else if (ton.contains('mesafeli') || ton.contains('soğuk') || ton.contains('resmi')) {
        kategoriler['iletisim'] = 45;
      } else {
        kategoriler['iletisim'] = 60;
      }
      
      // Niyet analizi
      if (niyet.contains('destek') || niyet.contains('yardım') || niyet.contains('anlayış')) {
        kategoriler['destek'] = 85;
      } else if (niyet.contains('çatışma') || niyet.contains('tartışma')) {
        kategoriler['destek'] = 35;
      } else {
        kategoriler['destek'] = 60;
      }
      
      // Yorum içeriği ile saygı ve güven analizi
      if (yorum.contains('saygı') || yorum.contains('değer veriyor') || yorum.contains('önemsiyor')) {
        kategoriler['saygi'] = 75;
      } else if (yorum.contains('saygısızlık') || yorum.contains('hakaret')) {
        kategoriler['saygi'] = 35;
      } else {
        kategoriler['saygi'] = 60;
      }
      
      if (yorum.contains('güven') || yorum.contains('tutarlı') || yorum.contains('dürüst')) {
        kategoriler['guven'] = 75;
      } else if (yorum.contains('güvensizlik') || yorum.contains('şüphe')) {
        kategoriler['guven'] = 40;
      } else {
        kategoriler['guven'] = 60;
      }
      
      return kategoriler;
    } catch (e) {
      // Hata durumunda varsayılan değerler
      return {
        'iletisim': 60,
        'guven': 60,
        'uyum': 60,
        'saygi': 60,
        'destek': 60,
      };
    }
  }
  
  /// Analiz yanıtından tavsiyeleri çıkarır
  static List<String> _extractRecommendations(Map<String, dynamic> analizSonucu) {
    final List<String> tavsiyeler = [];
    
    if (analizSonucu.containsKey('responseRecommendations')) {
      final dynamic rawRecommendations = analizSonucu['responseRecommendations'];
      if (rawRecommendations is List) {
        for (dynamic rec in rawRecommendations) {
          if (rec is String && rec.isNotEmpty) {
            tavsiyeler.add(rec);
          }
        }
      }
    }
    
    // Eğer tavsiye bulunamazsa varsayılan tavsiyeler ekle
    if (tavsiyeler.isEmpty) {
      tavsiyeler.addAll([
        'Duygu ve düşüncelerinizi açık şekilde ifade edin',
        'Birbirinizi aktif dinleyin',
        'İlişkinizde kaliteli zaman geçirin',
        'Zor zamanlarda birbirinize destek olun',
        'Düzenli ilişki değerlendirmeleri yapın',
      ]);
    }
    
    return tavsiyeler.take(5).toList();
  }
} 