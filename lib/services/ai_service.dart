import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_result_model.dart';
import '../models/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

class AiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoggerService _logger = LoggerService();
  
  // API anahtarını .env dosyasından alma
  String get _apiKey => dotenv.env['AI_API_KEY'] ?? '';
  String get _apiUrl => dotenv.env['AI_API_URL'] ?? 'https://api.openai.com/v1/chat/completions';

  // Mesajı analiz etme
  Future<AnalysisResult?> analyzeMessage(Message message) async {
    try {
      _logger.i('Mesaj analizi başlatılıyor: ${message.id}');
      
      // OpenAI veya Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'Sen bir ilişki analiz uzmanısın. Verilen mesajı analiz et ve duygu, niyet, ton ve ciddiyetini belirle.'
            },
            {
              'role': 'user',
              'content': 'Bu mesajı analiz et: "${message.content}"'
            }
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        _logger.d('API yanıtı alındı - status: ${response.statusCode}');
        
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['choices'][0]['message']['content'];
        
        // AI yanıtını işleme
        final Map<String, dynamic> parsedResponse = _parseAiResponse(aiContent);
        
        // Analiz sonucunu oluşturma
        final analysisResult = AnalysisResult(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          messageId: message.id,
          emotion: parsedResponse['emotion'] ?? 'nötr',
          intent: parsedResponse['intent'] ?? 'belirsiz',
          tone: parsedResponse['tone'] ?? 'normal',
          severity: parsedResponse['severity'] ?? 5,
          aiResponse: parsedResponse,
          createdAt: DateTime.now(),
        );
        
        // Firestore'a kaydetme
        await _saveAnalysisResult(analysisResult);
        
        // Mesajı analiz edildi olarak işaretle
        await _updateMessageAnalyzed(message.id);
        
        _logger.i('Mesaj analizi tamamlandı: ${message.id}');
        return analysisResult;
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.e('Mesaj analizi hatası', e);
      return null;
    }
  }

  // İlişki raporu oluşturma
  Future<Map<String, dynamic>> generateRelationshipReport(List<String> answers) async {
    try {
      // OpenAI veya Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'Sen bir ilişki koçusun. Aşağıdaki 5 soruya verilen yanıtlara dayanarak bir ilişki raporu hazırla.'
            },
            {
              'role': 'user',
              'content': '''
                Soru 1: İlişkinizdeki en büyük sorun nedir?
                Yanıt: ${answers[0]}
                
                Soru 2: Partnerinizle nasıl iletişim kuruyorsunuz?
                Yanıt: ${answers[1]}
                
                Soru 3: İlişkinizde sizi en çok ne mutlu ediyor?
                Yanıt: ${answers[2]}
                
                Soru 4: İlişkinizde gelecek beklentileriniz neler?
                Yanıt: ${answers[3]}
                
                Soru 5: İlişkinizde değiştirmek istediğiniz bir şey var mı?
                Yanıt: ${answers[4]}
              '''
            }
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['choices'][0]['message']['content'];
        
        // Raporu oluşturma ve döndürme
        return {
          'report': aiContent,
          'relationship_type': _extractRelationshipType(aiContent),
          'suggestions': _extractSuggestions(aiContent),
          'created_at': DateTime.now().toIso8601String(),
        };
      } else {
        debugPrint('API Hatası: ${response.statusCode} - ${response.body}');
        return {'error': 'Rapor oluşturulamadı'};
      }
    } catch (e) {
      debugPrint('Rapor oluşturma hatası: $e');
      return {'error': 'Bir hata oluştu'};
    }
  }

  // Günlük tavsiye kartı alma
  Future<Map<String, dynamic>> getDailyAdviceCard(String userId) async {
    try {
      // OpenAI veya Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4',
          'messages': [
            {
              'role': 'system',
              'content': 'Sen bir ilişki koçusun. Bir ilişki konusunda günlük bir tavsiye kartı oluştur.'
            },
            {
              'role': 'user',
              'content': 'Bugün için ilişkiler üzerine bir tavsiye kartı oluştur.'
            }
          ],
          'max_tokens': 300,
          'temperature': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['choices'][0]['message']['content'];
        
        // Tavsiye kartını döndür
        return {
          'advice': aiContent,
          'title': _extractAdviceTitle(aiContent),
          'created_at': DateTime.now().toIso8601String(),
        };
      } else {
        debugPrint('API Hatası: ${response.statusCode} - ${response.body}');
        return {'error': 'Tavsiye kartı oluşturulamadı'};
      }
    } catch (e) {
      debugPrint('Tavsiye kartı oluşturma hatası: $e');
      return {'error': 'Bir hata oluştu'};
    }
  }

  // AI yanıtını ayrıştırma
  Map<String, dynamic> _parseAiResponse(String aiContent) {
    try {
      _logger.d('AI yanıtı ayrıştırılıyor');
      
      // AI'ın JSON formatında yanıt verdiğini varsayarsak
      if (aiContent.contains('{') && aiContent.contains('}')) {
        // JSON başlangıç ve bitiş indekslerini bulma
        final jsonStartIndex = aiContent.indexOf('{');
        final jsonEndIndex = aiContent.lastIndexOf('}') + 1;
        final jsonString = aiContent.substring(jsonStartIndex, jsonEndIndex);
        
        // JSON'ı ayrıştırma
        return jsonDecode(jsonString);
      }
      
      // Basit metin yanıtı ise manuel ayrıştırma
      return {
        'emotion': _extractFromText(aiContent, 'duygu', 'nötr'),
        'intent': _extractFromText(aiContent, 'niyet', 'belirsiz'),
        'tone': _extractFromText(aiContent, 'ton', 'normal'),
        'severity': _extractSeverity(aiContent),
        'analysis': aiContent,
      };
    } catch (e) {
      _logger.e('AI yanıtı ayrıştırma hatası', e);
      return {
        'emotion': 'nötr',
        'intent': 'belirsiz',
        'tone': 'normal',
        'severity': 5,
        'analysis': aiContent,
      };
    }
  }

  // Metinden belirli bir öğeyi çıkarma
  String _extractFromText(String text, String field, String defaultValue) {
    final regex = RegExp('$field:?\\s*([\\wöçşığüÖÇŞİĞÜ]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1)?.toLowerCase() ?? defaultValue;
  }

  // Metinden ciddiyet seviyesini çıkarma
  int _extractSeverity(String text) {
    final regex = RegExp('ciddiyet:?\\s*(\\d+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    final severityStr = match?.group(1);
    
    if (severityStr != null) {
      final severity = int.tryParse(severityStr);
      if (severity != null && severity >= 1 && severity <= 10) {
        return severity;
      }
    }
    
    return 5; // Varsayılan ciddiyet
  }

  // Metinden ilişki tipini çıkarma
  String _extractRelationshipType(String text) {
    final regex = RegExp('ilişki\\s*tipi:?\\s*([\\wöçşığüÖÇŞİĞÜ\\s]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim() ?? 'Dengeli İlişki';
  }

  // Metinden önerileri çıkarma
  List<String> _extractSuggestions(String text) {
    final suggestions = <String>[];
    final regex = RegExp('öneriler:(.*?)(?=\\n\\n|\\z)', caseSensitive: false, dotAll: true);
    final match = regex.firstMatch(text);
    
    if (match != null && match.group(1) != null) {
      final suggestionsText = match.group(1)!.trim();
      final lines = suggestionsText.split('\n');
      
      for (var line in lines) {
        line = line.trim();
        if (line.startsWith('-') || line.startsWith('•')) {
          suggestions.add(line.substring(1).trim());
        } else if (line.isNotEmpty) {
          suggestions.add(line);
        }
      }
    }
    
    // Öneriler bulunamazsa varsayılan öneriler
    if (suggestions.isEmpty) {
      suggestions.addAll([
        'Açık iletişim kurmaya çalışın',
        'Birbirinize zaman ayırın',
        'Beklentilerinizi net bir şekilde ifade edin',
      ]);
    }
    
    return suggestions;
  }

  // Tavsiye başlığını çıkarma
  String _extractAdviceTitle(String text) {
    final lines = text.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        return line;
      }
    }
    return 'Günün İlişki Tavsiyesi';
  }

  // Analiz sonucunu Firestore'a kaydet
  Future<void> _saveAnalysisResult(AnalysisResult result) async {
    try {
      _logger.d('Analiz sonucu Firestore\'a kaydediliyor: ${result.id}');
      await _firestore.collection('analysis_results').doc(result.id).set(result.toFirestore());
      _logger.d('Analiz sonucu başarıyla kaydedildi');
    } catch (e) {
      _logger.e('Analiz sonucu kaydetme hatası', e);
    }
  }

  // Mesajı analiz edildi olarak işaretle
  Future<void> _updateMessageAnalyzed(String messageId) async {
    try {
      _logger.d('Mesaj analiz edildi olarak işaretleniyor: $messageId');
      await _firestore.collection('messages').doc(messageId).update({
        'isAnalyzed': true,
      });
      _logger.d('Mesaj başarıyla güncellendi');
    } catch (e) {
      _logger.e('Mesajı güncelleme hatası', e);
    }
  }
} 