class MessageAnalysisResult {
  final String? sohbetGenelHavasi;
  final String? sonMesajTonu;
  final Map<String, int> etki;
  final String? anlikTavsiye;
  final String? yenidenYazim;
  final String? karsiTarafYorumu;
  final String? strateji;
  final DateTime analizZamani;

  MessageAnalysisResult({
    this.sohbetGenelHavasi,
    this.sonMesajTonu,
    required this.etki,
    this.anlikTavsiye,
    this.yenidenYazim,
    this.karsiTarafYorumu,
    this.strateji,
    DateTime? analizZamani,
  }) : analizZamani = analizZamani ?? DateTime.now();

  /// JSON'dan MesajAnalizSonucu nesnesi oluştur
  factory MessageAnalysisResult.fromJson(Map<String, dynamic> json) {
    Map<String, int> etkiMap = {};
    
    // Etki alanını parse et
    if (json['etki'] is Map) {
      final Map<String, dynamic> rawEtki = json['etki'] as Map<String, dynamic>;
      rawEtki.forEach((key, value) {
        if (value is int) {
          etkiMap[key] = value;
        } else if (value is double) {
          etkiMap[key] = value.round();
        } else if (value is String) {
          etkiMap[key] = int.tryParse(value) ?? 0;
        }
      });
    }
    
    // Eğer etki boşsa, varsayılan değerler ata
    if (etkiMap.isEmpty) {
      etkiMap = {
        'olumlu': 33,
        'nötr': 34,
        'olumsuz': 33,
      };
    }
    
    return MessageAnalysisResult(
      sohbetGenelHavasi: json['sohbetGenelHavasi'] as String?,
      sonMesajTonu: json['sonMesajTonu'] as String?,
      etki: etkiMap,
      anlikTavsiye: json['anlikTavsiye'] as String?,
      yenidenYazim: json['yenidenYazim'] as String?,
      karsiTarafYorumu: json['karsiTarafYorumu'] as String?,
      strateji: json['strateji'] as String?,
      analizZamani: json['analizZamani'] != null 
          ? DateTime.parse(json['analizZamani'] as String) 
          : null,
    );
  }

  /// MesajAnalizSonucu nesnesini JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'sohbetGenelHavasi': sohbetGenelHavasi,
      'sonMesajTonu': sonMesajTonu,
      'etki': etki,
      'anlikTavsiye': anlikTavsiye,
      'yenidenYazim': yenidenYazim,
      'karsiTarafYorumu': karsiTarafYorumu,
      'strateji': strateji,
      'analizZamani': analizZamani.toIso8601String(),
    };
  }
  
  /// Yanıt verisinden analiz sonucu oluştur 
  static MessageAnalysisResult? fromResponse(Map<String, dynamic>? response) {
    if (response == null) return null;
    
    // Hata kontrolü
    if (response.containsKey('error')) {
      print('Analiz hatası: ${response['error']}');
      return null;
    }
    
    try {
      return MessageAnalysisResult.fromJson(response);
    } catch (e) {
      print('Analiz sonucu oluşturma hatası: $e');
      return null;
    }
  }
} 