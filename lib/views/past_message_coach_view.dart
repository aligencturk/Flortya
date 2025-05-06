import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../models/past_message_coach_analysis.dart';
import '../controllers/message_coach_controller.dart';
import '../controllers/message_coach_visual_controller.dart';
import '../utils/loading_indicator.dart';

class PastMessageCoachView extends ConsumerStatefulWidget {
  const PastMessageCoachView({super.key});

  @override
  ConsumerState<PastMessageCoachView> createState() => _PastMessageCoachViewState();
}

class _PastMessageCoachViewState extends ConsumerState<PastMessageCoachView> {
  bool _isLoading = true;
  List<PastMessageCoachAnalysis> _messageCoachHistory = [];
  Map<String, bool> _expandedState = {};
  bool _isFirstLoad = true;
  
  @override
  void initState() {
    super.initState();
    _isFirstLoad = true;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_isFirstLoad) {
      _loadMessageCoachHistory();
      _isFirstLoad = false;
    }
  }
  
  Future<void> _loadMessageCoachHistory() async {
    setState(() {
      _isLoading = true;
      _messageCoachHistory = [];
      _expandedState = {};
    });
    
    final authViewModel = provider.Provider.of<AuthViewModel>(context, listen: false);
    final messageCoachController = provider.Provider.of<MessageCoachController>(context, listen: false);
    
    if (authViewModel.currentUser == null) {
      setState(() {
        _isLoading = false;
        _messageCoachHistory = [];
      });
      return;
    }
    
    try {
      messageCoachController.setCurrentUserId(authViewModel.currentUser!.uid);
      
      final results = await messageCoachController.mesajKocuGecmisiniGetir();
      
      if (!mounted) return;
      
      setState(() {
        _messageCoachHistory = results;
        _isLoading = false;
        
        for (var result in results) {
          _expandedState[result.id] = false;
        }
      });
      
      print('📊 Mesaj koçu geçmişi yüklendi. Kayıt sayısı: ${results.length}');
      
    } catch (e) {
      print('❌ Mesaj koçu geçmişi yüklenirken hata: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _messageCoachHistory = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesaj koçu geçmişi yüklenirken hata: $e')),
      );
    }
  }
  
  void _toggleExpanded(String id) {
    setState(() {
      _expandedState[id] = !(_expandedState[id] ?? false);
    });
  }
  
  Future<void> _clearMessageCoachHistory() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF352269),
        title: const Text(
          'Mesaj Koçu Geçmişini Temizle',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tüm mesaj koçu geçmişiniz kalıcı olarak silinecek. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'İptal',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Temizle',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
    
    if (shouldClear) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final messageCoachController = provider.Provider.of<MessageCoachController>(context, listen: false);
        final success = await messageCoachController.mesajKocuGecmisiniTemizle();
        
        if (!mounted) return;
        
        await Future.delayed(const Duration(seconds: 2));
        
        setState(() {
          _messageCoachHistory = [];
          _expandedState.clear();
          _isLoading = false;
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mesaj koçu geçmişi temizlendi')),
          );
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _loadMessageCoachHistory();
            }
          });
          
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mesaj koçu geçmişi temizlenirken bir hata oluştu')),
          );
        }
      } catch (e) {
        print('❌ Mesaj koçu geçmişi temizlenirken hata: $e');
        
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj koçu geçmişi temizlenirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2A80), Color(0xFF2D1957)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => context.go('/profile'),
                    ),
                    const Text(
                      'Mesaj Koçu Geçmişi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Temizleme butonu
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white70),
                      onPressed: _messageCoachHistory.isEmpty ? null : _clearMessageCoachHistory,
                      tooltip: 'Geçmişi Temizle',
                    ),
                  ],
                ),
              ),
              
              // İçerik
              Expanded(
                child: _isLoading
                    ? Center(
                        child: yuklemeWidgeti(
                          tip: AnimasyonTipi.DAIRE,
                          mesaj: 'Mesaj koçu geçmişiniz yükleniyor...',
                        ),
                      )
                    : _messageCoachHistory.isEmpty
                        ? _buildEmptyState()
                        : _buildMessageCoachHistoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 70,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bir mesaj koçu kaydınız yok',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Mesajlaşma geçmişinizi analiz ettirmek için mesaj koçunu kullanabilirsiniz',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.go('/home', extra: {'tabIndex': 2});
            },
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('Mesaj Koçuna Git'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9D3FFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Widget _buildMessageCoachHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messageCoachHistory.length,
      itemBuilder: (context, index) {
        final item = _messageCoachHistory[index];
        final isExpanded = _expandedState[item.id] ?? false;
        
        return _buildMessageCoachItem(item, isExpanded);
      },
    ).animate().fadeIn(duration: 300.ms);
  }
  
  Widget _buildMessageCoachItem(PastMessageCoachAnalysis item, bool isExpanded) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _toggleExpanded(item.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve tarih
              Row(
                children: [
                  Icon(
                    item.isVisualAnalysis ? Icons.image : Icons.chat_bubble_outline,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.isVisualAnalysis ? 'Görsel Analiz' : 'Metin Analiz',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    item.getFormattedDate(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Özet
              Text(
                item.getOzet(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                maxLines: isExpanded ? 100 : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
              ),
              
              // Genişletilmiş içerik
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                
                if (item.isVisualAnalysis) 
                  _buildVisualAnalysisDetails(item)
                else 
                  _buildTextAnalysisDetails(item),
              ],
              
              // Genişletme göstergesi
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextAnalysisDetails(PastMessageCoachAnalysis item) {
    final analysis = item.toMessageCoachAnalysis();
    if (analysis == null) {
      return const Text(
        'Analiz detayları yüklenemedi',
        style: TextStyle(color: Colors.white70),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sohbet havası
        if (analysis.sohbetGenelHavasi != null) ...[
          const Text(
            'Sohbet Havası:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis.sohbetGenelHavasi!,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        
        // Son mesaj tonu
        if (analysis.sonMesajTonu != null) ...[
          const Text(
            'Son Mesaj Tonu:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis.sonMesajTonu!,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        
        // Doğrudan yorum
        if (analysis.direktYorum != null) ...[
          const Text(
            'Koçun Yorumu:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis.direktYorum!,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        
        // Yanıt önerileri
        if (analysis.cevapOnerileri != null && analysis.cevapOnerileri!.isNotEmpty) ...[
          const Text(
            'Yanıt Önerileri:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.cevapOnerileri!.map((oneri) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                oneri,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )),
        ],
      ],
    );
  }
  
  Widget _buildVisualAnalysisDetails(PastMessageCoachAnalysis item) {
    final analysis = item.toMessageCoachVisualAnalysis();
    if (analysis == null) {
      return const Text(
        'Görsel analiz detayları yüklenemedi',
        style: TextStyle(color: Colors.white70),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Açıklama
        if (item.aciklama != null && item.aciklama!.isNotEmpty) ...[
          const Text(
            'Sorduğunuz Soru:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${item.aciklama!}"',
            style: const TextStyle(
              color: Colors.white,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Konum değerlendirmesi
        if (analysis.konumDegerlendirmesi != null) ...[
          const Text(
            'Koçun Değerlendirmesi:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            analysis.konumDegerlendirmesi!,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        
        // Önerilen mesajlar
        if (analysis.alternativeMessages.isNotEmpty) ...[
          const Text(
            'Önerilen Mesajlar:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.alternativeMessages.map((oneri) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                oneri,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )),
          const SizedBox(height: 12),
        ],
        
        // Olası yanıtlar
        if (analysis.partnerResponses.isNotEmpty) ...[
          const Text(
            'Olası Yanıtlar:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          ...analysis.partnerResponses.asMap().entries.map((entry) {
            final index = entry.key;
            final yanit = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: index == 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      index == 0 ? '✓ Olumlu Yanıt:' : '✗ Olumsuz Yanıt:',
                      style: TextStyle(
                        color: index == 0 ? Colors.green[300] : Colors.red[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      yanit,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
} 