import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';


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
    await messageViewModel.addMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final messageViewModel = Provider.of<MessageViewModel>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messageViewModel.messages.length,
              itemBuilder: (context, index) {
                final message = messageViewModel.messages[index];
                return ListTile(
                  title: Text(message.content),
                );
              },
            ),
          ),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Mesaj yazın...',
            ),
          ),
          ElevatedButton(
            onPressed: _handleSendMessage,
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
    // ... (existing code)
  }
