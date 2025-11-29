import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../theme/color.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/email_verification_service.dart';
import 'additional_information.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isVerifying = false;
  bool _isResendingCode = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;
  Timer? _expiryTimer;
  String? _errorMessage;
  int _attempts = 0;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _startExpiryTimer();
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVerificationStatus() async {
    final attempts = await EmailVerificationService.instance.getAttempts();
    final remaining = await EmailVerificationService.instance
        .getRemainingTime();

    if (mounted) {
      setState(() {
        _attempts = attempts;
        _timeRemaining = remaining;
      });
    }
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = await EmailVerificationService.instance
          .getRemainingTime();
      if (mounted) {
        setState(() {
          _timeRemaining = remaining;
        });
      }
      if (remaining == null) {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final isValid = await EmailVerificationService.instance.verifyCode(code);

      if (isValid) {
        if (mounted) {
          // Navigate to additional information screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AdditionalInformationScreen(),
            ),
          );
        }
      } else {
        final attempts = await EmailVerificationService.instance.getAttempts();
        setState(() {
          _attempts = attempts;
          _errorMessage = 'Invalid code. ${5 - attempts} attempts remaining.';
        });

        // Clear the input fields
        for (var controller in _codeControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResendingCode = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuthService.instance.sendEmailVerification();
      await _loadVerificationStatus();
      _startExpiryTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New verification code sent! Please check your inbox.',
            ),
            backgroundColor: AppColors.green700,
          ),
        );

        // Clear existing codes
        for (var controller in _codeControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();

        // Start countdown
        setState(() {
          _resendCountdown = 60;
        });

        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_resendCountdown > 0) {
            setState(() {
              _resendCountdown--;
            });
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending code: ${e.toString()}'),
            backgroundColor: AppColors.red700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendingCode = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuthService.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: AppColors.red700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService.instance.currentUser;
    final email = user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.blue50,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowMedium,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.mark_email_read_outlined,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Enter Verification Code',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instruction text
                  Text(
                    'We sent a 6-digit code to',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.grey700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 6-digit code input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 50,
                        child: TextField(
                          controller: _codeControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.grey300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.grey300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }

                            // Auto-verify when all fields are filled
                            if (index == 5 && value.isNotEmpty) {
                              final code = _codeControllers
                                  .map((c) => c.text)
                                  .join();
                              if (code.length == 6) {
                                _verifyCode();
                              }
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.red300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.red700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: AppColors.red700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 24),

                  // Timer and attempts info
                  if (_timeRemaining != null || _attempts > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_timeRemaining != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 18,
                                  color: AppColors.orange700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Code expires in ${_timeRemaining!.inMinutes}:${(_timeRemaining!.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: AppColors.grey700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          if (_attempts > 0) ...[
                            if (_timeRemaining != null)
                              const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.blue700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Attempts: $_attempts/5',
                                  style: TextStyle(
                                    color: AppColors.grey700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_timeRemaining != null || _attempts > 0)
                    const SizedBox(height: 24),

                  // Verify button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Verify Code',
                              style: TextStyle(
                                color: AppColors.buttonText,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resend code button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isResendingCode || _resendCountdown > 0
                          ? null
                          : _resendVerificationEmail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.grey300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: AppColors.white,
                      ),
                      child: _isResendingCode
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : Text(
                              _resendCountdown > 0
                                  ? 'Resend Code ($_resendCountdown s)'
                                  : 'Resend Code',
                              style: TextStyle(
                                color: _resendCountdown > 0
                                    ? AppColors.grey600
                                    : AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign out link
                  TextButton(
                    onPressed: _signOut,
                    child: Text(
                      'Use a different account',
                      style: TextStyle(color: AppColors.grey600, fontSize: 16),
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
