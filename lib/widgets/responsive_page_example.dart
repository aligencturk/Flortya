import 'package:flutter/material.dart';
import 'responsive_scaffold.dart';

/// Bu dosya, [ResponsiveScaffold] ve [ResponsiveContentArea] widget'larının
/// nasıl kullanılacağını gösteren bir örnek sayfa içerir.
class ResponsivePageExample extends StatefulWidget {
  const ResponsivePageExample({super.key});

  @override
  State<ResponsivePageExample> createState() => _ResponsivePageExampleState();
}

class _ResponsivePageExampleState extends State<ResponsivePageExample> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Responsive Page Example',
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.settings),
        ),
      ],
      scrollController: _scrollController,
      resizeToAvoidBottomInset: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter Text',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'ResponsiveScaffold prevents "Bottom overflowed by XX pixels" errors.',
              style: TextStyle(fontSize: 16),
            ),
          ),
          // Örnek içerik - uzun liste
          Expanded(
            child: ListView.builder(
              itemCount: 20,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Dış ScrollView'ın kaydırma işlemini üstlenmesi için
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('List Item $index'),
                  subtitle: Text('This item remains visible when keyboard is open'),
                  trailing: const Icon(Icons.arrow_forward),
                );
              },
            ),
          ),
        ],
      ),
      bottomBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {},
      ),
    );
  }
}

/// Form içeren duyarlı sayfa örneği
class ResponsiveFormPageExample extends StatefulWidget {
  const ResponsiveFormPageExample({super.key});

  @override
  State<ResponsiveFormPageExample> createState() => _ResponsiveFormPageExampleState();
}

class _ResponsiveFormPageExampleState extends State<ResponsiveFormPageExample> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'Form Example',
      contentPadding: EdgeInsets.zero, // ResponsiveFormArea will set its own padding
      content: ResponsiveFormArea(
        formKey: _formKey,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  // Form is valid, proceed with submission
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Submitting form...')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
} 