import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:your_app/viewmodels/auth_viewmodel.dart';
import 'package:your_app/viewmodels/message_viewmodel.dart';
import 'package:your_app/models/message.dart';

class MessageScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  // ... (existing code)
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Form içeriğini temizle
    _messageController.clear();
    
    final messageViewModel = Provider.of<MessageViewModel>(context, listen: false);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Önce kullanıcı kimliğini kontrol et
    String? userId = authViewModel.currentUser?.uid;
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj göndermek için giriş yapmalısınız')),
      );
      return;
    }
    
    // Mesajı direkt olarak viewmodel üzerinden ekle ve analiz et
    await messageViewModel.addMessage(text, userId);
  }

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }
} 