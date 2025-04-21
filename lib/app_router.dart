import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'views/message_analysis_view.dart';
import 'views/report_view.dart';
import 'views/advice_view.dart';
import 'views/past_analyses_view.dart';
import 'views/past_reports_view.dart';
import 'views/analysis_detail_view.dart';
import 'views/report_detail_view.dart';
import 'views/consultation_view.dart';
import 'utils/utils.dart';

// Placeholder Widgets for new routes
class AccountSettingsView extends StatelessWidget {
  const AccountSettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Hesap Ayarları')));
  }
}

class NotificationSettingsView extends StatelessWidget {
  const NotificationSettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Bildirim Ayarları')));
  }
}

class PrivacySettingsView extends StatelessWidget {
  const PrivacySettingsView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Gizlilik ve Güvenlik')));
  }
}

class HelpSupportView extends StatelessWidget {
  const HelpSupportView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Yardım ve Destek')));
  }
}

class LoginView extends StatelessWidget {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929), // Onboarding ile aynı arka plan rengi
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Giriş Yap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Logo veya uygulama adı
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 64,
                      color: const Color(0xFF9D3FFF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FlörtAI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İlişkinize yapay zeka desteği',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Giriş seçenekleri
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aşağıdaki seçeneklerden biriyle devam edin:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Giriş Yap butonu
                  ElevatedButton(
                    onPressed: () {
                      // Email/şifre girişi sayfasına yönlendir
                      context.go(AppRouter.email_login);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Kayıt Ol butonu
                  ElevatedButton(
                    onPressed: () {
                      context.go(AppRouter.register);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Kayıt sayfasına yönlendirme
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Hesabınız yok mu?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go(AppRouter.register);
                        },
                        child: const Text(
                          'Kayıt Olun',
                          style: TextStyle(
                            color: Color(0xFF9D3FFF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Google ile giriş butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithGoogle();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.facebook, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Google ile Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple ile giriş butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithApple();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Apple ile Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Gizlilik politikası ve kullanım şartları
                  Text(
                    'Giriş yaparak, Kullanım Koşullarını ve Gizlilik Politikasını kabul etmiş olursunuz.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});
  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929), // Onboarding ile aynı arka plan rengi
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Kayıt Ol',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Logo veya uygulama adı
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 64,
                      color: const Color(0xFF9D3FFF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FlörtAI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'İlişkinize yapay zeka desteği',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Kayıt seçenekleri
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aşağıdaki seçeneklerden biriyle hesap oluşturun:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // E-posta ile kayıt butonu
                  ElevatedButton(
                    onPressed: () {
                      context.go(AppRouter.email_register);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'E-posta ile Kayıt Ol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Google ile kayıt butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithGoogle();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Google ile Kayıt Ol',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Apple ile kayıt butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () async {
                          final success = await authViewModel.signInWithApple();
                          if (success && context.mounted) {
                            context.go(AppRouter.home);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.apple, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              'Apple ile Kayıt Ol',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Giriş sayfasına yönlendirme
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Zaten bir hesabınız var mı?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go(AppRouter.login);
                        },
                        child: const Text(
                          'Giriş Yap',
                          style: TextStyle(
                            color: Color(0xFF9D3FFF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Gizlilik politikası ve kullanım şartları
                  Text(
                    'Kayıt olarak, Kullanım Koşullarını ve Gizlilik Politikasını kabul etmiş olursunuz.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailLoginView extends StatefulWidget {
  const EmailLoginView({super.key});

  @override
  State<EmailLoginView> createState() => _EmailLoginViewState();
}

class _EmailLoginViewState extends State<EmailLoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'E-posta ile Giriş',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // E-posta alanı
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.white70),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'E-posta adresinizi girin';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Geçerli bir e-posta adresi girin';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Şifre alanı
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Şifrenizi girin';
                    }
                    if (value.length < 6) {
                      return 'Şifre en az 6 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Şifremi Unuttum butonu
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Şifremi unuttum özelliği yakında eklenecek')),
                      );
                    },
                    child: const Text(
                      'Şifremi Unuttum',
                      style: TextStyle(
                        color: Color(0xFF9D3FFF),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Giriş Yap butonu
                ElevatedButton(
                  onPressed: authViewModel.isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          // E-posta ve şifre ile giriş işlemi
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          
                          authViewModel.signInWithEmail(
                            email: email,
                            password: password,
                          ).then((success) {
                            if (success) {
                              // Başarılı giriş sonrası ana sayfaya yönlendir
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Giriş başarılı! Anasayfaya yönlendiriliyorsunuz.')),
                              );
                              context.go(AppRouter.home);
                            } else {
                              // Hata durumunda kullanıcıya bilgi ver
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(authViewModel.errorMessage ?? 'Giriş sırasında bir hata oluştu')),
                              );
                            }
                          });
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9D3FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: const Color(0xFF9D3FFF).withOpacity(0.5),
                  ),
                  child: authViewModel.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
                
                const SizedBox(height: 20),
                
                // Ayırıcı çizgi ve "veya" yazısı
                Row(
                  children: const [
                    Expanded(
                      child: Divider(
                        color: Colors.white30,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'veya',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white30,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Google ile giriş butonu
                ElevatedButton(
                  onPressed: authViewModel.isLoading
                    ? null
                    : () async {
                        final success = await authViewModel.signInWithGoogle();
                        if (success && context.mounted) {
                          context.go(AppRouter.home);
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: authViewModel.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 24,
                            width: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Google ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                ),
                
                const SizedBox(height: 16),
                
                // Apple ile giriş butonu
                ElevatedButton(
                  onPressed: authViewModel.isLoading
                    ? null
                    : () async {
                        final success = await authViewModel.signInWithApple();
                        if (success && context.mounted) {
                          context.go(AppRouter.home);
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: authViewModel.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.apple, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Apple ile Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                ),
                
                const SizedBox(height: 20),
                
                // Kayıt Ol yönlendirmesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Hesabınız yok mu?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        context.go(AppRouter.register);
                      },
                      child: const Text(
                        'Kayıt Olun',
                        style: TextStyle(
                          color: Color(0xFF9D3FFF),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailRegisterView extends StatefulWidget {
  const EmailRegisterView({super.key});

  @override
  State<EmailRegisterView> createState() => _EmailRegisterViewState();
}

class _EmailRegisterViewState extends State<EmailRegisterView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'E-posta ile Kayıt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ad Soyad alanı
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ad ve soyadınızı girin';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // E-posta alanı
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.white70),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'E-posta adresinizi girin';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Geçerli bir e-posta adresi girin';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Şifre alanı
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isObscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _isObscure = !_isObscure;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Şifrenizi girin';
                      }
                      if (value.length < 6) {
                        return 'Şifre en az 6 karakter olmalıdır';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Şifre Tekrar alanı
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmObscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre Tekrar',
                      labelStyle: const TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF9D3FFF)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmObscure ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmObscure = !_isConfirmObscure;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Şifrenizi tekrar girin';
                      }
                      if (value != _passwordController.text) {
                        return 'Şifreler eşleşmiyor';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Kayıt Ol butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            // E-posta ve şifre ile kayıt işlemi
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final displayName = _nameController.text.trim();
                            
                            authViewModel.signUpWithEmail(
                              email: email,
                              password: password,
                              displayName: displayName,
                            ).then((success) {
                              if (success) {
                                // Başarılı kayıt sonrası ana sayfaya yönlendir
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kayıt başarılı! Anasayfaya yönlendiriliyorsunuz.')),
                                );
                                context.go(AppRouter.home);
                              } else {
                                // Hata durumunda kullanıcıya bilgi ver
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(authViewModel.errorMessage ?? 'Kayıt sırasında bir hata oluştu')),
                                );
                              }
                            });
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9D3FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: const Color(0xFF9D3FFF).withOpacity(0.5),
                    ),
                    child: authViewModel.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Kayıt Ol',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Giriş Yap yönlendirmesi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Zaten bir hesabınız var mı?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go(AppRouter.email_login);
                        },
                        child: const Text(
                          'Giriş Yap',
                          style: TextStyle(
                            color: Color(0xFF9D3FFF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Gizlilik politikası ve kullanım şartları
                  const Text(
                    'Kayıt olarak, Kullanım Koşullarını ve Gizlilik Politikasını kabul etmiş olursunuz.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppRouter {
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String email_login = '/email-login';
  static const String email_register = '/email-register';
  static const String home = '/home';
  static const String messageAnalysis = '/message-analysis';
  static const String report = '/report';
  static const String advice = '/advice';
  static const String profile = '/profile';
  // Yeni route sabitleri
  static const String accountSettings = '/account-settings';
  static const String notificationSettings = '/notification-settings';
  static const String privacySettings = '/privacy-settings';
  static const String helpSupport = '/help-support';
  // Geçmiş analizler ve raporlar için route sabitleri
  static const String pastAnalyses = '/past-analyses';
  static const String pastReports = '/past-reports';
  static const String analysisDetail = '/analysis-detail';
  static const String reportDetail = '/report-detail';
  static const String consultation = '/consultation';

  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: onboarding,
      debugLogDiagnostics: true,
      refreshListenable: authViewModel,
      navigatorKey: Utils.navigatorKey,
      redirect: (context, state) async {
        final bool isLoggedIn = authViewModel.isLoggedIn;
        final bool isInitialized = authViewModel.isInitialized;
        final bool isOnboardingRoute = state.uri.path == onboarding;
        final bool isLoginRoute = state.uri.path == login;
        final bool isRegisterRoute = state.uri.path == register;
        final bool isEmailLoginRoute = state.uri.path == email_login;
        final bool isEmailRegisterRoute = state.uri.path == email_register;
        
        // SharedPreferences'tan onboarding durumunu al
        final prefs = await SharedPreferences.getInstance();
        final bool hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
        
        debugPrint('------------------------------');
        debugPrint('Yönlendirme kontrolü:');
        debugPrint('isLoggedIn=$isLoggedIn');
        debugPrint('isInitialized=$isInitialized');
        debugPrint('hasCompletedOnboarding=$hasCompletedOnboarding');
        debugPrint('isOnboardingRoute=$isOnboardingRoute');
        debugPrint('isLoginRoute=$isLoginRoute');
        debugPrint('isRegisterRoute=$isRegisterRoute');
        debugPrint('isEmailLoginRoute=$isEmailLoginRoute');
        debugPrint('isEmailRegisterRoute=$isEmailRegisterRoute');
        debugPrint('path=${state.uri.path}');
        debugPrint('------------------------------');

        // Henüz initializing ise, bir redirect yapmadan bekle
        if (!isInitialized) {
          debugPrint('Henüz initialize edilmemiş, yönlendirme yok');
          return null;
        }

        // 1. Kullanıcı giriş yapmamışsa ve onboarding'i tamamlamamışsa:
        // - Onboarding sayfasına yönlendir
        if (!isLoggedIn && !hasCompletedOnboarding && !isOnboardingRoute) {
          debugPrint('Kullanıcı giriş yapmamış, onboarding tamamlanmamış');
          debugPrint('=> Onboarding sayfasına yönlendiriliyor');
          return onboarding;
        }
        
        // 2. Kullanıcı giriş yapmamışsa ancak onboarding'i tamamlamışsa:
        // - Login sayfasına yönlendir, ancak Register, Email Login ve Email Register sayfalarına izin ver
        if (!isLoggedIn && hasCompletedOnboarding && 
            !isLoginRoute && !isOnboardingRoute && 
            !isRegisterRoute && !isEmailLoginRoute && !isEmailRegisterRoute) {
          debugPrint('Kullanıcı giriş yapmamış, onboarding tamamlanmış ve izin verilen sayfalarda değil');
          debugPrint('=> Login sayfasına yönlendiriliyor');
          return login;
        }
        
        // 3. Kullanıcı giriş yapmışsa:
        // - Ana sayfaya yönlendir (home'da değilse)
        if (isLoggedIn && (isOnboardingRoute || isLoginRoute || isRegisterRoute || isEmailLoginRoute || isEmailRegisterRoute)) {
          debugPrint('Kullanıcı giriş yapmış ve giriş/kayıt sayfalarından birinde');
          debugPrint('=> Ana sayfaya yönlendiriliyor');
          return home;
        }
        
        // 4. Kullanıcı onboarding'i tamamlamışsa ve onboarding sayfasındaysa:
        // - Login sayfasına yönlendir
        if (hasCompletedOnboarding && isOnboardingRoute) {
          debugPrint('Onboarding tamamlanmış ve onboarding sayfasında');
          debugPrint('=> Login sayfasına yönlendiriliyor');
          return login;
        }
        
        // Diğer durumlar için redirect yok
        debugPrint('Herhangi bir yönlendirme koşulu sağlanmadı. Mevcut sayfada kalınıyor.');
        return null;
      },
      routes: [
        GoRoute(
          path: onboarding,
          name: 'onboarding',
          builder: (context, state) => const OnboardingView(),
        ),
        // Ana tabbar sayfası
        GoRoute(
          path: home,
          name: 'home',
          builder: (context, state) => const HomeView(),
        ),
        // Mesaj Analizi sayfası - Detay sayfası
        GoRoute(
          path: messageAnalysis,
          name: 'messageAnalysis',
          builder: (context, state) => const MessageAnalysisView(),
        ),
        // İlişki Raporu sayfası - Detay sayfası
        GoRoute(
          path: report,
          name: 'report',
          builder: (context, state) => const ReportView(),
        ),
        // Tavsiye Kartı sayfası - Detay sayfası
        GoRoute(
          path: advice,
          name: 'advice',
          builder: (context, state) => const AdviceView(),
        ),
        // Profil sayfası - Artık doğrudan HomeView'e yönlendirme yapılıyor  
        GoRoute(
          path: profile,
          name: 'profile',
          builder: (context, state) => const HomeView(initialTabIndex: 3),
        ),
        // Yeni route tanımlamaları
        GoRoute(
          path: accountSettings,
          name: 'accountSettings',
          builder: (context, state) => const AccountSettingsView(),
        ),
        GoRoute(
          path: notificationSettings,
          name: 'notificationSettings',
          builder: (context, state) => const NotificationSettingsView(),
        ),
        GoRoute(
          path: privacySettings,
          name: 'privacySettings',
          builder: (context, state) => const PrivacySettingsView(),
        ),
        GoRoute(
          path: helpSupport,
          name: 'helpSupport',
          builder: (context, state) => const HelpSupportView(),
        ),
        GoRoute(
          path: login,
          name: 'login',
          builder: (context, state) => const LoginView(),
        ),
        
        GoRoute(
          path: register,
          name: 'register',
          builder: (context, state) => const RegisterView(),
        ),
        
        GoRoute(
          path: email_login,
          name: 'email_login',
          builder: (context, state) => const EmailLoginView(),
        ),
        
        GoRoute(
          path: email_register,
          name: 'email_register',
          builder: (context, state) => const EmailRegisterView(),
        ),
        
        // Danışma sayfası rotası
        GoRoute(
          path: consultation,
          name: 'consultation',
          builder: (context, state) => const ConsultationView(),
        ),
        
        // Geçmiş analizler ve raporlar için route'lar
        GoRoute(
          path: pastAnalyses,
          name: 'pastAnalyses',
          builder: (context, state) => const PastAnalysesView(),
        ),
        GoRoute(
          path: pastReports,
          name: 'pastReports',
          builder: (context, state) => const PastReportsView(),
        ),
        GoRoute(
          path: '$analysisDetail/:id',
          name: 'analysisDetail',
          builder: (context, state) {
            final analysisId = state.pathParameters['id'] ?? '';
            return AnalysisDetailView(analysisId: analysisId);
          },
        ),
        GoRoute(
          path: '$reportDetail/:id',
          name: 'reportDetail',
          builder: (context, state) {
            final reportId = state.pathParameters['id'] ?? '';
            return ReportDetailView(reportId: reportId);
          },
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Sayfa Bulunamadı',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Aradığınız sayfa (${state.uri.path}) mevcut değil.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(home), 
                child: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 