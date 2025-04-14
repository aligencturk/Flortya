import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/analysis_result_model.dart';
import 'logger_service.dart';

class AiService {
  final LoggerService _logger = LoggerService();
  
  // Gemini API anahtarını ve ayarlarını .env dosyasından alma
  String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get _geminiModel => dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.0-flash';
  int get _geminiMaxTokens => int.tryParse(dotenv.env['GEMINI_MAX_TOKENS'] ?? '1024') ?? 1024;
  String get _geminiApiUrl => 'https://generativelanguage.googleapis.com/v1/models/$_geminiModel:generateContent?key=$_geminiApiKey';

  // İlişki raporu yorumuna yanıt oluşturma
  Future<Map<String, dynamic>> getCommentResponse(
    String comment, 
    String report, 
    String relationshipType
  ) async {
    try {
      _logger.i('Yorum yanıtı oluşturuluyor. Yorum: $comment');
      
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': '''
                Sen bir ilişki terapistisin. Kullanıcı ilişki raporu hakkında bir yorum yaptı.
                
                İlişki tipi: $relationshipType
                
                Rapor: $report
                
                Kullanıcının yorumu: "$comment"
                
                Bu yoruma empati kurarak, yapıcı ve samimi bir şekilde yanıt ver. Yanıt Türkçe olmalı ve en fazla 150 kelime olmalı.
                '''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Yorum yanıtı API isteği: $_geminiApiUrl');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Yanıt alınamadı'};
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        return {'answer': aiContent};
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Yanıt alınırken hata oluştu'};
      }
    } catch (e) {
      _logger.e('Yorum yanıtı hatası', e);
      return {'error': 'Beklenmeyen bir hata oluştu'};
    }
  }

  // İlişki danışmanı chat fonksiyonu
  Future<Map<String, dynamic>> getRelationshipAdvice(String question, List<Map<String, String>>? chatHistory) async {
    try {
      _logger.i('İlişki tavsiyesi alınıyor. Soru: $question');
      
      // Chat geçmişini hazırla
      final contents = <Map<String, dynamic>>[];
      
      // Sistem mesajını ekle
      contents.add({
        'role': 'model',
        'parts': [
          {
            'text': '''
            Sen bir ilişki danışmanısın. Kullanıcının ilişki sorunlarına ve sorularına profesyonel 
            tavsiyeler veriyorsun. İlişkilerin sağlıklı gelişmesi, iletişim problemlerinin çözülmesi ve
            romantik ilişkilerin iyileştirilmesi konusunda uzmansın. Vereceğin cevaplar:
            
            1. Empatik ve anlayışlı olmalı
            2. Yapıcı ve pratik öneriler içermeli
            3. Yargılayıcı olmamalı
            4. Bilimsel temellere dayanmalı
            5. Kültürel olarak duyarlı olmalı
            
            Cevaplarında Türkçe dilini kullan ve samimi bir üslup benimse.
            '''
          }
        ]
      });
      
      // Chat geçmişini ekle
      if (chatHistory != null && chatHistory.isNotEmpty) {
        for (final message in chatHistory) {
          contents.add({
            'role': message['role'] ?? 'user',
            'parts': [
              {
                'text': message['text'] ?? ''
              }
            ]
          });
        }
      }
      
      // Kullanıcının yeni sorusunu ekle
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': question
          }
        ]
      });
      
      // Gemini API'ye istek gönderme
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('İlişki tavsiyesi API isteği: $_geminiApiUrl');
      _logger.d('İstek gövdesi özeti: ${contents.length} mesaj');
      
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Tavsiye alınamadı'};
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // Tavsiye verilerini oluştur
        final advice = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'question': question,
          'answer': aiContent,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'chat'
        };
        
        _logger.i('İlişki tavsiyesi başarıyla alındı');
        return advice;
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Tavsiye alınırken hata oluştu. Lütfen tekrar deneyiniz.'};
      }
    } catch (e) {
      _logger.e('İlişki tavsiyesi hatası', e);
      return {'error': 'Beklenmeyen bir hata oluştu'};
    }
  }

  // Mesajı analiz etme
  Future<AnalysisResult?> analyzeMessage(String messageContent) async {
    try {
      _logger.i('Mesaj analizi başlatılıyor...');
      
      // Mesaj içeriğini kontrol etme
      if (messageContent.trim().isEmpty) {
        _logger.w('Boş mesaj içeriği, analiz yapılamıyor');
        return null;
      }
      
      // Mesaj türünü belirleme
      final bool isImageMessage = messageContent.contains("Ekran görüntüsü:") || 
          messageContent.contains("Görsel:") ||
          messageContent.contains("Fotoğraf:");
      
      final bool hasExtractedText = messageContent.contains("Görseldeki metin:") && 
          messageContent.split("Görseldeki metin:").length > 1 && 
          messageContent.split("Görseldeki metin:")[1].trim().isNotEmpty;
      
      // Prompt hazırlama
      String prompt = '';
      
      if (isImageMessage && hasExtractedText) {
        // Ekran görüntüsü ve OCR ile metin çıkarılmış
        prompt = '''
        Sen bir ilişki analiz uzmanı ve koçusun. Senin en önemli özelliğin ise son derece samimi, sıcak ve empatik bir arkadaş gibi cevap vermen. Bu mesaj bir ekran görüntüsü içeriyor ve görselden çıkarılan metin var. 
        
        Lütfen ekran görüntüsünden çıkarılan metne dayanarak aşağıdaki mesajın detaylı analizini yap:
        
        1. Ekran görüntüsündeki metin muhtemelen bir sohbet veya mesaj içeriyor - buna göre değerlendir.
        2. ÖNEMLİ: Sohbette kim mesaj göndermiş, kim mesaj almış bunu anlamaya çalış. Bu kişilere "mesaj gönderen" ve "mesaj alan" veya "konuşmacı 1" ve "konuşmacı 2" olarak atıfta bulun.
        3. Konuşmanın hangi tarafında analizi isteyen kişinin olduğunu belirlemeye çalış. Analizi isteyen kişi genelde şikayet eden, ilişki tavsiyesi almak isteyen kişi olabilir.
        4. Sohbetteki mesaj baloncuklarının düzeni (sağ-sol) veya zaman damgalarına dikkat ederek kimlikleri ayırt etmeye çalış.
        5. Metinde bahsedilen konuları, duyguları ve ilişki dinamiklerini analiz et.
        6. Metindeki kişilerin iletişim şekline, kullandıkları dile ve ilişkilerine dair ipuçlarını değerlendir.
        7. Cevabını ilişki koçu olarak değil, yakın bir arkadaş veya güvenilen bir dost gibi ver.
        8. Samimi, sıcak ve empatik bir dil kullan, resmi dilden uzak dur.
        9. "Sen" diye hitap et, "siz" değil.
        10. Günlük konuşma diline uygun, samimi ifadeler kullan (örn: "bence", "ya", "aslında", "hissediyorum ki" gibi).
        
        Analizi şu formatta JSON çıktısı olarak ver:
        
        {
          "duygu": "metindeki baskın duygu (pozitif, negatif, nötr, vb.)",
          "niyet": "mesajın/konuşmanın arkasındaki niyet",
          "ton": "iletişim tonu (samimi, resmi, agresif, sevecen, vb.)",
          "ciddiyet": "1-10 arasında bir rakam, 10 en ciddi",
          "kişiler": "konuşmada kimler var (örn: 'mesaj gönderen', 'mesaj alan' - bu kişileri net bir şekilde tanımla)",
          "mesajYorumu": "metindeki ilişki dinamiğine dair arkadaşça ve empatik bir yorum. Kullanıcıya bir arkadaşı konuşuyormuş gibi hitap et. Konuşmada kimin ne dediğini net olarak belirt.",
          "cevapOnerileri": [
            "Bu mesaja nasıl cevap vereceğine dair çok somut bir öneri. 'Şunu yazabilirsin: [örnek bir yanıt]' formatında olmalı. AÇIKÇA BELİRT bu öneri hangi kişiden hangi kişiye gidiyor.",
            "Bu duruma göre nasıl davranmanın ve ne söylemenin uygun olacağına dair ikinci somut öneri. Kesin cümleler ve ifade biçimleri içermeli. Kime hitap ettiğini net belirt.",
            "İlişki dinamiğini koruyarak nasıl yanıt vereceğin konusunda üçüncü bir taktik. İletişim stratejisi önerisi içermeli. Karşı tarafın kim olduğunu belirterek verilen bir öneri olsun."
          ]
        }
        
        Analiz edilecek mesaj: "${messageContent}"
        ''';
      } else if (isImageMessage) {
        // Sadece ekran görüntüsü var, OCR metni yok
        prompt = '''
        Sen bir ilişki analiz uzmanı ve yakın bir arkadaşsın. Senin en önemli özelliğin çok samimi, sıcak ve empatik bir şekilde cevap vermen. Bu mesaj bir ekran görüntüsü veya fotoğraf hakkında. 
        Mesaj içinde ekran görüntüsünden bahsediliyor. Görüntüyü göremediğimiz için, bu durumda:
        
        1. Bu muhtemelen bir sohbet ekranından alınmış ekran görüntüsü olabilir.
        2. Kullanıcı ilişkisiyle ilgili bir mesaj içeriğini, ekran görüntüsü formatında göndermek istemiş olabilir.
        3. Aşağıdaki mesaj bir görüntü açıklaması olabilir. 
        4. Kullanıcının analiz ettiği sohbette muhtemelen iki kişi var - biri mesajı gönderen diğeri alan.
        5. Kullanıcının tavsiye almak istediği kişi muhtemelen kendisi, karşı taraf ise mesajlaştığı partneri.
        
        Sana metin olarak gönderilen bilgiden yola çıkarak, bu tür bir ilişki mesajının aşağıdaki formatta analizini yap. Bir arkadaş veya güvenilen bir dost gibi cevap ver. Resmi dilden kaçın, günlük konuşma dilini kullan:
        
        {
          "duygu": "ekran görüntüsü mesajı olduğu için 'Belirlenemedi' yazabilirsin ya da içerik hakkında bir tahminde bulunabilirsin",
          "niyet": "ekran görüntüsünü paylaşmaktaki muhtemel niyet",
          "ton": "saygılı - ilişki ekran görüntüsü paylaşımı",
          "ciddiyet": "7",
          "kişiler": "muhtemelen kullanıcı ve mesajlaştığı kişi",
          "mesajYorumu": "Ekran görüntülerini göremediğim için tam bir analiz yapamıyorum ama seninle dost gibi konuşmaya çalışacağım. Bana görüntüleri paylaşman içini dökmek istediğini gösteriyor ve bunu çok iyi anlıyorum.",
          "cevapOnerileri": [
            "Bu mesaja şöyle cevap verebilirsin: '[somut bir cevap örneği]'. Bu yaklaşım karşı tarafın (mesajı gönderen kişinin) seni daha iyi anlamasını sağlayacak.",
            "Bence bu durumda duygularını açıkça ifade ederek '[somut öneri]' şeklinde yanıt vermen daha sağlıklı olur. Böylece karşındaki kişi (mesajı alan taraf) senin ne hissettiğini anlayabilir.",
            "Eğer bu bir tartışma ise, mesajı '[somut iletişim stratejisi]' ile yanıtlayarak ilişkini koruyabilirsin. Karşı tarafın (mesaj yazan kişi) bakış açısını anladığını göstermiş olursun."
          ]
        }
        
        Analiz edilecek mesaj: "${messageContent}"
        ''';
      } else {
        // Normal metin mesajı
        prompt = '''
        Sen bir ilişki analiz uzmanı olmasına rağmen, yakın bir arkadaş gibi davranıyorsun. Kullanıcıya asla bir uzman gibi cevap verme, bir arkadaş olarak cevap ver. 
        Resmi dilden ve profesyonel söylemlerden kaçın. Samimi, empatik ve sıcak bir yaklaşım sergile.
        
        Aşağıdaki ilişki mesajının analizini yap:
        
        1. Mesajdaki baskın duyguyu belirle
        2. Mesajın arkasındaki niyeti anlamaya çalış
        3. İletişimin tonunu belirle (samimi, resmi, agresif, sevecen, vb.)
        4. Mesajın ciddiyetini 1-10 arası derecelendir (10 en ciddi)
        5. Mesajda konuşan kişileri belirlemeye çalış - kim mesaj gönderiyor, kim alıyor veya mesajın içeriğinde bahsedilen kişiler kimler
        6. Mesajla ilgili dostça ve empatik bir yorum yap
        7. Mesaja nasıl yaklaşılması gerektiğine dair somut ve uygulanabilir öneriler sun
        
        Cevabını şu format içinde, ama bir arkadaş gibi konuşarak hazırla:
        
        {
          "duygu": "mesajdaki baskın duygu",
          "niyet": "mesajın arkasındaki niyet",
          "ton": "iletişim tonu",
          "ciddiyet": "1-10 arası rakam",
          "kişiler": "mesajda konuşan veya bahsedilen kişiler (örn: kullanıcı ve partneri)",
          "mesajYorumu": "mesaj hakkında arkadaşça, empatik bir yorum. Kesinlikle 'Sen' diye hitap et, 'siz' değil. Günlük konuşma diline uygun ifadeler kullan.",
          "cevapOnerileri": [
            "Bu mesaja şöyle cevap verebilirsin: '[somut bir cevap örneği]'. Bu yaklaşım iletişimi güçlendirecek. Hangi tarafın (mesaj gönderen/alan) ne yapması gerektiğini açıkça belirt.",
            "Bence bu durumda '[belirli bir iletişim stratejisi]' kullanarak yanıt vermen daha etkili olur. Örneğin: '[örnek yanıt]'. Bu yanıt karşı tarafın (partnerin) seni anlamasını kolaylaştırır.",
            "Eğer ilişkide bu konuyu ilerletmek istiyorsan, mesajı '[belirli bir teknik]' kullanarak yanıtla. Şöyle diyebilirsin: '[örnek yanıt]'. Böylece mesajı gönderen kişi senin bakış açını daha iyi anlayabilir."
          ]
        }
        
        Analiz edilecek mesaj: "${messageContent}"
        ''';
      }
      
      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': prompt
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': _geminiMaxTokens
        }
      });
      
      _logger.d('Gemini API isteği: $_geminiApiUrl');
      _logger.d('İstek gövdesi: $requestBody');
      
      // Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );
      
      _logger.d('API yanıtı - status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _logger.d('API yanıt içeriği: ${response.body}');
        
        // Gemini'nin yanıtını alıyoruz
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return null;
        }
        
        _logger.d('AI yanıt metni: $aiContent');
        
        // AI yanıtını işleme
        try {
          final Map<String, dynamic> parsedResponse = _parseAiResponse(aiContent);
          _logger.d('Ayrıştırılmış yanıt: $parsedResponse');
          
          // Analiz sonucunu oluşturma
          final analysisResult = AnalysisResult(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            messageId: DateTime.now().millisecondsSinceEpoch.toString(),
            emotion: parsedResponse['duygu'] ?? 'nötr',
            intent: parsedResponse['niyet'] ?? 'belirsiz',
            tone: parsedResponse['ton'] ?? 'normal',
            severity: _parseSeverity(parsedResponse['ciddiyet']),
            persons: parsedResponse['kişiler'] ?? '',
            aiResponse: {
              'mesajYorumu': parsedResponse['mesajYorumu'] ?? parsedResponse['mesaj_yorumu'] ?? '',
              'cevapOnerileri': _parseStringList(parsedResponse['cevapOnerileri'] ?? parsedResponse['cevap_onerileri'] ?? []),
            },
            createdAt: DateTime.now(),
          );
          
          _logger.i('Mesaj analizi tamamlandı');
          return analysisResult;
        } catch (e) {
          _logger.e('Yanıt ayrıştırma hatası', e);
          return null;
        }
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
      // Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
                  Sen bir ilişki koçusun. Aşağıdaki 5 soruya verilen yanıtlara dayanarak bir ilişki raporu hazırla.
                  
                  Raporu aşağıdaki JSON formatında hazırla:
                  {
                    "relationship_type": "ilişki tipi (sağlıklı, gelişmekte olan, zorlayıcı, vb.)",
                    "report": "Detaylı ilişki raporu",
                    "suggestions": ["öneri 1", "öneri 2", "öneri 3"]
                  }
                  
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
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Rapor oluşturulamadı'};
        }
        
        // JSON yanıtı ayrıştırma
        try {
          Map<String, dynamic> jsonResponse = _parseJsonFromText(aiContent);
          jsonResponse['created_at'] = DateTime.now().toIso8601String();
          return jsonResponse;
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası', e);
          return {
            'report': aiContent,
            'relationship_type': _extractRelationshipType(aiContent),
            'suggestions': _extractSuggestions(aiContent),
            'created_at': DateTime.now().toIso8601String(),
          };
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Rapor oluşturulamadı'};
      }
    } catch (e) {
      _logger.e('Rapor oluşturma hatası', e);
      return {'error': 'Bir hata oluştu'};
    }
  }

  // Günlük tavsiye kartı alma
  Future<Map<String, dynamic>> getDailyAdviceCard(String userId) async {
    try {
      // Gemini API'ye istek gönderme
      final response = await http.post(
        Uri.parse(_geminiApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '''
                  Sen bir ilişki koçusun. Bir ilişkiyi güçlendirmek için günlük bir tavsiye kartı oluştur.
                  
                  Tavsiyeyi şu JSON formatında hazırla:
                  {
                    "title": "Tavsiye başlığı",
                    "content": "Tavsiye içeriği - nasıl uygulanacağıyla ilgili detaylı açıklama",
                    "category": "tavsiye kategorisi (iletişim, duygusal bağ, aktiviteler, vb.)"
                  }
                  '''
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.9,
            'maxOutputTokens': _geminiMaxTokens
          }
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final aiContent = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (aiContent == null) {
          _logger.e('AI yanıtı boş veya beklenen formatta değil', data);
          return {'error': 'Tavsiye kartı oluşturulamadı'};
        }
        
        // JSON yanıtı ayrıştırma
        try {
          Map<String, dynamic> jsonResponse = _parseJsonFromText(aiContent);
          jsonResponse['created_at'] = DateTime.now().toIso8601String();
          return jsonResponse;
        } catch (e) {
          _logger.e('JSON ayrıştırma hatası', e);
          return {
            'title': _extractAdviceTitle(aiContent),
            'content': aiContent,
            'created_at': DateTime.now().toIso8601String(),
          };
        }
      } else {
        _logger.e('API Hatası', '${response.statusCode} - ${response.body}');
        return {'error': 'Tavsiye kartı oluşturulamadı'};
      }
    } catch (e) {
      _logger.e('Tavsiye kartı oluşturma hatası', e);
      return {'error': 'Bir hata oluştu'};
    }
  }

  // AI yanıtını ayrıştırma
  Map<String, dynamic> _parseAiResponse(String aiContent) {
    try {
      _logger.d('AI yanıtı ayrıştırılıyor');
      return _parseJsonFromText(aiContent);
    } catch (e) {
      _logger.e('AI yanıtı ayrıştırma hatası: $e, içerik: $aiContent');
      
      // JSON ayrıştırma başarısız olursa, manuel olarak ayrıştırma dene
      final Map<String, dynamic> fallbackResponse = {
        'duygu': _extractFieldFromText(aiContent, 'duygu') ?? 'nötr',
        'niyet': _extractFieldFromText(aiContent, 'niyet') ?? 'belirsiz',
        'ton': _extractFieldFromText(aiContent, 'ton') ?? 'normal',
        'ciddiyet': _extractFieldFromText(aiContent, 'ciddiyet') ?? '5',
        'kişiler': _extractFieldFromText(aiContent, 'kişiler') ?? 'belirsiz',
      };
      
      return fallbackResponse;
    }
  }
  
  // Metinden alan çıkarma
  String? _extractFieldFromText(String text, String fieldName) {
    final RegExp regex = RegExp('"$fieldName"\\s*:\\s*"([^"]*)"', caseSensitive: false);
    final match = regex.firstMatch(text);
    final value = match?.group(1)?.trim();
    _logger.d('$fieldName alanı çıkarıldı: $value');
    return value;
  }
  
  // Metinden sayısal alan çıkarma
  int? _extractNumericFieldFromText(String text, String fieldName) {
    final RegExp regex = RegExp('"$fieldName"\\s*:\\s*(\\d+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match == null) {
      // Alternatif regex - tırnak içinde sayı olabilir
      final altRegex = RegExp('"$fieldName"\\s*:\\s*"(\\d+)"', caseSensitive: false);
      final altMatch = altRegex.firstMatch(text);
      final altValue = altMatch?.group(1);
      final numericValue = altValue != null ? int.tryParse(altValue) : null;
      return numericValue ?? 5; // Varsayılan değer
    }
    
    final value = match.group(1);
    final numericValue = value != null ? int.tryParse(value) : null;
    return numericValue ?? 5; // Varsayılan değer
  }
  
  // Metinden önerileri çıkarma
  List<String>? _extractSuggestionsFromText(String text) {
    // Öneri listesi için regex
    final RegExp listRegex = RegExp('"cevap_onerileri"\\s*:\\s*\\[(.*?)\\]', caseSensitive: false, dotAll: true);
    final listMatch = listRegex.firstMatch(text);
    
    if (listMatch != null && listMatch.group(1) != null) {
      final listContent = listMatch.group(1)!;
      final suggestions = RegExp('"([^"]*)"').allMatches(listContent)
          .map((m) => m.group(1)?.trim())
          .where((s) => s != null && s.isNotEmpty)
          .map((s) => s!)
          .toList();
      
      _logger.d('Öneriler çıkarıldı: $suggestions');
      return suggestions.isNotEmpty ? suggestions : null;
    }
    
    // Madde işaretli liste biçiminde olabilir
    final bulletedItems = text.split('\n')
        .where((line) => line.contains('- ') || RegExp(r'^\d+\.').hasMatch(line.trim()))
        .map((line) => line.replaceAll(RegExp(r'^-|\d+\.'), '').trim())
        .where((item) => item.isNotEmpty)
        .toList();
    
    if (bulletedItems.isNotEmpty) {
      _logger.d('Madde işaretli öneriler çıkarıldı: $bulletedItems');
      return bulletedItems;
    }
    
    return null;
  }

  // Metinden JSON çıkarma
  Map<String, dynamic> _parseJsonFromText(String text) {
    // JSON'ı metinden çıkar
    final RegExp jsonRegex = RegExp(r'\{[\s\S]*\}');
    final match = jsonRegex.firstMatch(text);
    
    if (match == null) {
      throw Exception('Metinde JSON bulunamadı');
    }
    
    final jsonString = match.group(0);
    if (jsonString == null) {
      throw Exception('JSON çıkarılamadı');
    }
    
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Eksik alanlar için varsayılan değerler
      if (!data.containsKey('duygu')) data['duygu'] = 'nötr';
      if (!data.containsKey('niyet')) data['niyet'] = 'belirsiz';
      if (!data.containsKey('ton')) data['ton'] = 'normal';
      if (!data.containsKey('ciddiyet')) {
        data['ciddiyet'] = data['ciddiyet'] is String 
            ? int.tryParse(data['ciddiyet']) ?? 5 
            : (data['ciddiyet'] ?? 5);
      }
      if (!data.containsKey('kişiler')) data['kişiler'] = 'belirsiz';
      
      return data;
    } catch (e) {
      _logger.e('JSON ayrıştırma hatası: $e');
      throw Exception('JSON ayrıştırılamadı: $e');
    }
  }

  // Metinden ilişki tipini çıkarma
  String _extractRelationshipType(String text) {
    final regex = RegExp('ilişki tipi:?\\s*([\\wöçşığüÖÇŞİĞÜ\\s]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim() ?? 'belirsiz';
  }

  // Metinden önerileri çıkarma
  List<String> _extractSuggestions(String text) {
    final suggestions = <String>[];
    final lines = text.split('\n');
    
    bool inSuggestionSection = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.contains('öneriler') || trimmedLine.contains('tavsiyeler')) {
        inSuggestionSection = true;
        continue;
      }
      
      if (inSuggestionSection && trimmedLine.startsWith('-') || trimmedLine.contains('1.') || trimmedLine.contains('2.')) {
        final suggestion = trimmedLine.replaceFirst(RegExp(r'^-|\d+\.'), '').trim();
        if (suggestion.isNotEmpty) {
          suggestions.add(suggestion);
        }
      }
    }
    
    return suggestions.isNotEmpty ? suggestions : ['İletişimi açık tutun', 'Birbirinize zaman ayırın', 'Beklentilerinizi açıkça ifade edin'];
  }

  // Metinden tavsiye başlığını çıkarma
  String _extractAdviceTitle(String text) {
    final regex = RegExp('başlık:?\\s*([\\wöçşığüÖÇŞİĞÜ\\s]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim() ?? 'Günlük İlişki Tavsiyesi';
  }

  // Severity değerini int'e dönüştürme
  int _parseSeverity(dynamic severity) {
    if (severity is int) return severity;
    if (severity is String) return int.tryParse(severity) ?? 5;
    return 5;
  }

  // Metinden string listesi çıkarma
  List<String> _parseStringList(dynamic list) {
    if (list is List) {
      return list.map((item) => item.toString()).toList();
    }
    return [];
  }
} 