import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/message_coach_analysis.dart';
import '../models/analysis_result_model.dart';  // AnalysisResult için import ekliyorum
import '../services/ai_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';  // min fonksiyonu için import ekliyorum
import '../services/api_service.dart';  // ApiService için import ekliyorum

class AdviceViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final AiService _aiService;
  final LoggerService _logger;
  final NotificationService _notificationService;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Mesaj Koçu ile ilgili özellikler
  MesajKocuAnalizi? _mesajAnalizi;
  bool _isAnalyzing = false;
  int _ucretlizAnalizSayisi = 0;

  // Mesaj Koçu getters
  MesajKocuAnalizi? get mesajAnalizi => _mesajAnalizi;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  bool get hasAnalizi => _mesajAnalizi != null;
  int get ucretlizAnalizSayisi => _ucretlizAnalizSayisi;
  bool get analizHakkiVar => _ucretlizAnalizSayisi < MesajKocuAnalizi.ucretlizAnalizSayisi;
  bool get isLoading => _isLoading;
  
  // Constructor
  AdviceViewModel({
    required FirebaseFirestore firestore,
    required AiService aiService,
    required LoggerService logger,
    required NotificationService notificationService,
  }) : _firestore = firestore,
       _aiService = aiService,
       _logger = logger,
       _notificationService = notificationService;

  // Mesaj Koçu analizi yapma
  Future<void> analyzeMesaj(String metin, String userId) async {
    if (_isAnalyzing) {
      print('⚠️ Zaten analiz yapılıyor, işlem iptal edildi');
      return;
    }
    
    print('📊 Mesaj analizi başlatılıyor: "${metin.substring(0, min(20, metin.length))}..."');
    
    // Analizden önce tüm durumları sıfırla
    _mesajAnalizi = null;
    _isLoading = true;
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();
    
    // Analiz işlemi için bir zaman aşımı ekleyelim
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 25), () {
      print('⏰ Analiz zaman aşımına uğradı, durum temizleniyor');
      _isLoading = false;
      _isAnalyzing = false;
      _errorMessage = 'Analiz zaman aşımına uğradı, lütfen tekrar deneyin';
      notifyListeners();
    });
    
    try {
      // Ücretsiz analiz sınırını kontrol et
      if (_ucretlizAnalizSayisi >= MesajKocuAnalizi.ucretlizAnalizSayisi) {
        _isLoading = false;
        _isAnalyzing = false;
        _errorMessage = 'Ücretsiz analiz hakkınızı doldurdunuz';
        notifyListeners();
        timeoutTimer.cancel();
        return;
      }
      
      // Geminik AI üzerinden analiz
      final analiz = await ApiService().analyzeMessage(metin);
      
      // Zaman aşımı zamanlayıcısını iptal et
      timeoutTimer.cancel();
      
      if (analiz == null) {
        _isLoading = false;
        _isAnalyzing = false;
        _errorMessage = 'Sunucu yanıt vermedi veya analiz sonucu alınamadı. Lütfen tekrar deneyin.';
        notifyListeners();
        return;
      }
      
      // Analizi MesajKocuAnalizi tipine dönüştür
      final mesajAnalizi = _convertAnalysisToMesajKocu(analiz);
      
      // Firestore'a kaydet
      await _saveAnalysisToFirestore(userId, mesajAnalizi, metin);
      await _incrementAnalysisCount(userId);
      
      // Tüm işlemler tamamlandıktan sonra sonuç modelini ata
      _mesajAnalizi = mesajAnalizi;
      _isLoading = false;
      _isAnalyzing = false;
      
      // UI'a bildir
      notifyListeners();
      
      print('✅ Mesaj analizi tamamlandı: ${_mesajAnalizi?.anlikTavsiye?.substring(0, min(30, _mesajAnalizi?.anlikTavsiye?.length ?? 0))}...');
      print('✅ UI güncellendi - isAnalyzing=$_isAnalyzing, hasAnalizi=${hasAnalizi}');
      
    } catch (e) {
      print('❌ Mesaj analizi hatası: $e');
      timeoutTimer.cancel();
      
      _isLoading = false;
      _isAnalyzing = false;
      _errorMessage = 'Analiz sırasında bir hata oluştu: $e';
      
      notifyListeners();
    }
  }
  
  // AnalysisResult'ı MesajKocuAnalizi'ne dönüştür
  MesajKocuAnalizi _convertAnalysisToMesajKocu(dynamic analysisResult) {
    try {
      print('🔄 _convertAnalysisToMesajKocu başlıyor');
      
      // Dynamic tipindeki veriyi Map<String, dynamic>'e dönüştür
      Map<String, dynamic> resultMap;
      if (analysisResult is Map<String, dynamic>) {
        resultMap = analysisResult;
      } else if (analysisResult is AnalysisResult) {
        resultMap = analysisResult.toMap();
      } else {
        print('❌ Beklenmeyen analiz sonucu tipi: ${analysisResult.runtimeType}');
        throw Exception('Beklenmeyen analiz sonucu tipi: ${analysisResult.runtimeType}');
      }
      
      print('🔑 Analiz sonucu anahtarları: ${resultMap.keys.toList()}');
      
      // aiResponse içeriğini al
      Map<String, dynamic> aiResponseMap = {};
      
      if (resultMap.containsKey('aiResponse') && resultMap['aiResponse'] is Map) {
        aiResponseMap = Map<String, dynamic>.from(resultMap['aiResponse']);
        print('✅ aiResponse bulundu: ${aiResponseMap.keys.toList()}');
      } else {
        print('⚠️ aiResponse bulunamadı, alternatif değerler aranıyor');
      }
      
      // Öneriler listesini oluştur
      List<String> oneriler = [];
      
      // Önce aiResponse içindeki cevapOnerileri'ni kontrol et
      if (aiResponseMap.containsKey('cevapOnerileri') && aiResponseMap['cevapOnerileri'] is List) {
        oneriler = List<String>.from(aiResponseMap['cevapOnerileri'].map((item) => item.toString()));
        print('✅ aiResponse.cevapOnerileri bulundu: ${oneriler.length} öğe');
      } 
      // Doğrudan cevapOnerileri'ni kontrol et
      else if (resultMap.containsKey('cevapOnerileri') && resultMap['cevapOnerileri'] is List) {
        oneriler = List<String>.from(resultMap['cevapOnerileri'].map((item) => item.toString()));
        print('✅ cevapOnerileri bulundu: ${oneriler.length} öğe');
      }
      
      // Öneriler listesi boşsa varsayılan değerler ver
      if (oneriler.isEmpty) {
        oneriler = ['İletişim tekniklerini geliştir', 'Sakin ve net bir dil kullan'];
        print('⚠️ Öneriler listesi boş, varsayılan değerler eklendi');
      }
      
      // Etki haritasını oluştur
      Map<String, int> etki = {'nötr': 100};
      
      // Etki değerlerini kontrol et
      if (resultMap.containsKey('effect') && resultMap['effect'] is Map) {
        // effect alanının deep copy'sini al
        Map<String, dynamic> effectMap = Map<String, dynamic>.from(resultMap['effect']);
        
        effectMap.forEach((key, value) {
          if (value is int) {
            etki[key] = value;
          } else if (value is double) {
            etki[key] = value.toInt();
          } else if (value is String) {
            try {
              etki[key] = int.parse(value);
            } catch (e) {
              etki[key] = 50; // Varsayılan değer
            }
          }
        });
        
        print('✅ effect değerleri dönüştürüldü: ${etki.length} adet');
      } else {
        print('⚠️ effect değerleri bulunamadı, varsayılan değerler kullanıldı');
      }
      
      // Son mesaj etkisi haritası
      Map<String, int>? sonMesajEtkisi;
      if (resultMap.containsKey('lastMessageEffect') && resultMap['lastMessageEffect'] is Map) {
        sonMesajEtkisi = {};
        final lastMessageEffectMap = Map<String, dynamic>.from(resultMap['lastMessageEffect']);
        
        lastMessageEffectMap.forEach((key, value) {
          if (value is int) {
            sonMesajEtkisi![key] = value;
          } else if (value is double) {
            sonMesajEtkisi![key] = value.toInt();
          } else if (value is String) {
            try {
              sonMesajEtkisi![key] = int.parse(value);
            } catch (e) {
              sonMesajEtkisi![key] = 0;
            }
          }
        });
        
        print('✅ Son mesaj etkisi değerleri dönüştürüldü: ${sonMesajEtkisi.length} adet');
      }
      
      // anlikTavsiye, mesajYorumu dönüşümü
      String? anlikTavsiye;
      
      // Önce aiResponse içindeki mesajYorumu'nu kontrol et
      if (aiResponseMap.containsKey('mesajYorumu') && aiResponseMap['mesajYorumu'] != null) {
        anlikTavsiye = aiResponseMap['mesajYorumu'].toString();
        print('✅ aiResponse.mesajYorumu bulundu');
      } 
      // Doğrudan mesajYorumu'nu kontrol et
      else if (resultMap.containsKey('mesajYorumu') && resultMap['mesajYorumu'] != null) {
        anlikTavsiye = resultMap['mesajYorumu'].toString();
        print('✅ mesajYorumu bulundu');
      }
      
      // Yeniden yazım ve strateji
      String? yenidenYazim;
      if (aiResponseMap.containsKey('yenidenYazim') && aiResponseMap['yenidenYazim'] != null) {
        yenidenYazim = aiResponseMap['yenidenYazim'].toString();
        print('✅ aiResponse.yenidenYazim bulundu');
      } else if (resultMap.containsKey('yenidenYazim') && resultMap['yenidenYazim'] != null) {
        yenidenYazim = resultMap['yenidenYazim'].toString();
        print('✅ yenidenYazim bulundu');
      }
      
      // Yeni analiz formatı için alanlar
      String? sohbetGenelHavasi = resultMap['chatMood'] ?? aiResponseMap['chatMood'] ?? resultMap['sohbetGenelHavasi'];
      String? genelYorum = resultMap['generalComment'] ?? aiResponseMap['generalComment'] ?? resultMap['genelYorum'];
      String? sonMesajTonu = resultMap['lastMessageTone'] ?? aiResponseMap['lastMessageTone'] ?? resultMap['sonMesajTonu'];
      String? direktYorum = resultMap['directComment'] ?? aiResponseMap['directComment'] ?? resultMap['direktYorum'];
      String? cevapOnerisi = resultMap['responseProposal'] ?? aiResponseMap['responseProposal'] ?? resultMap['cevapOnerisi'];
      
      // Alanların boş olup olmadığını kontrol et ve varsayılan değerler ata
      if (sohbetGenelHavasi == null || sohbetGenelHavasi.isEmpty) {
        // Etki haritasına bakarak uygun bir sohbet havası belirle
        if (etki.containsKey('sempatik') && etki['sempatik']! > 50) {
          sohbetGenelHavasi = 'Samimi';
        } else if (etki.containsKey('soğuk') && etki['soğuk']! > 50) {
          sohbetGenelHavasi = 'Soğuk';
        } else if (etki.containsKey('kararsız') && etki['kararsız']! > 50) {
          sohbetGenelHavasi = 'Kararsız';
        } else {
          sohbetGenelHavasi = 'Normal';
        }
      }
      
      if (sonMesajTonu == null || sonMesajTonu.isEmpty) {
        // Etki haritasına bakarak uygun bir mesaj tonu belirle
        if (etki.containsKey('sempatik') && etki['sempatik']! > 50) {
          sonMesajTonu = 'Sempatik';
        } else if (etki.containsKey('soğuk') && etki['soğuk']! > 50) {
          sonMesajTonu = 'Soğuk';
        } else if (etki.containsKey('kararsız') && etki['kararsız']! > 50) {
          sonMesajTonu = 'Kararsız';
        } else {
          sonMesajTonu = 'Nötr';
        }
      }
      
      // Son mesaj etkisi haritası boşsa, genel etki haritasına dayanarak varsayılan değerler oluştur
      if (sonMesajEtkisi == null || sonMesajEtkisi.isEmpty) {
        sonMesajEtkisi = {};
        
        // Etki haritasındaki değerleri kullanarak son mesaj etkisi oluştur
        if (etki.containsKey('sempatik')) {
          sonMesajEtkisi['sempatik'] = etki['sempatik']!;
        } else {
          sonMesajEtkisi['sempatik'] = 60; // Varsayılan değer
        }
        
        if (etki.containsKey('kararsız')) {
          sonMesajEtkisi['kararsız'] = etki['kararsız']!;
        } else {
          sonMesajEtkisi['kararsız'] = 25; // Varsayılan değer
        }
        
        if (etki.containsKey('soğuk') || etki.containsKey('olumsuz')) {
          sonMesajEtkisi['olumsuz'] = etki.containsKey('soğuk') ? etki['soğuk']! : etki['olumsuz']!;
        } else {
          sonMesajEtkisi['olumsuz'] = 15; // Varsayılan değer
        }
      }
      
      // karşı taraf yorumu ve strateji
      String? karsiTarafYorumu = resultMap['karsiTarafYorumu'] ?? aiResponseMap['karsiTarafYorumu'];
      String? strateji = resultMap['strateji'] ?? aiResponseMap['strateji'] ?? resultMap['strategy'];
      
      // MesajKocuAnalizi nesnesini oluşturarak döndür
      return MesajKocuAnalizi(
        analiz: resultMap['analiz'] ?? 'Metin analizi',
        anlikTavsiye: anlikTavsiye,
        etki: etki,
        gucluYonler: resultMap['gucluYonler'],
        iliskiTipi: resultMap['iliskiTipi'],
        karsiTarafYorumu: karsiTarafYorumu,
        oneriler: oneriler,
        strateji: strateji,
        yenidenYazim: yenidenYazim,
        sohbetGenelHavasi: sohbetGenelHavasi,
        genelYorum: genelYorum, 
        sonMesajTonu: sonMesajTonu,
        sonMesajEtkisi: sonMesajEtkisi,
        direktYorum: direktYorum,
        cevapOnerisi: cevapOnerisi,
      );
    } catch (e) {
      print('❌ MesajKocuAnalizi dönüştürme hatası: $e');
      return MesajKocuAnalizi(
        analiz: 'Analiz sırasında bir hata oluştu: $e',
        etki: {'hata': 100},
        oneriler: ['Lütfen daha sonra tekrar deneyin'],
      );
    }
  }
  
  // İlişki danışma tavsiyesi alma
  Future<Map<String, dynamic>> getAdvice(String question) async {
    try {
      _logger.d('Danışma talebi: $question');
      
      // İlişki danışmanlığı yanıtı al
      final Map<String, dynamic> response = await _aiService.getRelationshipAdvice(question, null);
      
      if (response.containsKey('error')) {
        _logger.w('Danışma yanıtı alınamadı: ${response['error']}');
        return {'error': response['error']};
      }
      
      return response;
    } catch (e) {
      _logger.e('Danışma işlemi sırasında hata: $e');
      return {'error': 'Danışma yanıtı alınamadı: $e'};
    }
  }
  
  // Firestore'a analiz sonucunu kaydetme
  Future<void> _saveAnalysisToFirestore(String userId, MesajKocuAnalizi analiz, String messageText) async {
    try {
      final data = analiz.toFirestore();
      data['userId'] = userId;
      data['messageText'] = messageText;
      data['timestamp'] = Timestamp.now();
      
      await _firestore.collection('message_coach_analyses').add(data);
    } catch (e) {
      _logger.e('Analiz kaydedilirken hata: $e');
    }
  }
  
  // Kullanıcının bugün yaptığı analiz sayısını kontrol etme ve artırma
  Future<void> _incrementAnalysisCount(String userId) async {
    try {
      // Bugünün tarihini al (saat bilgisini sıfırla)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Kullanıcının bugün yaptığı analizleri sorgula
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      _ucretlizAnalizSayisi = analysisSnapshot.docs.length;
      
      _logger.i('Bugün yapılan analiz sayısı: $_ucretlizAnalizSayisi');
      notifyListeners();
    } catch (e) {
      _logger.e('Analiz sayısı kontrol edilirken hata: $e');
    }
  }
  
  // Kullanıcının bugün yaptığı analiz sayısını yükleme
  Future<void> loadAnalysisCount(String userId) async {
    try {
      if (userId.isEmpty) return;
      
      // Bugünün tarihini al (saat bilgisini sıfırla)
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Kullanıcının bugün yaptığı analizleri sorgula
      final QuerySnapshot analysisSnapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      _ucretlizAnalizSayisi = analysisSnapshot.docs.length;
      
      _logger.i('Bugün yapılan analiz sayısı yüklendi: $_ucretlizAnalizSayisi');
      notifyListeners();
    } catch (e) {
      _logger.e('Analiz sayısı yüklenirken hata: $e');
    }
  }
  
  // Kullanıcının geçmiş analizlerini getirme
  Future<List<Map<String, dynamic>>> getAnalysisHistory(String userId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      
      final List<Map<String, dynamic>> history = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
      
      return history;
    } catch (e) {
      _setError('Analiz geçmişi alınırken hata oluştu: $e');
      return [];
    }
  }
  
  // Kullanıcının tüm verilerini temizleme
  Future<void> clearUserData(String userId) async {
    try {
      // Mesaj Koçu analizlerini temizle
      final QuerySnapshot analyses = await _firestore
          .collection('message_coach_analyses')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in analyses.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      // Yerel verileri sıfırla
      _mesajAnalizi = null;
      _ucretlizAnalizSayisi = 0;
      
      notifyListeners();
      _logger.i('Kullanıcı verileri temizlendi: $userId');
    } catch (e) {
      _logger.e('Kullanıcı verileri temizlenirken hata: $e');
      _setError('Veriler temizlenirken hata oluştu: $e');
    }
  }
  
  // Yardımcı metodlar
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  void _setAnalyzing(bool value) {
    // İç durumu değiştir
    _isAnalyzing = value;
    
    // Log ekle
    _logger.i('_setAnalyzing çağrıldı - Yeni durum: $_isAnalyzing');
    
    // UI'a bildir
    notifyListeners();
  }
  
  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
  
  // Kullanıcı oturumu kapandığında
  void onUserSignOut() {
    _mesajAnalizi = null;
    _ucretlizAnalizSayisi = 0;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Analiz sonucunu sıfırlama
  void resetAnalysisResult() {
    _mesajAnalizi = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Hata mesajını sıfırla
  void resetError() {
    _errorMessage = null;
    notifyListeners();
    _logger.d('Hata mesajı sıfırlandı');
  }
  
  // Durumu zorla güncelleme yöntemleri
  void forceStartAnalysis() {
    _isLoading = true;
    _isAnalyzing = true;
    _mesajAnalizi = null;
    _errorMessage = null;
    notifyListeners();
    print('➡️ Analiz başlatıldı - isAnalyzing=$_isAnalyzing');
  }
  
  void forceStopAnalysis() {
    // Tüm state'leri temizle
    _isLoading = false;
    _isAnalyzing = false;
    
    // Durumları bildirip debug log yazdır
    notifyListeners();
    print('➡️ Analiz durduruldu - isAnalyzing=$_isAnalyzing, hasAnalizi=$hasAnalizi');
    
    // Durumun tamamen temizlenmesini garanti edelim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // İkinci bir bildirim - build işlemi tamamlandıktan sonra
      notifyListeners();
    });
  }
  
  void refreshUI() {
    notifyListeners();
    print('🔄 UI yenileniyor - isAnalyzing=$_isAnalyzing, hasAnalizi=${hasAnalizi}');
    
    // Takılı kalan analiz durumunu kontrol edip temizleyelim
    if (_isAnalyzing && !_isLoading) {
      // Durumu sıfırla
      print('⚠️ Analiz durumu sıfırlanıyor');
      _isAnalyzing = false;
      notifyListeners();
    }
  }
  
  // MessageViewModel'den gelen analiz sonucunu ayarla
  void setAnalysisResultFromMessage(dynamic analysisResult) {
    try {
      print('🔄 MessageViewModel analiz sonucu işleniyor...');
      
      // AnalysisResult'tan MesajKocuAnalizi oluştur
      final mesajAnalizi = _convertAnalysisToMesajKocu(analysisResult);
      
      // Mesaj analiz sonucunu ayarla
      _mesajAnalizi = mesajAnalizi;
      _isLoading = false;
      _isAnalyzing = false;
      _errorMessage = null;
      
      // UI'a bildir
      notifyListeners();
      
      print('✅ Mesaj analizi yüklendi: ${_mesajAnalizi?.anlikTavsiye?.substring(0, min(30, _mesajAnalizi?.anlikTavsiye?.length ?? 0))}...');
    } catch (e) {
      print('❌ Analiz sonucu dönüştürme hatası: $e');
      setError('Analiz sonucu işlenirken hata oluştu: $e');
    }
  }
  
  // Hata mesajını ayarla
  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    _isAnalyzing = false;
    notifyListeners();
    print('❌ Hata ayarlandı: $message');
  }
}