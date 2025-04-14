import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'logger_service.dart';
import '../models/text_recognition_script.dart' as local;

class OcrService {
  final LoggerService _logger = LoggerService();
  late final TextRecognizer _textRecognizer;
  bool _isClosed = false;
  local.TextRecognitionScript _currentScript = local.TextRecognitionScript.latin;

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
    _currentScript = local.TextRecognitionScript.latin;
    _isClosed = false;
  }

  /// Kullanılacak dil yazı tipini ayarlar (Sadece Latin/Türkçe desteklenir)
  void dilAyarla(local.TextRecognitionScript script) {
    if (script != local.TextRecognitionScript.latin) {
      debugPrint('Sadece Latin/Türkçe dil desteği aktif. Diğer diller kaldırıldı.');
    }
  }

  /// Verilen resim dosyasından metin çıkarır
  Future<String> metniOku(File imageFile) async {
    try {
      debugPrint('OCR işlemi başlıyor: ${imageFile.path}, Script: ${_currentScript.name}');
      
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
  
  /// Otomatik dil tanıma - Sadece Latin/Türkçe desteklendiği için normal OCR işlevini çağırır
  Future<String> otomatikDilTanima(File imageFile) async {
    debugPrint('Sadece Latin/Türkçe dil desteği aktif. Diğer diller kaldırıldı.');
    return await metniOku(imageFile);
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