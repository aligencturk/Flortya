import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../models/analysis_result_model.dart';
import '../models/analysis_type.dart';
import '../utils/loading_indicator.dart';
import '../widgets/analysis_result_box.dart';

class PastConsultationsView extends StatefulWidget {
  const PastConsultationsView({super.key});

  @override
  State<PastConsultationsView> createState() => _PastConsultationsViewState();
}

class _PastConsultationsViewState extends State<PastConsultationsView> {
  bool _isLoading = true;
  List<AnalysisResult> _consultations = [];
  final Map<String, bool> _expandedState = {};
  
  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConsultations();
    });
  }
  
  Future<void> _loadConsultations() async {
    setState(() {
      _isLoading = true;
    });
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    
    if (authViewModel.currentUser == null) {
      setState(() {
        _isLoading = false;
        _consultations = [];
      });
      return;
    }
    
    try {
      // Debug log
      print('🔍 Danışma geçmişi yükleniyor... - kullanıcı: ${authViewModel.currentUser!.uid}');
      
      // Sadece CONSULTATION tipindeki analizleri yükle
      final results = await messageViewModel.getUserAnalysisResults(
        authViewModel.currentUser!.uid,
        analysisType: AnalysisType.consultation,
      );
      
      // Debug log
      print('📊 Danışma sonuçları yüklendi: ${results.length} adet sonuç bulundu');
      
      if (results.isEmpty) {
        print('❗ Hiç danışma sonucu bulunamadı. Lütfen analyses koleksiyonunu kontrol edin.');
      } else {
        print('✅ İlk danışmanın ID\'si: ${results.first.id}');
      }
      
      // Tarihe göre sırala (en yeni en üstte)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      setState(() {
        _consultations = results;
        _isLoading = false;
        
        // Başlangıçta hepsini kapalı olarak ayarla
        for (var result in results) {
          _expandedState[result.id] = false;
        }
      });
    } catch (e) {
      print('❌ Danışma geçmişi yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
        _consultations = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Danışma geçmişi yüklenirken hata: $e')),
        );
      }
    }
  }
  
  void _toggleExpanded(String id) {
    setState(() {
      _expandedState[id] = !(_expandedState[id] ?? false);
    });
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
                      'Danışma Geçmişi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              
              // İçerik
              Expanded(
                child: _isLoading
                    ? Center(
                        child: yuklemeWidgeti(
                          tip: AnimasyonTipi.DAIRE,
                          mesaj: 'Danışma geçmişiniz yükleniyor...',
                        ),
                      )
                    : _consultations.isEmpty
                        ? _buildEmptyState()
                        : _buildConsultationsList(),
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
            Icons.chat_bubble_outline,
            size: 70,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz bir danışma kaydınız yok',
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
              'İlişkinizle ilgili danışmak için analiz sayfasındaki "Danış" butonunu kullanabilirsiniz',
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
              context.go('/profile');
            },
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Danışmak İstiyorum'),
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
  
  Widget _buildConsultationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _consultations.length,
      itemBuilder: (context, index) {
        final consultation = _consultations[index];
        final isExpanded = _expandedState[consultation.id] ?? false;
        
        return AnalysisResultBox(
          result: consultation,
          showDetailedInfo: isExpanded,
          onTap: () => _toggleExpanded(consultation.id),
        );
      },
    ).animate().fadeIn(duration: 300.ms);
  }
} 