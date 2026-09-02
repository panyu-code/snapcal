import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_model.dart';

/// 首次启动引导页: 3 页滑动 (对齐 iOS OnboardingView)
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    ('📸', '拍一下', '拍下餐盘照片，AI 自动识别菜品与份量'),
    ('🔥', '吃明白', '秒出卡路里与三大营养素，记录无需手动查表'),
    ('📊', '看得见', '圆环、趋势、体重曲线，坚持记录看见变化'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _pages.length,
              itemBuilder: (context, i) {
                final (emoji, title, desc) = _pages[i];
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(emoji, style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 24),
                    Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(desc, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _pages.length; i++)
              Container(
                width: 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? const Color(0xFF34D399) : Colors.grey.withAlpha(80)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              key: const Key('onboarding-next'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: const Color(0xFF34D399), foregroundColor: Colors.black),
              onPressed: () {
                if (_page < _pages.length - 1) {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else {
                  context.read<AppModel>().completeOnboarding();
                }
              },
              child: Text(_page < _pages.length - 1 ? '下一步' : '开始使用'),
            ),
          ),
        ]),
      ),
    );
  }
}
