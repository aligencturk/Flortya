import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'logger_service.dart';

class OcrService {
  final LoggerService _logger = LoggerService();
  late final TextRecognizer _textRecognizer;
  bool _isClosed = false;

  OcrService() {
    _initializeRecognizer();
  }

  void _initializeRecognizer() {
    if (!_isClosed) {
      try {
        // TextRecognizer zaten başlatılmışsa kapat
        if (!_isClosed) {
          _textRecognizer.close();
        }
      } catch (e) {
        debugPrint('Tanıyıcı kapatma hatası: $e');
      }
    }
    
    // Sadece Latin/Türkçe desteği
    _textRecognizer = TextRecognizer();
    _isClosed = false;
  }

  /// Verilen resim dosyasından metin çıkarır
  Future<String> metniOku(File imageFile) async {
    try {
      debugPrint('OCR işlemi başlıyor: ${imageFile.path}');
      
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String extractedText = recognizedText.text;
      
      // Eğer çıkarılan metin boşsa özel blokları deneyebiliriz
      if (extractedText.trim().isEmpty) {
        extractedText = '';
        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            extractedText += '${line.text}\n';
          }
        }
      }
      
      debugPrint('OCR sonucu (${extractedText.length} karakter): ${extractedText.substring(0, extractedText.length > 50 ? 50 : extractedText.length)}...');
      
      return extractedText.trim();
    } catch (e) {
      debugPrint('OCR hatası: $e');
      throw Exception('Metni çıkarma hatası: $e');
    }
  }
  
  /// Verilen resim dosyasından metin bloklarını döndürür
  Future<List<TextBlock>> metinBloklariGetir(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      return recognizedText.blocks;
    } catch (e) {
      debugPrint('Metin blokları çıkarma hatası: $e');
      throw Exception('Metin blokları çıkarma hatası: $e');
    }
  }
  
  /// OCR işlemleri için kullanılan kaynakları serbest bırakır
  Future<void> dispose() async {
    if (!_isClosed) {
      await _textRecognizer.close();
      _isClosed = true;
    }
  }
} 