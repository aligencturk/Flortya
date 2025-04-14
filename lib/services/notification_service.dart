import 'package:flutter/material.dart';

class NotificationService {
  // Bildirim gösterme fonksiyonu - başarı durumu için
  void showSuccessNotification(String title, String message) {
    print('BAŞARI: $title - $message');
    // Global snackbar veya toast gösterimi buraya eklenecek
  }
  
  // Bildirim gösterme fonksiyonu - hata durumu için
  void showErrorNotification(String title, String message) {
    print('HATA: $title - $message');
    // Global snackbar veya toast gösterimi buraya eklenecek
  }
  
  // Bildirim gösterme fonksiyonu - uyarı durumu için
  void showWarningNotification(String title, String message) {
    print('UYARI: $title - $message');
    // Global snackbar veya toast gösterimi buraya eklenecek
  }
  
  // Bildirim gösterme fonksiyonu - bilgi durumu için
  void showInfoNotification(String title, String message) {
    print('BİLGİ: $title - $message');
    // Global snackbar veya toast gösterimi buraya eklenecek
  }
  
  // Snackbar gösterimi için yardımcı metot
  void showSnackBar(BuildContext context, String message, {Color backgroundColor = Colors.black, Duration duration = const Duration(seconds: 2)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
  
  // Toast bildirim gösterimi için metot (platform spesifik uygulamalar için)
  void showToast(String message) {
    // Platform spesifik toast gösterimi buraya eklenecek
    print('TOAST: $message');
  }
} 