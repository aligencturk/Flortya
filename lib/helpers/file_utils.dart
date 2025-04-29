import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
} 