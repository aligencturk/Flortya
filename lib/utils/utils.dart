import 'package:flutter/material.dart';

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
} 