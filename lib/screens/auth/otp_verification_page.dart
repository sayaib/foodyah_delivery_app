import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_client.dart'; // Your API client

class OTPVerificationPage extends StatefulWidget {
  final String type; // 'phone' or 'email'
  final String value;

  const OTPVerificationPage({super.key, required this.type, required this.value});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController otpController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool isLoading = false;
  String errorMessage = '';

  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      setState(() => errorMessage = "Please enter a 6-digit OTP.");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ApiClient.post("/verify-otp", {
        widget.type: widget.value,
        "otp": otp,
      });

      debugPrint("response: $response");

      if (response['token'] != null && response['user'] != null) {
        // Save token securely
        await _secureStorage.write(key: 'jwt_token', value: response['token']);

        // Optionally save user info
        await _secureStorage.write(key: 'user_id', value: response['user']['id']);
        await _secureStorage.write(key: 'user_name', value: response['user']['name']);
        await _secureStorage.write(key: 'user_role', value: response['user']['role']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.type.toUpperCase()} verified successfully!')),
        );

        // TODO: Navigate to dashboard or home page
        Navigator.pushReplacementNamed(context, '/dashboard');

      } else {
        setState(() => errorMessage = response['message'] ?? 'Invalid OTP.');
      }
    } catch (e) {
      debugPrint("error verify: $e");
      setState(() => errorMessage = "Verification failed: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'phone' ? 'Phone Number' : 'Email';

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
                  child: Icon(Icons.lock, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  "Verify $label",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "OTP has been sent to ${widget.value}",
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter 6-digit OTP',
                    hintStyle: const TextStyle(color: Colors.white70),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _verifyOtp,
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
                      : const Text("Submit OTP"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
