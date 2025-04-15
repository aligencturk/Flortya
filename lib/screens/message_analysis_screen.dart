import 'package:flutter/material.dart';

// Boş ekran - gerçek uygulamada bu daha detaylı olmalı
class MessageAnalysisScreen extends StatelessWidget {
  const MessageAnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesaj Analizi'),
      ),
      body: const Center(
        child: Text('Mesaj Analiz Ekranı'),
      ),
    );
  }
} 