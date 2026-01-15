import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.6),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Header(),
                SizedBox(height: 48),
                _GoogleSignInButton(),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------- HEADER (CONST = FAST) ----------
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Icon(
          Icons.casino,
          size: 96,
          color: Colors.deepPurple,
        ),
        SizedBox(height: 24),
        Text(
          'Spin & Earn',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Spin the wheel and earn rewards',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// ---------- BUTTON (ONLY THIS REBUILDS) ----------
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        return SizedBox(
          width: double.infinity,
          height: 52,
            child: ElevatedButton(
            onPressed: auth.isLoading
                ? null
                : () async {
              final success = await auth.signInWithGoogle();
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in failed. Try again.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              elevation: 2,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Image(
                        image: AssetImage('assets/images/google_logo.png'),
                        height: 22,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
