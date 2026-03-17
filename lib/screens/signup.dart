import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_scaffold.dart';
import '../widgets/custom_textfield.dart';
import '../constants.dart';
import 'loginpage.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_emailController.text.isEmpty ||
        _mobileController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _mobileController.text.trim(),
      context,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully! Welcome."),
            backgroundColor: Colors.green,
          ),
        );
        // Pop the SignupPage to reveal the HomeScreen (managed by AuthGate)
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              // Header
              Image.asset('assets/logo.png', height: 80),
              const SizedBox(height: 10),
              const Text(
                'Join SafeTrack',
                style: TextStyle(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: kTextColor,
                ),
              ),
              const Text(
                'Create your secure account',
                style: TextStyle(fontSize: 14.0, color: kHintColor),
              ),
              const SizedBox(height: 40.0),

              // Form
              Column(
                children: [
                  CustomTextField(
                    hint: "Email",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                  ),
                  const SizedBox(height: 20.0),
                  CustomTextField(
                    hint: "Mobile Number",
                    icon: Icons.phone_iphone_outlined,
                    controller: _mobileController,
                  ),
                  const SizedBox(height: 20.0),
                  CustomTextField(
                    hint: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                  ),
                  const SizedBox(height: 20.0),
                  CustomTextField(
                    hint: "Confirm Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    controller: _confirmPasswordController,
                  ),
                  const SizedBox(height: 20.0),

                  // Terms Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                        side: const BorderSide(color: kHintColor),
                        activeColor: kPrimaryColor,
                        checkColor: kBackgroundColor,
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms of Service & Privacy Policy',
                          style: TextStyle(color: kHintColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30.0),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SIGN UP',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30.0),

                  // Login Link
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      }
                    },
                    child: RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: kHintColor),
                          ),
                          TextSpan(
                            text: 'Log In',
                            style: TextStyle(
                              color: kPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
