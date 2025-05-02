import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
import 'views/settings_view.dart';
import 'views/conversation_summary_view.dart';
import 'views/message_coach_view.dart';
import 'utils/utils.dart';
import 'utils/loading_indicator.dart';
import 'widgets/custom_password_field.dart';

// Profil Kurulum Sayfası
class ProfileSetupView extends StatefulWidget {
  final bool isGoogleOrAppleLogin;
  
  const ProfileSetupView({
    super.key,
    this.isGoogleOrAppleLogin = true,
  });

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  
  String _selectedGender = 'Belirtmek istemiyorum';
  DateTime? _selectedDate;
  final _formKey = GlobalKey<FormState>();
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }
  
  // Doğum tarihi seçiciyi göster
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9D3FFF),
              onPrimary: Colors.white,
              surface: Color(0xFF352269),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF352269),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profil Bilgilerinizi Tamamlayın',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
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
                  const Text(
                    'Size daha iyi hizmet verebilmemiz için lütfen bilgilerinizi tamamlayın.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Ad alanı
                  TextFormField(
                    controller: _firstNameController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: InputDecoration(
                      labelText: 'Ad',
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
                        return 'Lütfen adınızı girin';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Soyad alanı
                  TextFormField(
                    controller: _lastNameController,
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    decoration: InputDecoration(
                      labelText: 'Soyad',
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
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen soyadınızı girin';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Cinsiyet seçimi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Cinsiyet',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: const Color(0xFF352269),
                            isExpanded: true,
                            value: _selectedGender,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            items: ['Erkek', 'Kadın', 'Belirtmek istemiyorum']
                                .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Doğum tarihi
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _birthDateController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Doğum Tarihi',
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
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen doğum tarihinizi seçin';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Tamamla butonu
                  ElevatedButton(
                    onPressed: authViewModel.isLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              final firstName = _firstNameController.text.trim();
                              final lastName = _lastNameController.text.trim();
                              final gender = _selectedGender;
                              
                              // Google/Apple girişi için doğum tarihi kontrolü
                              if (widget.isGoogleOrAppleLogin && _selectedDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Lütfen doğum tarihinizi seçin')),
                                );
                                return;
                              }
                              
                              // Profil bilgilerini güncelle
                              authViewModel.updateUserProfile(
                                firstName: firstName,
                                lastName: lastName,
                                gender: gender,
                                birthDate: _selectedDate,
                              ).then((success) {
                                if (success) {
                                  // Başarılı güncelleme sonrası ana sayfaya yönlendir
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Profiliniz güncellendi! Ana sayfaya yönlendiriliyorsunuz.')),
                                  );
                                  context.go(AppRouter.home);
                                } else {
                                  // Hata durumunda kullanıcıya bilgi ver
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(authViewModel.errorMessage ?? 'Profil güncellenirken bir hata oluştu')),
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
                            ),
                          )
                        : const Text(
                            'Profili Tamamla',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
      resizeToAvoidBottomInset: true, // Klavye açıldığında içeriğin yukarı kaymasını sağlar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Giriş Yap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20), // Üst boşluğu azalt
                
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
                
                const SizedBox(height: 60), // Spacer yerine sabit boşluk
                
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
                              // Başarılı giriş, ana sayfaya yönlendir
                              context.go(AppRouter.home);
                            } else if (!success && context.mounted) {
                              // Kullanıcı ilk kez giriş yaptıysa profil sayfasına yönlendir
                              // isFirstLogin true ancak giriş yapıldı, profil eksik demektir
                              if (authViewModel.isLoggedIn) {
                                context.go(AppRouter.profileSetup, extra: true);
                              }
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.black87,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.g_mobiledata, size: 24),
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
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
      resizeToAvoidBottomInset: true, // Klavye açıldığında içeriğin yukarı kaymasını sağlar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Kayıt Ol',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20), // Spacer yerine sabit boşluk
                
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
                
                const SizedBox(height: 60), // Spacer yerine sabit boşluk
                
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.black87,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata,
                                color: Colors.black87,
                                size: 24,
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
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
              ],
            ),
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
  
  // Şifre alanı için FocusNode
  final FocusNode _passwordFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      resizeToAvoidBottomInset: true,
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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24.0, 
              right: 24.0, 
              top: 24.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // E-posta alanı
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      style: const TextStyle(color: Colors.white),
                      autofillHints: [AutofillHints.email],
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
                    
                    // Şifre alanı - Özel widget'a dönüştürüyoruz (Giriş ekranı)
                    CustomPasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      labelText: 'Şifre',
                      textInputAction: TextInputAction.done,
                      errorText: _validatePassword(_passwordController.text),
                      onChanged: (_) {
                        setState(() {});
                      },
                      onEditingComplete: () {
                        // Klavyeyi kapat ve giriş yap
                        FocusScope.of(context).unfocus();
                        _submitForm(authViewModel, context);
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
                        : () => _submitForm(authViewModel, context),
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.black87,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata,
                                color: Colors.black87,
                                size: 24,
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
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
        ),
      ),
    );
  }
  
  // Şifre doğrulama fonksiyonu
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifrenizi girin';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    return null;
  }
  
  // Form gönderim işlemi için yardımcı metod
  void _submitForm(AuthViewModel authViewModel, BuildContext context) {
    // Şifre kontrollerini manuel olarak yap
    final passwordError = _validatePassword(_passwordController.text);
    
    if (_formKey.currentState!.validate() && passwordError == null) {
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
    } else {
      setState(() {
        // Hataları göstermek için formu yenile
      });
    }
  }
}

class EmailRegisterView extends StatefulWidget {
  const EmailRegisterView({super.key});

  @override
  State<EmailRegisterView> createState() => _EmailRegisterViewState();
}

class _EmailRegisterViewState extends State<EmailRegisterView> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  String _selectedGender = 'Belirtmek istemiyorum';
  DateTime? _selectedDate;
  final _formKey = GlobalKey<FormState>();
  
  // Şifre alanları için FocusNode'lar
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthDateController.dispose();
    
    // FocusNode'ları temizleme
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    
    super.dispose();
  }
  
  // Doğum tarihi seçiciyi göster
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF9D3FFF),
              onPrimary: Colors.white,
              surface: Color(0xFF352269),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF352269),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121929),
      resizeToAvoidBottomInset: true,
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
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24.0, 
              right: 24.0, 
              top: 24.0,
              // Klavye açıkken alttan daha fazla padding ekle
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
            ),
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ad alanı
                    TextFormField(
                      controller: _firstNameController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        labelText: 'Ad',
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
                          return 'Lütfen adınızı girin';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Soyad alanı
                    TextFormField(
                      controller: _lastNameController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        labelText: 'Soyad',
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
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Lütfen soyadınızı girin';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // E-posta alanı
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      keyboardType: TextInputType.emailAddress,
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
                    
                    // Cinsiyet seçimi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white38),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Cinsiyet',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: const Color(0xFF352269),
                              isExpanded: true,
                              value: _selectedGender,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                              items: ['Erkek', 'Kadın', 'Belirtmek istemiyorum']
                                  .map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedGender = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Doğum tarihi
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _birthDateController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Doğum Tarihi',
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
                            prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
                            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen doğum tarihinizi seçin';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Şifre alanı - Özel widget'a dönüştürüyoruz (Kayıt ekranı)
                    CustomPasswordField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      labelText: 'Şifre',
                      textInputAction: TextInputAction.next,
                      errorText: _validatePassword(_passwordController.text),
                      onChanged: (_) {
                        setState(() {});
                      },
                      onEditingComplete: () {
                        // Şifre tekrar alanına geç
                        FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Şifre Tekrar alanı - Tamamen özel widget ile değiştiriyoruz
                    CustomPasswordField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocusNode,
                      labelText: 'Şifre Tekrar',
                      textInputAction: TextInputAction.done, 
                      errorText: _validateConfirmPassword(_confirmPasswordController.text),
                      onChanged: (_) {
                        setState(() {});
                      },
                      onEditingComplete: () {
                        // Klavyeyi kapat
                        FocusScope.of(context).unfocus();
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Kayıt Ol butonu
                    ElevatedButton(
                      onPressed: authViewModel.isLoading
                        ? null
                        : () => _submitForm(authViewModel, context),
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
                            child: YuklemeAnimasyonu(
                              boyut: 24.0,
                              renk: Colors.white,
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
      ),
    );
  }
  
  // Şifre doğrulama fonksiyonu
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifrenizi girin';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    return null;
  }
  
  // Şifre tekrar doğrulama fonksiyonu
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifrenizi tekrar girin';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    if (value != _passwordController.text) {
      return 'Şifreler eşleşmiyor';
    }
    return null;
  }
  
  // Form gönderim işlemi için yardımcı metod
  void _submitForm(AuthViewModel authViewModel, BuildContext context) {
    // Şifre kontrollerini manuel olarak yap
    final passwordError = _validatePassword(_passwordController.text);
    final confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
    
    if (_formKey.currentState!.validate() && passwordError == null && confirmPasswordError == null) {
      // E-posta ve şifre ile kayıt işlemi
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final displayName = '$firstName $lastName';
      
      // Doğum tarihi kontrolü
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen doğum tarihinizi seçin')),
        );
        return;
      }
      
      authViewModel.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        gender: _selectedGender,
        birthDate: _selectedDate,
      ).then((success) {
        if (success) {
          // Başarılı kayıt sonrası e-posta giriş sayfasına yönlendir
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt başarılı! Giriş yapabilirsiniz.')),
          );
          context.go(AppRouter.email_login);
        } else {
          // Hata durumunda kullanıcıya bilgi ver
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authViewModel.errorMessage ?? 'Kayıt sırasında bir hata oluştu')),
          );
        }
      });
    } else {
      setState(() {
        // Hataları göstermek için formu yenile
      });
    }
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
  static const String profileSetup = '/profile-setup'; // Profil kurulum sayfası
  // Yeni route sabitleri
  static const String accountSettings = '/account-settings';
  static const String notificationSettings = '/notification-settings';
  static const String privacySettings = '/privacy-settings';
  static const String helpSupport = '/help-support';
  static const String settings = '/settings';
  // Geçmiş analizler ve raporlar için route sabitleri
  static const String pastAnalyses = '/past-analyses';
  static const String pastReports = '/past-reports';
  static const String analysisDetail = '/analysis-detail';
  static const String reportDetail = '/report-detail';
  static const String consultation = '/consultation';
  // Konuşma özeti rotası
  static const String konusmaSummary = '/konusma-summary';

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
          path: settings,
          name: 'settings',
          builder: (context, state) => const SettingsView(),
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
        
        // Konuşma özeti sayfası
        GoRoute(
          path: konusmaSummary,
          name: 'konusmaSummary',
          builder: (context, state) {
            final summaryData = state.extra as List<Map<String, String>>? ?? [];
            return KonusmaSummaryView(summaryData: summaryData);
          },
        ),
        // Mesaj Koçu sayfası
        GoRoute(
          path: '/message-coach',
          name: 'message-coach',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const MessageCoachView(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        
        // Profil kurulum sayfası
        GoRoute(
          path: profileSetup,
          name: 'profileSetup',
          builder: (context, state) {
            final isGoogleOrAppleLogin = state.extra as bool? ?? true;
            return ProfileSetupView(isGoogleOrAppleLogin: isGoogleOrAppleLogin);
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