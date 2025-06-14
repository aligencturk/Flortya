import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:logger/logger.dart';
import 'platform_service.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;
  final Logger _logger;
  final PlatformService _platformService;

  RemoteConfigService({
    FirebaseRemoteConfig? remoteConfig,
    Logger? logger,
    PlatformService? platformService,
  })  : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
        _logger = logger ?? Logger(),
        _platformService = platformService ?? PlatformService();

  /// Remote Config'i başlatır ve ayarları yapar
  Future<void> baslat() async {
    try {
      _logger.i('Remote Config başlatılıyor...');
      
      // Fetch ayarlarını yapılandır (debug için daha kısa interval)
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(minutes: 1), // Debug için 1 dakika
        ),
      );
      

      
      // İlk fetch ve activate işlemini burada yapalım
      try {
        bool ilkFetch = await _remoteConfig.fetchAndActivate();
        _logger.i('İlk fetch işlemi sonucu: $ilkFetch');
      } catch (e) {
        _logger.w('İlk fetch işlemi başarısız: $e (Normal durum olabilir)');
      }
      
      _logger.i('Remote Config başarıyla yapılandırıldı');
    } catch (e) {
      _logger.e('Remote Config yapılandırma hatası: $e');
      throw Exception('Remote Config yapılandırma hatası: $e');
    }
  }

  /// Belirtilen parametreyi Remote Config'ten çeker
  Future<String> parametreAl(String parametreAdi) async {
    try {
      _logger.i('Remote Config parametresi alınıyor: $parametreAdi');
      
      // Önce mevcut değerleri kontrol et (fetch etmeden)
      RemoteConfigValue mevcutDeger = _remoteConfig.getValue(parametreAdi);
      _logger.i('Mevcut parametre değeri: ${mevcutDeger.asString()}, Kaynak: ${mevcutDeger.source}');
      
      // Verileri çek ve aktifleştir
      bool fetchBasarili = await _remoteConfig.fetchAndActivate();
      _logger.i('Fetch işlemi sonucu: $fetchBasarili');
      
      // Fetch başarısız olsa bile mevcut değerleri kullanmaya çalış
      RemoteConfigValue deger = _remoteConfig.getValue(parametreAdi);
      _logger.i('Fetch sonrası parametre değeri: ${deger.asString()}, Kaynak: ${deger.source}');
      
      // Eğer hiç değer yoksa hata ver
      if (deger.source == ValueSource.valueStatic) {
        _logger.e('Parametre bulunamadı: $parametreAdi (Kaynak: ${deger.source})');
        throw Exception('Parametre bulunamadı: $parametreAdi. Firebase Console\'da "$parametreAdi" parametresini oluşturun ve publish edin.');
      }
      
      String parametreDegeri = deger.asString();
      
      if (parametreDegeri.isEmpty) {
        _logger.e('Parametre boş: $parametreAdi');
        throw Exception('Parametre boş: $parametreAdi');
      }
      
      // Fetch başarısız olsa bile değer varsa uyarı ver ama devam et
      if (!fetchBasarili) {
        _logger.w('Fetch başarısız oldu ama cached/default değer kullanılıyor: $parametreAdi = $parametreDegeri');
      }
      
      _logger.i('Parametre başarıyla alındı: $parametreAdi = $parametreDegeri (Kaynak: ${deger.source})');
      return parametreDegeri;
      
    } catch (e) {
      _logger.e('Remote Config parametre alma hatası: $e');
      
      // Bağlantı hatalarını kontrol et
      if (e.toString().contains('network') || 
          e.toString().contains('internet') || 
          e.toString().contains('timeout')) {
        throw Exception('Bağlantı hatası: İnternet bağlantısını kontrol edin');
      }
      
      rethrow;
    }
  }

  // Welcome message metodu kaldırıldı

  /// Platform-specific parametreleri çeker (android/ios özel parametreler)
  Future<String> platformParametresiAl(String parametreAdi) async {
    final platform = _platformService.platformAdi;
    final platformSpecificKey = '${parametreAdi}_$platform';
    
    try {
      // Önce platform-specific parametreyi dene
      return await parametreAl(platformSpecificKey);
    } catch (e) {
      // Platform-specific parametre bulunamazsa genel parametreyi dene
      _logger.w('Platform-specific parametre bulunamadı: $platformSpecificKey, genel parametre deneniyor: $parametreAdi');
      return await parametreAl(parametreAdi);
    }
  }

  /// Versiyon kontrolü için minimum sürüm bilgisini çeker
  Future<Map<String, String>> minimumVersionBilgisiAl() async {
    try {
      final platform = _platformService.platformAdi;
      
      // Platform-specific minimum version
      final minVersion = await parametreAl('minimum_version_$platform');
      
      // Zorunlu güncelleme versiyonu
      final forceUpdateVersion = await parametreAl('force_update_version_$platform');
      
      // Güncelleme mesajı
      final updateMessage = await platformParametresiAl('update_message');
      
      // Store URL'leri
      String storeUrl = '';
      if (platform == 'android') {
        storeUrl = await parametreAl('play_store_url');
      } else if (platform == 'ios') {
        storeUrl = await parametreAl('app_store_url');
      }
      
      return {
        'minimumVersion': minVersion,
        'forceUpdateVersion': forceUpdateVersion,
        'updateMessage': updateMessage,
        'storeUrl': storeUrl,
        'platform': platform,
      };
    } catch (e) {
      _logger.e('Minimum versiyon bilgisi alınamadı: $e');
      rethrow;
    }
  }

  /// Aktif kampanyaları çeker
  Future<List<Map<String, dynamic>>> aktifKampanyalariAl() async {
    try {
      final platform = _platformService.platformAdi;
      _logger.i('🔍 Kampanyalar aranıyor, platform: $platform');
      
      // Kampanya JSON'larını parse et
      List<Map<String, dynamic>> campaigns = [];
      
      // Önce platform-specific kampanyaları dene
      String platformCampaignsJson = '';
      try {
        platformCampaignsJson = await parametreAl('active_campaigns_$platform');
        _logger.i('✅ Platform-specific kampanya bulundu: active_campaigns_$platform');
      } catch (e) {
        _logger.d('❌ Platform-specific kampanya bulunamadı: active_campaigns_$platform');
      }
      
      // Sonra genel kampanyaları dene
      String campaignsJson = '';
      try {
        campaignsJson = await parametreAl('active_campaigns');
        _logger.i('✅ Genel kampanya bulundu: active_campaigns');
      } catch (e) {
        _logger.d('❌ Genel kampanya bulunamadı: active_campaigns');
      }
      
      // Platform-specific kampanyaları ekle
      if (platformCampaignsJson.isNotEmpty) {
        try {
          final platformCampaigns = _parseKampanyaJson(platformCampaignsJson);
          campaigns.addAll(platformCampaigns);
          _logger.i('📱 ${platformCampaigns.length} platform-specific kampanya eklendi');
        } catch (e) {
          _logger.w('Platform kampanya parse hatası: $e');
        }
      }
      
      // Genel kampanyaları ekle
      if (campaignsJson.isNotEmpty) {
        try {
          final generalCampaigns = _parseKampanyaJson(campaignsJson);
          campaigns.addAll(generalCampaigns);
          _logger.i('🌍 ${generalCampaigns.length} genel kampanya eklendi');
        } catch (e) {
          _logger.w('Genel kampanya parse hatası: $e');
        }
      }
      
      // Hiç kampanya bulunamadıysa
      if (campaigns.isEmpty) {
        _logger.w('⚠️ Hiç kampanya bulunamadı. Firebase Console\'da şu parametreleri kontrol edin:');
        _logger.w('   - active_campaigns_$platform');
        _logger.w('   - active_campaigns');
        return [];
      }
      
      _logger.i('📊 Toplam ${campaigns.length} kampanya bulundu, filtreleme yapılıyor...');
      
      // Aktif kampanyaları filtrele
      final now = DateTime.now();
      final activeCampaigns = campaigns.where((campaign) {
        try {
          final startDate = DateTime.parse(campaign['startDate'] ?? '');
          final endDate = DateTime.parse(campaign['endDate'] ?? '');
          final isActive = campaign['isActive'] == true;
          final isInDateRange = now.isAfter(startDate) && now.isBefore(endDate);
          
          _logger.d('🗓️ Kampanya "${campaign['id']}": Aktif=$isActive, Tarih aralığında=$isInDateRange');
          
          return isInDateRange && isActive;
        } catch (e) {
          _logger.w('Kampanya tarih parse hatası: $e');
          return false;
        }
      }).toList();
      
      _logger.i('🎯 ${activeCampaigns.length} aktif kampanya bulundu');
      return activeCampaigns;
      
    } catch (e) {
      _logger.e('💥 Kampanya bilgisi alınamadı: $e');
      return [];
    }
  }

  /// Kampanya JSON'ını parse eder
  List<Map<String, dynamic>> _parseKampanyaJson(String jsonString) {
    try {
      _logger.d('Kampanya JSON parse ediliyor: $jsonString');
      
      if (jsonString.isEmpty) {
        _logger.w('Boş JSON string');
        return [];
      }
      
      // JSON string'i parse et
      final dynamic parsed = jsonDecode(jsonString);
      
      if (parsed is List) {
        return List<Map<String, dynamic>>.from(
          parsed.map((item) => Map<String, dynamic>.from(item))
        );
      } else {
        _logger.w('JSON formatı liste değil: ${parsed.runtimeType}');
        return [];
      }
    } catch (e) {
      _logger.e('JSON parse hatası: $e');
      _logger.e('Problematik JSON: $jsonString');
      return [];
    }
  }

  /// Uygulama yapılandırma bilgilerini çeker
  Future<Map<String, dynamic>> uygulamaYapilandirmaBilgisiAl() async {
    try {
      final platform = _platformService.platformAdi;
      
      final config = <String, dynamic>{};
      
      // Temel yapılandırma
      config['maintenanceMode'] = await _getBoolParameter('maintenance_mode');
      config['maintenanceMessage'] = await parametreAl('maintenance_message');
      
      // Platform-specific yapılandırma
      config['enableFeatures'] = await _getListParameter('enabled_features_$platform');
      config['disableFeatures'] = await _getListParameter('disabled_features_$platform');
      
      // API yapılandırması
      config['apiTimeout'] = await _getIntParameter('api_timeout');
      config['maxRetries'] = await _getIntParameter('max_retries');
      
      // UI yapılandırması
      config['defaultTheme'] = await parametreAl('default_theme');
      
      return config;
    } catch (e) {
      _logger.e('Uygulama yapılandırma bilgisi alınamadı: $e');
      return {};
    }
  }

  /// Boolean parametre çeker
  Future<bool> _getBoolParameter(String key) async {
    try {
      final value = await parametreAl(key);
      return value.toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Integer parametre çeker
  Future<int> _getIntParameter(String key) async {
    try {
      final value = await parametreAl(key);
      return int.parse(value);
    } catch (e) {
      return 0;
    }
  }

  /// Liste parametre çeker (virgülle ayrılmış)
  Future<List<String>> _getListParameter(String key) async {
    try {
      final value = await parametreAl(key);
      if (value.isEmpty) return [];
      return value.split(',').map((e) => e.trim()).toList();
    } catch (e) {
      return [];
    }
  }
} 