import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/push/push_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/core/utils/validation_functions.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';

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

  static const Color _bg = Color(0xFFF6F7F6);
  static const Color _panel = Colors.white;
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _soft2 = Color(0xFFF2F4F2);

  static const Color _text = Color(0xFF0B0F14);
  static const Color _secondary = Color(0xFF5F6670);
  static const Color _subtle = Color(0xFF8A9099);
  static const Color _divider = Color(0xFFE9ECEA);

  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _greenSoft2 = Color(0xFFF8FEFA);
  static const Color _greenBorder = Color(0xFFD7F0E2);

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
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final bool desktop = width >= 980;
              final bool tablet = width >= 700 && width < 980;

              if (desktop || tablet) {
                return _buildTabletDesktop(
                  constraints: constraints,
                  desktop: desktop,
                );
              }

              return _buildMobile(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabletDesktop({
    required BoxConstraints constraints,
    required bool desktop,
  }) {
    final horizontal = desktop ? 28.0 : 18.0;
    final vertical = desktop ? 24.0 : 16.0;
    final minHeight = desktop ? 650.0 : 620.0;

    // Важно: SingleChildScrollView даёт ребёнку неограниченную высоту.
    // Внутри экрана есть Row(crossAxisAlignment: stretch) и Spacer(),
    // поэтому им обязательно нужна конечная высота.
    //
    // Делаем дочерний блок фиксированной высоты: не меньше minHeight
    // и не меньше доступной высоты окна. Если окно ниже minHeight,
    // внешний scroll просто позволит прокрутить экран.
    final availableHeight =
        (constraints.maxHeight - vertical * 2).clamp(0.0, double.infinity);
    final contentHeight =
        availableHeight > minHeight ? availableHeight : minHeight;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: vertical,
      ),
      child: SizedBox(
        height: contentHeight,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktop ? 1180 : 900,
            ),
            child: SizedBox(
              height: contentHeight,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _divider.withOpacity(.82),
                    width: .8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.035),
                      blurRadius: 28,
                      spreadRadius: -18,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: desktop ? 10 : 9,
                      child: _buildInfoPane(desktop: desktop),
                    ),
                    Container(
                      width: 1,
                      color: _divider,
                    ),
                    Expanded(
                      flex: desktop ? 11 : 10,
                      child: _buildFormPane(
                        desktop: desktop,
                        mobile: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile(BoxConstraints constraints) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - 36,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _divider.withOpacity(.82),
                  width: .8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMobileHeader(),
                  Container(height: 1, color: _divider),
                  _buildFormPane(
                    desktop: false,
                    mobile: true,
                  ),
                  Container(height: 1, color: _divider),
                  _buildMobileBenefits(),
                  Container(height: 1, color: _divider),
                  _buildFooter(mobile: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPane({required bool desktop}) {
    return Container(
      color: _panel,
      padding: EdgeInsets.fromLTRB(
        desktop ? 40 : 28,
        desktop ? 34 : 28,
        desktop ? 40 : 28,
        desktop ? 28 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(compact: false),
          SizedBox(height: desktop ? 72 : 52),
          Text(
            'Вход в систему',
            style: AppTypography.screenTitle(
              color: _text,
              scale: desktop ? 1.18 : 1.08,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Text(
              'Добро пожаловать в Sportoteka. Войдите, чтобы открыть профиль, клубный кабинет и рабочие модули.',
              style: AppTypography.body(
                color: _secondary,
                scale: desktop ? 1.03 : 1,
              ),
            ),
          ),
          SizedBox(height: desktop ? 44 : 32),
          const _LoginBenefit(
            icon: Icons.groups_2_outlined,
            title: 'Управление командой',
            subtitle: 'Состав, тренировки, календарь и развитие игроков',
          ),
          const SizedBox(height: 24),
          const _LoginBenefit(
            icon: Icons.query_stats_outlined,
            title: 'Аналитика и отчёты',
            subtitle: 'Метрики, тестирование, динамика и показатели',
          ),
          const SizedBox(height: 24),
          const _LoginBenefit(
            icon: Icons.verified_user_outlined,
            title: 'Рабочая среда клуба',
            subtitle: 'Все основные модули в едином интерфейсе Sportoteka',
          ),
          const Spacer(),
          _buildFooter(mobile: false),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: _buildBrand(compact: true),
    );
  }

  Widget _buildBrand({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SportotekaMark(size: compact ? 34 : 40),
        const SizedBox(width: 10),
        Text(
          'SPORTOTEKA',
          style: compact
              ? AppTypography.sectionTitle(color: _text, scale: 1.05)
              : AppTypography.screenTitle(color: _text),
        ),
      ],
    );
  }

  Widget _buildFormPane({
    required bool desktop,
    required bool mobile,
  }) {
    return Container(
      color: _panel,
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : (desktop ? 54 : 34),
        mobile ? 24 : (desktop ? 64 : 44),
        mobile ? 16 : (desktop ? 54 : 34),
        mobile ? 26 : (desktop ? 42 : 34),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Вход',
                    style: AppTypography.screenTitle(color: _text),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Введите данные вашей учётной записи',
                    style: AppTypography.body(color: _secondary),
                  ),
                  SizedBox(height: mobile ? 26 : 32),
                  _fieldLabel('Эл. почта'),
                  const SizedBox(height: 7),
                  _buildEmailField(),
                  const SizedBox(height: 18),
                  _fieldLabel('Пароль'),
                  const SizedBox(height: 7),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildAgreementBlock(),
                  const SizedBox(height: 22),
                  _buildLoginButton(),
                  const SizedBox(height: 22),
                  _buildCreateAccountRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.formLabel(color: _text),
    );
  }

  Widget _buildEmailField() {
    return _LoginTextField(
      controller: controller.emailController,
      hintText: 'Введите email',
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
        hintText: 'Введите пароль',
        obscureText: isPasswordVisible.value,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onFieldSubmitted: (_) {
          if (!_loading) _submitLogin();
        },
        suffixIcon: IconButton(
          splashRadius: 18,
          tooltip: isPasswordVisible.value
              ? 'Показать пароль'
              : 'Скрыть пароль',
          color: _secondary,
          icon: Icon(
            isPasswordVisible.value
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
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
      () => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _loading
              ? null
              : () => agreedToTerms.value = !agreedToTerms.value,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: agreedToTerms.value,
                      onChanged: _loading
                          ? null
                          : (value) =>
                              agreedToTerms.value = value ?? false,
                      activeColor: _green,
                      checkColor: Colors.white,
                      side: const BorderSide(
                        color: _subtle,
                        width: 1.1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Я согласен с ',
                        style: AppTypography.caption(color: _secondary),
                      ),
                      _LinkText(
                        text: 'Условиями использования',
                        onTap: () =>
                            _openUrl('https://sportoteka.by/terms'),
                      ),
                      Text(
                        ' и ',
                        style: AppTypography.caption(color: _secondary),
                      ),
                      _LinkText(
                        text: 'Политикой конфиденциальности',
                        onTap: () =>
                            _openUrl('https://sportoteka.by/privacy'),
                      ),
                      Text(
                        '.',
                        style: AppTypography.caption(color: _secondary),
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
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _green,
          disabledBackgroundColor: _soft2,
          foregroundColor: Colors.white,
          disabledForegroundColor: _subtle,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: _loading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  key: const ValueKey('text'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Войти',
                      style: AppTypography.actionStrong(color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCreateAccountRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Нет аккаунта?',
          style: AppTypography.secondary(color: _secondary),
        ),
        const SizedBox(width: 5),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _loading
              ? null
              : () => Get.toNamed(AppRoutes.signUpScreen),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 5,
            ),
            child: Text(
              'Зарегистрироваться',
              style: AppTypography.action(color: _greenDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBenefits() {
    return Container(
      color: _panel,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _MobileBenefitRow(
            icon: Icons.groups_2_outlined,
            title: 'Управление командой',
            subtitle: 'Состав, тренировки и календарь',
          ),
          SizedBox(height: 14),
          _MobileBenefitRow(
            icon: Icons.query_stats_outlined,
            title: 'Аналитика и отчёты',
            subtitle: 'Показатели, тестирование и динамика',
          ),
          SizedBox(height: 14),
          _MobileBenefitRow(
            icon: Icons.verified_user_outlined,
            title: 'Единая рабочая среда',
            subtitle: 'Профиль и клубные модули Sportoteka',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter({required bool mobile}) {
    return Padding(
      padding: mobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
          : EdgeInsets.zero,
      child: Text(
        '© Sportoteka\nВсе права защищены',
        textAlign: mobile ? TextAlign.center : TextAlign.left,
        style: AppTypography.commentMeta(color: _subtle).copyWith(height: 1.4),
      ),
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
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode != 200) {
        Get.snackbar(
          'Ошибка',
          'Ошибка сервера: ${response.statusCode}',
        );
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['user'] != null) {
        final user = data['user'];

        final userId = int.tryParse(user['id'].toString()) ?? 0;
        if (userId == 0) {
          Get.snackbar(
            'Ошибка',
            'Не удалось получить ID пользователя',
          );
          return;
        }

        final role = (user['role'] ?? '').toString().trim();

        // Чистим старые данные, чтобы после входа
        // не подтягивались данные прошлого пользователя.
        await PrefUtils.clearAll();

        await PrefUtils.setIsSignIn(true);
        await PrefUtils.setUserId(userId);
        await PrefUtils.setRole(role);

        debugPrint(
          '✅ LOGIN SUCCESS userId=$userId -> init push',
        );

        try {
          await PushService.instance.init(userId: userId);
          debugPrint('✅ PUSH INIT DONE');
        } catch (e) {
          debugPrint('❌ PUSH INIT ERROR: $e');
        }

        final pref = PrefUtils();
        await pref.init();

        await pref.setUserFirstName(
          (user['first_name'] ?? '').toString(),
        );
        await pref.setUserLastName(
          (user['last_name'] ?? '').toString(),
        );
        await pref.setUserEmail(
          (user['email'] ?? '').toString(),
        );
        await pref.setUserRole(
          (user['role'] ?? '').toString(),
        );

        // На macOS не перестраиваем всё дерево маршрутов в тот же момент,
        // когда Flutter может обновлять состояние указателя мыши.
        // Переходим на следующий кадр и без route-анимации.
        if (!mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          // После входа для ВСЕХ ролей открываем главный профиль.
          // MyProfileScreen уже определяет роль пользователя:
          // player / coach / club / parent.
          //
          // Для parent/родитель основной рабочий блок ведёт в
          // «Мои дети», где активируется Parent Key и открывается
          // дневник привязанного игрока.
          Get.offAll<void>(
            () => const MyProfileScreen(),
            transition: Transition.noTransition,
            duration: Duration.zero,
          );
        });
      } else {
        Get.snackbar(
          'Ошибка',
          data['message'] ?? 'Неверный логин или пароль',
        );
      }
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        'Ошибка подключения: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
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
      cursorColor: _LoginScreenState._green,
      style: AppTypography.formText(color: _LoginScreenState._text),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.formHint(color: _LoginScreenState._subtle),
        filled: true,
        fillColor: _LoginScreenState._panel,
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _LoginScreenState._divider,
            width: .9,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _LoginScreenState._divider,
            width: .9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _LoginScreenState._green,
            width: 1.1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1,
          ),
        ),
        errorStyle: AppTypography.commentMeta(
          color: const Color(0xFFDC2626),
        ),
      ),
    );
  }
}

class _SportotekaMark extends StatelessWidget {
  const _SportotekaMark({
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _LoginScreenState._greenSoft,
        borderRadius: BorderRadius.circular(size * .23),
        border: Border.all(
          color: _LoginScreenState._greenBorder,
          width: .8,
        ),
      ),
      child: Icon(
        Icons.sports_soccer_outlined,
        color: _LoginScreenState._greenDark,
        size: size * .52,
      ),
    );
  }
}

class _LoginBenefit extends StatelessWidget {
  const _LoginBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _LoginScreenState._greenSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _LoginScreenState._greenBorder,
              width: .8,
            ),
          ),
          child: Icon(
            icon,
            color: _LoginScreenState._greenDark,
            size: 20,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.itemTitle(color: _LoginScreenState._text),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.secondary(
                  color: _LoginScreenState._secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileBenefitRow extends StatelessWidget {
  const _MobileBenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _LoginScreenState._greenSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _LoginScreenState._greenBorder,
              width: .8,
            ),
          ),
          child: Icon(
            icon,
            color: _LoginScreenState._greenDark,
            size: 18,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.menuTitle(color: _LoginScreenState._text),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTypography.caption(
                  color: _LoginScreenState._secondary,
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
  const _LinkText({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: AppTypography.captionMedium(
          color: _LoginScreenState._greenDark,
        ),
      ),
    );
  }
}
