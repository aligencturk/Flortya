import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../widgets/custom_button.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditingProfile = false;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Kullanıcı profilini yükleme
  Future<void> _loadUserProfile() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      await profileViewModel.getUserProfile(authViewModel.user!.id);
      
      if (profileViewModel.userProfile != null) {
        _nameController.text = profileViewModel.userProfile!['name'] ?? '';
      }
    }
  }

  // Profil düzenleme modunu açma/kapama
  void _toggleEditMode() {
    setState(() {
      _isEditingProfile = !_isEditingProfile;
      
      if (!_isEditingProfile) {
        // Düzenleme modundan çıkarken orijinal değerleri geri yükle
        final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
        if (profileViewModel.userProfile != null) {
          _nameController.text = profileViewModel.userProfile!['name'] ?? '';
        }
      }
    });
  }

  // Profil güncelleme
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final profileViewModel = Provider.of<ProfileViewModel>(context, listen: false);
    
    if (authViewModel.user != null) {
      final success = await profileViewModel.updateUserProfile(
        authViewModel.user!.id,
        _nameController.text.trim(),
        '', // bio parametresi için boş değer
        '', // relationshipStatus için boş değer
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi')),
        );
        setState(() {
          _isEditingProfile = false;
        });
      }
    }
  }

  // Çıkış yapma
  Future<void> _logout() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Onay iletişim kutusu göster
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await authViewModel.signOut();
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  // Premium abonelik satın alma
  Future<void> _upgradeToPremium() async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    
    // Burada normalde ödeme işlemi başlatılır
    // Şimdilik sadece premium durumunu simüle edelim
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Abonelik'),
        content: const Text(
          'Premium abonelik satın almak istediğinizden emin misiniz?\n\n'
          'Aylık Ücret: ₺49.99',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Normalde gerçek ödeme işlemi yapılır
      final success = await authViewModel.upgradeToPremium();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium abonelik başarıyla aktifleştirildi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final profileViewModel = Provider.of<ProfileViewModel>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isEditingProfile)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _toggleEditMode,
              tooltip: 'Profili Düzenle',
            ),
        ],
      ),
      body: profileViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profil resmi ve kullanıcı bilgileri
                  _buildProfileHeader(context, authViewModel, profileViewModel),
                  
                  const SizedBox(height: 32),
                  
                  // Profil düzenleme veya profil bilgileri
                  _isEditingProfile
                      ? _buildProfileEditForm(context)
                      : _buildProfileInfo(context, profileViewModel),
                  
                  const SizedBox(height: 32),
                  
                  // Premium abonelik durumu
                  _buildPremiumStatus(context, authViewModel),
                  
                  const SizedBox(height: 32),
                  
                  // Çıkış yap butonu
                  CustomButton(
                    text: 'Çıkış Yap',
                    onPressed: _logout,
                    icon: Icons.logout,
                    isFullWidth: true,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
    );
  }

  // Profil başlık alanı
  Widget _buildProfileHeader(
    BuildContext context,
    AuthViewModel authViewModel,
    ProfileViewModel profileViewModel,
  ) {
    final user = authViewModel.user;
    final profile = profileViewModel.userProfile;
    
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            profile != null && profile['name'] != null && profile['name'].isNotEmpty
                ? profile['name'][0].toUpperCase()
                : (user?.email != null ? user!.email[0].toUpperCase() : '?'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile != null && profile['name'] != null && profile['name'].isNotEmpty
                    ? profile['name']
                    : 'İsimsiz Kullanıcı',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (authViewModel.isPremium) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 16,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Premium Üye',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    )
    .animate()
    .fadeIn(duration: 400.ms)
    .slideX(begin: -0.1, end: 0, duration: 400.ms);
  }

  // Profil düzenleme formu
  Widget _buildProfileEditForm(BuildContext context) {
    final profileViewModel = Provider.of<ProfileViewModel>(context);
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profil Bilgilerinizi Düzenleyin',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // İsim alanı
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'İsim',
              hintText: 'İsminizi girin',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Lütfen isminizi girin';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 24),
          
          // Butonlar
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'İptal',
                  onPressed: _toggleEditMode,
                  isOutlined: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomButton(
                  text: 'Kaydet',
                  onPressed: _updateProfile,
                  isLoading: profileViewModel.isUpdating,
                ),
              ),
            ],
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  // Profil bilgileri
  Widget _buildProfileInfo(BuildContext context, ProfileViewModel profileViewModel) {
    final profile = profileViewModel.userProfile;
    
    if (profile == null) {
      return const Center(
        child: Text('Profil bilgileri yüklenemedi.'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Profil Bilgileri',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Profil bilgileri listesi
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.person,
                  title: 'İsim',
                  value: profile['name'] ?? 'Belirtilmemiş',
                ),
                
                const Divider(height: 32),
                
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today,
                  title: 'Üyelik Tarihi',
                  value: profile['joinDate'] != null
                      ? _formatDate(DateTime.parse(profile['joinDate']))
                      : 'Belirtilmemiş',
                ),
                
                if (profile['messagesAnalyzed'] != null) ...[
                  const Divider(height: 32),
                  
                  _buildInfoItem(
                    context,
                    icon: Icons.message,
                    title: 'Analiz Edilen Mesaj Sayısı',
                    value: profile['messagesAnalyzed'].toString(),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms),
      ],
    );
  }

  // Premium abonelik durumu
  Widget _buildPremiumStatus(BuildContext context, AuthViewModel authViewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: authViewModel.isPremium
              ? [Colors.amber.shade300, Colors.amber.shade700]
              : [Colors.blue.shade700, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                authViewModel.isPremium ? Icons.workspace_premium : Icons.star,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                authViewModel.isPremium ? 'Premium Üyelik' : 'Standart Üyelik',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            authViewModel.isPremium
                ? 'Premium üyeliğiniz sayesinde sınırsız mesaj analizi ve günlük yeni tavsiyeler alabilirsiniz.'
                : 'Premium üyelikle daha fazla analiz ve günlük yeni tavsiyeler alabilirsiniz.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (!authViewModel.isPremium)
            CustomButton(
              text: 'Premium\'a Yükselt',
              onPressed: _upgradeToPremium,
              color: Colors.indigo.shade800,
              isFullWidth: true,
            ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms)
    .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  // Bilgi öğesi
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tarih formatı
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
} 