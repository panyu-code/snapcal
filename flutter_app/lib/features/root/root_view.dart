import 'package:flutter/material.dart';

import '../../core/theme.dart' show AppColors;
import '../history/history_view.dart';
import '../profile/profile_view.dart';
import '../today/today_view.dart';
import '../trends/trends_view.dart';
import '../recognize/recognize_flow.dart';

/// 主框架: 4 Tab + 中央拍照按钮 (对齐 iOS MainTabView)
class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[TodayView(), HistoryView(), TrendsView(), ProfileView()];
    return Scaffold(
      // 按当前 Tab 懒显示: 切到记录页时重新加载最新餐次, 也降低四页常驻内存
      body: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      floatingActionButton: FloatingActionButton(
        key: const Key('camera-fab'),
        backgroundColor: AppColors.brandGreenDark,
        shape: const CircleBorder(),
        child: const Icon(Icons.photo_camera_outlined, color: Colors.white),
        onPressed: () => openRecognizeFlow(context),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '今日'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '记录'),
          NavigationDestination(icon: Icon(Icons.trending_up_outlined), selectedIcon: Icon(Icons.trending_up), label: '趋势'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
