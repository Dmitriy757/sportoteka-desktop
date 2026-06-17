import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/validation_functions.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/widgets/custom_elevated_button.dart';
import 'package:sportoteka/widgets/custom_text_form_field.dart';
import 'package:url_launcher/url_launcher.dart';

import 'controller/login_controller.dart';
import 'package:sportoteka/core/push/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginController controller = Get.put(LoginController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RxBool isPasswordVisible = true.obs;

  // согласие
  final RxBool agreedToTerms = false.obs;
  bool alreadyAgreed = false;

  bool _loading = false;

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
      Get.snackbar("Ошибка", "Не удалось открыть ссылку");
    }
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
        backgroundColor: appTheme.bgColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.h, vertical: 36.v),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 36.v),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Вход в аккаунт",
                              style: theme.textTheme.headlineMedium!.copyWith(
                                color: appTheme.black900,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.v),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Введите свои данные для входа.",
                              style: theme.textTheme.bodyLarge!.copyWith(
                                color: appTheme.black900,
                                height: 1.50,
                              ),
                            ),
                          ),
                          SizedBox(height: 45.v),

                          // Email
                          CustomTextFormField(
                            controller: controller.emailController,
                            hintText: "Эл. почта",
                            textInputType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || (!isValidEmail(value, isRequired: true))) {
                                return "Введите корректный email.";
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20.v),

                          // Пароль
                          Obx(
                            () => CustomTextFormField(
                              controller: controller.passwordController,
                              hintText: "Пароль",
                              obscureText: isPasswordVisible.value,
                              suffix: IconButton(
                                icon: Icon(
                                  isPasswordVisible.value
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  isPasswordVisible.value = !isPasswordVisible.value;
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Введите пароль.";
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(height: 20.v),

                          // Согласие
                          Obx(
                            () => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: agreedToTerms.value,
                              onChanged: _loading ? null : (v) => agreedToTerms.value = v ?? false,
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

                          SizedBox(height: 24.v),

                          CustomElevatedButton(
                            text: _loading ? "Вход..." : "Войти",
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!agreedToTerms.value && !alreadyAgreed) {
                                      Get.snackbar(
                                        "Требуется согласие",
                                        "Подтвердите Условия и Политику, чтобы продолжить",
                                      );
                                      return;
                                    }
                                    if (agreedToTerms.value && !alreadyAgreed) {
                                      await PrefUtils.setAgreedEula(true);
                                      alreadyAgreed = true;
                                    }
                                    if (_formKey.currentState!.validate()) {
                                      await onTapLogIn();
                                    }
                                  },
                          ),

                          const Spacer(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Нет аккаунта?", style: CustomTextStyles.bodyLargeGray60001),
                              GestureDetector(
                                onTap: _loading ? null : () => Get.toNamed(AppRoutes.signUpScreen),
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4.h),
                                  child: Text(
                                    "Зарегистрироваться",
                                    style: CustomTextStyles.titleMediumPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> onTapLogIn() async {
    final email = controller.emailController.text.trim();
    final password = controller.passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar("Ошибка", "Пожалуйста, заполните все поля");
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
        Get.snackbar("Ошибка", "Ошибка сервера: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] == 'success' && data['user'] != null) {
        final user = data['user'];

        final userId = int.tryParse(user['id'].toString()) ?? 0;
        if (userId == 0) {
          Get.snackbar("Ошибка", "Не удалось получить ID пользователя");
          return;
        }

        final role = (user['role'] ?? '').toString().trim();

        // ✅ КЛЮЧЕВО: сначала чистим старые данные, чтобы не было "чужих команд"
        await PrefUtils.clearAll();

        // ✅ Сохраняем всё в одном стиле (STATIC)
        await PrefUtils.setIsSignIn(true);
        await PrefUtils.setUserId(userId);
        await PrefUtils.setRole(role);
        
        // ✅ PUSH: включаем после сохранения userId
print("✅ LOGIN SUCCESS userId=$userId -> init push");
try {
  await PushService.instance.init(userId: userId);
  print("✅ PUSH INIT DONE");
} catch (e) {
  print("❌ PUSH INIT ERROR: $e");
}


        final pref = PrefUtils();
await pref.init();

await pref.setUserFirstName((user['first_name'] ?? '').toString());
await pref.setUserLastName((user['last_name'] ?? '').toString());
await pref.setUserEmail((user['email'] ?? '').toString());
await pref.setUserRole((user['role'] ?? '').toString());


        // ✅ Роутинг по роли (если хочешь иначе — скажи)
        Get.offAllNamed(
  AppRoutes.homeContainerScreen,
  arguments: {"startTab": role == 'club' ? "club" : "home"},
);
      } else {
        Get.snackbar("Ошибка", data['message'] ?? "Неверный логин или пароль");
      }
    } catch (e) {
      Get.snackbar("Ошибка", "Ошибка подключения: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
