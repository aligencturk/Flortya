import 'package:flutter/material.dart';
import '../services/premium_service.dart';

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLocked;
  final VoidCallback onTap;
  final VoidCallback onPremiumInfoRequest;
  final PremiumFeature feature;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isLocked,
    required this.onTap,
    required this.onPremiumInfoRequest,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? onPremiumInfoRequest : onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF352269),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if (isLocked)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.lock,
                      color: Color(0xFF9D3FFF),
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Premium bilgilendirme dialog'unu gösteren fonksiyon
void showPremiumInfoDialog(BuildContext context, PremiumFeature feature) {
  String title = 'Premium Özellik';
  String message = '';

  // Özelliğe göre mesajları ayarla
  switch (feature) {
    case PremiumFeature.VISUAL_OCR:
      title = 'Günlük Limit Doldu';
      message = 'Görsel Analiz için günlük 5 kullanım hakkınız doldu. Sınırsız kullanım için Premium\'a geçebilirsiniz.';
      break;
    case PremiumFeature.TXT_ANALYSIS:
      title = 'Kullanım Limiti Doldu';
      message = 'TXT dosyası analizi için kullanım hakkınız doldu. Sınırsız kullanım için Premium\'a geçebilirsiniz.';
      break;
    case PremiumFeature.WRAPPED_ANALYSIS:
      title = 'Premium Özellik';
      message = 'Wrapped tarzı analiz özetini tekrar görüntülemek için Premium abonelik gereklidir.';
      break;
    case PremiumFeature.CONSULTATION:
      title = 'Premium Özellik';
      message = 'Bu özellik yalnızca Premium kullanıcılar içindir.';
      break;
    case PremiumFeature.MESSAGE_COACH:
      title = 'Kullanım Limiti';
      message = 'Mesaj koçu özelliğini sınırsız kullanmak için Premium\'a geçebilirsiniz. Diğer türlü her kullanım için reklam izlemeniz gerekecektir.';
      break;
    case PremiumFeature.ALTERNATIVE_SUGGESTIONS:
      title = 'Alternatif Öneriler';
      message = 'Alternatif mesaj önerilerini görüntülemek için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
    case PremiumFeature.RESPONSE_SCENARIOS:
      title = 'Yanıt Senaryoları';
      message = 'Olası yanıt senaryolarını görmek için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
    case PremiumFeature.VISUAL_MODE:
      title = 'Görsel Mod';
      message = 'Görsel mod özelliğini kullanmak için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
    case PremiumFeature.VISUAL_ALTERNATIVE_SUGGESTIONS:
      title = 'Görsel Alternatif Öneriler';
      message = 'Görsel mod alternatif mesaj önerilerini görüntülemek için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
    case PremiumFeature.VISUAL_POSITIVE_SCENARIO:
      title = 'Görsel Olumlu Senaryo';
      message = 'Görsel mod olumlu yanıt senaryolarını görmek için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
    case PremiumFeature.VISUAL_NEGATIVE_SCENARIO:
      title = 'Görsel Olumsuz Senaryo';
      message = 'Görsel mod olumsuz yanıt senaryolarını görmek için Premium abonelik alabilir veya reklam izleyebilirsiniz.';
      break;
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Kapat'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9D3FFF),
          ),
          onPressed: () {
            Navigator.pop(context);
            // Burada premium satın alma sayfasına yönlendirme yapılabilir
            // Navigator.pushNamed(context, '/premium');
          },
          child: const Text(
            'Premium\'a Geç',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
} 