import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'phone_input_page.dart';
import 'email_input_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6600),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
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
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    children: [
                      TextSpan(text: 'Food'),
                      TextSpan(text: 'yah', style: TextStyle(color: Colors.yellow)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Delicious Food, Delivered Fast",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text("Welcome Back!",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                const Text("Sign in to continue your culinary journey",
                    style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),

                // Phone Login
                LoginButton(
                  icon: Icons.phone,
                  label: "Continue with Phone",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PhoneInputPage()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Email Login
                LoginButton(
                  icon: Icons.email,
                  label: "Continue with Email",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmailInputPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Forgot your password?",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: Colors.white),
                  ),
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
      onPressed: onPressed,
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
    );
  }
}
