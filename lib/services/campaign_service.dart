import 'dart:convert';
import 'package:flutter/material.dart';
import 'remote_config_service.dart';
import 'platform_service.dart';
import 'logger_service.dart';

enum CampaignType {
  notification,  // Bildirim kampanyası
  popup,         // Popup kampanyası
  banner,        // Banner kampanyası
  discount,      // İndirim kampanyası
  feature,       // Özellik tanıtımı
}

class Campaign {
  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final CampaignType type;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Map<String, dynamic> metadata;
  final List<String> targetPlatforms;
  final String? actionUrl;
  final String? actionText;
  final int priority;

  const Campaign({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.metadata = const {},
    this.targetPlatforms = const [],
    this.actionUrl,
    this.actionText,
    this.priority = 1,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      imageUrl: json['imageUrl'],
      type: CampaignType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CampaignType.notification,
      ),
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toString()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().add(const Duration(days: 30)).toString()),
      isActive: json['isActive'] ?? true,
      metadata: json['metadata'] ?? {},
      targetPlatforms: List<String>.from(json['targetPlatforms'] ?? []),
      actionUrl: json['actionUrl'],
      actionText: json['actionText'],
      priority: json['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'imageUrl': imageUrl,
      'type': type.name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
      'targetPlatforms': targetPlatforms,
      'actionUrl': actionUrl,
      'actionText': actionText,
      'priority': priority,
    };
  }

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           now.isBefore(endDate);
  }

  bool isTargetPlatform(String platform) {
    return targetPlatforms.isEmpty || targetPlatforms.contains(platform);
  }
}

class CampaignService {
  final RemoteConfigService _remoteConfigService;
  final PlatformService _platformService;
  final LoggerService _logger;

  List<Campaign> _campaigns = [];
  List<String> _shownCampaignIds = [];

  CampaignService({
    required RemoteConfigService remoteConfigService,
    required PlatformService platformService,
    LoggerService? logger,
  })  : _remoteConfigService = remoteConfigService,
        _platformService = platformService,
        _logger = logger ?? LoggerService();

  /// Kampanyaları Remote Config'ten yükler
  Future<void> kampanyalariYukle() async {
    try {
      _logger.i('🚀 Kampanyalar yükleniyor...');

      final campaigns = await _remoteConfigService.aktifKampanyalariAl();
      _logger.i('📥 Remote Config\'ten ${campaigns.length} kampanya alındı');
      
      if (campaigns.isEmpty) {
        _logger.w('⚠️ Remote Config\'te kampanya bulunamadı. Firebase Console\'da active_campaigns veya active_campaigns_android parametrelerini kontrol edin.');
        _campaigns = [];
        return;
      }

      // Her kampanyayı detaylı logla
      for (int i = 0; i < campaigns.length; i++) {
        _logger.d('📋 Kampanya $i: ${campaigns[i]}');
      }
      
      _campaigns = campaigns.map((campaignJson) {
        try {
          final campaign = Campaign.fromJson(campaignJson);
          _logger.i('✅ Kampanya parse edildi: ${campaign.title} (${campaign.id})');
          return campaign;
        } catch (e) {
          _logger.w('❌ Kampanya parse hatası: $e');
          _logger.w('🔍 Problematik kampanya JSON: $campaignJson');
          return null;
        }
      }).where((campaign) => campaign != null).cast<Campaign>().toList();

      _logger.i('📊 ${_campaigns.length} kampanya başarıyla parse edildi');
      
      // Platform filtrelemesi
      final platform = _platformService.platformAdi;
      _logger.i('🔍 Platform filtrelemesi yapılıyor: $platform');
      
      final beforeFilter = _campaigns.length;
      _campaigns = _campaigns.where((campaign) {
        final isTargetPlatform = campaign.isTargetPlatform(platform);
        final isCurrentlyActive = campaign.isCurrentlyActive;
        
        _logger.d('🎯 Kampanya ${campaign.title}: Platform uygun: $isTargetPlatform, Aktif: $isCurrentlyActive');
        
        return isTargetPlatform && isCurrentlyActive;
      }).toList();

      // Öncelik sıralaması
      _campaigns.sort((a, b) => b.priority.compareTo(a.priority));

      _logger.i('🎉 Platform filtrelemesi tamamlandı: $beforeFilter → ${_campaigns.length} kampanya');
      
      // Final kampanya listesini logla
      for (final campaign in _campaigns) {
        _logger.i('🏆 Final kampanya: ${campaign.title} (${campaign.type.name}, öncelik: ${campaign.priority})');
      }

    } catch (e) {
      _logger.e('💥 Kampanya yükleme hatası: $e');
      _campaigns = [];
    }
  }

  /// Aktif kampanyaları döndürür
  List<Campaign> get aktifKampanyalar => _campaigns;

  /// Belirli tipte kampanyaları döndürür
  List<Campaign> kampanyalariTipiAl(CampaignType type) {
    return _campaigns.where((campaign) => campaign.type == type).toList();
  }

  /// Henüz gösterilmemiş kampanyaları döndürür
  List<Campaign> get gosterilmemisKampanyalar {
    return _campaigns.where((campaign) => 
      !_shownCampaignIds.contains(campaign.id)
    ).toList();
  }

  /// Popup kampanyalarını gösterir
  Future<void> popupKampanyalariGoster(BuildContext context) async {
    _logger.i('🎪 Popup kampanyaları kontrol ediliyor...');
    _logger.i('📊 Toplam yüklenen kampanya sayısı: ${_campaigns.length}');
    
    // Tüm kampanyaları detaylı logla
    for (int i = 0; i < _campaigns.length; i++) {
      final campaign = _campaigns[i];
      _logger.d('📋 Kampanya $i: "${campaign.title}" (Tip: ${campaign.type.name}, ID: ${campaign.id}, Aktif: ${campaign.isCurrentlyActive})');
    }
    
    final allCampaigns = gosterilmemisKampanyalar;
    _logger.i('📋 Gösterilmemiş kampanya sayısı: ${allCampaigns.length}');
    
    // Gösterilmemiş kampanyaları detaylı logla
    for (int i = 0; i < allCampaigns.length; i++) {
      final campaign = allCampaigns[i];
      _logger.d('🔍 Gösterilmemiş kampanya $i: "${campaign.title}" (Tip: ${campaign.type.name})');
    }
    
    final popupCampaigns = allCampaigns
        .where((campaign) => campaign.type == CampaignType.popup)
        .toList();
    
    _logger.i('🎯 Popup tipinde kampanya sayısı: ${popupCampaigns.length}');
    
    if (popupCampaigns.isEmpty) {
      _logger.w('⚠️ Gösterilecek popup kampanyası bulunamadı');
      _logger.w('💡 Kontrol edilecekler:');
      _logger.w('   1. Firebase Console\'da kampanya parametresi var mı?');
      _logger.w('   2. Kampanya tipi "popup" olarak ayarlanmış mı?');
      _logger.w('   3. Kampanya tarihleri geçerli mi?');
      _logger.w('   4. Platform hedeflemesi doğru mu?');
      
      // Mevcut kampanya tiplerini göster
      final campaignTypes = _campaigns.map((c) => c.type.name).toSet().toList();
      _logger.w('   📋 Mevcut kampanya tipleri: $campaignTypes');
      
      return;
    }

    for (final campaign in popupCampaigns) {
      _logger.i('🎪 Popup gösteriliyor: ${campaign.title}');
      if (context.mounted) {
        await _kampanyaPopupGoster(context, campaign);
        _kampanyaGosterildiOlarakIsaretle(campaign.id);
        _logger.i('✅ Popup gösterildi ve işaretlendi: ${campaign.id}');
      } else {
        _logger.w('⚠️ Context mounted değil, popup gösterilemiyor');
      }
    }
  }

  /// Tek bir kampanya popup'ını gösterir
  Future<void> _kampanyaPopupGoster(BuildContext context, Campaign campaign) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üst kısım - İkon ve başlık
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // İkon container
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getCampaignIcon(campaign.type),
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Başlık
                      Text(
                        campaign.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      
                      // Mesaj
                      Text(
                        campaign.message,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Görsel varsa göster
                if (campaign.imageUrl != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        campaign.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.white.withOpacity(0.5),
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Geçerlilik bilgisi
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Geçerli: ${_formatDate(campaign.endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Butonlar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Kapat butonu
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
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
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text(
                              'Kapat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Aksiyon butonu (varsa)
                      if (campaign.actionUrl != null && campaign.actionText != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.white, Color(0xFFF0F0F0)],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _kampanyaAksiyonuCalistir(campaign);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFF6A11CB),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: Text(
                                campaign.actionText!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Kampanya tipine göre ikon döndürür
  IconData _getCampaignIcon(CampaignType type) {
    switch (type) {
      case CampaignType.notification:
        return Icons.notifications_rounded;
      case CampaignType.popup:
        return Icons.campaign_rounded;
      case CampaignType.banner:
        return Icons.flag_rounded;
      case CampaignType.discount:
        return Icons.local_offer_rounded;
      case CampaignType.feature:
        return Icons.star_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  /// Banner kampanyalarını döndürür
  List<Campaign> get bannerKampanyalar {
    return kampanyalariTipiAl(CampaignType.banner);
  }

  /// Bildirim kampanyalarını döndürür
  List<Campaign> get bildirimKampanyalar {
    return kampanyalariTipiAl(CampaignType.notification);
  }

  /// İndirim kampanyalarını döndürür
  List<Campaign> get indirimKampanyalar {
    return kampanyalariTipiAl(CampaignType.discount);
  }

  /// Kampanya aksiyonunu çalıştırır
  Future<void> _kampanyaAksiyonuCalistir(Campaign campaign) async {
    if (campaign.actionUrl != null) {
      try {
        _logger.i('Kampanya aksiyonu çalıştırılıyor: ${campaign.actionUrl}');
        // URL açma işlemi için url_launcher gerekli
      } catch (e) {
        _logger.e('Kampanya aksiyonu çalıştırılamadı: $e');
      }
    }
  }

  /// Kampanyayı gösterildi olarak işaretler
  void _kampanyaGosterildiOlarakIsaretle(String campaignId) {
    if (!_shownCampaignIds.contains(campaignId)) {
      _shownCampaignIds.add(campaignId);
      _logger.d('Kampanya gösterildi olarak işaretlendi: $campaignId');
    }
  }

  /// Kampanya ID'sini gösterildi olarak işaretler
  void kampanyaGosterildi(String campaignId) {
    _kampanyaGosterildiOlarakIsaretle(campaignId);
  }

  /// Gösterilmiş kampanyaları temizler
  void gosterilmisKampanyalariTemizle() {
    _shownCampaignIds.clear();
    _logger.d('Gösterilmiş kampanyalar temizlendi');
  }

  /// Tarih formatını düzenler
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Kampanya widget'ı oluşturur
  Widget kampanyaWidgetOlustur(Campaign campaign) {
    switch (campaign.type) {
      case CampaignType.banner:
        return _bannerKampanyaWidget(campaign);
      case CampaignType.notification:
        return _bildirimKampanyaWidget(campaign);
      case CampaignType.discount:
        return _indirimKampanyaWidget(campaign);
      default:
        return _varsayilanKampanyaWidget(campaign);
    }
  }

  /// Banner kampanya widget'ı
  Widget _bannerKampanyaWidget(Campaign campaign) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  campaign.message,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (campaign.actionText != null)
            ElevatedButton(
              onPressed: () => _kampanyaAksiyonuCalistir(campaign),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
              ),
              child: Text(campaign.actionText!),
            ),
        ],
      ),
    );
  }

  /// Bildirim kampanya widget'ı
  Widget _bildirimKampanyaWidget(Campaign campaign) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications, color: Colors.blue),
        title: Text(campaign.title),
        subtitle: Text(campaign.message),
        trailing: campaign.actionText != null
            ? TextButton(
                onPressed: () => _kampanyaAksiyonuCalistir(campaign),
                child: Text(campaign.actionText!),
              )
            : null,
      ),
    );
  }

  /// İndirim kampanya widget'ı
  Widget _indirimKampanyaWidget(Campaign campaign) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border.all(color: Colors.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(campaign.message),
              ],
            ),
          ),
          if (campaign.actionText != null)
            ElevatedButton(
              onPressed: () => _kampanyaAksiyonuCalistir(campaign),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(campaign.actionText!),
            ),
        ],
      ),
    );
  }

  /// Varsayılan kampanya widget'ı
  Widget _varsayilanKampanyaWidget(Campaign campaign) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campaign.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(campaign.message),
            if (campaign.actionText != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _kampanyaAksiyonuCalistir(campaign),
                child: Text(campaign.actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 