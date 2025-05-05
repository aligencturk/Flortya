import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../utils/utils.dart';
import '../utils/loading_indicator.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onSuccess;
  final bool isWide;

  const GoogleSignInButton({
    super.key,
    this.onSuccess,
    this.isWide = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authViewModel = Provider.of<AuthViewModel>(context);

    return ElevatedButton(
      onPressed: authViewModel.isLoading
          ? null
          : () => _handleGoogleSignIn(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: authViewModel.isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: YuklemeAnimasyonu(
                boyut: 24.0,
                renk: colorScheme.primary,
              ),
            )
          : Row(
              mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Image.asset(
                    'assets/icons/pngwing.com.png',
                    height: 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Google ile Giriş Yap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      final success = await authViewModel.signInWithGoogle();

      if (success && onSuccess != null) {
        onSuccess!();
      } else if (!success) {
        Utils.showErrorFeedback(context, 'Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
      }
    } catch (e) {
      Utils.showErrorFeedback(
        context, 
        'Google ile giriş yapılırken bir hata oluştu: $e',
      );
    }
  }
}

class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onSuccess;
  final bool isWide;

  const AppleSignInButton({
    super.key,
    this.onSuccess,
    this.isWide = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authViewModel = Provider.of<AuthViewModel>(context);

    return ElevatedButton(
      onPressed: authViewModel.isLoading
          ? null
          : () => _handleAppleSignIn(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: authViewModel.isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: YuklemeAnimasyonu(
                boyut: 24.0,
                renk: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, size: 24),
                SizedBox(width: 12),
                Text(
                  'Apple ile Giriş Yap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleAppleSignIn(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    final success = await authViewModel.signInWithApple();

    if (success && onSuccess != null) {
      onSuccess!();
    }
  }
} 