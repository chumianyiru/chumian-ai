import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'oobe_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await ApiClient().init();

    final matches = await AuthService().verifyClientMatches();
    if (!mounted) return;
    if (!matches) {
      Fluttertoast.showToast(msg: '你使用的不是官方版');
    }

    final token = ApiClient().token;
    if (token == null || token.isEmpty) {
      _goTo(const LoginScreen());
      return;
    }

    try {
      await AuthService().verifyClient();
      final user = await AuthService().fetchMe();
      if (!mounted) return;
      if (user.oobeCompleted) {
        _goTo(const HomeScreen());
      } else {
        _goTo(const OobeScreen());
      }
    } catch (e) {
      if (!mounted) return;
      _goTo(const LoginScreen());
    }
  }

  void _goTo(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: appBackgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: AppColors.onPrimary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                kAppName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
