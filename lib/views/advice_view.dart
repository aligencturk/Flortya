import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/advice_viewmodel.dart';
import '../services/input_service.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  // Verileri yükleme
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    // Tavsiye kartını yükle
    await adviceViewModel.getDailyAdviceCard(authViewModel.currentUser!.uid);
    
    // Chat geçmişini yükle
    await adviceViewModel.loadChats(authViewModel.currentUser!.uid);
    
    setState(() {
      _isLoading = false;
    });
  }

  // Tavsiye kartını yenileme (premium kullanıcı için)
  Future<void> _refreshAdvice() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    // Premium kontrolü yap
    if (!authViewModel.isPremium) {
      // Snackbar ile kullanıcıya bildirme işlemi buton içerisine taşındı
      // Burada herhangi bir işlem yapmıyoruz, böylece mevcut tavsiye kartı korunacak
      return;
    }
    
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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'İlişki Tavsiyeleri',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadData,
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              height: 45,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Colors.white,
                ),
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.white,
                tabs: const [
                  Tab(text: 'Günlük Tavsiye'),
                  Tab(text: 'İlişki Danışmanı'),
                ],
              ),
            ),
            
            // Ana içerik
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Günlük Tavsiye Tab
                      _buildDailyAdviceTab(),
                      
                      // İlişki Danışmanı Chat Tab
                      _buildRelationshipChatTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Günlük Tavsiye Tab
  Widget _buildDailyAdviceTab() {
    // ScaffoldMessenger için context'i burada yakala
    final scaffoldContext = context;
    return Consumer<AdviceViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading || _isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (viewModel.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(viewModel.errorMessage!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    viewModel.clearError();
                    _loadData();
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          );
        }
        
        if (!viewModel.hasAdviceCard) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Henüz tavsiye kartı alınmamış.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Tavsiye Al'),
                ),
              ],
            ),
          );
        }
        
        // Tavsiye kartı mevcut
        final advice = viewModel.adviceCard!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Text(
                advice['title'] ?? 'Günlük İlişki Tavsiyesi',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Tarih
              Text(
                'Tarih: ${_formatDate(advice['timestamp'])}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              
              // Kategori
              if (advice['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    advice['category'],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              
              // İçerik
              Text(
                advice['content'] ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Yenile butonu
              Center(
                child: Consumer<AuthViewModel>(
                  builder: (context, authViewModel, _) {
                    final isPremium = authViewModel.isPremium;
                    
                    return ElevatedButton.icon(
                      onPressed: () {
                        // AuthViewModel'i burada da alabiliriz, Consumer2 kullanmak yerine
                        final authViewModel = Provider.of<AuthViewModel>(scaffoldContext, listen: false);
                        final isPremium = authViewModel.isPremium;
                        
                        if (isPremium) {
                          _refreshAdvice();
                        } else {
                          // Premium olmayan kullanıcılar için uyarı mesajı
                          // Builder context'i yerine dışarıdaki scaffoldContext'i kullan
                          ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                            const SnackBar(
                              content: Text('Bu özellik sadece premium üyelik ile kullanılabilir.'),
                              backgroundColor: Colors.deepOrange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        // isPremium durumunu burada tekrar kontrol etmemiz gerekecek veya Consumer içinde kalmalı
                        // Şimdilik Consumer içinde bırakalım, sadece context'i değiştirdik
                        Provider.of<AuthViewModel>(context, listen: false).isPremium ? Icons.refresh : Icons.lock,
                        color: Provider.of<AuthViewModel>(context, listen: false).isPremium ? null : Colors.grey,
                      ),
                      label: Text(Provider.of<AuthViewModel>(context, listen: false).isPremium ? 'Tavsiye Yenile' : 'Premium Özellik'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Provider.of<AuthViewModel>(context, listen: false).isPremium ? null : Colors.grey.shade200,
                      ),
                    );
                  },
                ),
              ),
              
              // Premium olmayan kullanıcılara premium bilgilendirme metni
              Consumer<AuthViewModel>(
                builder: (context, authViewModel, _) {
                  if (!authViewModel.isPremium) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tavsiye yenilemek için premium üyelik gereklidir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // İlişki Danışmanı Chat Tab
  Widget _buildRelationshipChatTab() {
    return Consumer2<AdviceViewModel, AuthViewModel>(
      builder: (context, adviceViewModel, authViewModel, child) {
        final currentUser = authViewModel.currentUser;
        
        if (currentUser == null) {
          return const Center(child: Text('Oturum açmanız gerekiyor'));
        }
        
        return Column(
          children: [
            // Sohbet listesi veya mevcut sohbet gösterimi
            Expanded(
              child: adviceViewModel.hasCurrentChat
                  ? _buildChatMessages(adviceViewModel)
                  : _buildChatList(adviceViewModel),
            ),
            
            // Mesaj girişi
            if (adviceViewModel.hasCurrentChat)
              _buildChatInput(adviceViewModel, currentUser.uid),
          ],
        );
      },
    );
  }
  
  // Sohbet listesi
  Widget _buildChatList(AdviceViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (viewModel.chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Henüz sohbet bulunmuyor'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showNewChatDialog(context),
              child: const Text('Sohbet Başlat'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Yeni sohbet butonu
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showNewChatDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Sohbet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        
        // Sohbet listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.chats.length,
            itemBuilder: (context, index) {
              final chat = viewModel.chats[index];
              return _buildChatListItem(context, chat, viewModel);
            },
          ),
        ),
      ],
    );
  }
  
  // Sohbet liste öğesi
  Widget _buildChatListItem(BuildContext context, chat, AdviceViewModel viewModel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          await viewModel.loadChat(chat.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.chat, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(chat.updatedAt ?? chat.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDeleteChat(context, chat.id, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Sohbet mesajları
  Widget _buildChatMessages(AdviceViewModel viewModel) {
    return Column(
      children: [
        // Sohbet başlığı ve geri butonu
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  viewModel.clearCurrentChat();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  viewModel.currentChat?.title ?? 'İlişki Danışmanı',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // Mesaj listesi
        Expanded(
          child: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : viewModel.currentMessages.isEmpty
                  ? const Center(child: Text('Henüz mesaj bulunmuyor'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      reverse: true,
                      itemCount: viewModel.currentMessages.length,
                      itemBuilder: (context, index) {
                        // Mesajları sondan başlayarak göster
                        final message = viewModel.currentMessages[viewModel.currentMessages.length - 1 - index];
                        return _buildChatMessage(context, message);
                      },
                    ),
        ),
      ],
    );
  }
  
  // Sohbet mesajı görünümü
  Widget _buildChatMessage(BuildContext context, message) {
    final isUser = message.role == 'user';
    final bgColor = isUser 
        ? Theme.of(context).colorScheme.primary 
        : Colors.grey[200];
    final textColor = isUser ? Colors.white : Colors.black87;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: const Icon(Icons.psychology, color: Colors.purple),
            ),
          
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          if (isUser)
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              child: const Icon(Icons.person, color: Colors.blue),
            ),
        ],
      ),
    );
  }
  
  // Mesaj girişi
  Widget _buildChatInput(AdviceViewModel viewModel, String userId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatInputController,
              inputFormatters: InputService.getTurkishTextFormatters(),
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Bir mesaj yazın...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: IconButton(
              icon: viewModel.isLoading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: viewModel.isLoading
                  ? null
                  : () => _sendMessage(viewModel, userId),
            ),
          ),
        ],
      ),
    );
  }
  
  // Mesaj gönderme
  void _sendMessage(AdviceViewModel viewModel, String userId) {
    final message = _chatInputController.text.trim();
    if (message.isEmpty) return;
    
    viewModel.sendMessage(userId, message, viewModel.currentChat!.id);
    _chatInputController.clear();
  }
  
  // Yeni sohbet başlatma dialogu
  Future<void> _showNewChatDialog(BuildContext context) async {
    final textController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sohbet Başlat'),
        content: TextField(
          controller: textController,
          inputFormatters: InputService.getTurkishTextFormatters(),
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'İlişki sorunuz nedir?',
            border: OutlineInputBorder(),
          ),
          minLines: 3,
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final message = textController.text.trim();
              if (message.isNotEmpty) {
                Navigator.pop(context);
                _createNewChat(message);
              }
            },
            child: const Text('Başlat'),
          ),
        ],
      ),
    );
  }
  
  // Yeni sohbet oluşturma
  void _createNewChat(String message) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final adviceViewModel = Provider.of<AdviceViewModel>(context, listen: false);
    
    await adviceViewModel.createChat(authViewModel.currentUser!.uid, message);
  }
  
  // Sohbet silme onayı
  Future<void> _confirmDeleteChat(BuildContext context, String chatId, AdviceViewModel viewModel) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbet Silinecek'),
        content: const Text('Bu sohbeti silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              viewModel.deleteChat(chatId);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Tarih formatı
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '';
    }
    
    return DateFormat('dd MMMM yyyy', 'tr_TR').format(date);
  }
  
  // Saat formatı
  String _formatTime(DateTime timestamp) {
    return DateFormat('HH:mm', 'tr_TR').format(timestamp);
  }
} 