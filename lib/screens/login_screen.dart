import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentPage = 0;
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Start auto-scrolling for the PageView
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < 2) {
        // Cycle through slides (0,1,2)
        _currentPage++;
      } else {
        _currentPage = 0; // Reset to the first page
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final User? user = await _authService.signInWithGoogle();

      if (user != null) {
        // Navigate to home screen or main app
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() {
          _error = 'Sign in was cancelled or failed. Please try again.';
        });
      }
    } catch (error) {
      print("Login failed: $error");
      setState(() {
        _error = 'Login failed. Please check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSliderImage(String imagePath) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    double deviceH = MediaQuery.of(context).size.height;
    const double sliderH = 500;
    const double pullup = -50;

    return Scaffold(
      body: Stack(
        children: [
          // Top slider
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: sliderH,
            child: PageView(
              controller: _pageController,
              children: [
                _buildSliderImage('assets/login_slider/slider1.jpg'),
                _buildSliderImage('assets/login_slider/slider2.jpg'),
                _buildSliderImage('assets/login_slider/slider3.jpg'),
              ],
            ),
          ),
          // Bottom container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: deviceH - sliderH - pullup,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xff080808),
                borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
              ),
              child: Stack(
                children: [
                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Welcome logo/brand (placeholder)
                            Container(
                              height: 100,
                              width: 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Text(
                                  'RUMI TALK',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            _isLoading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xff4285F4)),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _loginWithGoogle(context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                        horizontal: 30,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 3,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Google logo SVG
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: SvgPicture.string(
                                            '''<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" xmlns:xlink="http://www.w3.org/1999/xlink" style="display: block;">
        <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"></path>
        <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"></path>
        <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"></path>
        <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"></path>
        <path fill="none" d="M0 0h48v48H0z"></path>
      </svg>''',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Continue with Google',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.3,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            if (_error != null) ...[
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
