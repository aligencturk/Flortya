import 'package:flutter/material.dart';

/// Uygulama genelinde standart bildirim yöntemlerini sağlayan yardımcı sınıf
class FeedbackUtils {
  /// Hata bildirimi gösterir - Kullanıcının mutlaka görmesi gereken önemli hatalar için
  static void showErrorFeedback(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Başarı bildirimi gösterir - Önemli başarılı işlemler için
  static void showSuccessFeedback(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// Uyarı bildirimi gösterir - Kullanıcının dikkat etmesi gereken durumlar için
  static void showWarningFeedback(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Bilgilendirme dialog'u gösterir - SnackBar'dan daha önemli bilgiler için
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Tamam',
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Onay dialog'u gösterir - Kullanıcının onaylaması gereken işlemler için
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Evet',
    String cancelText = 'Hayır',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Toast tarzı geçici bildirimi gösterir - Konuma bağlı, hafif bildirimler için
  static void showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).size.height * 0.1,
        width: MediaQuery.of(context).size.width,
        child: Center(
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(24),
            color: Colors.black87,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// Üst bildirim banner'ı gösterir - Geçici olmayan, önemli bilgiler için
  static void showBanner(
    BuildContext context, {
    required String message, 
    required IconData icon,
    Color backgroundColor = Colors.blue,
    List<Widget>? actions,
  }) {
    final banner = MaterialBanner(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: backgroundColor,
      actions: actions ?? [
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Tamam', style: TextStyle(color: Colors.white)),
        ),
      ],
    );

    ScaffoldMessenger.of(context).showMaterialBanner(banner);
  }

  /// Yükleme dialog'u gösterir - İşlem devam ederken kullanıcıyı bilgilendirir
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF3A2A70),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 