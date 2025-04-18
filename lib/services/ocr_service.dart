import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:logger/logger.dart';

/// Görsellerden metin çıkarmak için OCR servisi
class OCRService {
  final Logger _logger = Logger();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Görüntüden metin çıkarma
  Future<String?> extractTextFromImage(File imageFile) async {
    try {
      _logger.i('Görselden metin çıkarma işlemi başlatılıyor...');
      
      if (!await imageFile.exists()) {
        _logger.e('Görsel dosyası bulunamadı: ${imageFile.path}');
        return null;
      }
      
      // ML Kit için görüntüyü işleme
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Tanınan metni birleştir
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }
      
      _logger.i('Metin çıkarma tamamlandı: ${extractedText.length} karakter');
      
      if (extractedText.trim().isEmpty) {
        _logger.w('Görüntüden hiç metin çıkarılamadı');
        return null;
      }
      
      return extractedText;
    } catch (e) {
      _logger.e('Metin çıkarma sırasında hata oluştu: $e');
      return null;
    }
  }

  /// Mesaj içeriğindeki metin bölgelerini belirleme
  Future<Map<String, String>?> identifyMessageParts(String text) async {
    try {
      if (text.trim().isEmpty) {
        return null;
      }
      
      // Bu metin bir sohbet içeriği olabilir, sağdaki ve soldaki mesajları belirlemeye çalış
      final Map<String, String> messageParts = {};
      final List<String> lines = text.split('\n');
      
      String currentSpeaker = '';
      String currentMessage = '';
      
      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;
        
        // Konuşmacı değişimleri için ipuçları ara
        // Bu kısım, konuşmacı isimlerini ve mesaj içeriklerini 
        // belirlemek için mesaj formatına özgü mantıkla geliştirilebilir
        
        // Şimdilik basit ayrıştırma
        messageParts.putIfAbsent('user1', () => '');
        messageParts.putIfAbsent('user2', () => '');
        
        // Satırda ":" varsa veya belirli bir formattaysa, konuşmacı değişimi olabilir
        if (line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            currentSpeaker = parts[0].trim();
            currentMessage = parts.sublist(1).join(':').trim();
            
            if (!messageParts.containsKey(currentSpeaker)) {
              messageParts[currentSpeaker] = currentMessage;
            } else {
              String existingMessage = messageParts[currentSpeaker] ?? '';
              messageParts[currentSpeaker] = '$existingMessage\n$currentMessage';
            }
            continue;
          }
        }
        
        // Konuşmacı değişimi algılanamadıysa, mevcut konuşmacının mesajına ekle
        if (currentSpeaker.isNotEmpty) {
          String existingMessage = messageParts[currentSpeaker] ?? '';
          messageParts[currentSpeaker] = '$existingMessage\n$line';
        } else {
          // Konuşmacı belirsizse, içeriği genel mesaj olarak ekle
          messageParts.putIfAbsent('general', () => '');
          String existingMessage = messageParts['general'] ?? '';
          messageParts['general'] = existingMessage + (existingMessage.isEmpty ? '' : '\n') + line;
        }
      }
      
      return messageParts;
    } catch (e) {
      _logger.e('Mesaj bölümlerini belirlerken hata oluştu: $e');
      return null;
    }
  }

  /// Servis kaynakları serbest bırakma
  void dispose() {
    _textRecognizer.close();
  }
} 