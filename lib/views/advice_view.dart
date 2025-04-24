import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../services/input_service.dart';
import '../services/logger_service.dart';

class AdviceView extends StatefulWidget {
  const AdviceView({super.key});

  @override
  State<AdviceView> createState() => _AdviceViewState();
}

class _AdviceViewState extends State<AdviceView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isFlipped = false;
  late TabController _tabController;
  bool _isLoading = false;
  final TextEditingController _chatInputController = TextEditingController();
  final _logger = LoggerService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _tabController = TabController(length: 3, vsync: this);
    
    // Sayfa her açıldığında verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Kullanıcı giriş yapmışsa verileri yükle ve zamanlayıcıyı başlat
        if (authViewModel.currentUser != null) {
          // Tavsiye ve alıntı yükle
          await adviceViewModel.fetchDailyAdviceAndQuote();
          
          // Otomatik yenileme zamanlayıcısını başlat
          adviceViewModel.startDailyAdviceTimer(authViewModel.currentUser!.uid);
        }
        
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        _logger.e('Veri yükleme hatası: $e');
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  // Kartı çevirme
  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
      if (_isFlipped) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9D3FFF),
        title: const Text(
          'Günlük Tavsiyeler',
          style: TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
                controller: _tabController,
                tabs: const [
            Tab(text: 'İlişki Koçu'),
            Tab(text: 'Danışma'),
            Tab(text: 'Sohbet'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF121212),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyAdviceView(),
          _buildConsultationView(),
          _buildChatView(),
        ],
      ),
    );
  }
  
  Widget _buildDailyAdviceView() {
    return Consumer<AdviceViewModel>(
      builder: (context, viewModel, child) {
        if (_isLoading || viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF9D3FFF)),
          );
        }

        // İlişki koçu alıntısını almak için buton göster
        if (!viewModel.hasQuote) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 48, color: Color(0xFF9D3FFF)),
                const SizedBox(height: 16),
                Text(
                  viewModel.quoteErrorMessage ?? 'Tavsiye yükleniyor. Lütfen bekleyin.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // İlişki koçu alıntısı varsa göster
        final quote = viewModel.dailyQuote!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alıntı kartı
              Card(
                color: const Color(0xFF1E1E1E),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF9D3FFF).withOpacity(0.5), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_quote, color: Color(0xFF9D3FFF), size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              quote.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '"${quote.content}"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          quote.source,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Tavsiye kartı
              if (viewModel.hasAdviceCard) ...[
                const Text(
                  'Günün Tavsiyesi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAdviceCard(viewModel.adviceCard!),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildAdviceCard(Map<String, dynamic> advice) {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF9D3FFF).withOpacity(0.5), width: 1),
      ),
        child: Padding(
          padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Row(
              children: [
                Icon(Icons.local_fire_department, color: Color(0xFF9D3FFF), size: 24),
                SizedBox(width: 8),
                    Text(
                  'İlişki Tavsiyesi',
                      style: TextStyle(
            color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    ),
        ),
      ],
            ),
            const SizedBox(height: 12),
                  Text(
              advice['content'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildConsultationView() {
    // Implementation of _buildConsultationView
    throw UnimplementedError();
  }
  
  Widget _buildChatView() {
    // Implementation of _buildChatView
    throw UnimplementedError();
  }
} 