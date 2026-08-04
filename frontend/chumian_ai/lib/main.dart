import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChumianAiApp());
}

class ChumianAiApp extends StatelessWidget {
  const ChumianAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '初眠AI',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
