import 'package:flutter/material.dart';
import 'loading_indicator.dart';

// SnackBar tipi
enum SnackBarType {
  error,
  success,
  warning,
  info,
}

/// Uygulama genelinde yardımcı fonksiyonları içeren sınıf
class Utils {
  /// SnackBar göster - Farklı tipte mesajlar için
  static void showSnackBar({
    required String message,
    required SnackBarType type,
    BuildContext? context,
    Duration? duration,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context ?? navigatorKey.currentContext!);
    
    scaffoldMessenger.clearSnackBars();
    
    // Tip bazında renk ve ikon belirle
    Color backgroundColor;
    IconData iconData;
    
    switch (type) {
      case SnackBarType.error:
        backgroundColor = Colors.red;
        iconData = Icons.error_outline;
        break;
      case SnackBarType.success:
        backgroundColor = Colors.green;
        iconData = Icons.check_circle;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange;
        iconData = Icons.warning_amber_outlined;
        break;
      case SnackBarType.info:
      default:
        backgroundColor = Colors.blue;
        iconData = Icons.info_outline;
        break;
    }
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// NavigationKey - Context olmadan SnackBar gösterebilmek için
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Hata bildirimi gösterir - Kullanıcının mutlaka görmesi gereken önemli hatalar için
  static void showErrorFeedback(BuildContext context, String message, {Duration? duration}) {
    showSnackBar(
      context: context,
      message: message,
      type: SnackBarType.error,
      duration: duration,
    );
  }

  /// Başarı bildirimi gösterir - Önemli başarılı işlemler için
  static void showSuccessFeedback(BuildContext context, String message, {Duration? duration}) {
    showSnackBar(
      context: context,
      message: message,
      type: SnackBarType.success,
      duration: duration,
    );
  }

  /// Uyarı bildirimi gösterir - Kullanıcının dikkat etmesi gereken durumlar için
  static void showWarningFeedback(BuildContext context, String message, {Duration? duration}) {
    showSnackBar(
      context: context,
      message: message,
      type: SnackBarType.warning,
      duration: duration,
    );
  }
  
  /// Dialog göster
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
  
  /// Onay dialog'u göster
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
                const YuklemeAnimasyonu(
                  renk: Colors.white,
                  boyut: 40.0,
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