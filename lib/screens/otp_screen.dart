import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  late String _currentVerificationId;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.verifyOTP(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );

      if (user != null && mounted) {
        // Handle successful login
        await context.read<UserProvider>().handleLogin(user);
        
        if (mounted) {
             // Navigate to Home and remove all previous routes
             Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
             );
        }
      } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid OTP. Please try again.')),
            );
         }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Invalid OTP';
        if (e.code == 'invalid-verification-code') {
            msg = 'The code you entered is incorrect.';
        } else if (e.code == 'session-expired') {
            msg = 'The code has expired. Please resend.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onVerificationCompleted: (credential) async {
            // Auto-retrieval (Android)
             final user = await FirebaseAuth.instance.signInWithCredential(credential);
             if (mounted && user.user != null) {
                  await context.read<UserProvider>().handleLogin(user.user!);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
             }
        },
        onVerificationFailed: (e) {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Resend Failed: ${e.message}')),
                );
             }
        },
        onCodeSent: (verificationId, forceResendingToken) {
             if (mounted) {
                 setState(() {
                     _currentVerificationId = verificationId;
                     _startTimer();
                 });
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('OTP Resent Successfully')),
                 );
             }
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
             _currentVerificationId = verificationId;
        },
      );
    } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error resending OTP: $e')),
            );
        }
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(fontSize: 20, color: Color.fromRGBO(30, 60, 87, 1), fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: Color.fromRGBO(243, 246, 249, 0),
        border: Border(bottom: BorderSide(color: Color.fromRGBO(30, 60, 87, 1), width: 2.0)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify OTP"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
         width: double.infinity,
         height: double.infinity,
         padding: const EdgeInsets.all(24),
         decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffE3F2FD), Color(0xffBBDEFB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
         ),
         child: SafeArea(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               const SizedBox(height: 20),
               Image.asset('assets/images/app_logo.png', height: 80, width: 80), // Or OTP icon
               const SizedBox(height: 30),
               const Text(
                 "Verification Code",
                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 10),
               Text(
                 "Enter the 6-digit code sent to\n${widget.phoneNumber}",
                 textAlign: TextAlign.center,
                 style: const TextStyle(fontSize: 16, color: Colors.black54),
               ),
               const SizedBox(height: 40),
               
               Pinput(
                 length: 6,
                 controller: _otpController,
                 defaultPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueAccent),
                    ),
                 ),
                 focusedPinTheme: defaultPinTheme.copyWith(
                     decoration: defaultPinTheme.decoration!.copyWith(
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.blue, width: 2),
                     ),
                 ),
                 onCompleted: (pin) => _verifyOtp(pin),
               ),
               
               const SizedBox(height: 40),
               
               if (_isLoading)
                 const CircularProgressIndicator()
               else
                 Column(
                   children: [
                      ElevatedButton(
                        onPressed: () => _verifyOtp(_otpController.text),
                        style: ElevatedButton.styleFrom(
                           minimumSize: const Size(double.infinity, 50),
                           backgroundColor: Colors.blue,
                           foregroundColor: Colors.white,
                        ),
                        child: const Text("Verify"),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                         onPressed: _secondsRemaining == 0 ? _resendOtp : null,
                         child: Text(
                             _secondsRemaining > 0 
                               ? "Resend OTP in $_secondsRemaining sec"
                               : "Resend OTP",
                             style: TextStyle(
                                color: _secondsRemaining == 0 ? Colors.blue : Colors.grey,
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
    );
  }
}
