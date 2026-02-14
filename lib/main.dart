import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
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
        colorScheme: ColorScheme.light(
          surface: const Color(0xFFF6F6F6),
          primary: const Color(0xFF1A1A2E),
          secondary: const Color(0xFF6C63FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F6),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const HomeScreen(),
    );
  }
}

// ─── Auth Service ───────────────────────────────────────────
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

// ─── Home Screen ────────────────────────────────────────────
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
  bool _sortByUpvotes = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference tipsCollection =
      FirebaseFirestore.instance.collection('tips');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A2E),
                          letterSpacing: -1,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover life hacks',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return GestureDetector(
                        onTap: () => _showProfileMenu(user),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: user?.photoURL != null
                              ? CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(user!.photoURL!),
                                  backgroundColor: const Color(0xFFEEEEEE),
                                )
                              : CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: const Color(0xFFBDBDBD),
                                    size: 22,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search tips...',
                    hintStyle: TextStyle(
                      color: const Color(0xFFBDBDBD),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: const Color(0xFFBDBDBD),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: const Color(0xFFBDBDBD),
                              size: 18,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // Category Tabs
            SizedBox(
              height: 40,
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
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1A1A2E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      const Color(0xFF1A1A2E).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcons[categories[index]],
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFBDBDBD),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF757575),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              fontSize: 13,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            // Sort toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  _buildSortChip('Newest', !_sortByUpvotes, () {
                    setState(() => _sortByUpvotes = false);
                  }),
                  const SizedBox(width: 8),
                  _buildSortChip('Top', _sortByUpvotes, () {
                    setState(() => _sortByUpvotes = true);
                  }),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Tips Feed from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildTipsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF1A1A2E),
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(color: const Color(0xFF9E9E9E)),
                      ),
                    );
                  }

                  final allTips = snapshot.data?.docs ?? [];

                  final tips = _searchQuery.isEmpty
                      ? allTips
                      : allTips.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title =
                              (data['title'] ?? '').toString().toLowerCase();
                          final desc = (data['description'] ?? '')
                              .toString()
                              .toLowerCase();
                          final author = (data['authorName'] ?? '')
                              .toString()
                              .toLowerCase();
                          return title.contains(_searchQuery) ||
                              desc.contains(_searchQuery) ||
                              author.contains(_searchQuery);
                        }).toList();

                  if (tips.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: const Color(0xFFE0E0E0),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tips found',
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (tips.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: tips.length,
                    itemBuilder: (context, index) {
                      final tip =
                          tips[index].data() as Map<String, dynamic>;
                      final docId = tips[index].id;
                      return _buildTipCard(tip, index, docId);
                    },
                  );
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
            if (!AuthService.isSignedIn) {
              final user = await _showSignInPrompt();
              if (user == null) return;
            }

            if (!mounted) return;

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
              final user = AuthService.currentUser;
              await tipsCollection.add({
                ...newTip,
                'authorName': user?.displayName ?? 'Anonymous',
                'authorEmail': user?.email ?? '',
                'authorPhoto': user?.photoURL ?? '',
                'authorId': user?.uid ?? '',
                'upvotes': 0,
                'upvotedBy': [],
                'commentCount': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1A2E).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─── Sign-in prompt ───────────────────────────────────────
  Future<User?> _showSignInPrompt() async {
    User? user;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign in to post',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with your Google account to\nshare tips with the community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF9E9E9E),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () async {
                  user = await AuthService.signInWithGoogle();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 18,
                        height: 18,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.g_mobiledata_rounded,
                                color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Not now',
                      style: TextStyle(
                        color: const Color(0xFF9E9E9E),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    return user;
  }

  // ─── Profile menu ─────────────────────────────────────────
  void _showProfileMenu(User? user) {
    if (user == null) {
      _showSignInPrompt().then((_) => setState(() {}));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              CircleAvatar(
                radius: 36,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                backgroundColor: const Color(0xFF1A1A2E),
                child: user.photoURL == null
                    ? Text(
                        (user.displayName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName ?? 'User',
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email ?? '',
                style: TextStyle(
                  color: const Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () async {
                  await AuthService.signOut();
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: const Color(0xFFBDBDBD),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tips yet',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first to share a life hack!\nTap + to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF9E9E9E),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip, int index, String docId) {
    final authorName = tip['authorName'] ?? 'Anonymous';
    final authorPhoto = tip['authorPhoto'] ?? '';
    final upvotes = tip['upvotes'] ?? 0;
    final List<dynamic> upvotedBy = tip['upvotedBy'] ?? [];
    final currentUserId = AuthService.currentUser?.uid;
    final hasUpvoted =
        currentUserId != null && upvotedBy.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                authorPhoto.isNotEmpty
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(authorPhoto),
                        backgroundColor: const Color(0xFFF5F5F5),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(tip['category'] ?? '')
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcons[tip['category']] ??
                              Icons.lightbulb_rounded,
                          color: _getCategoryColor(tip['category'] ?? ''),
                          size: 18,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                          fontSize: 14,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        tip['category'] ?? '',
                        style: TextStyle(
                          color: const Color(0xFFBDBDBD),
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
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(tip['category'] ?? '')
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tip['category'] ?? '',
                    style: TextStyle(
                      color: _getCategoryColor(tip['category'] ?? ''),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            Text(
              tip['title'] ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1A1A2E),
                height: 1.3,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            // Description
            Text(
              tip['description'] ?? '',
              style: TextStyle(
                color: const Color(0xFF757575),
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 14),
            // Divider
            Container(
              height: 1,
              color: const Color(0xFFF5F5F5),
            ),
            const SizedBox(height: 10),
            // Actions
            Row(
              children: [
                // Upvote
                GestureDetector(
                  onTap: () => _handleUpvote(docId, hasUpvoted),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasUpvoted
                          ? const Color(0xFF1A1A2E).withOpacity(0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: hasUpvoted
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFFBDBDBD),
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$upvotes',
                          style: TextStyle(
                            color: hasUpvoted
                                ? const Color(0xFF1A1A2E)
                                : const Color(0xFFBDBDBD),
                            fontSize: 13,
                            fontWeight: hasUpvoted
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Comment
                GestureDetector(
                  onTap: () => _showComments(docId),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFFBDBDBD),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tip['commentCount'] ?? 0}',
                          style: TextStyle(
                            color: const Color(0xFFBDBDBD),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final title = tip['title'] ?? '';
                    final desc = tip['description'] ?? '';
                    Share.share('$title\n\n$desc\n\n— Shared from Tips App');
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Icon(
                      Icons.share_outlined,
                      color: const Color(0xFFBDBDBD),
                      size: 17,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      _showTipOptions(docId, tip['authorId'] ?? ''),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    color: const Color(0xFFBDBDBD),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _buildTipsStream() {
    final orderField = _sortByUpvotes ? 'upvotes' : 'createdAt';

    if (selectedCategoryIndex == 0) {
      return tipsCollection
          .orderBy(orderField, descending: true)
          .snapshots();
    } else {
      return tipsCollection
          .where('category',
              isEqualTo: categories[selectedCategoryIndex])
          .orderBy(orderField, descending: true)
          .snapshots();
    }
  }

  Widget _buildSortChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1A1A2E).withOpacity(0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == 'Newest'
                  ? Icons.schedule_rounded
                  : Icons.trending_up_rounded,
              size: 14,
              color: isActive
                  ? const Color(0xFF1A1A2E)
                  : const Color(0xFFBDBDBD),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpvote(String docId, bool hasUpvoted) async {
    if (!AuthService.isSignedIn) {
      final user = await _showSignInPrompt();
      if (user == null) return;
      setState(() {});
    }

    final userId = AuthService.currentUser!.uid;
    final docRef = tipsCollection.doc(docId);

    if (hasUpvoted) {
      await docRef.update({
        'upvotes': FieldValue.increment(-1),
        'upvotedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'upvotes': FieldValue.increment(1),
        'upvotedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  void _showComments(String docId) {
    final commentController = TextEditingController();
    final commentsRef = tipsCollection.doc(docId).collection('comments');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Comments',
                  style: TextStyle(
                    color: const Color(0xFF1A1A2E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(height: 1, color: const Color(0xFFF5F5F5)),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: commentsRef
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF1A1A2E),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    final comments = snapshot.data?.docs ?? [];

                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: const Color(0xFFE0E0E0),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: const Color(0xFF9E9E9E),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: const Color(0xFFBDBDBD),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment =
                            comments[index].data() as Map<String, dynamic>;
                        final photo = comment['authorPhoto'] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              photo.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(photo),
                                      backgroundColor:
                                          const Color(0xFFF5F5F5),
                                    )
                                  : CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          const Color(0xFFF5F5F5),
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        color: const Color(0xFFBDBDBD),
                                        size: 16,
                                      ),
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment['authorName'] ?? 'Anonymous',
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A2E),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      comment['text'] ?? '',
                                      style: TextStyle(
                                        color: const Color(0xFF616161),
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Input field
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 8,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                        color: const Color(0xFFF5F5F5), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: AuthService.isSignedIn
                              ? 'Add a comment...'
                              : 'Sign in to comment',
                          hintStyle: TextStyle(
                            color: const Color(0xFFBDBDBD),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          enabled: AuthService.isSignedIn,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (!AuthService.isSignedIn) {
                          Navigator.pop(context);
                          final user = await _showSignInPrompt();
                          if (user != null) {
                            setState(() {});
                            _showComments(docId);
                          }
                          return;
                        }

                        final text = commentController.text.trim();
                        if (text.isEmpty) return;

                        final user = AuthService.currentUser!;
                        commentController.clear();

                        await commentsRef.add({
                          'text': text,
                          'authorName': user.displayName ?? 'Anonymous',
                          'authorPhoto': user.photoURL ?? '',
                          'authorId': user.uid,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        await tipsCollection.doc(docId).update({
                          'commentCount': FieldValue.increment(1),
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.send_rounded,
                          color: const Color(0xFF1A1A2E),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTipOptions(String docId, String authorId) {
    final currentUserId = AuthService.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == authorId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (isOwner)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(docId);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFE53935), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Delete Tip',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isOwner)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _reportTip(docId);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag_outlined,
                            color: Color(0xFFFF8F00), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Report Tip',
                          style: TextStyle(
                            color: Color(0xFFFF8F00),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: const Color(0xFF9E9E9E),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _reportTip(String docId) async {
    if (!AuthService.isSignedIn) {
      final user = await _showSignInPrompt();
      if (user == null) return;
      setState(() {});
    }

    final userId = AuthService.currentUser!.uid;
    final reportsRef = FirebaseFirestore.instance.collection('reports');

    // Check if already reported
    final existing = await reportsRef
        .where('tipId', isEqualTo: docId)
        .where('reportedBy', isEqualTo: userId)
        .get();

    if (existing.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'You already reported this tip',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
            ),
            backgroundColor: const Color(0xFFFF8F00),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    await reportsRef.add({
      'tipId': docId,
      'reportedBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment report count on the tip
    await tipsCollection.doc(docId).update({
      'reportCount': FieldValue.increment(1),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Tip reported. We\'ll review it shortly.',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Tip?',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            'This action cannot be undone.',
            style: TextStyle(color: const Color(0xFF9E9E9E)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: const Color(0xFF9E9E9E)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await tipsCollection.doc(docId).delete();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'University':
        return const Color(0xFF6C63FF);
      case 'Food':
        return const Color(0xFFFF8A65);
      case 'Sports':
        return const Color(0xFF4CAF50);
      case 'Shopping':
        return const Color(0xFFE91E63);
      case 'Tech':
        return const Color(0xFF42A5F5);
      case 'Travel':
        return const Color(0xFF26C6DA);
      case 'Finance':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF42A5F5);
    }
  }
}

// ─── Submit Tip Screen ──────────────────────────────────────
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
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
        return const Color(0xFF6C63FF);
      case 'Food':
        return const Color(0xFFFF8A65);
      case 'Sports':
        return const Color(0xFF4CAF50);
      case 'Shopping':
        return const Color(0xFFE91E63);
      case 'Tech':
        return const Color(0xFF42A5F5);
      case 'Travel':
        return const Color(0xFF26C6DA);
      case 'Finance':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames =
        widget.categories.where((c) => c != 'All').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: const Color(0xFF9E9E9E),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        leadingWidth: 80,
        title: const Text(
          'New Tip',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: _submitTip,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
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
            Text(
              'CATEGORY',
              style: TextStyle(
                color: const Color(0xFFBDBDBD),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
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
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.4)
                            : const Color(0xFFEEEEEE),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcons[category],
                          size: 16,
                          color: isSelected
                              ? color
                              : const Color(0xFFBDBDBD),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : const Color(0xFF757575),
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
            const SizedBox(height: 30),
            Text(
              'TITLE',
              style: TextStyle(
                color: const Color(0xFFBDBDBD),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'What\'s the tip?',
                  hintStyle: TextStyle(
                    color: const Color(0xFFBDBDBD),
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF1A1A2E).withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'DESCRIPTION',
              style: TextStyle(
                color: const Color(0xFFBDBDBD),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _descriptionController,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Share the details...',
                  hintStyle: TextStyle(
                    color: const Color(0xFFBDBDBD),
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF1A1A2E).withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}