import 'package:flutter/material.dart';
import 'otp_verification_page.dart'; // Ensure this file exists and class is named correctly
import '../../services/api_client.dart'; // Adjust path to your actual API helper


class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;

  Future<void> _sendOtp() async {
    final phone = phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid phone number")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiClient.post('/request-otp', {
        "phone": phone,
        "role": "restaurant"
      });
      debugPrint("response: $response");

      if (response['msg'] == "OTP sent") {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationPage(type: 'phone', value: phone),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['err'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e,stackTrace) {
      debugPrint("Error during OTP request: $e");
      debugPrint("StackTrace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error occurred")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

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
                  child: Icon(Icons.phone_android, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Enter your phone number",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    hintStyle: const TextStyle(color: Colors.white70),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.phone, color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("Send OTP"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
