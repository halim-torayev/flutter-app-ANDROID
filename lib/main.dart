import 'package:flutter/cupertino.dart';
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
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
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
          secondary: const Color(0xFF5E5CE6),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        useMaterial3: true,
        fontFamily: '.SF Pro Text',
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

// ─── Nickname Service ───────────────────────────────────────
class NicknameService {
  static final _nicknames = FirebaseFirestore.instance.collection('nicknames');
  static String? _cachedNickname;

  static String? get cachedNickname => _cachedNickname;

  /// Check if a nickname is available (case-insensitive)
  static Future<bool> isAvailable(String nickname) async {
    final query = await _nicknames
        .where('nicknameLower', isEqualTo: nickname.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  /// Get the nickname for a user
  static Future<String?> getNickname(String uid) async {
    final query = await _nicknames
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final nick = query.docs.first['nickname'] as String;
      _cachedNickname = nick;
      return nick;
    }
    return null;
  }

  /// Save a nickname for a user and update all existing posts/comments
  static Future<bool> setNickname(String uid, String nickname) async {
    // Double-check availability
    final available = await isAvailable(nickname);
    if (!available) return false;

    // Remove existing nickname if any
    final existing = await _nicknames
        .where('uid', isEqualTo: uid)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    await _nicknames.add({
      'uid': uid,
      'nickname': nickname,
      'nicknameLower': nickname.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _cachedNickname = nickname;

    // Update all existing tips by this user
    final tips = await FirebaseFirestore.instance
        .collection('tips')
        .where('authorId', isEqualTo: uid)
        .get();
    for (final doc in tips.docs) {
      await doc.reference.update({'authorName': nickname});
    }

    // Update all existing comments by this user
    for (final tipDoc in (await FirebaseFirestore.instance.collection('tips').get()).docs) {
      final comments = await tipDoc.reference
          .collection('comments')
          .where('authorId', isEqualTo: uid)
          .get();
      for (final commentDoc in comments.docs) {
        await commentDoc.reference.update({'authorName': nickname});
      }
    }

    return true;
  }

  /// Check if user has a nickname
  static Future<bool> hasNickname(String uid) async {
    final nick = await getNickname(uid);
    return nick != null;
  }

  /// Validate nickname format (Instagram-style)
  static String? validate(String nickname) {
    if (nickname.isEmpty) return null;
    if (nickname.length < 3) return 'At least 3 characters';
    if (nickname.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(nickname)) {
      if (RegExp(r'^[0-9]').hasMatch(nickname)) {
        return 'Must start with a letter';
      }
      if (nickname != nickname.toLowerCase()) {
        return 'Lowercase only';
      }
      return 'Letters, numbers & underscores only';
    }
    return null; // valid
  }

  static void clearCache() {
    _cachedNickname = null;
  }
}

// ─── Home Screen ────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _nickname;
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
    'All': CupertinoIcons.square_grid_2x2,
    'University': CupertinoIcons.book,
    'Food': CupertinoIcons.cart,
    'Sports': CupertinoIcons.sportscourt,
    'Shopping': CupertinoIcons.bag,
    'Tech': CupertinoIcons.device_laptop,
    'Travel': CupertinoIcons.airplane,
    'Finance': CupertinoIcons.money_dollar_circle,
  };

  int selectedCategoryIndex = 0;
  bool _sortByUpvotes = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final CollectionReference tipsCollection =
      FirebaseFirestore.instance.collection('tips');

  // Cached stream to avoid recreating on every build
  Stream<QuerySnapshot>? _cachedStream;
  int _lastCategoryIndex = 0;
  bool _lastSortByUpvotes = false;

  @override
  void initState() {
    super.initState();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final user = AuthService.currentUser;
    if (user != null) {
      final nick = await NicknameService.getNickname(user.uid);
      if (mounted) setState(() => _nickname = nick);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tips',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                      letterSpacing: 0.4,
                    ),
                  ),
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
                                backgroundColor: const Color(0xFF38383A),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1C1C1E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_fill,
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

            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                placeholder: 'Search tips',
                backgroundColor: const Color(0xFF1C1C1E),
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 17,
                ),
                placeholderStyle: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 17,
                ),
              ),
            ),

            // Category Tabs
            SizedBox(
              height: 36,
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
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcons[categories[index]],
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF8E8E93),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFAEAEB2),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
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

            // Sort toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  _buildSortChip('Newest', !_sortByUpvotes, () {
                    setState(() => _sortByUpvotes = false);
                  }),
                  const SizedBox(width: 6),
                  _buildSortChip('Top', _sortByUpvotes, () {
                    setState(() => _sortByUpvotes = true);
                  }),
                ],
              ),
            ),

            // Tips Feed
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getCachedStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CupertinoActivityIndicator(
                        radius: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Something went wrong',
                        style: TextStyle(color: Color(0xFF8E8E93)),
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
                        children: const [
                          Icon(
                            CupertinoIcons.search,
                            color: Color(0xFF48484A),
                            size: 44,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No Results',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    cacheExtent: 500,
                    itemCount: tips.length,
                    itemBuilder: (context, index) {
                      final tip =
                          tips[index].data() as Map<String, dynamic>;
                      final docId = tips[index].id;
                      return RepaintBoundary(
                        child: _buildTipCard(tip, index, docId),
                      );
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
              CupertinoPageRoute(
                builder: (context) =>
                    SubmitTipScreen(categories: categories),
              ),
            );
            if (newTip != null) {
              final user = AuthService.currentUser;
              final nickname = _nickname ?? NicknameService.cachedNickname ?? 'Anonymous';
              await tipsCollection.add({
                ...newTip,
                'authorName': nickname,
                'authorEmail': '',
                'authorPhoto': '',
                'authorId': user?.uid ?? '',
                'upvotes': 0,
                'upvotedBy': [],
                'commentCount': 0,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            // Dismiss any keyboard/focus after returning
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 26),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─── Sign-in prompt ───────────────────────────────────────
  Future<User?> _showSignInPrompt() async {
    User? user;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  CupertinoIcons.pencil,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign In to Post',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
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
                  if (user != null) {
                    // Check if user has a nickname
                    final hasNick = await NicknameService.hasNickname(user!.uid);
                    if (!hasNick && context.mounted) {
                      Navigator.pop(context);
                      // Navigate to nickname setup
                      final nickname = await Navigator.push<String>(
                        this.context,
                        CupertinoPageRoute(
                          builder: (context) => NicknameSetupScreen(),
                        ),
                      );
                      if (nickname != null) {
                        _nickname = nickname;
                      } else {
                        user = null; // cancelled
                      }
                      return;
                    }
                    _nickname = NicknameService.cachedNickname;
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Not Now',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
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

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF48484A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 28),
              // Nickname avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF0A84FF),
                child: Text(
                  (_nickname ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Nickname (prominent)
              Text(
                '@${_nickname ?? 'no nickname'}',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              // Real name (subtle, only visible to them)
              Text(
                user.displayName ?? 'User',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email ?? '',
                style: const TextStyle(
                  color: Color(0xFF636366),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              // Edit Nickname button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  Navigator.pop(context);
                  final newNick = await Navigator.push<String>(
                    this.context,
                    CupertinoPageRoute(
                      builder: (context) => NicknameSetupScreen(
                        currentNickname: _nickname,
                      ),
                    ),
                  );
                  if (newNick != null) {
                    setState(() => _nickname = newNick);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A84FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Edit Nickname',
                      style: TextStyle(
                        color: Color(0xFF0A84FF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Sign Out button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await AuthService.signOut();
                  NicknameService.clearCache();
                  _nickname = null;
                  if (context.mounted) Navigator.pop(context);
                  setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFFF453A),
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
          ),
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            CupertinoIcons.lightbulb,
            color: Color(0xFF48484A),
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'No Tips Yet',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Be the first to share a tip!\nTap + to get started.',
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

  // ─── Tip Card ─────────────────────────────────────────────
  Widget _buildTipCard(Map<String, dynamic> tip, int index, String docId) {
    final authorName = tip['authorName'] ?? 'Anonymous';
    final authorPhoto = tip['authorPhoto'] ?? '';
    final upvotes = tip['upvotes'] ?? 0;
    final List<dynamic> upvotedBy = tip['upvotedBy'] ?? [];
    final currentUserId = AuthService.currentUser?.uid;
    final hasUpvoted =
        currentUserId != null && upvotedBy.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                authorPhoto.isNotEmpty
                    ? CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(authorPhoto),
                        backgroundColor: const Color(0xFF38383A),
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(tip['category'] ?? '')
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          categoryIcons[tip['category']] ??
                              CupertinoIcons.lightbulb,
                          color: _getCategoryColor(tip['category'] ?? ''),
                          size: 16,
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
                          color: Color(0xFFFFFFFF),
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        tip['category'] ?? '',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tip['category'] ?? '',
                    style: TextStyle(
                      color: _getCategoryColor(tip['category'] ?? ''),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w600,
                fontSize: 17,
                color: Color(0xFFFFFFFF),
                height: 1.3,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            // Description
            Text(
              tip['description'] ?? '',
              style: TextStyle(
                color: const Color(0xFFEBEBF5).withOpacity(0.6),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            // Separator
            Container(
              height: 0.5,
              color: const Color(0xFF38383A),
            ),
            const SizedBox(height: 10),
            // Action row
            Row(
              children: [
                // Upvote
                GestureDetector(
                  onTap: () => _handleUpvote(docId, hasUpvoted),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasUpvoted
                          ? const Color(0xFF0A84FF).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasUpvoted
                              ? CupertinoIcons.arrow_up_circle_fill
                              : CupertinoIcons.arrow_up_circle,
                          color: hasUpvoted
                              ? const Color(0xFF0A84FF)
                              : const Color(0xFF8E8E93),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$upvotes',
                          style: TextStyle(
                            color: hasUpvoted
                                ? const Color(0xFF0A84FF)
                                : const Color(0xFF8E8E93),
                            fontSize: 14,
                            fontWeight: hasUpvoted
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Comment
                GestureDetector(
                  onTap: () => _showComments(docId),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.bubble_left,
                          color: Color(0xFF8E8E93),
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tip['commentCount'] ?? 0}',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Share
                GestureDetector(
                  onTap: () async {
                    final title = tip['title'] ?? '';
                    final desc = tip['description'] ?? '';
                    final text = '$title\n\n$desc\n\n— Shared from Tips';
                    try {
                      await Share.share(text);
                    } catch (_) {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Copied to clipboard!',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFF0A84FF),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: const Icon(
                      CupertinoIcons.share,
                      color: Color(0xFF8E8E93),
                      size: 17,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showTipOptions(docId, tip),
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    color: Color(0xFF8E8E93),
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

  // ─── Helpers ──────────────────────────────────────────────

  Stream<QuerySnapshot> _getCachedStream() {
    if (_cachedStream == null ||
        _lastCategoryIndex != selectedCategoryIndex ||
        _lastSortByUpvotes != _sortByUpvotes) {
      _lastCategoryIndex = selectedCategoryIndex;
      _lastSortByUpvotes = _sortByUpvotes;
      _cachedStream = _buildTipsStream();
    }
    return _cachedStream!;
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
              ? const Color(0xFF0A84FF).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == 'Newest'
                  ? CupertinoIcons.clock
                  : CupertinoIcons.flame,
              size: 14,
              color: isActive
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? const Color(0xFF0A84FF)
                    : const Color(0xFF8E8E93),
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

    if (hasUpvoted) {
      await tipsCollection.doc(docId).update({
        'upvotes': FieldValue.increment(-1),
        'upvotedBy': FieldValue.arrayRemove([userId]),
      });
    } else {
      await tipsCollection.doc(docId).update({
        'upvotes': FieldValue.increment(1),
        'upvotedBy': FieldValue.arrayUnion([userId]),
      });
    }
  }

  // ─── Comments ─────────────────────────────────────────────
  void _showComments(String docId) {
    final commentController = TextEditingController();
    final focusNode = FocusNode();
    final commentsRef = tipsCollection.doc(docId).collection('comments');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => focusNode.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48484A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Comments',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Container(
                  height: 0.5,
                  color: const Color(0xFF38383A),
                ),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: commentsRef
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(
                            radius: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        );
                      }

                      final comments = snapshot.data?.docs ?? [];

                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.bubble_left,
                                color: Color(0xFF48484A),
                                size: 36,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No Comments Yet',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Be the first to comment',
                                style: TextStyle(
                                  color: Color(0xFF48484A),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment =
                              comments[index].data() as Map<String, dynamic>;
                          final photo = comment['authorPhoto'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                photo.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 14,
                                        backgroundImage: NetworkImage(photo),
                                        backgroundColor:
                                            const Color(0xFF38383A),
                                      )
                                    : CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            const Color(0xFF38383A),
                                        child: const Icon(
                                          CupertinoIcons.person_fill,
                                          color: Color(0xFF8E8E93),
                                          size: 14,
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
                                          color: Color(0xFFFFFFFF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        comment['text'] ?? '',
                                        style: TextStyle(
                                          color: const Color(0xFFEBEBF5)
                                              .withOpacity(0.6),
                                          fontSize: 15,
                                          height: 1.3,
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
                    color: const Color(0xFF1C1C1E),
                    border: Border(
                      top: BorderSide(
                          color: const Color(0xFF38383A),
                          width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: commentController,
                          focusNode: focusNode,
                          placeholder: 'Add a comment...',
                          placeholderStyle: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 15,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;

                          if (!AuthService.isSignedIn) {
                            Navigator.pop(context);
                            final user = await _showSignInPrompt();
                            if (user == null) return;
                            setState(() {});
                            _showComments(docId);
                            return;
                          }

                          // Dismiss keyboard after posting
                          focusNode.unfocus();
                          commentController.clear();
                          final user = AuthService.currentUser!;
                          final nickname = _nickname ?? NicknameService.cachedNickname ?? 'Anonymous';

                          await commentsRef.add({
                            'text': text,
                            'authorName': nickname,
                            'authorPhoto': '',
                            'authorId': user.uid,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          await tipsCollection.doc(docId).update({
                            'commentCount': FieldValue.increment(1),
                          });
                        },
                        child: const Icon(
                          CupertinoIcons.arrow_up_circle_fill,
                          color: Color(0xFF0A84FF),
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Dismiss any active keyboard and clean up
      FocusManager.instance.primaryFocus?.unfocus();
      focusNode.dispose();
      commentController.dispose();
    });
  }

  // ─── Tip Options ──────────────────────────────────────────
  void _showTipOptions(String docId, Map<String, dynamic> tip) {
    final authorId = tip['authorId'] ?? '';
    final currentUserId = AuthService.currentUser?.uid;
    final isOwner = currentUserId != null && currentUserId == authorId;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          actions: [
            if (isOwner)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(docId);
                },
                child: const Text('Delete Tip'),
              ),
            if (!isOwner)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _reportTip(docId, tip);
                },
                child: const Text(
                  'Report Tip',
                  style: TextStyle(color: Color(0xFFFF9F0A)),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _reportTip(String docId, Map<String, dynamic> tip) async {
    if (!AuthService.isSignedIn) {
      final user = await _showSignInPrompt();
      if (user == null) return;
      setState(() {});
    }

    final user = AuthService.currentUser!;
    final userId = user.uid;
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
            backgroundColor: const Color(0xFFFF9F0A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    await reportsRef.add({
      'tipId': docId,
      'tipTitle': tip['title'] ?? '',
      'tipAuthor': tip['authorName'] ?? 'Unknown',
      'tipAuthorId': tip['authorId'] ?? '',
      'reportedBy': userId,
      'reporterName': user.displayName ?? 'Anonymous',
      'reporterEmail': user.email ?? '',
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
          backgroundColor: const Color(0xFF0A84FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _confirmDelete(String docId) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Delete Tip?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                await tipsCollection.doc(docId).delete();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'University':
        return const Color(0xFF5E5CE6);
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
    'University': CupertinoIcons.book,
    'Food': CupertinoIcons.cart,
    'Sports': CupertinoIcons.sportscourt,
    'Shopping': CupertinoIcons.bag,
    'Tech': CupertinoIcons.device_laptop,
    'Travel': CupertinoIcons.airplane,
    'Finance': CupertinoIcons.money_dollar_circle,
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
          backgroundColor: const Color(0xFFFF453A),
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
        return const Color(0xFF5E5CE6);
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
        scrolledUnderElevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF0A84FF),
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        leadingWidth: 90,
        title: const Text(
          'New Tip',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF),
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _submitTip,
            child: const Text(
              'Post',
              style: TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w600,
                fontSize: 17,
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
              'CATEGORY',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
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
                          ? color.withOpacity(0.15)
                          : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color.withOpacity(0.4)
                            : const Color(0xFF38383A),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryIcons[category],
                          size: 15,
                          color: isSelected
                              ? color
                              : const Color(0xFF8E8E93),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? color
                                : const Color(0xFFAEAEB2),
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
              'TITLE',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _titleController,
              placeholder: "What's the tip?",
              placeholderStyle: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 16,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _descriptionController,
              placeholder: 'Share the details...',
              placeholderStyle: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 16,
              ),
              maxLines: 6,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nickname Setup Screen ──────────────────────────────────
class NicknameSetupScreen extends StatefulWidget {
  final String? currentNickname;

  const NicknameSetupScreen({super.key, this.currentNickname});

  @override
  State<NicknameSetupScreen> createState() => _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends State<NicknameSetupScreen> {
  final _controller = TextEditingController();
  String? _validationError;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentNickname != null) {
      _controller.text = widget.currentNickname!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability(String nickname) async {
    final formatError = NicknameService.validate(nickname);
    if (formatError != null) {
      setState(() {
        _validationError = formatError;
        _isAvailable = false;
        _isChecking = false;
      });
      return;
    }

    // Skip check if it's the current nickname
    if (nickname == widget.currentNickname) {
      setState(() {
        _validationError = null;
        _isAvailable = true;
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _validationError = null;
    });

    final available = await NicknameService.isAvailable(nickname);
    
    // Only update if this is still the current text
    if (nickname == _controller.text.trim()) {
      setState(() {
        _isChecking = false;
        _isAvailable = available;
        if (!available) {
          _validationError = 'This nickname is taken';
        }
      });
    }
  }

  Future<void> _saveNickname() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty || !_isAvailable) return;

    setState(() => _isSaving = true);

    final uid = AuthService.currentUser!.uid;
    final success = await NicknameService.setNickname(uid, nickname);

    if (success) {
      if (mounted) Navigator.pop(context, nickname);
    } else {
      setState(() {
        _isSaving = false;
        _validationError = 'This nickname was just taken';
        _isAvailable = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _controller.text.trim();
    final isValid = nickname.isNotEmpty &&
        _isAvailable &&
        !_isChecking &&
        _validationError == null;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Color(0xFF0A84FF),
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        leadingWidth: 90,
        title: Text(
          widget.currentNickname != null ? 'Edit Nickname' : 'Choose Nickname',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF),
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
        centerTitle: true,
        actions: [
          CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: (isValid && !_isSaving) ? _saveNickname : null,
            child: _isSaving
                ? const CupertinoActivityIndicator(
                    radius: 10,
                    color: Color(0xFF0A84FF),
                  )
                : Text(
                    'Done',
                    style: TextStyle(
                      color: isValid
                          ? const Color(0xFF0A84FF)
                          : const Color(0xFF48484A),
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  CupertinoIcons.at,
                  color: Color(0xFF0A84FF),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Your nickname is how others\nwill see you in the community.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'NICKNAME',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _controller,
              placeholder: 'e.g. cool_student',
              placeholderStyle: const TextStyle(
                color: Color(0xFF636366),
                fontSize: 16,
              ),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  '@',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(
                  left: 4, right: 16, top: 14, bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 16,
              ),
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              onChanged: (value) {
                final trimmed = value.trim();
                if (trimmed.isEmpty) {
                  setState(() {
                    _validationError = null;
                    _isAvailable = false;
                    _isChecking = false;
                  });
                  return;
                }
                _checkAvailability(trimmed);
              },
            ),
            const SizedBox(height: 12),
            // Status indicator
            if (nickname.isNotEmpty)
              Row(
                children: [
                  if (_isChecking)
                    const Row(
                      children: [
                        CupertinoActivityIndicator(
                            radius: 7, color: Color(0xFF8E8E93)),
                        SizedBox(width: 8),
                        Text(
                          'Checking availability...',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  else if (_validationError != null)
                    Row(
                      children: [
                        const Icon(CupertinoIcons.xmark_circle_fill,
                            color: Color(0xFFFF453A), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _validationError!,
                          style: const TextStyle(
                            color: Color(0xFFFF453A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else if (_isAvailable)
                    const Row(
                      children: [
                        Icon(CupertinoIcons.checkmark_circle_fill,
                            color: Color(0xFF30D158), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Available!',
                          style: TextStyle(
                            color: Color(0xFF30D158),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 24),
            // Rules
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Rules',
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  _RuleItem(text: 'Lowercase letters, numbers & underscores'),
                  SizedBox(height: 4),
                  _RuleItem(text: 'Must start with a letter'),
                  SizedBox(height: 4),
                  _RuleItem(text: '3-20 characters'),
                  SizedBox(height: 4),
                  _RuleItem(text: 'Must be unique'),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          CupertinoIcons.circle_fill,
          color: Color(0xFF48484A),
          size: 5,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}