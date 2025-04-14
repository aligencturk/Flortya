import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'logger_service.dart';
import '../models/text_recognition_script.dart';

class OcrService {
  final LoggerService _logger = LoggerService();
  late final TextRecognizer _textRecognizer;
  bool _isClosed = false;
  TextRecognitionScript _currentScript = TextRecognitionScript.latin;

  OcrService() {
    _initializeRecognizer(TextRecognitionScript.latin);
  }

  void _initializeRecognizer(TextRecognitionScript script) {
    if (!_isClosed) {
      try {
        // TextRecognizer zaten başlatılmışsa kapat
        // Burada late final olduğu için açıkça null kontrolü yapmıyoruz
        if (!_isClosed) {
          _textRecognizer.close();
        }
      } catch (e) {
        debugPrint('Tanıyıcı kapatma hatası: $e');
      }
    }
    
    // Script'e göre ML Kit tanıyıcısını ayarla
    switch (script) {
      case TextRecognitionScript.latin:
        _textRecognizer = GoogleMlKit.vision.textRecognizer();
        break;
      case TextRecognitionScript.chinese:
        _textRecognizer = GoogleMlKit.vision.textRecognizerChinese();
        break;
      case TextRecognitionScript.devanagari:
        _textRecognizer = GoogleMlKit.vision.textRecognizerDevanagari();
        break;
      case TextRecognitionScript.japanese:
        _textRecognizer = GoogleMlKit.vision.textRecognizerJapanese();
        break;
      case TextRecognitionScript.korean:
        _textRecognizer = GoogleMlKit.vision.textRecognizerKorean();
        break;
    }
    
    _currentScript = script;
    _isClosed = false;
  }

  /// Kullanılacak dil yazı tipini ayarlar (Latin, Çince, Devanagari, Japonca, Korece)
  void dilAyarla(TextRecognitionScript script) {
    if (_currentScript != script) {
      _initializeRecognizer(script);
      debugPrint('OCR dil ayarı değiştirildi: $script');
    }
  }

  /// Verilen resim dosyasından metin çıkarır
  Future<String> metniOku(File imageFile, {TextRecognitionScript? script}) async {
    try {
      // Eğer belirli bir script belirtilmişse, onu kullan
      if (script != null && script != _currentScript) {
        dilAyarla(script);
      }
      
      debugPrint('OCR işlemi başlıyor: ${imageFile.path}, Script: $_currentScript');
      
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
  
  /// Tüm desteklenen dillerde metni sırayla tanımayı dener ve sonuçları karşılaştırır
  Future<String> otomatikDilTanima(File imageFile) async {
    try {
      debugPrint('Tüm dil seçenekleri deneniyor...');
      
      final scripts = [
        TextRecognitionScript.latin,
        TextRecognitionScript.chinese,
        TextRecognitionScript.japanese,
        TextRecognitionScript.korean,
      ];
      
      String bestResult = '';
      int maxLength = 0;
      TextRecognitionScript? bestScript;
      
      for (final script in scripts) {
        try {
          final result = await metniOku(imageFile, script: script);
          debugPrint('${script.name} dili sonucu: ${result.length} karakter');
          
          // En uzun sonucu sakla (genellikle en iyi sonuç en çok metni çıkarandır)
          if (result.length > maxLength) {
            maxLength = result.length;
            bestResult = result;
            bestScript = script;
          }
        } catch (e) {
          debugPrint('${script.name} dili tanıma hatası: $e');
        }
      }
      
      if (bestScript != null) {
        debugPrint('En iyi sonuç: ${bestScript.name} dili - ${bestResult.length} karakter');
      }
      
      return bestResult;
    } catch (e) {
      debugPrint('Çoklu dil OCR hatası: $e');
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