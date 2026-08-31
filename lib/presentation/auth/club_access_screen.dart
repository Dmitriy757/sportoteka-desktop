import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/push/push_service.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

class ClubAccessScreen extends StatefulWidget {
  const ClubAccessScreen({
    super.key,
    required this.userId,
    required this.clubName,
    required this.email,
  });

  final int userId;
  final String clubName;
  final String email;

  @override
  State<ClubAccessScreen> createState() => _ClubAccessScreenState();
}

class _ClubAccessScreenState extends State<ClubAccessScreen> {
  static const String _base =
      'https://sportotekaapp.ru/api/club_access';

  static const Color _bg = Color(0xFFF6F7F6);
  static const Color _panel = Colors.white;
  static const Color _text = Color(0xFF0B0F14);
  static const Color _secondary = Color(0xFF667085);
  static const Color _subtle = Color(0xFF98A2B3);
  static const Color _line = Color(0xFFE9ECEA);
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _amberSoft = Color(0xFFFFF7ED);
  static const Color _amber = Color(0xFFB54708);

  final TextEditingController _keyController =
      TextEditingController();

  bool _loading = false;
  bool _checking = true;
  String _status = 'pending';
  String? _keySentAt;
  String? _keyExpiresAt;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _json(String raw) {
    try {
      final value = jsonDecode(raw);

      if (value is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    } catch (_) {}

    return null;
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() => _checking = true);
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_base/status.php'),
            headers: const {
              'Content-Type':
                  'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'user_id': widget.userId,
              'email': widget.email,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final data = _json(response.body);

      if (response.statusCode != 200 ||
          data == null ||
          data['status'] != 'success') {
        return;
      }

      final application = data['application'];

      if (application is Map) {
        final status =
            '${application['status'] ?? 'pending'}'
                .trim();

        if (!mounted) return;

        setState(() {
          _status =
              status.isEmpty ? 'pending' : status;

          _keySentAt =
              '${application['key_sent_at'] ?? ''}'
                      .trim()
                      .isEmpty
                  ? null
                  : '${application['key_sent_at']}';

          _keyExpiresAt =
              '${application['key_expires_at'] ?? ''}'
                      .trim()
                      .isEmpty
                  ? null
                  : '${application['key_expires_at']}';
        });

        if (_status == 'approved') {
          await _enterApplication();
        }
      }
    } catch (_) {
      // Экран остаётся рабочим даже при временной ошибке сети.
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _activate() async {
    if (_loading) return;

    final key =
        _keyController.text.trim().toUpperCase();

    if (key.isEmpty) {
      Get.snackbar(
        'Club Key',
        'Введите ключ доступа из письма',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_base/activate.php'),
            headers: const {
              'Content-Type':
                  'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'user_id': widget.userId,
              'email': widget.email,
              'key': key,
            }),
          )
          .timeout(
            const Duration(seconds: 18),
          );

      final data = _json(response.body);

      if (response.statusCode != 200 ||
          data == null ||
          data['status'] != 'success') {
        Get.snackbar(
          'Не удалось активировать',
          data?['message'] ??
              'Проверьте Club Key',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
        return;
      }

      await _enterApplication(
        userData: data['user'],
      );
    } catch (e) {
      Get.snackbar(
        'Ошибка подключения',
        'Не удалось проверить ключ',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enterApplication({
    dynamic userData,
  }) async {
    Map<String, dynamic> user = {};

    if (userData is Map) {
      user =
          Map<String, dynamic>.from(userData);
    }

    final userId = int.tryParse(
          '${user['id'] ?? widget.userId}',
        ) ??
        widget.userId;

    await PrefUtils.clearAll();

    await PrefUtils.setIsSignIn(true);
    await PrefUtils.setUserId(userId);
    await PrefUtils.setRole('club');

    final pref = PrefUtils();
    await pref.init();

    await pref.setUserRole('club');

    await pref.setUserFirstName(
      '${user['first_name'] ?? widget.clubName}',
    );

    await pref.setUserLastName(
      '${user['last_name'] ?? ''}',
    );

    await pref.setUserEmail(
      '${user['email'] ?? widget.email}',
    );

    try {
      await PushService.instance.init(
        userId: userId,
      );
    } catch (_) {}

    if (!mounted) return;

    Get.offAll<void>(
      () => const MyProfileScreen(),
      transition: Transition.noTransition,
      duration: Duration.zero,
    );
  }

  Future<void> _backToLogin() async {
    await PrefUtils.clearAll();

    Get.offAllNamed(
      AppRoutes.loginScreen,
    );
  }

  String get _statusTitle {
    switch (_status) {
      case 'key_issued':
        return 'Ключ доступа отправлен';
      case 'approved':
        return 'Клуб активирован';
      case 'rejected':
        return 'Заявка отклонена';
      default:
        return 'Заявка на проверке';
    }
  }

  String get _statusText {
    switch (_status) {
      case 'key_issued':
        return 'Мы подтвердили заявку и отправили Club Key '
            'на ${widget.email}. Введите его ниже.';
      case 'rejected':
        return 'Заявка пока не подтверждена. '
            'Свяжитесь с поддержкой Sportoteka.';
      default:
        return 'После подтверждения заявки Club Key автоматически '
            'придёт на ${widget.email}.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final wide =
                constraints.maxWidth >= 760;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 12,
                wide ? 30 : 14,
                wide ? 24 : 12,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 760,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: _line,
                        width: .8,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _header(wide),
                        Container(
                          height: 1,
                          color: _line,
                        ),
                        Padding(
                          padding:
                              EdgeInsets.fromLTRB(
                            wide ? 34 : 16,
                            wide ? 32 : 22,
                            wide ? 34 : 16,
                            wide ? 34 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              _statusCard(),
                              const SizedBox(
                                height: 24,
                              ),
                              Text(
                                'Club Key',
                                style:
                                    AppTypography
                                        .formLabel(
                                  color: _text,
                                ),
                              ),
                              const SizedBox(
                                height: 7,
                              ),
                              TextField(
                                controller:
                                    _keyController,
                                textCapitalization:
                                    TextCapitalization
                                        .characters,
                                autocorrect: false,
                                enableSuggestions:
                                    false,
                                style:
                                    AppTypography
                                        .formText(
                                  color: _text,
                                ),
                                decoration:
                                    InputDecoration(
                                  hintText:
                                      'CLUB-XXXX-XXXX',
                                  hintStyle:
                                      AppTypography
                                          .formHint(
                                    color: _subtle,
                                  ),
                                  filled: true,
                                  fillColor:
                                      _greenSoft,
                                  prefixIcon:
                                      const Icon(
                                    Icons
                                        .key_rounded,
                                    color:
                                        _greenDark,
                                    size: 19,
                                  ),
                                  border:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                    borderSide:
                                        const BorderSide(
                                      color: _line,
                                    ),
                                  ),
                                  enabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                    borderSide:
                                        const BorderSide(
                                      color: _line,
                                    ),
                                  ),
                                  focusedBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      10,
                                    ),
                                    borderSide:
                                        const BorderSide(
                                      color: _green,
                                      width: 1.1,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  if (!_loading) {
                                    _activate();
                                  }
                                },
                              ),
                              const SizedBox(
                                height: 14,
                              ),
                              SizedBox(
                                height: 48,
                                child:
                                    FilledButton(
                                  onPressed:
                                      _loading ||
                                              _status ==
                                                  'pending' ||
                                              _status ==
                                                  'rejected'
                                          ? null
                                          : _activate,
                                  style:
                                      FilledButton
                                          .styleFrom(
                                    backgroundColor:
                                        _green,
                                    disabledBackgroundColor:
                                        const Color(
                                      0xFFE7EAE8,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color: Colors
                                                .white,
                                          ),
                                        )
                                      : Text(
                                          'Активировать клуб',
                                          style:
                                              AppTypography
                                                  .actionStrong(
                                            color:
                                                Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _checking
                                        ? null
                                        : _loadStatus,
                                icon: _checking
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              1.8,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .refresh_rounded,
                                        size: 17,
                                      ),
                                label: const Text(
                                  'Проверить статус',
                                ),
                              ),
                              const SizedBox(
                                height: 18,
                              ),
                              TextButton(
                                onPressed:
                                    _backToLogin,
                                child: const Text(
                                  'Вернуться ко входу',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(bool wide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 24 : 16,
        16,
        wide ? 24 : 16,
        16,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _greenSoft,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: _greenDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'SPORTOTEKA',
                  style:
                      AppTypography
                          .sectionTitle(
                    color: _text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Активация клуба',
                  style:
                      AppTypography.caption(
                    color: _secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final issued =
        _status == 'key_issued';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            issued ? _greenSoft : _amberSoft,
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            issued
                ? Icons.mark_email_read_outlined
                : Icons.schedule_rounded,
            color:
                issued ? _greenDark : _amber,
            size: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style:
                      AppTypography.itemTitle(
                    color: _text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _statusText,
                  style: AppTypography.body(
                    color: _secondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.clubName,
                  style:
                      AppTypography
                          .secondaryMedium(
                    color: _text,
                  ),
                ),
                if (_keySentAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ключ отправлен: $_keySentAt',
                    style:
                        AppTypography
                            .commentMeta(
                      color: _secondary,
                    ),
                  ),
                ],
                if (_keyExpiresAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Действует до: $_keyExpiresAt',
                    style:
                        AppTypography
                            .commentMeta(
                      color: _secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
