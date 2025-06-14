import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'remote_config_service.dart';
import 'platform_service.dart';
import 'logger_service.dart';

enum UpdateType {
  none,        // Güncelleme gerekmiyor
  optional,    // Opsiyonel güncelleme
  required,    // Zorunlu güncelleme
}

class VersionUpdateInfo {
  final UpdateType updateType;
  final String currentVersion;
  final String minimumVersion;
  final String forceUpdateVersion;
  final String updateMessage;
  final String storeUrl;
  final String platform;

  const VersionUpdateInfo({
    required this.updateType,
    required this.currentVersion,
    required this.minimumVersion,
    required this.forceUpdateVersion,
    required this.updateMessage,
    required this.storeUrl,
    required this.platform,
  });
}

class VersionUpdateService {
  final RemoteConfigService _remoteConfigService;
  final PlatformService _platformService;
  final LoggerService _logger;

  VersionUpdateService({
    required RemoteConfigService remoteConfigService,
    required PlatformService platformService,
    LoggerService? logger,
  })  : _remoteConfigService = remoteConfigService,
        _platformService = platformService,
        _logger = logger ?? LoggerService();

  /// Versiyon güncelleme durumunu kontrol eder
  Future<VersionUpdateInfo> versiyonKontrolEt() async {
    try {
      _logger.i('Versiyon güncelleme kontrolü başlatılıyor...');

      // Platform ve mevcut versiyon bilgilerini al
      final currentVersion = _platformService.uygulamaVersionu;
      final platform = _platformService.platformAdi;

      _logger.i('Mevcut versiyon: $currentVersion, Platform: $platform');

      // Remote Config'ten versiyon bilgilerini al
      final versionInfo = await _remoteConfigService.minimumVersionBilgisiAl();
      
      final minimumVersion = versionInfo['minimumVersion'] ?? '0.0.0';
      final forceUpdateVersion = versionInfo['forceUpdateVersion'] ?? '0.0.0';
      final updateMessage = versionInfo['updateMessage'] ?? 'Yeni bir güncelleme mevcut';
      final storeUrl = versionInfo['storeUrl'] ?? '';

      _logger.i('Minimum versiyon: $minimumVersion');
      _logger.i('Zorunlu güncelleme versiyonu: $forceUpdateVersion');

      // Versiyon karşılaştırması yap
      UpdateType updateType = UpdateType.none;

      // Zorunlu güncelleme kontrolü
      if (_platformService.versiyonKarsilastir(currentVersion, forceUpdateVersion) < 0) {
        updateType = UpdateType.required;
        _logger.w('Zorunlu güncelleme gerekli: $currentVersion < $forceUpdateVersion');
      }
      // Opsiyonel güncelleme kontrolü
      else if (_platformService.versiyonKarsilastir(currentVersion, minimumVersion) < 0) {
        updateType = UpdateType.optional;
        _logger.i('Opsiyonel güncelleme mevcut: $currentVersion < $minimumVersion');
      }
      else {
        _logger.i('Uygulama güncel: $currentVersion');
      }

      return VersionUpdateInfo(
        updateType: updateType,
        currentVersion: currentVersion,
        minimumVersion: minimumVersion,
        forceUpdateVersion: forceUpdateVersion,
        updateMessage: updateMessage,
        storeUrl: storeUrl,
        platform: platform,
      );

    } catch (e) {
      _logger.e('Versiyon kontrolü hatası: $e');
      
      // Hata durumunda güncelleme yok olarak döndür
      return VersionUpdateInfo(
        updateType: UpdateType.none,
        currentVersion: _platformService.uygulamaVersionu,
        minimumVersion: '0.0.0',
        forceUpdateVersion: '0.0.0',
        updateMessage: 'Versiyon kontrolü yapılamadı',
        storeUrl: '',
        platform: _platformService.platformAdi,
      );
    }
  }

  /// Güncelleme dialog'unu gösterir
  Future<void> guncellemeDialogGoster(
    BuildContext context,
    VersionUpdateInfo updateInfo,
  ) async {
    if (updateInfo.updateType == UpdateType.none) {
      _logger.w('Dialog gösterilmiyor: UpdateType.none');
      return;
    }

    final isRequired = updateInfo.updateType == UpdateType.required;
    _logger.i('Dialog gösteriliyor - Zorunlu: $isRequired, Tip: ${updateInfo.updateType.name}');

    await showDialog<void>(
      context: context,
      barrierDismissible: !isRequired, // Zorunlu güncelleme durumunda kapatılamaz
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6A11CB),
                  const Color(0xFF2575FC),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst kısım - İkon ve başlık
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isRequired ? Icons.system_update_alt : Icons.update,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Başlık
                  Text(
                    isRequired ? 'Zorunlu Güncelleme' : 'Yeni Güncelleme Mevcut',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Mesaj
                  Text(
                    updateInfo.updateMessage,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Versiyon bilgisi kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.8),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Versiyon Bilgisi',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mevcut:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              updateInfo.currentVersion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isRequired ? 'Minimum:' : 'Önerilen:',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              isRequired ? updateInfo.forceUpdateVersion : updateInfo.minimumVersion,
                              style: TextStyle(
                                color: isRequired ? Colors.orange[300] : Colors.green[300],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Butonlar
                  Row(
                    children: [
                      if (!isRequired) ...[
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Daha Sonra',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isRequired 
                                ? [Colors.red[400]!, Colors.red[600]!]
                                : [Colors.white, Colors.white.withOpacity(0.9)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: (isRequired ? Colors.red : Colors.white).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _storeAc(updateInfo.storeUrl);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: isRequired ? Colors.white : const Color(0xFF6A11CB),
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isRequired ? 'Şimdi Güncelle' : 'Güncelle',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Store sayfasını açar
  Future<void> _storeAc(String storeUrl) async {
    try {
      if (storeUrl.isEmpty) {
        _logger.w('Store URL\'si boş');
        return;
      }

      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('Store açıldı: $storeUrl');
      } else {
        _logger.e('Store açılamadı: $storeUrl');
      }
    } catch (e) {
      _logger.e('Store açma hatası: $e');
    }
  }

  /// Otomatik versiyon kontrolü yapar (uygulama başlatılırken)
  Future<void> otomatikVersionKontrol(BuildContext context) async {
    try {
      _logger.i('Otomatik versiyon kontrolü başlatılıyor...');
      
      final updateInfo = await versiyonKontrolEt();
      
      _logger.i('Versiyon kontrolü sonucu: ${updateInfo.updateType.name}');
      _logger.i('Mevcut versiyon: ${updateInfo.currentVersion}');
      _logger.i('Minimum versiyon: ${updateInfo.minimumVersion}');
      _logger.i('Zorunlu güncelleme versiyonu: ${updateInfo.forceUpdateVersion}');
      
      if (updateInfo.updateType != UpdateType.none) {
        _logger.i('Güncelleme gerekli, dialog gösteriliyor...');
        
        // UI'nin tamamen yüklenmesini bekle
        await Future.delayed(const Duration(seconds: 1));
        
        if (context.mounted) {
          _logger.i('Context mounted, dialog gösteriliyor');
          await guncellemeDialogGoster(context, updateInfo);
          _logger.i('Dialog gösterildi');
        } else {
          _logger.w('Context mounted değil, dialog gösterilemiyor');
        }
      } else {
        _logger.i('Güncelleme gerekmiyor');
      }
    } catch (e) {
      _logger.e('Otomatik versiyon kontrolü hatası: $e');
    }
  }

  /// Versiyon güncellemesi gerekip gerekmediğini basit bir bool olarak döndürür
  Future<bool> guncellemeGerekliMi() async {
    try {
      final updateInfo = await versiyonKontrolEt();
      return updateInfo.updateType != UpdateType.none;
    } catch (e) {
      _logger.e('Güncelleme kontrolü hatası: $e');
      return false;
    }
  }

  /// Zorunlu güncelleme gerekip gerekmediğini kontrol eder
  Future<bool> zorunluGuncellemeGerekliMi() async {
    try {
      final updateInfo = await versiyonKontrolEt();
      return updateInfo.updateType == UpdateType.required;
    } catch (e) {
      _logger.e('Zorunlu güncelleme kontrolü hatası: $e');
      return false;
    }
  }
} 