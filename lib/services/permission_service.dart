import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'logger_service.dart';

/// iOS ve Android izinlerini yöneten servis
class PermissionService {
  final LoggerService _logger = LoggerService();
  
  /// Gerekli izinleri kontrol eder ve istek yapar
  Future<bool> checkAndRequestPermissions(BuildContext context) async {
    if (!Platform.isIOS) {
      // Android için gerekirse ayrı implementasyon yapılabilir
      return true;
    }
    
    _logger.i('iOS izinleri kontrol ediliyor...');
    
    // İhtiyaç duyulan izinler
    final List<Permission> requiredPermissions = [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ];
    
    bool allGranted = true;
    List<Permission> needToRequest = [];
    
    // Mevcut izin durumlarını kontrol et
    for (Permission permission in requiredPermissions) {
      final status = await permission.status;
      _logger.i('${permission.toString()} izni durumu: $status');
      
      if (status != PermissionStatus.granted) {
        needToRequest.add(permission);
        allGranted = false;
      }
    }
    
    // Eğer tüm izinler verilmişse direkt true döndür
    if (allGranted) {
      _logger.i('Tüm izinler zaten verilmiş');
      return true;
    }
    
    // Kullanıcıya izin açıklama diyaloğunu göster
    if (context.mounted) {
      final shouldProceed = await _showPermissionExplanationDialog(context);
      if (!shouldProceed) {
        _logger.i('Kullanıcı izin vermeyi reddetti');
        return false;
      }
    }
    
    // İzinleri iste
    Map<Permission, PermissionStatus> statuses = await needToRequest.request();
    
    // Sonuçları kontrol et
    bool finalResult = true;
    for (var entry in statuses.entries) {
      _logger.i('${entry.key.toString()} izni sonucu: ${entry.value}');
      
      if (entry.value != PermissionStatus.granted) {
        finalResult = false;
        
        // Kalıcı olarak reddedilmişse ayarlara yönlendir
        if (entry.value == PermissionStatus.permanentlyDenied) {
          if (context.mounted) {
            await _showSettingsDialog(context, entry.key);
          }
        }
      }
    }
    
    return finalResult;
  }
  
  /// İzin açıklama diyaloğu
  Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Uygulama İzinleri',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flörtya\'nın tam işlevsellik kazanması için aşağıdaki izinlere ihtiyacı var:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                Icons.camera_alt,
                'Kamera',
                'Mesaj ekran görüntüleri çekmek için',
              ),
              _buildPermissionItem(
                Icons.photo_library,
                'Fotoğraf Galerisi',
                'Galeri\'den görsel seçmek için',
              ),
              _buildPermissionItem(
                Icons.folder,
                'Depolama',
                'Dosya yükleme ve kaydetme için',
              ),
              _buildPermissionItem(
                Icons.notifications,
                'Bildirimler',
                'Önemli güncellemeler için',
              ),
              const SizedBox(height: 16),
              Text(
                'Bu izinler sadece belirtilen özellikler için kullanılır ve gizliliğiniz korunur.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(
                'Şimdi Değil',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'İzin Ver',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }
  
  /// İzin maddesi widget'ı
  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF9D3FFF),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Ayarlar diyaloğu
  Future<void> _showSettingsDialog(BuildContext context, Permission permission) async {
    String permissionName = _getPermissionName(permission);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF352269),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'İzin Gerekli',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$permissionName izni kalıcı olarak reddedildi. Lütfen Ayarlar > Flörtya > İzinler bölümünden bu izni manuel olarak aktifleştirin.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Tamam',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9D3FFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Ayarlara Git',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// İzin adını döndürür
  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Kamera';
      case Permission.photos:
        return 'Fotoğraf Galerisi';
      case Permission.storage:
        return 'Depolama';
      case Permission.notification:
        return 'Bildirimler';
      default:
        return 'İzin';
    }
  }
  
  /// Belirli bir izin durumunu kontrol eder
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status == PermissionStatus.granted;
  }
  
  /// Kamera izni kontrol eder
  Future<bool> isCameraPermissionGranted() async {
    return await isPermissionGranted(Permission.camera);
  }
  
  /// Fotoğraf izni kontrol eder
  Future<bool> isPhotosPermissionGranted() async {
    return await isPermissionGranted(Permission.photos);
  }
  
  /// Bildirim izni kontrol eder
  Future<bool> isNotificationPermissionGranted() async {
    return await isPermissionGranted(Permission.notification);
  }
}