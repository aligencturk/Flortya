import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../widgets/custom_button.dart';

class AdviceView extends StatefulWidget {
  const AdviceView({Key? key}) : super(key: key);

  @override
  State<AdviceView> createState() => _AdviceViewState();
}

class _AdviceViewState extends State<AdviceView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvice();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Tavsiye yükleme
  Future<void> _loadAdvice() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await adviceViewModel.getDailyAdvice(
        authViewModel.user!.id,
        isPremium: authViewModel.isPremium,
      );
    }
  }

  // Tavsiye kartını yenileme (premium kullanıcı için)
  Future<void> _refreshAdvice() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await adviceViewModel.getDailyAdvice(
        authViewModel.user!.id,
        isPremium: authViewModel.isPremium,
        force: true,
      );
    }
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
    final authViewModel = Provider.of<AuthViewModel>(context);
    final adviceViewModel = Provider.of<AdviceViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Tavsiye'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: adviceViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Açıklama metni
                  Text(
                    'Günün İlişki Tavsiyesi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Her gün yeni bir tavsiye ile ilişkinizi güçlendirin.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Tavsiye kartı
                  if (adviceViewModel.hasAdvice)
                    Expanded(
                      child: _buildAdviceCard(context, adviceViewModel),
                    )
                  else
                    Expanded(
                      child: _buildEmptyAdviceCard(context),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Yenile butonu (premium kullanıcı için)
                  if (authViewModel.isPremium)
                    CustomButton(
                      text: 'Yeni Tavsiye Al',
                      onPressed: _refreshAdvice,
                      icon: Icons.refresh,
                      isLoading: adviceViewModel.isLoading,
                      isFullWidth: true,
                    )
                  else
                    // Premium olmayan kullanıcı için premium bilgisi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Premium Özellik',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Premium üye olarak her gün yeni tavsiyeler alabilirsiniz.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // Tavsiye kartı widget'ı
  Widget _buildAdviceCard(BuildContext context, AdviceViewModel adviceViewModel) {
    final advice = adviceViewModel.dailyAdvice!;
    
    return InkWell(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final value = _animationController.value;
          final isBack = value >= 0.5;
          
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(isBack ? (1 - value) * -3.14 : value * 3.14),
            alignment: Alignment.center,
            child: isBack
                ? _buildCardBack(context, advice)
                : _buildCardFront(context, advice),
          );
        },
      ),
    );
  }

  // Kart ön yüzü
  Widget _buildCardFront(BuildContext context, Map<String, dynamic> advice) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lightbulb,
              size: 64,
              color: Colors.white,
            ),
            
            const SizedBox(height: 24),
            
            Text(
              advice['title'],
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            const Spacer(),
            
            Text(
              'Kartı çevirmek için dokunun',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  // Kart arka yüzü
  Widget _buildCardBack(BuildContext context, Map<String, dynamic> advice) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              advice['title'],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const Divider(height: 32),
            
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  advice['advice'],
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Kartı çevirmek için dokunun',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Boş tavsiye kartı (henüz tavsiye yoksa)
  Widget _buildEmptyAdviceCard(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Henüz günlük tavsiye mevcut değil',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Tavsiye almak için butona tıklayın',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 