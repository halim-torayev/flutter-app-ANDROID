import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

// ─── Auth Service ───────────────────────────────────────────
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static bool get isSignedIn => _auth.currentUser != null;

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

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

  final CollectionReference tipsCollection =
      FirebaseFirestore.instance.collection('tips');

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
                  // Profile icon — shows user avatar or sign-in button
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return GestureDetector(
                        onTap: () => _showProfileMenu(user),
                        child: user?.photoURL != null
                            ? CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    NetworkImage(user!.photoURL!),
                                backgroundColor: const Color(0xFF1C1C1E),
                              )
                            : Container(
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
                      );
                    },
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

            Container(
              height: 0.5,
              color: const Color(0xFF1C1C1E),
            ),

            // Tips Feed from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: selectedCategoryIndex == 0
                    ? tipsCollection
                        .orderBy('createdAt', descending: true)
                        .snapshots()
                    : tipsCollection
                        .where('category',
                            isEqualTo: categories[selectedCategoryIndex])
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0A84FF),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    );
                  }

                  final tips = snapshot.data?.docs ?? [];

                  if (tips.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
            // Require sign-in to post
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
                'createdAt': FieldValue.serverTimestamp(),
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
            child:
                const Icon(Icons.add_rounded, color: Colors.white, size: 30),
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
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A84FF), Color(0xFF5856D6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign in to post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with your Google account to\nshare tips with the community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () async {
                  user = await AuthService.signInWithGoogle();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.g_mobiledata_rounded,
                                color: Colors.black87, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
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
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Not now',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 16,
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
      // Not signed in — show sign in prompt
      _showSignInPrompt().then((_) => setState(() {}));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 36,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                backgroundColor: const Color(0xFF0A84FF),
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
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.email ?? '',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
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
                    color: const Color(0xFFFF375F).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFFF375F),
                        fontSize: 16,
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
          const Text(
            'Be the first to share a life hack!\nTap + to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
              height: 1.4,
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
    final hasUpvoted = currentUserId != null && upvotedBy.contains(currentUserId);

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
            Row(
              children: [
                authorPhoto.isNotEmpty
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(authorPhoto),
                        backgroundColor: const Color(0xFF2C2C2E),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getCategoryColor(tip['category'] ?? ''),
                              _getCategoryColor(tip['category'] ?? '')
                                  .withOpacity(0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcons[tip['category']] ??
                              Icons.lightbulb_rounded,
                          color: Colors.white,
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
                    color: _getCategoryColor(tip['category'] ?? '')
                        .withOpacity(0.15),
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
            Row(
              children: [
                // Upvote button
                GestureDetector(
                  onTap: () => _handleUpvote(docId, hasUpvoted),
                  child: Row(
                    children: [
                      Icon(
                        hasUpvoted
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_upward_rounded,
                        color: hasUpvoted
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF48484A),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$upvotes',
                        style: TextStyle(
                          color: hasUpvoted
                              ? const Color(0xFF0A84FF)
                              : const Color(0xFF48484A),
                          fontSize: 12,
                          fontWeight: hasUpvoted
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildActionButton(Icons.chat_bubble_outline_rounded, '0'),
                const SizedBox(width: 16),
                _buildActionButton(Icons.bookmark_outline_rounded, ''),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showTipOptions(docId, tip['authorId'] ?? ''),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF48484A),
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

  Future<void> _handleUpvote(String docId, bool hasUpvoted) async {
    if (!AuthService.isSignedIn) {
      final user = await _showSignInPrompt();
      if (user == null) return;
      setState(() {});
    }

    final userId = AuthService.currentUser!.uid;
    final docRef = tipsCollection.doc(docId);

    if (hasUpvoted) {
      // Remove upvote
      await docRef.update({
        'upvotes': FieldValue.increment(-1),
        'upvotedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      // Add upvote
      await docRef.update({
        'upvotes': FieldValue.increment(1),
        'upvotedBy': FieldValue.arrayUnion([userId]),
      });
    }
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
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
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
                      color: const Color(0xFFFF375F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFFF375F), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Delete Tip',
                          style: TextStyle(
                            color: Color(0xFFFF375F),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'No actions available',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 15,
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
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 16,
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

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Tip?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'This action cannot be undone.',
            style: TextStyle(color: Color(0xFF8E8E93)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8E8E93)),
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
                  color: Color(0xFFFF375F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
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
    final categoryNames =
        widget.categories.where((c) => c != 'All').toList();

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
                          color:
                              isSelected ? color : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : const Color(0xFF8E8E93),
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