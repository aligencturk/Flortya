import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:typed_data';

/// Görsellerden metin çıkarmak için OCR servisi
class OCRService {
  final Logger _logger = Logger();
  final TextRecognizer _textRecognizer;
  
  OCRService() : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Görüntüden metin çıkarma
  Future<String?> extractTextFromImage(File imageFile) async {
    try {
      _logger.i('Görselden metin çıkarma işlemi başlatılıyor: ${imageFile.path}');
      
      // Dosya kontrolü
      if (!await imageFile.exists()) {
        _logger.e('Görsel dosyası bulunamadı: ${imageFile.path}');
        return null;
      }
      
      // Dosya boyutunu ve bilgilerini kontrol et
      final fileStats = await imageFile.stat();
      _logger.i('Görsel boyutu: ${(fileStats.size / 1024).toStringAsFixed(2)} KB');
      
      // Görsel formatını kontrol et
      final String extension = imageFile.path.split('.').last.toLowerCase();
      _logger.i('Görsel formatı: $extension');
      
      // Görsel dosyasını okumayı dene
      Uint8List imageBytes;
      try {
        imageBytes = await imageFile.readAsBytes();
        _logger.i('Görsel byte olarak okundu, boyut: ${imageBytes.length} bytes');
      } catch (readError) {
        _logger.e('Görsel okunurken hata: $readError');
        return null;
      }
      
      // Farklı bir yaklaşımla görsel okuma dene (sorun yaşanırsa)
      if (imageBytes.isEmpty) {
        _logger.w('Görsel boş olarak okundu, alternatif yöntem deneniyor');
        try {
          // Eğer bir URL ise HTTP ile indirmeyi dene
          if (imageFile.path.startsWith('http')) {
            final response = await http.get(Uri.parse(imageFile.path));
            imageBytes = response.bodyBytes;
            _logger.i('Görsel HTTP ile indirildi: ${imageBytes.length} bytes');
          }
        } catch (alternativeError) {
          _logger.e('Alternatif görsel okuma hatası: $alternativeError');
        }
      }
      
      // Görüntü kalitesini iyileştirmeyi dene
      Uint8List processedImageBytes = await _preProcessImage(imageBytes);
      
      // İşlenmiş görsel dosyasını geçici olarak kaydet
      final tempDir = await getTemporaryDirectory();
      final processedImagePath = '${tempDir.path}/processed_image_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final processedImageFile = File(processedImagePath);
      await processedImageFile.writeAsBytes(processedImageBytes);
      _logger.i('İşlenmiş görsel kaydedildi: $processedImagePath');
      
      // ML Kit için önce orijinal görüntüyü dene
      _logger.i('ML Kit orijinal görsel işleme başlatılıyor...');
      InputImage inputImage = InputImage.fromFile(imageFile);
      RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Orijinal görselde metin bulunamadıysa işlenmiş görseli dene
      if (recognizedText.text.isEmpty) {
        _logger.w('Orijinal görselde metin bulunamadı, işlenmiş görsel deneniyor...');
        inputImage = InputImage.fromFile(processedImageFile);
        recognizedText = await _textRecognizer.processImage(inputImage);
      }
      
      // Hata günlüğü
      if (recognizedText.text.isEmpty) {
        _logger.w('Görüntüden hiç metin çıkarılamadı');
        
        // Tüm blokları ayrıntılı logla
        if (recognizedText.blocks.isNotEmpty) {
          _logger.i('Blok sayısı: ${recognizedText.blocks.length}');
          for (var i = 0; i < recognizedText.blocks.length; i++) {
            _logger.i('Blok $i: ${recognizedText.blocks[i].text}');
            
            // Blok içindeki satırları ve elementleri de logla
            final block = recognizedText.blocks[i];
            for (var j = 0; j < block.lines.length; j++) {
              _logger.i('  Satır $j: ${block.lines[j].text}');
              
              for (var k = 0; k < block.lines[j].elements.length; k++) {
                _logger.i('    Element $k: ${block.lines[j].elements[k].text}');
              }
            }
          }
        } else {
          _logger.w('Hiç metin bloğu bulunamadı');
        }
        
        // İşlenmiş görsel dosyasını temizle
        await processedImageFile.delete();
        
        // Boş sonuç döndürme (burada null yerine formatlanmış boş string döndürüyoruz)
        return "---- Görüntüden çıkarılan metin ----\n[Görüntüden metin çıkarılamadı]\n---- Çıkarılan metin sonu ----";
      }
      
      // Başarılı metin çıkarma
      _logger.i('Metin çıkarma tamamlandı: ${recognizedText.text.length} karakter');
      _logger.i('İlk 100 karakter: ${recognizedText.text.substring(0, recognizedText.text.length > 100 ? 100 : recognizedText.text.length)}...');
      
      // Tüm blokları ayrıntılı logla
      _logger.i('Blok sayısı: ${recognizedText.blocks.length}');
      
      // İşlenmiş görsel dosyasını temizle
      await processedImageFile.delete();
      
      // Sohbet formatına dönüştürülmüş metni oluştur
      String formattedChat = await formatChatFromRecognizedText(recognizedText);
      
      // Formatlanmış metin döndür
      return "---- Görüntüden çıkarılan metin ----\n$formattedChat\n---- Çıkarılan metin sonu ----";
    } catch (e, stack) {
      _logger.e('Metin çıkarma sırasında hata oluştu: $e');
      _logger.e('Stack trace: $stack');
      
      // Hata durumunda formatlanmış boş string döndür
      return "---- Görüntüden çıkarılan metin ----\n[Görüntü işlenirken hata oluştu: $e]\n---- Çıkarılan metin sonu ----";
    }
  }

  /// Tanınan metni sohbet formatına dönüştüren yeni metot
  Future<String> formatChatFromRecognizedText(RecognizedText recognizedText) async {
    try {
      _logger.i('Tanınan metin sohbet formatına dönüştürülüyor...');
      
      // Ekranın ortasını belirle (varsayılan olarak 500)
      double screenCenterX = 500.0;
      
      // Her bir TextLine'ı pozisyonuna göre incele
      List<Map<String, dynamic>> chatLines = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          if (line.text.trim().isEmpty) continue;
          
          // Mesajın ekranda konumunu belirle
          final centerX = line.boundingBox.center.dx;
          String sender;
          
          // Konuma göre göndereni belirle
          if (centerX > screenCenterX) {
            sender = "Kullanıcı"; // Sağda ise kullanıcı mesajı
          } else {
            sender = "Partner"; // Solda ise eşleşme/partner mesajı
          }
          
          // Satırın y koordinatını ve içeriğini kaydet
          chatLines.add({
            'y': line.boundingBox.top,
            'sender': sender,
            'text': line.text.trim(),
          });
        }
      }
      
      // Satırları y koordinatına göre sırala (yukarıdan aşağıya)
      chatLines.sort((a, b) => (a['y'] as double).compareTo(b['y'] as double));
      
      // Sıralanmış mesajları sohbet formatına dönüştür
      StringBuffer formattedChat = StringBuffer();
      
      for (var line in chatLines) {
        formattedChat.writeln("${line['sender']}: ${line['text']}");
      }
      
      String result = formattedChat.toString().trim();
      _logger.i('Sohbet formatına dönüştürme tamamlandı, ${chatLines.length} satır işlendi');
      
      return result;
    } catch (e) {
      _logger.e('Sohbet formatına dönüştürme hatası: $e');
      // Hata durumunda orijinal metni döndür
      return recognizedText.text;
    }
  }

  /// Görüntü işleme (ön işleme) metodu
  Future<Uint8List> _preProcessImage(Uint8List imageBytes) async {
    try {
      _logger.i('Görüntü ön işleme başlatılıyor...');
      
      // image paketini kullanarak görüntüyü decode et
      img.Image? decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage == null) {
        _logger.e('Görüntü decode edilemedi');
        return imageBytes; // Orijinal görüntüyü döndür
      }
      
      _logger.i('Görüntü decode edildi: ${decodedImage.width}x${decodedImage.height}');
      
      // Görüntü işleme adımları
      // 1. Gri tonlamaya çevir
      img.Image grayscale = img.grayscale(decodedImage);
      _logger.i('Görüntü gri tonlamaya çevrildi');
      
      // 2. Kontrast artırma
      img.Image enhancedImage = img.adjustColor(
        grayscale,
        contrast: 1.5,
      );
      _logger.i('Görüntü kontrastı artırıldı');
      
      // 3. Yeniden boyutlandırma ve ek kontrast iyileştirme
      img.Image resizedImage = img.copyResize(enhancedImage, width: enhancedImage.width, height: enhancedImage.height);
      img.Image finalImage = img.adjustColor(
        resizedImage,
        brightness: 0.1,
        contrast: 1.3,
        saturation: 0.0,
      );
      _logger.i('Görüntü iyileştirildi');
      
      // 4. İşlenmiş görüntüyü encode et
      Uint8List processedBytes = Uint8List.fromList(img.encodePng(finalImage));
      _logger.i('İşlenmiş görüntü encode edildi: ${processedBytes.length} bytes');
      
      return processedBytes;
    } catch (e) {
      _logger.e('Görüntü ön işleme hatası: $e');
      return imageBytes; // Hata durumunda orijinal görüntüyü döndür
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
    _logger.d('OCRService kaynakları temizlendi');
  }
} 