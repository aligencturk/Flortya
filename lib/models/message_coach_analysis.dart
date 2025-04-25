import 'package:flutter/foundation.dart';

class MesajKocuAnalizi {
  final String? iliskiTipi;
  final String analiz;
  final String? gucluYonler;
  final List<String> oneriler;
  final Map<String, int> etki;
  final String? yenidenYazim;
  final String? strateji;
  final String? karsiTarafYorumu;
  final String? anlikTavsiye;
  
  // İlk 3 analizi tanımlamak için sabit
  static const int ucretlizAnalizSayisi = 3;

  MesajKocuAnalizi({
    this.iliskiTipi,
    required this.analiz,
    this.gucluYonler,
    required this.oneriler,
    required this.etki,
    this.yenidenYazim,
    this.strateji,
    this.karsiTarafYorumu,
    this.anlikTavsiye,
  });

  factory MesajKocuAnalizi.fromJson(Map<String, dynamic> json) {
    // Debug log için konsola yazdır
    print('MesajKocuAnalizi.fromJson çağrıldı: ${json.keys.toList()}');
    
    // Öneriler listesini dönüştür
    final List<dynamic> onerileriJson = json['öneriler'] ?? [];
    final List<String> onerileriList = onerileriJson
        .map((item) => item.toString())
        .toList();
    
    // Öneriler listesi boşsa varsayılan değerler ver
    if (onerileriList.isEmpty) {
      onerileriList.addAll(['İletişim tekniklerini geliştir', 'Karşı tarafı dinlemeye özen göster']);
    }

    // Etki alanını Map<String, int> olarak dönüştür
    Map<String, int> etkiMap = {};
    if (json.containsKey('effect') && json['effect'] is Map) {
      final etkiJson = json['effect'] as Map<String, dynamic>;
      
      etkiJson.forEach((key, value) {
        if (value is int) {
          etkiMap[key] = value;
        } else if (value is double) {
          etkiMap[key] = value.toInt();
        } else if (value is String) {
          try {
            etkiMap[key] = int.parse(value);
          } catch (e) {
            etkiMap[key] = 0;
          }
        } else {
          etkiMap[key] = 0;
        }
      });
    }
    
    // Etki haritası boşsa varsayılan değer ekle
    if (etkiMap.isEmpty) {
      etkiMap = {'nötr': 100};
    }

    // Zorunlu alanların varlığını kontrol et
    String? analiz = json['analiz'] ?? json['mesajYorumu'];
    if (analiz == null) {
      throw Exception('Analiz sonucu bulunamadı');
    }
    
    String? anlikTavsiye = json['anlikTavsiye'] ?? json['instantAdvice'] ?? json['mesajYorumu'];
    String? yenidenYazim = json['yenidenYazim'] ?? json['rewrite'];
    String? strateji = json['strateji'] ?? json['strategy'];
    String? karsiTarafYorumu = json['karsiTarafYorumu'] ?? json['counterpartOpinion'];
    String? gucluYonler = json['gucluYonler'] ?? json['strongPoints'];
    String? iliskiTipi = json['iliskiTipi'] ?? json['relationshipType'];

    return MesajKocuAnalizi(
      iliskiTipi: iliskiTipi,
      analiz: analiz,
      gucluYonler: gucluYonler,
      oneriler: onerileriList,
      etki: etkiMap,
      yenidenYazim: yenidenYazim,
      strateji: strateji,
      karsiTarafYorumu: karsiTarafYorumu,
      anlikTavsiye: anlikTavsiye,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ilişki_tipi': iliskiTipi,
      'analiz': analiz,
      'güçlü_yönler': gucluYonler,
      'öneriler': oneriler,
      'effect': etki,
      'rewrite': yenidenYazim,
      'strategy': strateji,
      'karsiTarafYorumu': karsiTarafYorumu,
      'anlikTavsiye': anlikTavsiye,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'iliskiTipi': iliskiTipi,
      'analiz': analiz,
      'gucluYonler': gucluYonler,
      'oneriler': oneriler,
      'etki': etki,
      'yenidenYazim': yenidenYazim,
      'strateji': strateji,
      'karsiTarafYorumu': karsiTarafYorumu,
      'anlikTavsiye': anlikTavsiye,
    };
  }
} 