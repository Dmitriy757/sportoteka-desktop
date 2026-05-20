// lib/presentation/my_profile_screen/my_profile_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';

// ✅ FIFA Skills widget (заглушка)
import 'package:sportoteka/widgets/player_skills_fifa_stub.dart';

// ✅ Reels upload + viewer
import 'package:sportoteka/presentation/reels_screen/upload_reel_screen.dart';
import 'package:sportoteka/presentation/reels_screen/user_reels_screen.dart';

/// ================== ЗЕЛЕНАЯ ЦВЕТОВАЯ ПАЛИТРА ==================
class ProfilePalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const background = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
}

enum _ProfileFeedMode { posts, reels, feed }

class MyProfileScreen extends StatefulWidget {
  final int? userId; // если null -> мой профиль

  const MyProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  // =========================
  // CONFIG
  // =========================
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _uploadsBase = 'https://sportotekaapp.ru/uploads';

  // =========================
  // PROFILE
  // =========================
  String firstName = "";
  String lastName = "";
  String email = "";
  String role = "";
  String? photo; // FULL URL for UI
  String? bio;
  String? location;

  // =========================
  // PLAYER PRO DATA
  // =========================
  int? age;
  String? birthDateRaw;

  String? playerTeamName;
  String? playerClubName;
  String? playerTeamLogoUrl;

  // =========================
  // POSTS (PROFILE GRID)
  // =========================
  List<dynamic> userPosts = [];
  bool isLoadingPosts = false;

  // =========================
  // REELS (profile grid)
  // =========================
  List<Map<String, dynamic>> userReels = [];
  bool isLoadingReels = false;

  // =========================
  // FEED POSTS (общая лента автора)
  // =========================
  List<Map<String, dynamic>> feedPosts = [];
  bool isLoadingFeed = false;

  // =========================
  // SCREEN
  // =========================
  bool isLoadingProfile = true;
  _ProfileFeedMode _mode = _ProfileFeedMode.posts;

  // ✅ Create post (PROFILE ONLY)
  File? _newPostImage;
  final TextEditingController _newPostText = TextEditingController();
  bool _posting = false;

  // =========================
  // FOLLOW
  // =========================
  bool isFollowing = false;
  bool isOwnProfile = true;
  int followersCount = 0;
  int followingsCount = 0;

  // =========================
  // MODALS CACHE
  // =========================
  List<_UserShort> _followers = [];
  List<_UserShort> _followings = [];
  bool _loadingFollowers = false;
  bool _loadingFollowings = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _newPostText.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    try {
      final pure = s.contains(' ') ? s.split(' ').first : s;
      return DateTime.tryParse(pure);
    } catch (_) {
      return null;
    }
  }

  int? _calcAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int a = now.year - dob.year;
    final hadBirthdayThisYear =
        (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) a -= 1;
    if (a < 0 || a > 120) return null;
    return a;
  }

  String? _normalizePhotoUrl(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '$_uploadsBase/$s';
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Пользователь' : name;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  }

  // --- Feed parsing helpers (из SportCommunityScreen) ---
  String _safeStr(dynamic v) => (v ?? '').toString();
  int _safeInt(dynamic v) => int.tryParse(_safeStr(v)) ?? 0;

  String _fixUrl(String s) {
    final u = s.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http")) return u;
    return "https://sportotekaapp.ru/$u";
  }

  bool _looksLikeHtml(String s) {
    final t = s.trim().toLowerCase();
    return t.contains('<p') ||
        t.contains('<br') ||
        t.contains('</') ||
        t.contains('<div') ||
        t.contains('<span');
  }

  String _htmlToPlain(String html) {
    var t = html;

    // переносы
    t = t.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    t = t.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');

    // убрать открывающие <p ...>
    t = t.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');

    // убрать остальные теги
    t = t.replaceAll(RegExp(r'<[^>]+>'), '');

    // html entities
    t = t.replaceAll('&nbsp;', ' ');
    t = t.replaceAll('&amp;', '&');
    t = t.replaceAll('&quot;', '"');
    t = t.replaceAll('&#39;', "'");
    t = t.replaceAll('&lt;', '<');
    t = t.replaceAll('&gt;', '>');

    return t.trim();
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([
        loadUserData(),
        _fetchUserPosts(),
        _fetchUserReels(),
        _fetchAuthorFeedPosts(),
        _checkIfFollowing(),
        _loadFollowersData(),
      ]);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  // ------------------------------------------------------------
  // USER DATA
  // ------------------------------------------------------------
  Future<void> loadUserData() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (viewedUserId == null || viewedUserId <= 0) {
      await _loadLocalData();
      return;
    }

    try {
      final uri = Uri.parse('$_apiBase/get_user.php?user_id=$viewedUserId');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        if (viewedUserId == currentUserId) {
          await _loadLocalData();
        } else {
          if (mounted) {
            setState(() {
              firstName = 'Пользователь';
              lastName = '';
            });
          }
        }
        return;
      }

      final responseBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(responseBody);

      Map<String, dynamic> root = {};
      if (data is Map) root = data.cast<String, dynamic>();

      Map<String, dynamic> userData = {};
      if (root['success'] == true && root['user'] is Map) {
        userData = (root['user'] as Map).cast<String, dynamic>();
      } else if (root['user'] is Map) {
        userData = (root['user'] as Map).cast<String, dynamic>();
      } else {
        userData = root;
      }

      // basic
      final first =
          (userData['first_name'] ?? userData['firstName'] ?? '').toString().trim();
      final last =
          (userData['last_name'] ?? userData['lastName'] ?? '').toString().trim();
      final mail = (userData['email'] ?? '').toString().trim();
      final r = (userData['role'] ?? '').toString().trim();

      final photo1 = _normalizePhotoUrl(userData['photo_url']);
      final photo2 = _normalizePhotoUrl(userData['photo_urls']);
      final photo3 = _normalizePhotoUrl(userData['photo']);
      final resolvedPhoto = photo1 ?? photo2 ?? photo3;

      final b =
          (userData['bio'] ?? userData['description'] ?? '').toString().trim();
      final loc =
          (userData['location'] ?? userData['city'] ?? '').toString().trim();

      // =========================
      // PLAYER EXTRA (from get_user.php)
      // =========================
      int? resolvedAge;
      String? resolvedBirthRaw;
      String? resolvedTeamName;
      String? resolvedClubName;
      String? resolvedTeamLogo;

      final player = (root['player'] is Map)
          ? (root['player'] as Map).cast<String, dynamic>()
          : null;
      final playerTeam = (root['player_team'] is Map)
          ? (root['player_team'] as Map).cast<String, dynamic>()
          : null;

      if (player != null) {
        final apiAge = _asInt(player['age']);
        final birthAny = player['birth_date'] ??
            player['dob'] ??
            player['date_of_birth'] ??
            player['birthday'];
        final dob = _parseDate(birthAny);
        final computedAge = _calcAge(dob);

        resolvedAge = (apiAge > 0) ? apiAge : computedAge;
        resolvedBirthRaw = (birthAny ?? '').toString().trim();
        if (resolvedBirthRaw != null && resolvedBirthRaw!.isEmpty) {
          resolvedBirthRaw = null;
        }
      }

      if (playerTeam != null) {
        resolvedTeamName =
            (playerTeam['name'] ?? playerTeam['team_name'] ?? '').toString().trim();
        if (resolvedTeamName.isEmpty) resolvedTeamName = null;

        resolvedClubName =
            (playerTeam['club_name'] ?? playerTeam['clubName'] ?? '').toString().trim();
        if (resolvedClubName.isEmpty) resolvedClubName = null;

        resolvedTeamLogo =
            (playerTeam['logo_url'] ?? playerTeam['logoUrl'] ?? '').toString().trim();
        if (resolvedTeamLogo.isEmpty) resolvedTeamLogo = null;
      }

      if (!mounted) return;
      setState(() {
        firstName = first;
        lastName = last;
        email = mail;
        role = r;
        photo = resolvedPhoto;
        bio = b.isEmpty ? null : b;
        location = loc.isEmpty ? null : loc;

        age = resolvedAge;
        birthDateRaw = resolvedBirthRaw;

        playerTeamName = resolvedTeamName;
        playerClubName = resolvedClubName;
        playerTeamLogoUrl = resolvedTeamLogo;
      });

      // cache only my profile
      if (viewedUserId == currentUserId) {
        await PrefUtils.setUserFirstName(firstName);
        await PrefUtils.setUserLastName(lastName);
        await PrefUtils.setUserEmail(email);
        await PrefUtils.setRole(role);

        final photoFile = (userData['photo'] ?? '').toString().trim();
        if (photoFile.isNotEmpty) {
          await PrefUtils.setUserPhoto(photoFile);
        }
      }
    } catch (_) {
      final currentUserId2 = await PrefUtils.getUserId();
      final viewedUserId2 = widget.userId ?? currentUserId2;

      if (viewedUserId2 == currentUserId2) {
        await _loadLocalData();
      } else {
        if (mounted) {
          setState(() {
            firstName = 'Пользователь';
            lastName = '';
          });
        }
      }
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final savedFirstName = await PrefUtils.getUserFirstName();
      final savedLastName = await PrefUtils.getUserLastName();
      final savedEmail = await PrefUtils.getUserEmail();
      final savedRole = await PrefUtils.getRole();
      final savedPhotoFile = await PrefUtils.getUserPhoto();

      if (!mounted) return;
      setState(() {
        firstName = savedFirstName;
        lastName = savedLastName;
        email = savedEmail;
        role = savedRole;
        photo = _normalizePhotoUrl(savedPhotoFile);
      });
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // FOLLOW / UNFOLLOW
  // ------------------------------------------------------------
  Future<void> _checkIfFollowing() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (currentUserId == null || currentUserId <= 0) return;

    if (viewedUserId == currentUserId || viewedUserId == null) {
      if (mounted) {
        setState(() {
          isOwnProfile = true;
          isFollowing = false;
        });
      }
      return;
    }

    if (mounted) setState(() => isOwnProfile = false);

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/check_following.php'),
        body: {
          'follower_id': currentUserId.toString(),
          'following_id': viewedUserId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() => isFollowing = (data is Map && data['following'] == true));
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final currentUserId = await PrefUtils.getUserId();
    final viewedUserId = widget.userId ?? currentUserId;

    if (currentUserId == null || currentUserId <= 0) return;
    if (viewedUserId == null || viewedUserId <= 0) return;

    final url = isFollowing ? '$_apiBase/unsubscribe.php' : '$_apiBase/subscribe.php';

    try {
      final response = await http.post(Uri.parse(url), body: {
        'follower_id': currentUserId.toString(),
        'following_id': viewedUserId.toString(),
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ok = (data is Map) && (
  data['status'] == 'success' ||
  data['status'] == 'subscribed' ||
  data['status'] == 'unsubscribed' ||
  data['success'] == true
);
        if (ok) {
          if (mounted) setState(() => isFollowing = !isFollowing);
          await _loadFollowersData();
          _followers.clear();
          _followings.clear();
        } else {
          Get.snackbar(
            'Ошибка',
            'Не удалось изменить подписку',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (_) {
      Get.snackbar(
        'Ошибка сети',
        'Проверьте соединение',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _loadFollowersData() async {
  final userId = widget.userId ?? await PrefUtils.getUserId();
  if (userId == null || userId <= 0) return;

  try {
    final response = await http.post(
      Uri.parse('$_apiBase/get_follow_counts.php'),
      body: {'user_id': userId.toString()},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final ok = (data is Map) &&
          (data['status'] == 'success' || data['success'] == true);

      if (ok && mounted) {
        setState(() {
          followersCount = _asInt(data['followers']);
          followingsCount = _asInt(data['followings']);
        });
      }
    }
  } catch (_) {}
}

  // ------------------------------------------------------------
  // POSTS (PROFILE ONLY - grid)
  // ------------------------------------------------------------
  Future<void> _fetchUserPosts() async {
    if (mounted) setState(() => isLoadingPosts = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) return;

      final response = await http.post(
        Uri.parse('$_apiBase/get_posts_by_user.php'),
        body: jsonEncode({
          'user_id': userId,
          'visibility': 'profile',
          'post_type': 'post',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success') {
          if (mounted) {
            setState(() => userPosts = (data['posts'] is List) ? data['posts'] : []);
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingPosts = false);
    }
  }

  // ------------------------------------------------------------
  // REELS (PROFILE GRID)
  // ------------------------------------------------------------
  Future<void> _fetchUserReels() async {
    if (mounted) setState(() => isLoadingReels = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) return;

      final url = Uri.parse("$_apiBase/get_reels.php?limit=200&offset=0&user_id=$userId");
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final jsonAny = jsonDecode(body);

      final parsed = _parseReels(jsonAny);

      // ✅ на всякий: фильтруем строго по userId (если сервер вернул все)
      final filtered = parsed.where((m) => (m['user_id'] ?? 0) == userId).toList();

      if (mounted) setState(() => userReels = filtered);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingReels = false);
    }
  }

  List<Map<String, dynamic>> _parseReels(dynamic jsonAny) {
    List raw;
    if (jsonAny is Map) {
      raw = (jsonAny['reels'] ??
              jsonAny['data'] ??
              jsonAny['items'] ??
              jsonAny['list'] ??
              []) as List? ??
          [];
    } else if (jsonAny is List) {
      raw = jsonAny;
    } else {
      raw = const [];
    }

    return raw
        .map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);

          final String video =
              (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '')
                  .toString()
                  .trim();
          String thumb =
              (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? '').toString().trim();
          if (thumb.isEmpty && m['preview'] != null) {
            thumb = m['preview'].toString().trim();
          }

          return {
            'id': _toInt(m['id'] ?? m['reel_id'] ?? 0),
            'user_id': _toInt(m['user_id'] ?? m['author_id'] ?? 0),
            'video_url': video,
            'thumbnail': thumb,
            'description': (m['description'] ?? m['caption'] ?? '').toString(),
            'likes': _toInt(m['likes'] ?? m['like_count'] ?? 0),
            'comments': _toInt(m['comments'] ?? m['comment_count'] ?? 0),
            'views': _toInt(m['views'] ?? m['view_count'] ?? 0),
          };
        })
        .where((e) => (e['video_url'] as String).isNotEmpty)
        .toList();
  }

  // ------------------------------------------------------------
  // FEED POSTS (Лента автора из общего get_posts.php)
  // ------------------------------------------------------------
  Future<void> _fetchAuthorFeedPosts() async {
    if (mounted) setState(() => isLoadingFeed = true);

    try {
      final currentUserId = await PrefUtils.getUserId() ?? 0;
      final authorId = widget.userId ?? currentUserId;

      if (authorId <= 0) return;

      final uri = Uri.parse('$_apiBase/get_posts.php?user_id=$currentUserId');
      final res = await http.get(uri);
      if (res.statusCode != 200) return;

      final decoded = json.decode(res.body);

      final List<dynamic> data = decoded is List
          ? decoded
          : (decoded is Map && decoded['posts'] is List)
              ? (decoded['posts'] as List)
              : [];

      final filtered = data.where((raw) => _safeInt(raw['user_id']) == authorId).toList();

      final list = filtered.map<Map<String, dynamic>>((raw) {
        final firstName = _safeStr(raw['first_name']);
        final lastName = _safeStr(raw['last_name']);
        final fullName = ('$firstName $lastName').trim();

        final image = _fixUrl(_safeStr(raw['image']));
        final avatar =
            _fixUrl(_safeStr(raw['photo'] ?? raw['photo_url'] ?? raw['avatar']));

        final rawBody = _safeStr(raw['body']);
        final plainBody = _looksLikeHtml(rawBody) ? _htmlToPlain(rawBody) : rawBody;

        return <String, dynamic>{
          'id': _safeInt(raw['id']),
          'title': _safeStr(raw['title']),
          'text': plainBody,
          'imageUrl': image,
          'date': DateTime.tryParse(_safeStr(raw['created_at'])) ?? DateTime.now(),
          'authorName': fullName.isNotEmpty
              ? fullName
              : (_safeStr(raw['author_name']).isNotEmpty
                  ? _safeStr(raw['author_name'])
                  : 'Пользователь'),
          'user_id': _safeInt(raw['user_id']),
          'authorAvatar': avatar,
          'likes': _safeInt(raw['likes_count']),
          'comments': _safeInt(raw['comments_count']),
        };
      }).toList();

      if (!mounted) return;
      setState(() => feedPosts = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => isLoadingFeed = false);
    }
  }

  void _openFeedPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(
          title: _safeStr(post['title']).isNotEmpty ? _safeStr(post['title']) : 'Пост',
          body: _safeStr(post['text']),
          newsId: _safeInt(post['id']),
          imageUrl: _safeStr(post['imageUrl']),
        ),
      ),
    ).then((_) => _fetchAuthorFeedPosts());
  }

  // ------------------------------------------------------------
  // CREATE POST (PROFILE ONLY)
  // ------------------------------------------------------------
  Future<void> _submitProfilePost() async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId <= 0) return;

    final text = _newPostText.text.trim();
    if (text.isEmpty && _newPostImage == null) {
      Get.snackbar(
        "Публикация",
        "Напишите текст или добавьте фото",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (mounted) setState(() => _posting = true);

    final uri = Uri.parse('$_apiBase/insert_post.php');
    final req = http.MultipartRequest('POST', uri)
      ..fields['title'] = ''
      ..fields['body'] = text
      ..fields['category'] = ''
      ..fields['team'] = ''
      ..fields['author'] = ''
      ..fields['user_id'] = userId.toString()
      ..fields['visibility'] = 'profile'
      ..fields['post_type'] = 'post';

    if (_newPostImage != null) {
      req.files.add(await http.MultipartFile.fromPath('image', _newPostImage!.path));
    }

    try {
      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        if (mounted) Navigator.pop(context); // закрыть bottom sheet

        if (mounted) {
          setState(() {
            _newPostText.clear();
            _newPostImage = null;
          });
        }

        await _fetchUserPosts();
        await _fetchAuthorFeedPosts();
      } else {
        Get.snackbar("Ошибка", "Не удалось опубликовать: $body",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar("Ошибка сети", e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Новая публикация",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Chip(
                        label: const Text("Профиль"),
                        avatar: const Icon(Icons.person, size: 18),
                        backgroundColor: ProfilePalette.primaryGreen.withOpacity(0.10),
                        side: BorderSide(color: ProfilePalette.primaryGreen.withOpacity(0.25)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _newPostText,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Что нового?",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),

                  if (_newPostImage != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _newPostImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setModalState(() => _newPostImage = null),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final picked =
                              await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            setModalState(() => _newPostImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        color: ProfilePalette.primaryGreen,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _posting ? null : _submitProfilePost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProfilePalette.primaryGreen,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                        ),
                        child: _posting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Опубликовать"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------
  // REELS UPLOAD FROM PROFILE
  // ------------------------------------------------------------
  Future<void> _openUploadReels() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadReelScreen(
          onUploadComplete: () async {
            await _fetchUserReels();
          },
        ),
      ),
    );
    await _fetchUserReels();
  }

  // ------------------------------------------------------------
  // PHOTO UPLOAD (avatar)
  // ------------------------------------------------------------
  Future<void> _uploadProfilePhoto(File imageFile) async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId <= 0) return;

    final uri = Uri.parse('$_apiBase/upload_user_photo.php');

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = userId.toString()
        ..files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

      final response = await request.send();
      if (response.statusCode != 200) return;

      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);

      if (data is Map && data['status'] == 'success') {
        final serverPhotoUrl = (data['photo_url'] ?? '').toString().trim();
        final fileName = (data['file_name'] ?? '').toString().trim();

        final newUrl = serverPhotoUrl.isNotEmpty
            ? _normalizePhotoUrl(serverPhotoUrl)
            : _normalizePhotoUrl(fileName);

        if (mounted) setState(() => photo = newUrl);

        if (fileName.isNotEmpty) {
          await PrefUtils.setUserPhoto(fileName);
        }

        await loadUserData();
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _uploadProfilePhoto(File(picked.path));
    }
  }

  // ------------------------------------------------------------
  // MODALS: FOLLOWERS / FOLLOWINGS
  // ------------------------------------------------------------
  Future<void> _fetchFollowersList() async {
    if (_loadingFollowers) return;
    if (mounted) setState(() => _loadingFollowers = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) {
        _followers = [];
        return;
      }

      final res = await http.post(
        Uri.parse('$_apiBase/get_followers.php'),
        body: {'user_id': userId.toString()},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['users'] is List) {
          _followers = (data['users'] as List)
              .map((e) => _UserShort.fromJson(e))
              .toList();
        } else {
          _followers = [];
        }
      }
    } catch (_) {
      _followers = [];
    } finally {
      if (mounted) setState(() => _loadingFollowers = false);
    }
  }

  Future<void> _fetchFollowingsList() async {
    if (_loadingFollowings) return;
    if (mounted) setState(() => _loadingFollowings = true);

    try {
      final userId = widget.userId ?? await PrefUtils.getUserId();
      if (userId == null || userId <= 0) {
        _followings = [];
        return;
      }

      final res = await http.post(
        Uri.parse('$_apiBase/get_followings.php'),
        body: {'user_id': userId.toString()},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success' && data['users'] is List) {
          _followings = (data['users'] as List)
              .map((e) => _UserShort.fromJson(e))
              .toList();
        } else {
          _followings = [];
        }
      }
    } catch (_) {
      _followings = [];
    } finally {
      if (mounted) setState(() => _loadingFollowings = false);
    }
  }

  void _openUsersModal({required bool showFollowers}) async {
    if (showFollowers) {
      await _fetchFollowersList();
    } else {
      await _fetchFollowingsList();
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final title = showFollowers ? 'Подписчики' : 'Подписки';
        final loading = showFollowers ? _loadingFollowers : _loadingFollowings;
        final items = showFollowers ? _followers : _followings;

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 24, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (loading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: ProfilePalette.primaryGreen),
                  ),
                )
              else if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          showFollowers ? Icons.people_outline : Icons.person_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          showFollowers ? 'Пока нет подписчиков' : 'Пока нет подписок',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = items[index];
                      final hasPhoto = (u.photoUrl ?? '').trim().isNotEmpty;

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: ProfilePalette.primaryGreen.withOpacity(0.1),
                          backgroundImage: hasPhoto ? NetworkImage(u.photoUrl!) : null,
                          child: !hasPhoto
                              ? Text(
                                  u.fullName.isNotEmpty
                                      ? u.fullName[0].toUpperCase()
                                      : 'П',
                                  style: const TextStyle(
                                    color: ProfilePalette.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          u.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        subtitle: u.role?.isNotEmpty == true
                            ? Text(
                                u.role!,
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              )
                            : null,
                        trailing: (u.id != null)
                            ? OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MyProfileScreen(userId: u.id),
                                    ),
                                  ).then((_) {
                                    _loadFollowersData();
                                    _checkIfFollowing();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ProfilePalette.primaryGreen,
                                  side: const BorderSide(color: ProfilePalette.primaryGreen),
                                ),
                                child: const Text('Посмотреть'),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // TOP MENU (⋮)
  // ------------------------------------------------------------
  void _onEditProfile() {
    Get.snackbar(
      "Профиль",
      "Редактирование профиля подключим следующим шагом.",
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final hasAvatar = (photo ?? '').trim().isNotEmpty;
    final isPlayer = role.trim().toLowerCase() == 'player';

    return Scaffold(
      backgroundColor: ProfilePalette.background,
      appBar: AppBar(
        backgroundColor: ProfilePalette.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Row(
          children: [
            if (widget.userId != null)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.black),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.userId == null) ...[
            // ✅ быстрые действия: пост/реил
            PopupMenuButton<String>(
              icon: const Icon(Icons.add, color: Colors.black),
              onSelected: (v) {
                if (v == 'post') _openCreatePostModal();
                if (v == 'reel') _openUploadReels();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'post', child: Text("Новый пост")),
                PopupMenuItem(value: 'reel', child: Text("Новый Reels")),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (v) {
                if (v == 'edit') _onEditProfile();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.black),
                      SizedBox(width: 10),
                      Text("Редактировать профиль"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: ProfilePalette.primaryGreen),
            )
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: ProfilePalette.primaryGreen,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ========= header row =========
Row(
  children: [
    GestureDetector(
      onTap: widget.userId == null ? _pickAndUploadPhoto : null,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: ProfilePalette.primaryGreen.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  photo!,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                )
              : _buildDefaultAvatar(),
        ),
      ),
    ),
    const SizedBox(width: 18),
    Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(count: userPosts.length, label: 'Посты'),
              _buildStatItem(count: userReels.length, label: 'Reels'),
              GestureDetector(
                onTap: () => _openUsersModal(showFollowers: true),
                child:
                    _buildStatItem(count: followersCount, label: 'Подписчики'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 🔥 КНОПКИ ТУТ
          if (!isOwnProfile)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.grey.shade200
                          : ProfilePalette.primaryGreen,
                      foregroundColor:
                          isFollowing ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isFollowing ? 'Отписаться' : 'Подписаться',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  child: const Text('Написать'),
                ),
              ],
            ),
        ],
      ),
    ),
  ],
),

                          // ===== PRO FOOTBALL BLOCK (AGE + TEAM) =====
                          if (age != null || playerTeamName != null || playerClubName != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (age != null)
                                  _infoChip(icon: Icons.cake_outlined, text: "Возраст: $age"),
                                if ((playerTeamName ?? '').trim().isNotEmpty)
                                  _infoChip(icon: Icons.groups_2_outlined, text: playerTeamName!),
                                if ((playerClubName ?? '').trim().isNotEmpty)
                                  _infoChip(icon: Icons.shield_outlined, text: playerClubName!),
                              ],
                            ),
                          ],

                          if ((playerTeamName ?? '').trim().isNotEmpty ||
                              (playerTeamLogoUrl ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildTeamCard(),
                          ],

                          // ✅ FIFA SKILLS (ONLY PLAYER)
                          if (isPlayer) ...[
                            const SizedBox(height: 14),
                            const Text(
                              "Скиллы игрока",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Автоматически рассчитываются на основе тренировок и матчей.",
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.black.withOpacity(0.55),
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PlayerSkillsFifaStub(
                              playerName: fullName,
                              position: "ST",
                              clubName: (playerClubName ?? "Sportoteka").toString(),
                              photoUrl: photo,
                            ),
                          ],

                          if (bio?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Text(bio!, style: const TextStyle(fontSize: 14, color: Colors.black)),
                          ],
                          if (location?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(location!, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // ✅ для чужого профиля — оставляем действия
                          //if (!isOwnProfile) _buildOtherProfileActions(),

                          const SizedBox(height: 14),

                          // ✅ ОСТАВЛЯЕМ ТОЛЬКО ЭТИ КНОПКИ (без баннеров и без "Добавить Reels" здесь)
                          _buildModeSwitcher(),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // ========= CONTENT (3 режима) =========
                  if (_mode == _ProfileFeedMode.posts) ..._buildPostsSlivers(),
                  if (_mode == _ProfileFeedMode.reels) ..._buildReelsSlivers(),
                  if (_mode == _ProfileFeedMode.feed) ..._buildFeedSlivers(),
                ],
              ),
            ),
    );
  }

  // ----------------- mode switcher -----------------
  Widget _buildModeSwitcher() {
    final isPosts = _mode == _ProfileFeedMode.posts;
    final isReels = _mode == _ProfileFeedMode.reels;
    final isFeed = _mode == _ProfileFeedMode.feed;

    Widget btn({
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? ProfilePalette.primaryGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: active ? Colors.white : Colors.black54),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          btn(
            active: isPosts,
            icon: Icons.grid_on_rounded,
            label: "Посты",
            onTap: () => setState(() => _mode = _ProfileFeedMode.posts),
          ),
          btn(
            active: isReels,
            icon: Icons.play_circle_fill_rounded,
            label: "Reels",
            onTap: () => setState(() => _mode = _ProfileFeedMode.reels),
          ),
          btn(
            active: isFeed,
            icon: Icons.public,
            label: "Лента",
            onTap: () => setState(() => _mode = _ProfileFeedMode.feed),
          ),
        ],
      ),
    );
  }

  // ----------------- POSTS slivers -----------------
  List<Widget> _buildPostsSlivers() {
    if (isLoadingPosts) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: ProfilePalette.primaryGreen),
            ),
          ),
        ),
      ];
    }

    if (userPosts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                const Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Пока нет постов', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isOwnProfile)
                  const Text('Создайте свой первый пост!', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = userPosts[index] as Map<String, dynamic>;
            final imageUrl = (post['image'] ?? '').toString().trim();
            final hasImage = imageUrl.isNotEmpty;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailScreen(
                      title: (post['category'] ?? 'Мой пост').toString(),
                      body: (post['body'] ?? '').toString(),
                      newsId: int.tryParse(post['id'].toString()) ?? 0,
                      imageUrl: imageUrl,
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.grey.shade50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: ProfilePalette.lightGreen,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: ProfilePalette.lightGreen,
                        child: Center(
                          child: Icon(Icons.article_outlined, size: 40, color: Colors.grey.shade400),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.30), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(hasImage ? Icons.photo : Icons.article, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: userPosts.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ----------------- REELS slivers -----------------
  List<Widget> _buildReelsSlivers() {
    if (isLoadingReels) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: ProfilePalette.primaryGreen),
            ),
          ),
        ),
      ];
    }

    if (userReels.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.play_circle_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('Пока нет Reels', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                if (isOwnProfile)
                  const Text('Добавьте своё первое видео!', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 9 / 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final reel = userReels[index];
            final thumb = (reel['thumbnail'] ?? '').toString().trim();

            return GestureDetector(
              onTap: () async {
                final viewedUserId = widget.userId ?? await PrefUtils.getUserId() ?? 0;
                if (!mounted || viewedUserId <= 0) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReelsScreen(
                      userId: viewedUserId,
                      initialIndex: index,
                      title: "Reels: $fullName",
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb.isNotEmpty)
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.06)),
                      child: const Center(
                        child: Icon(Icons.play_arrow_rounded, size: 34, color: Colors.black45),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        _miniBadge("❤ ${reel['likes'] ?? 0}"),
                        const SizedBox(width: 6),
                        _miniBadge("💬 ${reel['comments'] ?? 0}"),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: userReels.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ----------------- FEED slivers -----------------
  List<Widget> _buildFeedSlivers() {
    if (isLoadingFeed) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: ProfilePalette.primaryGreen),
            ),
          ),
        ),
      ];
    }

    if (feedPosts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.public, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('В ленте пока нет постов', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Это посты автора, опубликованные в сообществе.',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = feedPosts[index];
            final img = _safeStr(post['imageUrl']).trim();
            final hasImage = img.isNotEmpty;

            return GestureDetector(
              onTap: () => _openFeedPostDetail(post),
              child: Container(
                color: Colors.grey.shade50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: ProfilePalette.lightGreen,
                          child: Center(
                            child: Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: ProfilePalette.lightGreen,
                        child: Center(
                          child: Icon(Icons.public, size: 40, color: Colors.grey.shade400),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.30), Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(hasImage ? Icons.photo : Icons.public, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: feedPosts.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _miniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }

  // ===== Team card UI =====
  Widget _buildTeamCard() {
    final logo = (playerTeamLogoUrl ?? '').trim();
    final team = (playerTeamName ?? '').trim();
    final club = (playerClubName ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ProfilePalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ProfilePalette.primaryGreen.withOpacity(0.08),
              border: Border.all(color: ProfilePalette.primaryGreen.withOpacity(0.18)),
            ),
            child: ClipOval(
              child: logo.isNotEmpty
                  ? Image.network(
                      logo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shield_outlined,
                        color: ProfilePalette.primaryGreen,
                        size: 26,
                      ),
                    )
                  : const Icon(Icons.shield_outlined, color: ProfilePalette.primaryGreen, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.isNotEmpty ? team : "Команда",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  club.isNotEmpty ? "Клуб: $club" : "Клуб: —",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ProfilePalette.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Профи",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: ProfilePalette.lightGreen,
      child: const Center(
        child: Icon(Icons.person, size: 48, color: ProfilePalette.primaryGreen),
      ),
    );
  }

  Widget _infoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ProfilePalette.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfilePalette.primaryGreen.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ProfilePalette.primaryGreen),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required int count, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  }

// ============================================================
// Model for followers/followings modal
// ============================================================
class _UserShort {
  final int? id;
  final String fullName;
  final String? role;
  final String? photoUrl;

  _UserShort({this.id, required this.fullName, this.role, this.photoUrl});

  factory _UserShort.fromJson(dynamic json) {
    final m = (json as Map).cast<String, dynamic>();

    final first = (m['first_name'] ?? '').toString().trim();
    final last = (m['last_name'] ?? '').toString().trim();

    String? normalize(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      if (s.startsWith('http://') || s.startsWith('https://')) return s;
      return 'https://sportotekaapp.ru/uploads/$s';
    }

    final photo = normalize(m['photo_url']) ?? normalize(m['photo']);

    final name = '$first $last'.trim();
    return _UserShort(
      id: (m['id'] is int) ? m['id'] as int : int.tryParse(m['id']?.toString() ?? ''),
      fullName: name.isEmpty ? 'Пользователь' : name,
      role: (m['role'] ?? '').toString(),
      photoUrl: photo,
    );
  }
}
