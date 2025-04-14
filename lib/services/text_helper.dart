import 'package:flutter/material.dart';

/// Türkçe metin işlemleri için yardımcı sınıf
class TextHelper {
  /// Türkçe karakterleri düzeltir
  static String fixTurkishChars(String text) {
    final Map<String, String> replacements = {
      'i\u0307': 'i', // i̇ → i
      'İ': 'İ',
      'ı': 'ı',
      'I': 'I',
      'ğ': 'ğ',
      'Ğ': 'Ğ',
      'ü': 'ü',
      'Ü': 'Ü',
      'ş': 'ş',
      'Ş': 'Ş',
      'ö': 'ö',
      'Ö': 'Ö',
      'ç': 'ç',
      'Ç': 'Ç',
    };
    
    String result = text;
    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    return result;
  }
  
  /// Mesaj içeriğini biçimlendirir
  static String formatMessage(String message) {
    // Boş ise boş döndür
    if (message.isEmpty) return message;
    
    // Başındaki ve sonundaki boşlukları temizle
    String formattedMessage = message.trim();
    
    // Türkçe karakterleri düzelt
    formattedMessage = fixTurkishChars(formattedMessage);
    
    // İlk harfi büyük yap, eğer cümle sonunda nokta yoksa nokta ekle
    if (formattedMessage.length > 0) {
      formattedMessage = formattedMessage[0].toUpperCase() + formattedMessage.substring(1);
      
      if (!formattedMessage.endsWith('.') && 
          !formattedMessage.endsWith('?') && 
          !formattedMessage.endsWith('!')) {
        formattedMessage = '$formattedMessage.';
      }
    }
    
    return formattedMessage;
  }
} 