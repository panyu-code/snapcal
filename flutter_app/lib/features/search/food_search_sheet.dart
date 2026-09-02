import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/food_emoji.dart';
import '../../core/models.dart';
import '../../core/theme.dart' show AppColors;

/// 关键词高亮富文本 (命中部分品牌绿, 对齐 iOS Text.highlighted)
class HighlightedText extends StatelessWidget {
  final String text;
  final String keyword;
  final TextStyle? style;

  const HighlightedText(this.text, {super.key, required this.keyword, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    if (keyword.isEmpty || !text.toLowerCase().contains(keyword.toLowerCase())) {
      return Text(text, style: base);
    }
    final spans = <TextSpan>[];
    final lower = text.toLowerCase(), kwLower = keyword.toLowerCase();
    var start = 0;
    while (true) {
      final hit = lower.indexOf(kwLower, start);
      if (hit < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (hit > start) spans.add(TextSpan(text: text.substring(start, hit)));
      spans.add(TextSpan(text: text.substring(hit, hit + kwLower.length), style: base.copyWith(color: AppColors.brandGreen)));
      start = hit + kwLower.length;
    }
    return RichText(text: TextSpan(style: base, children: spans));
  }
}

/// 食物搜索弹窗: 即时搜索 + 高亮 + 收藏 + 连续添加 (对齐 iOS FoodSearchSheet)
class FoodSearchSheet extends StatefulWidget {
  final ValueChanged<Food> onSelect;
  final bool stayOpen;

  const FoodSearchSheet({super.key, required this.onSelect, this.stayOpen = false});

  @override
  State<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends State<FoodSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Food> _results = [];
  Set<int> _favoredIds = {};
  bool _loading = false;
  late Future<List<Food>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _favoritesFuture = _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<List<Food>> _loadFavorites() async {
    try {
      final favs = await ApiClient.instance.favorites();
      if (mounted) setState(() => _favoredIds = favs.map((f) => f.id).toSet());
      return favs;
    } catch (_) {
      return [];
    }
  }

  void _onChanged() {
    _debounce?.cancel();
    if (_controller.text.isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final kw = _controller.text;
    if (kw.isEmpty) return;
    setState(() => _loading = true);
    try {
      final fresh = await ApiClient.instance.searchFood(kw);
      if (kw == _controller.text && mounted) setState(() { _results = fresh; _loading = false; });
    } catch (_) {
      if (kw == _controller.text && mounted) setState(() { _results = []; _loading = false; });
    }
  }

  Future<void> _toggleFavorite(Food food) async {
    final was = _favoredIds.contains(food.id);
    setState(() => was ? _favoredIds.remove(food.id) : _favoredIds.add(food.id));
    try {
      final favored = await ApiClient.instance.toggleFavorite(food.id);
      if (mounted) setState(() => favored ? _favoredIds.add(food.id) : _favoredIds.remove(food.id));
    } catch (_) {
      if (mounted) setState(() => was ? _favoredIds.add(food.id) : _favoredIds.remove(food.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kw = _controller.text;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stayOpen ? '添加食物' : '替换食物'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('food-search-field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '搜索食物名称',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                  : (kw.isNotEmpty ? IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () => _controller.clear()) : null),
            ),
          ),
        ),
        Expanded(child: _buildBody(context, kw)),
      ]),
    );
  }

  Widget _buildBody(BuildContext context, String kw) {
    if (kw.isEmpty) {
      return FutureBuilder<List<Food>>(
        future: _favoritesFuture,
        builder: (context, snap) {
          final favs = snap.data ?? const <Food>[];
          return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            if (favs.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: Text('⭐ 我的收藏', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              for (final f in favs) _foodRow(context, f, ''),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('输入食物名称, 实时匹配，如「鸡胸肉」「米饭」', style: TextStyle(fontSize: 12))),
            ),
          ]);
        },
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 8),
        Text('没有找到相关食物', style: Theme.of(context).textTheme.titleMedium),
        Text('换个关键词试试', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ]));
    }
    return ListView.builder(
      key: const Key('food-search-results'),
      itemCount: _results.length,
      itemBuilder: (context, i) => _foodRow(context, _results[i], kw),
    );
  }

  Widget _foodRow(BuildContext context, Food food, String kw) {
    final favored = _favoredIds.contains(food.id);
    return InkWell(
      key: Key('food-row-${food.id}'),
      onTap: () {
        widget.onSelect(food);
        if (!widget.stayOpen) Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Text(food.emoji ?? FoodEmoji.forFood(food.name), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HighlightedText(food.name, keyword: kw, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text('${food.kcalPer100g ?? 0} kcal / 100g · 蛋白 ${food.proteinPer100g ?? 0}g · 碳水 ${food.carbsPer100g ?? 0}g · 脂肪 ${food.fatPer100g ?? 0}g',
                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
          ])),
          IconButton(
            key: Key('fav-${food.id}'),
            icon: Icon(favored ? Icons.star : Icons.star_border, color: favored ? Colors.orange : Colors.grey),
            onPressed: () => _toggleFavorite(food),
          ),
        ]),
      ),
    );
  }
}

Future<void> showFoodSearchSheet(BuildContext context, {required ValueChanged<Food> onSelect, bool stayOpen = false}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => FoodSearchSheet(onSelect: onSelect, stayOpen: stayOpen),
  ));
}
