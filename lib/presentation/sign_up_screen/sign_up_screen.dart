import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/widgets/custom_elevated_button.dart';
import 'package:sportoteka/widgets/custom_text_form_field.dart';
import 'controller/sign_up_controller.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({Key? key}) : super(key: key);

  final SignUpController controller = Get.put(SignUpController());

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// чекбокс согласия c EULA/Privacy (обычная регистрация)
  final RxBool agreedToTerms = false.obs;

  // Единый визуальный язык Auth → Hub → Profile.
  static const Color _bg = Color(0xFFF6F7F6);
  static const Color _panel = Colors.white;
  static const Color _soft = Color(0xFFF7F8F7);
  static const Color _text = Color(0xFF0B0F14);
  static const Color _secondary = Color(0xFF5F6670);
  static const Color _subtle = Color(0xFF8A9099);
  static const Color _divider = Color(0xFFE9ECEA);
  static const Color _green = Color(0xFF00A750);
  static const Color _greenDark = Color(0xFF067A46);
  static const Color _greenSoft = Color(0xFFF3FAF6);
  static const Color _greenSoft2 = Color(0xFFF8FCF9);
  static const Color _greenBorder = Color(0xFFD7F0E2);
  static const Color _graphite = Color(0xFF111827);
  static const Color _graphiteSoft = Color(0xFF374151);
  static const Color _soft2 = Color(0xFFF2F4F2);

  final Map<String, String> roleMapping = const {
  "Тренер": "coach",
  "Пользователь": "user",
  "Игрок": "player",
  "Родитель": "parent",
};

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar("Ошибка", "Не удалось открыть ссылку");
    }
  }

  @override
  Widget build(BuildContext context) {
    mediaQueryData = MediaQuery.of(context);

    if (controller.selectedRole.value.isEmpty) {
      controller.selectedRole.value = "coach";
    }

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final desktop = width >= 980;
            final tablet = width >= 700 && width < 980;

            if (desktop || tablet) {
              return _buildWideRegistration(
                context: context,
                constraints: constraints,
                desktop: desktop,
              );
            }

            return _buildMobileRegistration(
              context,
              constraints,
            );
          },
        ),
      ),
    );
  }

  Widget _buildWideRegistration({
    required BuildContext context,
    required BoxConstraints constraints,
    required bool desktop,
  }) {
    final horizontal = desktop ? 28.0 : 18.0;
    final vertical = desktop ? 24.0 : 16.0;
    final minHeight = desktop ? 720.0 : 680.0;

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
            child: Container(
              height: contentHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _divider,
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
                  SizedBox(
                    width: desktop ? 360 : 300,
                    child: _buildRegistrationIntro(
                      desktop: desktop,
                    ),
                  ),
                  Container(
                    width: 1,
                    color: _divider,
                  ),
                  Expanded(
                    child: _buildRegistrationFormPane(
                      context: context,
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
    );
  }

  Widget _buildMobileRegistration(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 22),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 36).clamp(0.0, double.infinity),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _divider,
                  width: .8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: _buildBrand(compact: true),
                  ),
                  Container(height: 1, color: _divider),
                  _buildRegistrationFormPane(
                    context: context,
                    desktop: false,
                    mobile: true,
                  ),
                  Container(height: 1, color: _divider),
                  _buildRegistrationMobileInfo(),
                  Container(height: 1, color: _divider),
                  _buildRegistrationFooter(mobile: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationIntro({required bool desktop}) {
    return Container(
      color: _panel,
      padding: EdgeInsets.fromLTRB(
        desktop ? 34 : 26,
        desktop ? 30 : 24,
        desktop ? 34 : 26,
        desktop ? 28 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(compact: false),
          SizedBox(height: desktop ? 88 : 62),
          Text(
            'Создайте аккаунт\nSportoteka',
            style: _hubTitle(desktop ? 28 : 25),
          ),
          const SizedBox(height: 12),
          Text(
            'Выберите свою роль. После регистрации Sportoteka '
            'покажет только доступные вашему аккаунту рабочие пространства.',
            style: _hubBody(desktop ? 13.4 : 13),
          ),
          SizedBox(height: desktop ? 42 : 32),
          _buildRoleInfo(
            icon: Icons.sports_soccer_outlined,
            title: 'Игрок',
            text: 'Профиль, команда, дневник и личный прогресс',
          ),
          const SizedBox(height: 14),
          _buildRoleInfo(
            icon: Icons.sports_outlined,
            title: 'Тренер',
            text: 'Команда, состав, календарь и рабочие модули',
          ),
          const SizedBox(height: 14),
          _buildRoleInfo(
            icon: Icons.family_restroom_rounded,
            title: 'Родитель',
            text: 'Доступ к ребёнку через персональный Parent Key',
          ),
          const Spacer(),
          _buildRegistrationFooter(mobile: false),
        ],
      ),
    );
  }

  Widget _buildRegistrationFormPane({
    required BuildContext context,
    required bool desktop,
    required bool mobile,
  }) {
    return Container(
      color: _panel,
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : (desktop ? 50 : 34),
        mobile ? 22 : (desktop ? 34 : 28),
        mobile ? 16 : (desktop ? 50 : 34),
        mobile ? 26 : (desktop ? 34 : 28),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Регистрация',
                    style: _hubTitle(mobile ? 24 : 27),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Заполните данные учётной записи',
                    style: _hubBody(mobile ? 12.6 : 13),
                  ),
                  const SizedBox(height: 22),

                  _buildClubCtaBanner(context),
                  const SizedBox(height: 20),

                  _hubFieldLabel('Имя'),
                  const SizedBox(height: 7),
                  _buildFirstNameField(),
                  const SizedBox(height: 14),

                  _hubFieldLabel('Фамилия'),
                  const SizedBox(height: 7),
                  _buildLastNameField(),
                  const SizedBox(height: 14),

                  _hubFieldLabel('Эл. почта'),
                  const SizedBox(height: 7),
                  _buildEmailField(),
                  const SizedBox(height: 14),

                  _hubFieldLabel('Пароль'),
                  const SizedBox(height: 7),
                  _buildPasswordField(),
                  const SizedBox(height: 14),

                  _hubFieldLabel('Роль'),
                  const SizedBox(height: 7),
                  _buildRoleDropdown(),
                  const SizedBox(height: 10),

                  _buildParentAccessHint(),
                  const SizedBox(height: 14),

                  Obx(
                    () => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            agreedToTerms.value = !agreedToTerms.value,
                        borderRadius: BorderRadius.circular(8),
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
                                    onChanged: (v) =>
                                        agreedToTerms.value = v ?? false,
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
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Я согласен с ',
                                      style: _hubCaption(),
                                    ),
                                    _AuthLinkText(
                                      text: 'Условиями использования',
                                      onTap: () => _openUrl(
                                        'https://sportoteka.by/terms',
                                      ),
                                    ),
                                    Text(' и ', style: _hubCaption()),
                                    _AuthLinkText(
                                      text: 'Политикой конфиденциальности',
                                      onTap: () => _openUrl(
                                        'https://sportoteka.by/privacy',
                                      ),
                                    ),
                                    Text('.', style: _hubCaption()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!agreedToTerms.value) {
                          Get.snackbar(
                            'Требуется согласие',
                            'Вы должны подтвердить Условия и Политику, чтобы продолжить',
                            snackPosition: SnackPosition.BOTTOM,
                            margin: const EdgeInsets.all(12),
                          );
                          return;
                        }

                        if (_formKey.currentState?.validate() ?? false) {
                          controller.registerUser();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Зарегистрироваться',
                        style: AppTypography.custom(
                          size: 13.2,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAlreadyHaveAccount(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationMobileInfo() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: _greenDark,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Роль определяет доступные кабинеты. '
              'Родитель связывается с конкретным ребёнком только через Parent Key.',
              style: TextStyle(
                color: _secondary,
                fontSize: 10.8,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand({required bool compact}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _greenSoft,
            borderRadius: BorderRadius.circular(compact ? 8 : 9),
            border: Border.all(
              color: _greenBorder,
              width: .8,
            ),
          ),
          child: Icon(
            Icons.sports_soccer_outlined,
            color: _greenDark,
            size: compact ? 18 : 21,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SPORTOTEKA',
          style: AppTypography.custom(
            size: compact ? 15.2 : 16.4,
            weight: FontWeight.w700,
            color: _text,
            height: 1,
            letterSpacing: .15,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleInfo({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _greenSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _greenBorder, width: .8),
          ),
          child: Icon(
            icon,
            color: _greenDark,
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
                style: AppTypography.custom(
                  size: 12.2,
                  weight: FontWeight.w600,
                  color: _text,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: AppTypography.custom(
                  size: 10.8,
                  weight: FontWeight.w400,
                  color: _secondary,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _hubFieldLabel(String text) {
    return Text(
      text,
      style: AppTypography.custom(
        size: 12,
        weight: FontWeight.w600,
        color: _text,
        height: 1.18,
        letterSpacing: 0,
      ),
    );
  }

  TextStyle _hubTitle(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w600,
      color: _text,
      height: 1.18,
      letterSpacing: 0,
    );
  }

  TextStyle _hubBody(double size) {
    return AppTypography.custom(
      size: size,
      weight: FontWeight.w400,
      color: _secondary,
      height: 1.32,
      letterSpacing: 0,
    );
  }

  TextStyle _hubCaption() {
    return AppTypography.custom(
      size: 10.8,
      weight: FontWeight.w500,
      color: _subtle,
      height: 1.18,
      letterSpacing: 0,
    );
  }

  Widget _buildRegistrationFooter({required bool mobile}) {
    return Padding(
      padding: mobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
          : EdgeInsets.zero,
      child: Text(
        '© Sportoteka · Все права защищены',
        textAlign: mobile ? TextAlign.center : TextAlign.left,
        style: AppTypography.custom(
          size: 10.3,
          weight: FontWeight.w400,
          color: _subtle,
          height: 1.4,
          letterSpacing: 0,
        ),
      ),
    );
  }

  // ---------- CTA: Клубы ----------

  Widget _buildClubCtaBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openClubApplicationSheet(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
          decoration: BoxDecoration(
            color: _greenSoft2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _greenBorder,
              width: .8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _divider,
                    width: .8,
                  ),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  color: _greenDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Клуб / ДЮСШ / СДЮШОР',
                      style: AppTypography.custom(
                        size: 12.3,
                        weight: FontWeight.w600,
                        color: _text,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Отдельная регистрация клуба по заявке',
                      style: AppTypography.custom(
                        size: 10.6,
                        weight: FontWeight.w400,
                        color: _secondary,
                        height: 1.35,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _greenDark,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openClubApplicationSheet(BuildContext context) {
    controller.resetClubForm();

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (dialogContext, constraints) {
            final width = MediaQuery.sizeOf(dialogContext).width;
            final mobile = width < 700;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mobile ? 540 : 920,
                maxHeight: mobile ? 760 : 720,
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _divider,
                    width: .8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 36,
                      spreadRadius: -10,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: mobile
                    ? _buildClubApplicationMobile(dialogContext)
                    : _buildClubApplicationWide(dialogContext),
              ),
            );
          },
        ),
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.42),
    );
  }

  Widget _buildClubApplicationWide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 290,
          child: Container(
            color: _soft,
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrand(compact: false),
                const SizedBox(height: 54),
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _greenBorder,
                      width: .8,
                    ),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: _graphiteSoft,
                    size: 23,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'КЛУБ\nДЮСШ\nСДЮШОР',
                  style: AppTypography.custom(
                    size: 22.5,
                    weight: FontWeight.w600,
                    color: _text,
                    height: 1.08,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Создайте заявку организации. '
                  'После проверки аккаунт получит доступ к клубному кабинету Sportoteka.',
                  style: _hubBody(12.3),
                ),
                const SizedBox(height: 28),
                _buildClubApplicationInfoRow(
                  Icons.groups_2_outlined,
                  'Команды и состав',
                ),
                const SizedBox(height: 13),
                _buildClubApplicationInfoRow(
                  Icons.calendar_month_outlined,
                  'Календарь и тренировки',
                ),
                const SizedBox(height: 13),
                _buildClubApplicationInfoRow(
                  Icons.query_stats_outlined,
                  'Аналитика и развитие',
                ),
                const Spacer(),
                Text(
                  'Заявка создаёт аккаунт организации '
                  'со статусом «ожидает подтверждения».',
                  style: AppTypography.custom(
                    size: 9.9,
                    weight: FontWeight.w400,
                    color: _subtle,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 1,
          color: _divider,
        ),
        Expanded(
          child: _buildClubApplicationForm(
            context,
            mobile: false,
          ),
        ),
      ],
    );
  }

  Widget _buildClubApplicationMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _divider,
                width: .7,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildBrand(compact: true),
              const Spacer(),
              IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Get.back(),
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: _text,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildClubApplicationForm(
            context,
            mobile: true,
          ),
        ),
      ],
    );
  }

  Widget _buildClubApplicationInfoRow(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _divider,
              width: .7,
            ),
          ),
          child: Icon(
            icon,
            color: _greenDark,
            size: 16,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTypography.custom(
              size: 10.8,
              weight: FontWeight.w600,
              color: _text,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClubApplicationForm(
    BuildContext context, {
    required bool mobile,
  }) {
    return Form(
      key: controller.clubFormKey,
      child: SingleChildScrollView(
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          mobile ? 16 : 34,
          mobile ? 20 : 28,
          mobile ? 16 : 34,
          mobile ? 24 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Заявка: КЛУБ / ДЮСШ / СДЮШОР',
                          style: _hubTitle(21.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Заполните данные организации',
                          style: _hubBody(12.2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _text,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                'Заявка: КЛУБ / ДЮСШ / СДЮШОР',
                style: _hubTitle(20.8),
              ),
              const SizedBox(height: 6),
              Text(
                'Заполните данные организации',
                style: _hubBody(12.2),
              ),
            ],

            const SizedBox(height: 22),

            _hubFieldLabel(
              'Наименование КЛУБА / ДЮСШ / СДЮШОР',
            ),
            const SizedBox(height: 7),
            _buildClubInputField(
              controller: controller.clubNameController,
              hintText: 'Например: ФК Спортотека',
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Введите наименование'
                      : null,
            ),

            const SizedBox(height: 14),

            _hubFieldLabel('Краткое описание'),
            const SizedBox(height: 7),
            _buildClubInputField(
              controller: controller.clubDescriptionController,
              hintText: 'Расскажите об организации',
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Введите описание'
                      : null,
            ),

            const SizedBox(height: 14),

            _hubFieldLabel('Адрес'),
            const SizedBox(height: 7),
            _buildClubInputField(
              controller: controller.clubAddressController,
              hintText: 'Город, улица, дом',
              validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Введите адрес'
                      : null,
            ),

            const SizedBox(height: 14),

            _hubFieldLabel('E-mail организации'),
            const SizedBox(height: 7),
            _buildClubInputField(
              controller: controller.clubEmailController,
              hintText: 'club@example.com',
              textInputType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || !GetUtils.isEmail(value)) {
                  return 'Введите корректный email';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            _hubFieldLabel('Пароль'),
            const SizedBox(height: 7),
            Obx(
              () => _buildClubInputField(
                controller: controller.clubPasswordController,
                hintText: 'Минимум 6 символов',
                obscureText:
                    controller.clubIsShowPassword.value,
                suffixIcon: IconButton(
                  splashRadius: 18,
                  icon: Icon(
                    controller.clubIsShowPassword.value
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _greenDark,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clubIsShowPassword.value =
                        !controller.clubIsShowPassword.value;
                  },
                ),
                validator: (value) =>
                    (value == null || value.length < 6)
                        ? 'Пароль должен быть минимум 6 символов'
                        : null,
              ),
            ),

            const SizedBox(height: 13),

            Obx(
              () => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    controller.clubAgreedToTerms.value =
                        !controller.clubAgreedToTerms.value;
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 1),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value:
                                  controller.clubAgreedToTerms.value,
                              onChanged: (v) {
                                controller.clubAgreedToTerms.value =
                                    v ?? false;
                              },
                              activeColor: _green,
                              checkColor: Colors.white,
                              side: const BorderSide(
                                color: _subtle,
                                width: 1.1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment:
                                WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Я согласен с ',
                                style: _hubCaption(),
                              ),
                              _AuthLinkText(
                                text: 'Условиями использования',
                                onTap: () => _openUrl(
                                  'https://sportoteka.by/terms',
                                ),
                              ),
                              Text(
                                ' и ',
                                style: _hubCaption(),
                              ),
                              _AuthLinkText(
                                text:
                                    'Политикой конфиденциальности',
                                onTap: () => _openUrl(
                                  'https://sportoteka.by/privacy',
                                ),
                              ),
                              Text(
                                '.',
                                style: _hubCaption(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: () async {
                  if (!controller.clubAgreedToTerms.value) {
                    Get.snackbar(
                      'Требуется согласие',
                      'Подтвердите Условия и Политику, '
                          'чтобы продолжить',
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(12),
                    );
                    return;
                  }

                  if (controller.clubFormKey.currentState
                          ?.validate() ??
                      false) {
                    await controller.submitClubApplication();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Отправить заявку',
                  style: AppTypography.custom(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'После отправки будет создан аккаунт '
              'КЛУБА / ДЮСШ / СДЮШОР со статусом '
              '«ожидает подтверждения».',
              textAlign: mobile
                  ? TextAlign.center
                  : TextAlign.left,
              style: AppTypography.custom(
                size: 9.8,
                weight: FontWeight.w400,
                color: _subtle,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubInputField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? textInputType,
    bool obscureText = false,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: textInputType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: AppTypography.custom(
        size: 13,
        weight: FontWeight.w500,
        color: _text,
        height: 1.25,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.custom(
          size: 12.8,
          weight: FontWeight.w400,
          color: _subtle,
          height: 1.25,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: _greenSoft2,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 16 : 14,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _greenBorder,
            width: .9,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _greenBorder,
            width: .9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _green,
            width: 1.05,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
      ),
    );
  }

  // ---------- Поля обычной формы ----------

  Widget _buildFirstNameField() {
    return _buildClubInputField(
      controller: controller.firstNameController,
      hintText: 'Имя',
      validator: (value) =>
          (value == null || value.trim().isEmpty)
              ? 'Введите имя'
              : null,
    );
  }

  Widget _buildLastNameField() {
    return _buildClubInputField(
      controller: controller.lastNameController,
      hintText: 'Фамилия',
      validator: (value) =>
          (value == null || value.trim().isEmpty)
              ? 'Введите фамилию'
              : null,
    );
  }

  Widget _buildEmailField() {
    return _buildClubInputField(
      controller: controller.emailController,
      hintText: 'Email',
      textInputType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || !GetUtils.isEmail(value)) {
          return 'Введите корректный email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => _buildClubInputField(
        controller: controller.passwordController,
        hintText: 'Пароль',
        obscureText: controller.isShowPassword.value,
        suffixIcon: IconButton(
          splashRadius: 18,
          icon: Icon(
            controller.isShowPassword.value
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _greenDark,
            size: 18,
          ),
          onPressed: () {
            controller.isShowPassword.value =
                !controller.isShowPassword.value;
          },
        ),
        validator: (value) =>
            (value == null || value.length < 6)
                ? 'Пароль должен быть минимум 6 символов'
                : null,
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Obx(() {
      final currentRoleKey = roleMapping.entries
          .firstWhere(
            (e) => e.value == controller.selectedRole.value,
            orElse: () =>
                MapEntry(roleMapping.keys.first, roleMapping.values.first),
          )
          .key;

      return DropdownButtonFormField<String>(
        value: currentRoleKey,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _greenDark,
          size: 20,
        ),
        style: AppTypography.custom(
          size: 13,
          weight: FontWeight.w500,
          color: _text,
          height: 1.25,
          letterSpacing: 0,
        ),
        items: roleMapping.keys
            .map(
              (role) => DropdownMenuItem<String>(
                value: role,
                child: Text(
                  role,
                  style: AppTypography.custom(
                    size: 13,
                    weight: FontWeight.w500,
                    color: _text,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            controller.selectedRole.value = roleMapping[value]!;
          }
        },
        decoration: InputDecoration(
          hintText: 'Выберите роль',
          filled: true,
          fillColor: _greenSoft2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: _greenBorder,
              width: .9,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: _greenBorder,
              width: .9,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: _green,
              width: 1.05,
            ),
          ),
        ),
      );
    });
  }


  Widget _buildParentAccessHint() {
    return Obx(() {
      final isParent =
          controller.selectedRole.value.trim().toLowerCase() == 'parent';

      if (!isParent) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _greenBorder,
            width: .8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.family_restroom_rounded,
                color: _greenDark,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Доступ родителя к ребёнку',
                    style: AppTypography.custom(
                      size: 11.8,
                      weight: FontWeight.w600,
                      color: _text,
                      height: 1.20,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'После регистрации откройте «Мои дети» и введите '
                    'Parent Key, который клуб выдаёт именно для вашего ребёнка.',
                    style: AppTypography.custom(
                      size: 10.5,
                      weight: FontWeight.w400,
                      color: _secondary,
                      height: 1.32,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }


  // ---------- Кнопки / ссылки ----------

  Widget _buildAlreadyHaveAccount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Уже есть аккаунт?',
          style: AppTypography.custom(
            size: 12.2,
            weight: FontWeight.w400,
            color: _secondary,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 5),
        TextButton(
          onPressed: () => Get.back(),
          style: TextButton.styleFrom(
            foregroundColor: _greenDark,
          ),
          child: Text(
            'Войти',
            style: AppTypography.custom(
              size: 12.2,
              weight: FontWeight.w600,
              color: _greenDark,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLinkText extends StatelessWidget {
  const _AuthLinkText({
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
        style: AppTypography.custom(
          size: 11.5,
          weight: FontWeight.w600,
          color: SignUpScreen._greenDark,
          height: 1.42,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
