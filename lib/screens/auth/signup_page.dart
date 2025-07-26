import 'package:flutter/material.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6600),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    children: [
                      TextSpan(text: 'Food'),
                      TextSpan(text: 'ya', style: TextStyle(color: Colors.yellow)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Create Account",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                const Text("Join and enjoy delicious meals instantly",
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),

                // Phone Signup
                LoginButton(
                  icon: Icons.phone,
                  label: "Sign up with Phone",
                  onPressed: () {
                    // Navigate to phone signup OTP
                  },
                ),
                const SizedBox(height: 16),

                // Email Signup
                LoginButton(
                  icon: Icons.email,
                  label: "Sign up with Email",
                  onPressed: () {
                    // Navigate to email signup OTP
                  },
                ),

                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Already have an account? Log in",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const LoginButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.white.withOpacity(0.15),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
