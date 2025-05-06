import 'package:flutter/foundation.dart';

@immutable
class MessageCoachVisualAnalysis {
  /// Analiz bölümüne yönlendirme gerekiyor mu?
  final bool isAnalysisRedirect;
  
  /// Yönlendirme mesajı (isAnalysisRedirect = true ise)
  final String? redirectMessage;
  
  /// Durumun değerlendirmesi (isAnalysisRedirect = false ise)
  final String? konumDegerlendirmesi;
  
  /// Alternatif mesaj önerileri
  final List<String> alternativeMessages;
  
  /// Potansiyel partner yanıtları [olumlu, olumsuz]
  final List<String> partnerResponses;
  
  const MessageCoachVisualAnalysis({
    required this.isAnalysisRedirect,
    this.redirectMessage,
    this.konumDegerlendirmesi,
    required this.alternativeMessages,
    required this.partnerResponses,
  });
      
  /// Boş bir analiz nesnesi oluşturma  
  static MessageCoachVisualAnalysis bos() => const MessageCoachVisualAnalysis(
    isAnalysisRedirect: false,
    konumDegerlendirmesi: "Analiz henüz tamamlanmadı.",
    alternativeMessages: [],
    partnerResponses: []
  );
  
  /// Hata durumunda analiz nesnesi oluşturma
  static MessageCoachVisualAnalysis hata(String hataIleti) => MessageCoachVisualAnalysis(
    isAnalysisRedirect: false,
    konumDegerlendirmesi: "Hata: $hataIleti",
    alternativeMessages: [],
    partnerResponses: []
  );
} 