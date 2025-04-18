import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
      
      if (recognizedText.text.isEmpty) {
        _logger.w('Görüntüden hiç metin çıkarılamadı');
        return null;
      }
      
      _logger.i('Metin çıkarma tamamlandı: ${recognizedText.text.length} karakter');
      
      return recognizedText.text;
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
      
      // Basit bir WhatsApp mesajı analizi yapıyoruz
      // Format: [tarih saat] Gönderen: Mesaj
      final Map<String, String> messageParts = {};
      final RegExp messagePattern = RegExp(r'\[(.*?)\]\s+(.*?):\s+(.*)');
      
      // Mesajı satırlara böl
      final lines = text.split('\n');
      
      for (final line in lines) {
        final match = messagePattern.firstMatch(line);
        
        if (match != null && match.groupCount >= 3) {
          final dateTime = match.group(1)?.trim() ?? '';
          final sender = match.group(2)?.trim() ?? '';
          final message = match.group(3)?.trim() ?? '';
          
          // Gönderen adını anahtar olarak kullan
          if (messageParts.containsKey(sender)) {
            messageParts[sender] = '${messageParts[sender]}\n$message';
          } else {
            messageParts[sender] = message;
          }
        } else {
          // Mesaj formatına uymayan satırlar için "general" anahtarı kullan
          if (messageParts.containsKey('general')) {
            messageParts['general'] = '${messageParts['general']}\n$line';
          } else {
            messageParts['general'] = line;
          }
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