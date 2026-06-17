import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/widgets/custom_elevated_button.dart';
import 'package:sportoteka/widgets/custom_text_form_field.dart';
import 'controller/sign_up_controller.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({Key? key}) : super(key: key);

  final SignUpController controller = Get.put(SignUpController());

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// чекбокс согласия c EULA/Privacy (обычная регистрация)
  final RxBool agreedToTerms = false.obs;

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
      backgroundColor: appTheme.bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 36.v),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36.v),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Регистрация", style: theme.textTheme.headlineMedium),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Пожалуйста, введите свои данные для регистрации.",
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 18),

                      /// ✅ КЛУБЫ — отдельный платный план (заявка)
                      _buildClubCtaBanner(context),
                      const SizedBox(height: 22),

                      _buildFirstNameField(),
                      const SizedBox(height: 16),

                      _buildLastNameField(),
                      const SizedBox(height: 16),

                      _buildEmailField(),
                      const SizedBox(height: 16),

                      _buildPasswordField(),
                      const SizedBox(height: 16),

                      _buildRoleDropdown(),
                      const SizedBox(height: 20),

                      // Чекбокс согласия с Terms/Privacy
                      Obx(
                        () => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: agreedToTerms.value,
                          onChanged: (v) => agreedToTerms.value = v ?? false,
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text("Я согласен с "),
                              GestureDetector(
                                onTap: () => _openUrl('https://sportoteka.by/terms'),
                                child: const Text(
                                  "Условиями использования",
                                  style: TextStyle(decoration: TextDecoration.underline),
                                ),
                              ),
                              const Text(" и "),
                              GestureDetector(
                                onTap: () => _openUrl('https://sportoteka.by/privacy'),
                                child: const Text(
                                  "Политикой конфиденциальности",
                                  style: TextStyle(decoration: TextDecoration.underline),
                                ),
                              ),
                              const Text("."),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Кнопка регистрации
                      CustomElevatedButton(
                        text: "Зарегистрироваться",
                        onPressed: () {
                          if (!agreedToTerms.value) {
                            Get.snackbar(
                              "Требуется согласие",
                              "Вы должны подтвердить Условия и Политику, чтобы продолжить",
                              snackPosition: SnackPosition.BOTTOM,
                              margin: const EdgeInsets.all(12),
                            );
                            return;
                          }
                          if (_formKey.currentState?.validate() ?? false) {
                            controller.registerUser();
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildAlreadyHaveAccount(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- CTA: Клубы ----------

 Widget _buildClubCtaBanner(BuildContext context) {
  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () => _openClubApplicationSheet(context),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.95),
            theme.colorScheme.primary.withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Клуб / ДЮСШ / СДЮШОР / Команда",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Платный план — расширенный ключ доступа. Регистрация по заявке.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "Подать заявку",
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  void _openClubApplicationSheet(BuildContext context) {
    // сбросим поля перед открытием
    controller.resetClubForm();

    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: appTheme.bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Form(
            key: controller.clubFormKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // “ручка”
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Заявка для клуба",
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.close),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "После подтверждения с вашей почты доступ будет расширен. Пока — автоматический вход после отправки.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: appTheme.gray600),
                  ),
                  const SizedBox(height: 18),

                  CustomTextFormField(
                    controller: controller.clubNameController,
                    hintText: "Наименование клуба / команды",
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Введите наименование" : null,
                  ),
                  const SizedBox(height: 14),

                  CustomTextFormField(
                    controller: controller.clubDescriptionController,
                    hintText: "Краткое описание",
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Введите описание" : null,
                  ),
                  const SizedBox(height: 14),

                  CustomTextFormField(
                    controller: controller.clubAddressController,
                    hintText: "Адрес",
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Введите адрес" : null,
                  ),
                  const SizedBox(height: 14),

                  CustomTextFormField(
                    controller: controller.clubEmailController,
                    hintText: "E-mail",
                    textInputType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || !GetUtils.isEmail(value)) return "Введите корректный email";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Obx(
                    () => CustomTextFormField(
                      controller: controller.clubPasswordController,
                      hintText: "Пароль",
                      obscureText: controller.clubIsShowPassword.value,
                      suffix: IconButton(
                        icon: Icon(
                          controller.clubIsShowPassword.value ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => controller.clubIsShowPassword.value =
                            !controller.clubIsShowPassword.value,
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? "Пароль должен быть минимум 6 символов"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Obx(
                    () => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: controller.clubAgreedToTerms.value,
                      onChanged: (v) => controller.clubAgreedToTerms.value = v ?? false,
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Я согласен с "),
                          GestureDetector(
                            onTap: () => _openUrl('https://sportoteka.by/terms'),
                            child: const Text(
                              "Условиями использования",
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ),
                          const Text(" и "),
                          GestureDetector(
                            onTap: () => _openUrl('https://sportoteka.by/privacy'),
                            child: const Text(
                              "Политикой конфиденциальности",
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ),
                          const Text("."),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  CustomElevatedButton(
                    text: "Отправить заявку",
                    onPressed: () async {
                      if (!controller.clubAgreedToTerms.value) {
                        Get.snackbar(
                          "Требуется согласие",
                          "Подтвердите Условия и Политику, чтобы продолжить",
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(12),
                        );
                        return;
                      }
                      if (controller.clubFormKey.currentState?.validate() ?? false) {
                        await controller.submitClubApplication();
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  Text(
                    "Нажимая «Отправить заявку», вы создаёте аккаунт клуба со статусом «ожидает подтверждения».",
                    style: theme.textTheme.bodySmall?.copyWith(color: appTheme.gray600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // ---------- Поля обычной формы ----------

  Widget _buildFirstNameField() {
    return CustomTextFormField(
      controller: controller.firstNameController,
      hintText: "Имя",
      validator: (value) => (value == null || value.isEmpty) ? "Введите имя" : null,
    );
  }

  Widget _buildLastNameField() {
    return CustomTextFormField(
      controller: controller.lastNameController,
      hintText: "Фамилия",
      validator: (value) => (value == null || value.isEmpty) ? "Введите фамилию" : null,
    );
  }

  Widget _buildEmailField() {
    return CustomTextFormField(
      controller: controller.emailController,
      hintText: "Email",
      textInputType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || !GetUtils.isEmail(value)) return "Введите корректный email";
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Obx(
      () => CustomTextFormField(
        controller: controller.passwordController,
        hintText: "Пароль",
        obscureText: controller.isShowPassword.value,
        suffix: IconButton(
          icon: Icon(
            controller.isShowPassword.value ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () => controller.isShowPassword.value = !controller.isShowPassword.value,
        ),
        validator: (value) =>
            (value == null || value.length < 6) ? "Пароль должен быть минимум 6 символов" : null,
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Obx(() {
      final currentRoleKey = roleMapping.entries
          .firstWhere(
            (e) => e.value == controller.selectedRole.value,
            orElse: () => MapEntry(roleMapping.keys.first, roleMapping.values.first),
          )
          .key;

      return DropdownButtonFormField<String>(
        value: currentRoleKey,
        items: roleMapping.keys
            .map((role) => DropdownMenuItem<String>(value: role, child: Text(role)))
            .toList(),
        onChanged: (value) {
          if (value != null) controller.selectedRole.value = roleMapping[value]!;
        },
        decoration: const InputDecoration(
          labelText: 'Выберите роль',
          border: OutlineInputBorder(),
        ),
      );
    });
  }

  // ---------- Кнопки / ссылки ----------

  Widget _buildAlreadyHaveAccount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Уже есть аккаунт?"),
        TextButton(onPressed: () => Get.back(), child: const Text("Войти")),
      ],
    );
  }
}
