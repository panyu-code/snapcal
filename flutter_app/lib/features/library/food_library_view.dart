import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/food_emoji.dart';
import '../../core/models.dart';
import '../../core/theme.dart' show AppColors;
import '../search/food_search_sheet.dart' show HighlightedText;

/// 食物库：分类筛选、即时搜索和分页营养数据列表。
class FoodLibraryView extends StatefulWidget {
  const FoodLibraryView({super.key});

  @override
  State<FoodLibraryView> createState() => _FoodLibraryViewState();
}

class _FoodLibraryViewState extends State<FoodLibraryView> {
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<String> _categories = const [];
  List<Food> _foods = const [];
  String? _selectedCategory;
  int _page = 1;
  int _total = 0;
  int _requestGeneration = 0;
  bool _loading = false;
  bool _loadingCategories = false;
  String? _error;

  bool get _hasMore => _foods.length < _total;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadCategories(), _resetAndLoad()]);
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await ApiClient.instance.get<List<String>>(
        '/food/categories',
        fromJson: (data) => (data as List)
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toList(),
      );
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // 分类失败不阻塞全部食物列表。
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), _resetAndLoad);
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 240 && _hasMore && !_loading) {
      _loadMore();
    }
  }

  Future<void> _selectCategory(String? category) async {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    await _resetAndLoad();
  }

  Future<void> _resetAndLoad() async {
    final generation = ++_requestGeneration;
    if (mounted) {
      setState(() {
        _page = 1;
        _foods = const [];
        _total = 0;
        _error = null;
      });
    }
    await _loadPage(1, generation);
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    await _loadPage(_page + 1, _requestGeneration);
  }

  Future<void> _loadPage(int requestedPage, int generation) async {
    final keyword = _searchController.text.trim();
    final category = _selectedCategory;
    setState(() => _loading = true);
    try {
      final result = await ApiClient.instance.foodList(
        page: requestedPage,
        size: _pageSize,
        kw: keyword.isEmpty ? null : keyword,
        category: category,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          keyword != _searchController.text.trim() ||
          category != _selectedCategory) {
        return;
      }
      setState(() {
        _page = requestedPage;
        _foods = requestedPage == 1
            ? result.records
            : [..._foods, ...result.records];
        _total = result.total;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('食物库')),
      body: Column(
        children: [
          _buildSearchField(keyword),
          _buildCategories(),
          Expanded(child: _buildBody(keyword)),
        ],
      ),
    );
  }

  Widget _buildSearchField(String keyword) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        key: const Key('food-library-search-field'),
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _debounce?.cancel();
          _resetAndLoad();
        },
        decoration: InputDecoration(
          hintText: '搜索食物',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _loading && _foods.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : keyword.isNotEmpty
              ? IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.cancel, size: 19),
                  onPressed: _searchController.clear,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        children: [
          _categoryChip('全部', null),
          for (final category in _categories) _categoryChip(category, category),
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.brandGreen,
        labelStyle: TextStyle(
          color: selected ? Colors.black87 : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        onSelected: (_) => _selectCategory(value),
      ),
    );
  }

  Widget _buildBody(String keyword) {
    if (_loading && _foods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _foods.isEmpty) {
      return _StatusView(
        icon: Icons.cloud_off_outlined,
        title: '加载失败',
        subtitle: _error!,
        actionLabel: '重试',
        onAction: _resetAndLoad,
      );
    }
    if (_foods.isEmpty) {
      return _StatusView(
        icon: keyword.isEmpty
            ? Icons.restaurant_menu_outlined
            : Icons.search_off_outlined,
        title: keyword.isEmpty ? '暂无食物' : '没有找到相关食物',
        subtitle: keyword.isEmpty ? '当前分类还没有食物' : '换个关键词试试',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        key: const Key('food-library-list'),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _foods.length + (_hasMore || _loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _foods.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : TextButton(
                        onPressed: _loadMore,
                        child: Text('加载更多 (${_foods.length}/$_total)'),
                      ),
              ),
            );
          }
          return _FoodRow(food: _foods[index], keyword: keyword);
        },
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.keyword});

  final Food food;
  final String keyword;

  String _grams(double? value) {
    final number = value ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                food.emoji ?? FoodEmoji.forFood(food.name),
                style: const TextStyle(fontSize: 21),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    food.name,
                    keyword: keyword,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '蛋白 ${_grams(food.proteinPer100g)}g · '
                    '碳水 ${_grams(food.carbsPer100g)}g · '
                    '脂肪 ${_grams(food.fatPer100g)}g',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.kcalPer100g ?? 0}',
                  style: const TextStyle(
                    color: AppColors.brandGreenDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'kcal/100g',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).hintColor,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
