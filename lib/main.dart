import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TipsApp());
}

class TipsApp extends StatelessWidget {
  const TipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tips',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: const Color(0xFF000000),
          primary: const Color(0xFF0A84FF),
          secondary: const Color(0xFF30D158),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<String> categories = [
    'All',
    'University',
    'Food',
    'Sports',
    'Shopping',
    'Tech',
    'Travel',
    'Finance',
  ];

  final Map<String, IconData> categoryIcons = {
    'All': Icons.grid_view_rounded,
    'University': Icons.school_rounded,
    'Food': Icons.restaurant_rounded,
    'Sports': Icons.sports_soccer_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Tech': Icons.devices_rounded,
    'Travel': Icons.flight_rounded,
    'Finance': Icons.account_balance_wallet_rounded,
  };

  int selectedCategoryIndex = 0;

  // Start with empty feed
  final List<Map<String, String>> tips = [];

  List<Map<String, String>> get filteredTips {
    if (selectedCategoryIndex == 0) return tips;
    final selectedCategory = categories[selectedCategoryIndex];
    return tips.where((tip) => tip['category'] == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Discover life hacks',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  // Profile icon placeholder
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category Tabs
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedCategoryIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategoryIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcons[categories[index]],
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF8E8E93),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF8E8E93),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Divider
            Container(
              height: 0.5,
              color: const Color(0xFF1C1C1E),
            ),

            // Tips Feed
            Expanded(
              child: filteredTips.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: filteredTips.length,
                      itemBuilder: (context, index) {
                        final tip = filteredTips[index];
                        return _buildTipCard(tip, index);
                      },
                    ),
            ),
          ],
        ),
      ),

      // FAB
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () async {
            final newTip = await Navigator.push<Map<String, String>>(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    SubmitTipScreen(categories: categories),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
            if (newTip != null) {
              setState(() {
                tips.insert(0, newTip);
              });
            }
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A84FF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFF0A84FF),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tips yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a life hack!\nTap + to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF8E8E93),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(Map<String, String> tip, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getCategoryColor(tip['category'] ?? ''),
                        _getCategoryColor(tip['category'] ?? '').withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    categoryIcons[tip['category']] ?? Icons.lightbulb_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Anonymous',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tip['category'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(tip['category'] ?? '').withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tip['category'] ?? '',
                    style: TextStyle(
                      color: _getCategoryColor(tip['category'] ?? ''),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              tip['title'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              tip['description'] ?? '',
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 12),

            // Action row
            Row(
              children: [
                _buildActionButton(Icons.arrow_upward_rounded, '0'),
                const SizedBox(width: 16),
                _buildActionButton(Icons.chat_bubble_outline_rounded, '0'),
                const SizedBox(width: 16),
                _buildActionButton(Icons.bookmark_outline_rounded, ''),
                const Spacer(),
                Icon(
                  Icons.more_horiz_rounded,
                  color: const Color(0xFF48484A),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF48484A), size: 18),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF48484A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'University':
        return const Color(0xFF5856D6);
      case 'Food':
        return const Color(0xFFFF9F0A);
      case 'Sports':
        return const Color(0xFF30D158);
      case 'Shopping':
        return const Color(0xFFFF375F);
      case 'Tech':
        return const Color(0xFF0A84FF);
      case 'Travel':
        return const Color(0xFF64D2FF);
      case 'Finance':
        return const Color(0xFFFFD60A);
      default:
        return const Color(0xFF0A84FF);
    }
  }
}

class SubmitTipScreen extends StatefulWidget {
  final List<String> categories;

  const SubmitTipScreen({super.key, required this.categories});

  @override
  State<SubmitTipScreen> createState() => _SubmitTipScreenState();
}

class _SubmitTipScreenState extends State<SubmitTipScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  final Map<String, IconData> categoryIcons = {
    'University': Icons.school_rounded,
    'Food': Icons.restaurant_rounded,
    'Sports': Icons.sports_soccer_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Tech': Icons.devices_rounded,
    'Travel': Icons.flight_rounded,
    'Finance': Icons.account_balance_wallet_rounded,
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitTip() {
    if (_selectedCategory == null ||
        _titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please fill in all fields',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFFFF375F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final newTip = {
      'category': _selectedCategory!,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
    };

    Navigator.pop(context, newTip);
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'University':
        return const Color(0xFF5856D6);
      case 'Food':
        return const Color(0xFFFF9F0A);
      case 'Sports':
        return const Color(0xFF30D158);
      case 'Shopping':
        return const Color(0xFFFF375F);
      case 'Tech':
        return const Color(0xFF0A84FF);
      case 'Travel':
        return const Color(0xFF64D2FF);
      case 'Finance':
        return const Color(0xFFFFD60A);
      default:
        return const Color(0xFF0A84FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.categories
        .where((c) => c != 'All')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Center(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF0A84FF),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        leadingWidth: 80,
        title: const Text(
          'New Tip',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _submitTip,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Post',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Selector
            const Text(
              'Category',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoryNames.map((category) {
                final isSelected = _selectedCategory == category;
                final color = _getCategoryColor(category);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.2)
                          : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcons[category],
                          size: 16,
                          color: isSelected ? color : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? color : const Color(0xFF8E8E93),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Title Field
            const Text(
              'Title',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'What\'s the tip?',
                hintStyle: const TextStyle(
                  color: Color(0xFF48484A),
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0A84FF),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Description Field
            const Text(
              'Description',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Share the details...',
                hintStyle: const TextStyle(
                  color: Color(0xFF48484A),
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0A84FF),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}