import 'package:flutter/material.dart';

void main() {
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
          surface: const Color(0xFF121212),
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFF03DAC6),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        fontFamily: 'Roboto',
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

class _HomeScreenState extends State<HomeScreen> {
  final List<String> categories = [
    '🔥 All',
    '🎓 University',
    '🍔 Food',
    '⚽ Sports',
    '🛍️ Shopping',
    '💻 Tech',
    '✈️ Travel',
    '💰 Finance',
  ];

  int selectedCategoryIndex = 0;

  // Dummy tips for now
  final List<Map<String, String>> tips = [
    {
      'category': 'Shopping',
      'title': 'Apple Student Discount',
      'description':
          'Students get 20% discount at official Apple stores. Just show your student ID!',
    },
    {
      'category': 'University',
      'title': 'Free Microsoft Office',
      'description':
          'Most universities give you free Microsoft Office 365 with your student email.',
    },
    {
      'category': 'Food',
      'title': 'Free Birthday Meals',
      'description':
          'Many restaurants in Turkey offer free meals on your birthday. Just show your ID!',
    },
    {
      'category': 'Tech',
      'title': 'GitHub Student Pack',
      'description':
          'Get free domains, cloud credits, and premium tools with GitHub Student Developer Pack.',
    },
    {
      'category': 'Travel',
      'title': 'Museum Card Turkey',
      'description':
          'The Müzekart gives you access to 300+ museums and ruins across Turkey for a yearly fee.',
    },
  ];

  List<Map<String, String>> get filteredTips {
    if (selectedCategoryIndex == 0) return tips; // "All"
    final selectedCategory = categories[selectedCategoryIndex]
        .substring(2)
        .trim(); // Remove emoji
    return tips.where((tip) => tip['category'] == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tips',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Category Tabs
          Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedCategoryIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategoryIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFF3A3A3A),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Tips Feed
          Expanded(
            child: filteredTips.isEmpty
                ? Center(
                    child: Text(
                      'No tips in this category yet',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredTips.length,
                    itemBuilder: (context, index) {
                      final tip = filteredTips[index];
                      return _buildTipCard(tip);
                    },
                  ),
          ),
        ],
      ),

      // FAB + button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Will add submit screen later
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submit screen coming soon!')),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildTipCard(Map<String, String> tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              // Anonymous avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF6C63FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anonymous',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    tip['category'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tip['category'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
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
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            tip['description'] ?? '',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}