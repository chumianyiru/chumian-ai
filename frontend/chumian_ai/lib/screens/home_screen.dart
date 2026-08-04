import 'package:flutter/material.dart';

import '../widgets/custom_nav_bar.dart';
import '../widgets/gradient_scaffold.dart';
import 'chat_screen.dart';
import 'creative_screen.dart';
import 'explore_screen.dart';
import 'play_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    ChatScreen(),
    CreativeScreen(),
    PlayScreen(),
    ExploreScreen(),
    ProfileScreen(),
  ];

  final List<NavItem> _items = [
    NavItem(icon: Icons.chat_bubble_outline, label: '对话'),
    NavItem(icon: Icons.auto_awesome, label: '创意'),
    NavItem(icon: Icons.videogame_asset_outlined, label: '玩乐'),
    NavItem(icon: Icons.explore_outlined, label: '探索'),
    NavItem(icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: CustomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _items,
      ),
    );
  }
}
