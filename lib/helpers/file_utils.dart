import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Dosya işlemleri için yardımcı fonksiyonlar sağlar
class FileUtils {
  
  /// Dosya seçme işlemini gerçekleştirir
  static Future<XFile?> dosyaSec({
    List<XTypeGroup>? dosyaTurleri,
    String? baslik,
  }) async {
    try {
      // Dosya seçme diyaloğunu aç
      final XFile? secilmisDosya = await openFile(
        acceptedTypeGroups: dosyaTurleri ?? <XTypeGroup>[],
        confirmButtonText: 'Seç',
      );
      
      return secilmisDosya;
    } on PlatformException catch (e) {
      throw Exception('Dosya seçme hatası: ${e.message}');
    } catch (e) {
      throw Exception('Dosya seçerken beklenmeyen hata: $e');
    }
  }
  
  /// Çoklu dosya seçme işlemini gerçekleştirir
  static Future<List<XFile>> cokluDosyaSec({
    List<XTypeGroup>? dosyaTurleri,
    String? baslangicDizini,
  }) async {
    try {
      final List<XFile> dosyalar = await openFiles(
        acceptedTypeGroups: dosyaTurleri ?? [],
        initialDirectory: baslangicDizini,
      );
      return dosyalar;
    } catch (e) {
      debugPrint('Çoklu dosya seçme hatası: $e');
      return [];
    }
  }
  
  /// Dizin seçme işlemini gerçekleştirir
  static Future<String?> dizinSec({
    String? baslangicDizini,
  }) async {
    try {
      final String? dizin = await getDirectoryPath(
        initialDirectory: baslangicDizini,
      );
      return dizin;
    } catch (e) {
      debugPrint('Dizin seçme hatası: $e');
      return null;
    }
  }
  
  /// Dosya kaydetme işlemini gerçekleştirir
  static Future<String?> dosyaKaydet({
    required String icerik,
    String? dosyaAdi,
    List<XTypeGroup>? dosyaTurleri,
  }) async {
    try {
      // Dosya adını belirle
      String kaydedilecekDosyaAdi = dosyaAdi ?? 'sohbet_analizi.txt';
      
      // Kaydetme diyaloğunu açma
      final String? yol = await getSaveLocation(
        suggestedName: kaydedilecekDosyaAdi,
        acceptedTypeGroups: dosyaTurleri ?? <XTypeGroup>[],
      ).then((FileSaveLocation? location) => location?.path);
      
      if (yol == null) {
        return null; // Kullanıcı iptal etti
      }
      
      // Dosyayı kaydet
      final Uint8List byteData = Uint8List.fromList(icerik.codeUnits);
      final XFile dosya = XFile.fromData(
        byteData,
        name: kaydedilecekDosyaAdi,
        mimeType: 'text/plain',
      );
      
      await dosya.saveTo(yol);
      return yol;
    } catch (e) {
      throw Exception('Dosya kaydederken hata: $e');
    }
  }
  
  /// Görselden metin çıkarma işlemini gerçekleştirir
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      // ML Kit entegrasyonu için TextRecognizer kullanımı
      final TextRecognizer textRecognizer = TextRecognizer();
      
      try {
        // Görseli işleme
        final inputImage = InputImage.fromFile(imageFile);
        
        final recognizedText = await textRecognizer.processImage(inputImage);
        
        // Tanınan metni döndür
        final String extractedText = recognizedText.text;
        
        // Eğer metin boşsa, hata mesajı döndür
        if (extractedText.trim().isEmpty) {
          return "Görselde metin bulunamadı.";
        }
        
        return "---- Görüntüden çıkarılan metin ----\n$extractedText";
      } finally {
        // Her durumda recognizer'ı serbest bırak
        textRecognizer.close();
      }
    } catch (e) {
      debugPrint('Görselden metin çıkarma hatası: $e');
      return "Görselden metin çıkarma hatası: $e";
    }
  }
} 