import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/push/push_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/utils/validation_functions.dart';

import 'controller/login_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginController controller = Get.put(LoginController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final RxBool isPasswordVisible = true.obs;
  final RxBool agreedToTerms = false.obs;

  bool alreadyAgreed = false;
  bool _loading = false;

  static const Color _green = Color(0xFF31C48D);
  static const Color _greenDark = Color(0xFF11895F);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _softBg = Color(0xFFF7FAF9);

  @override
  void initState() {
    super.initState();
    setSafeAreaColor();
    _loadAgreement();
  }

  Future<void> _loadAgreement() async {
    alreadyAgreed = await PrefUtils.getAgreedEula();
    agreedToTerms.value = alreadyAgreed;
    if (mounted) setState(() {});
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Ошибка', 'Не удалось открыть ссылку');
    }
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!agreedToTerms.value && !alreadyAgreed) {
      Get.snackbar(
        'Требуется согласие',
        'Подтвердите Условия и Политику, чтобы продолжить',
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) return;

    if (agreedToTerms.value && !alreadyAgreed) {
      await PrefUtils.setAgreedEula(true);
      alreadyAgreed = true;
    }

    await onTapLogIn();
  }

  @override
  Widget build(BuildContext context) {
    mediaQueryData = MediaQuery.of(context);

    return WillPopScope(
      onWillPop: () async {
        closeApp();
        return false;
      },
      child: Scaffold(
        backgroundColor: _softBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 1040;
              final double horizontalPadding = isWide ? 32 : 18;
              final double verticalPadding = isWide ? 30 : 18;

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - verticalPadding * 2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1060),
                      child: isWide
                          ? SizedBox(
                              height: 620,
                              child: Row(
                                children: [
                                  const Expanded(flex: 5, child: _LoginHeroPanel()),
                                  const SizedBox(width: 22),
                                  SizedBox(
                                    width: 430,
                                    child: _buildLoginCard(isWide: true),
                                  ),
                                ],
                              ),
                            )
                          : _buildLoginCard(isWide: false),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({required bool isWide}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isWide ? 34 : 22,
        isWide ? 34 : 24,
        isWide ? 34 : 22,
        isWide ? 30 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWide ? 34 : 28),
        border: Border.all(color: Colors.white.withOpacity(0.75)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isWide) ...[
              const Center(child: _SportotekaMark(size: 62)),
              const SizedBox(height: 18),
            ],
            Text(
              'Вход в систему',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 28,
                height: 1.08,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Добро пожаловать в Sportoteka. Войдите, чтобы открыть профиль, клубный кабинет и рабочие модули.',
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isWide ? 30 : 26),
            _buildEmailField(),
            const SizedBox(height: 14),
            _buildPasswordField(),
            const SizedBox(height: 14),
            _buildAgreementBlock(),
            const SizedBox(height: 22),
            _buildLoginButton(),
            const SizedBox(height: 18),
            _buildCreateAccountRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return _LoginTextField(
      controller: controller.emailController,
      hintText: 'Эл. почта',
      icon: Icons.alternate_email_rounded,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      validator: (value) {
        if (value == null || !isValidEmail(value, isRequired: true)) {
          return 'Введите корректный email.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => _LoginTextField(
        controller: controller.passwordController,
        hintText: 'Пароль',
        icon: Icons.lock_outline_rounded,
        obscureText: isPasswordVisible.value,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) {
          if (!_loading) _submitLogin();
        },
        suffixIcon: IconButton(
          splashRadius: 20,
          color: _muted,
          icon: Icon(
            isPasswordVisible.value
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
          ),
          onPressed: () {
            isPasswordVisible.value = !isPasswordVisible.value;
          },
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Введите пароль.';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildAgreementBlock() {
    return Obx(
      () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: agreedToTerms.value,
                onChanged: _loading
                    ? null
                    : (value) => agreedToTerms.value = value ?? false,
                activeColor: _greenDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Я согласен с ',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.8,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _LinkText(
                    text: 'Условиями использования',
                    onTap: () => _openUrl('https://sportoteka.by/terms'),
                  ),
                  const Text(
                    ' и ',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.8,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _LinkText(
                    text: 'Политикой конфиденциальности',
                    onTap: () => _openUrl('https://sportoteka.by/privacy'),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(color: _muted, fontSize: 12.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _loading
              ? null
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_green, _greenDark],
                ),
          color: _loading ? const Color(0xFFCBD5E1) : null,
          boxShadow: _loading
              ? []
              : [
                  BoxShadow(
                    color: _green.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _submitLogin,
          style: ButtonStyle(
            elevation: MaterialStateProperty.all(0),
            backgroundColor: MaterialStateProperty.all(Colors.transparent),
            shadowColor: MaterialStateProperty.all(Colors.transparent),
            overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.08)),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _loading
                ? const SizedBox(
                    key: ValueKey('loader'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    key: ValueKey('text'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Войти',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Нет аккаунта?',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _loading ? null : () => Get.toNamed(AppRoutes.signUpScreen),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Зарегистрироваться',
              style: TextStyle(
                color: _greenDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> onTapLogIn() async {
    final email = controller.emailController.text.trim();
    final password = controller.passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Ошибка', 'Пожалуйста, заполните все поля');
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 200) {
        Get.snackbar('Ошибка', 'Ошибка сервера: ${response.statusCode}');
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['user'] != null) {
        final user = data['user'];

        final userId = int.tryParse(user['id'].toString()) ?? 0;
        if (userId == 0) {
          Get.snackbar('Ошибка', 'Не удалось получить ID пользователя');
          return;
        }

        final role = (user['role'] ?? '').toString().trim();

        // Важно: чистим старые данные, чтобы после входа не подтягивались чужие команды.
        await PrefUtils.clearAll();

        await PrefUtils.setIsSignIn(true);
        await PrefUtils.setUserId(userId);
        await PrefUtils.setRole(role);

        debugPrint('✅ LOGIN SUCCESS userId=$userId -> init push');
        try {
          await PushService.instance.init(userId: userId);
          debugPrint('✅ PUSH INIT DONE');
        } catch (e) {
          debugPrint('❌ PUSH INIT ERROR: $e');
        }

        final pref = PrefUtils();
        await pref.init();
        await pref.setUserFirstName((user['first_name'] ?? '').toString());
        await pref.setUserLastName((user['last_name'] ?? '').toString());
        await pref.setUserEmail((user['email'] ?? '').toString());
        await pref.setUserRole((user['role'] ?? '').toString());

        // После успешного входа открываем социальный профиль по умолчанию.
        Get.offAllNamed(AppRoutes.myProfileScreen);
      } else {
        Get.snackbar('Ошибка', data['message'] ?? 'Неверный логин или пароль');
      }
    } catch (e) {
      Get.snackbar('Ошибка', 'Ошибка подключения: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();

  static const Color _heroGreen = Color(0xFF22B981);
  static const Color _heroDark = Color(0xFF0B2F27);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 520;
        final double titleSize = compact ? 24 : 30;

        return Container(
          height: double.infinity,
          padding: EdgeInsets.all(compact ? 24 : 30),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B2F27),
                Color(0xFF12684D),
                Color(0xFF27C28A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -86,
                top: -78,
                child: _BlurCircle(size: 230, color: Colors.white.withOpacity(0.10)),
              ),
              Positioned(
                left: -92,
                bottom: -76,
                child: _BlurCircle(size: 250, color: Colors.white.withOpacity(0.08)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _SportotekaMark(size: 54),
                      SizedBox(width: 14),
                      Text(
                        'Sportoteka',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Рабочее пространство клуба',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Все модули команды — в одном кабинете',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Профиль, состав, календарь, матчи, чаты и аналитика доступны сразу после входа.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.80),
                      fontSize: 14.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _HeroFeatureChip(icon: Icons.person_rounded, text: 'Профиль'),
                      _HeroFeatureChip(icon: Icons.groups_rounded, text: 'Команды'),
                      _HeroFeatureChip(icon: Icons.event_rounded, text: 'Календарь'),
                      _HeroFeatureChip(icon: Icons.analytics_rounded, text: 'Аналитика'),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'После входа',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Откроется ваш профиль Sportoteka',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.76),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _heroDark,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroFeatureChip extends StatelessWidget {
  const _HeroFeatureChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      cursorColor: _LoginScreenState._greenDark,
      style: const TextStyle(
        color: _LoginScreenState._ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _LoginScreenState._muted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: Icon(icon, color: _LoginScreenState._muted, size: 20),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _LoginScreenState._line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _LoginScreenState._line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _LoginScreenState._green, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
      ),
    );
  }
}

class _SportotekaMark extends StatelessWidget {
  const _SportotekaMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF0F8A61)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31C48D).withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_rounded,
          color: Colors.white,
          size: size * 0.48,
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _HeroMiniMetric extends StatelessWidget {
  const _HeroMiniMetric({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: _LoginScreenState._greenDark,
          fontSize: 12.8,
          height: 1.45,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
