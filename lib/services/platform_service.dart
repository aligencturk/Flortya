import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

class PlatformService {
  final DeviceInfoPlugin _deviceInfoPlugin;
  final LoggerService _logger;
  
  PackageInfo? _packageInfo;
  String? _platformName;
  String? _deviceModel;
  String? _osVersion;

  PlatformService({
    DeviceInfoPlugin? deviceInfoPlugin,
    LoggerService? logger,
  })  : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
        _logger = logger ?? LoggerService();

  /// Platform adını döndürür (android, ios, web)
  String get platformAdi {
    if (_platformName != null) return _platformName!;
    
    if (kIsWeb) {
      _platformName = 'web';
    } else if (Platform.isAndroid) {
      _platformName = 'android';
    } else if (Platform.isIOS) {
      _platformName = 'ios';
    } else {
      _platformName = 'bilinmeyen';
    }
    
    return _platformName!;
  }

  /// Android olup olmadığını kontrol eder
  bool get isAndroid => platformAdi == 'android';

  /// iOS olup olmadığını kontrol eder
  bool get isIOS => platformAdi == 'ios';

  /// Web olup olmadığını kontrol eder
  bool get isWeb => platformAdi == 'web';

  /// Uygulama versiyonunu döndürür
  String get uygulamaVersionu => _packageInfo?.version ?? '0.0.0';

  /// Build numarasını döndürür
  String get buildNumarasi => _packageInfo?.buildNumber ?? '0';

  /// Tam versiyon bilgisini döndürür (versiyon+build)
  String get tamVersionBilgisi => '${uygulamaVersionu}+${buildNumarasi}';

  /// Cihaz modelini döndürür
  String get cihazModeli => _deviceModel ?? 'Bilinmeyen Cihaz';

  /// İşletim sistemi versiyonunu döndürür
  String get osVersionu => _osVersion ?? 'Bilinmeyen Versiyon';

  /// Platform servisini başlatır ve tüm bilgileri toplar
  Future<void> baslat() async {
    try {
      _logger.i('Platform servisi başlatılıyor...');
      
      // Paket bilgilerini al
      await _paketBilgileriniAl();
      
      // Cihaz bilgilerini al
      await _cihazBilgileriniAl();
      
      _logger.i('Platform servisi başlatıldı');
      _logger.i('Platform: $platformAdi');
      _logger.i('Uygulama Versiyonu: $tamVersionBilgisi');
      _logger.i('Cihaz: $cihazModeli');
      _logger.i('OS Versiyonu: $osVersionu');
      
    } catch (e) {
      _logger.e('Platform servisi başlatma hatası: $e');
      rethrow;
    }
  }

  /// Paket bilgilerini alır
  Future<void> _paketBilgileriniAl() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _logger.d('Paket bilgileri alındı: ${_packageInfo?.appName} v${_packageInfo?.version}');
    } catch (e) {
      _logger.w('Paket bilgileri alınamadı: $e');
    }
  }

  /// Cihaz bilgilerini alır
  Future<void> _cihazBilgileriniAl() async {
    try {
      if (kIsWeb) {
        final webBrowserInfo = await _deviceInfoPlugin.webBrowserInfo;
        _deviceModel = '${webBrowserInfo.browserName.name} ${webBrowserInfo.platform}';
        _osVersion = webBrowserInfo.userAgent ?? 'Bilinmeyen';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        _osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        _deviceModel = '${iosInfo.name} ${iosInfo.model}';
        _osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }
      
      _logger.d('Cihaz bilgileri alındı: $_deviceModel, $_osVersion');
    } catch (e) {
      _logger.w('Cihaz bilgileri alınamadı: $e');
    }
  }

  /// Platform bilgilerini map olarak döndürür
  Map<String, dynamic> platformBilgileriniAl() {
    return {
      'platform': platformAdi,
      'appVersion': uygulamaVersionu,
      'buildNumber': buildNumarasi,
      'fullVersion': tamVersionBilgisi,
      'device': cihazModeli,
      'osVersion': osVersionu,
      'isAndroid': isAndroid,
      'isIOS': isIOS,
      'isWeb': isWeb,
    };
  }

  /// İki versiyon karşılaştırır (1.2.3 formatında)
  /// Returns: -1 if current < target, 0 if equal, 1 if current > target
  int versiyonKarsilastir(String mevcutVersiyon, String hedefVersiyon) {
    try {
      final mevcut = mevcutVersiyon.split('.').map(int.parse).toList();
      final hedef = hedefVersiyon.split('.').map(int.parse).toList();
      
      // Liste uzunluklarını eşitle
      while (mevcut.length < hedef.length) mevcut.add(0);
      while (hedef.length < mevcut.length) hedef.add(0);
      
      for (int i = 0; i < mevcut.length; i++) {
        if (mevcut[i] < hedef[i]) return -1;
        if (mevcut[i] > hedef[i]) return 1;
      }
      
      return 0;
    } catch (e) {
      _logger.w('Versiyon karşılaştırma hatası: $e');
      return 0;
    }
  }

  /// Mevcut uygulama versiyonunun belirtilen versiyondan eski olup olmadığını kontrol eder
  bool uygulamaGuncellemesiGerekliMi(String minumumVersiyon) {
    return versiyonKarsilastir(uygulamaVersionu, minumumVersiyon) < 0;
  }
} 