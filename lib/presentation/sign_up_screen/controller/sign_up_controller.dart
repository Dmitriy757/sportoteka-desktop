import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/auth/club_access_screen.dart';

class SignUpController extends GetxController {
  // ==========================
  // Обычная регистрация
  // ==========================

  final TextEditingController firstNameController =
      TextEditingController();

  final TextEditingController lastNameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final RxBool isShowPassword = true.obs;

  final RxString selectedRole = 'coach'.obs;

  // ==========================
  // Клубная заявка
  // ==========================

  final GlobalKey<FormState> clubFormKey =
      GlobalKey<FormState>();

  final TextEditingController clubNameController =
      TextEditingController();

  final TextEditingController clubDescriptionController =
      TextEditingController();

  final TextEditingController clubAddressController =
      TextEditingController();

  final TextEditingController clubEmailController =
      TextEditingController();

  final TextEditingController clubPasswordController =
      TextEditingController();

  final RxBool clubIsShowPassword = true.obs;

  final RxBool clubAgreedToTerms = false.obs;

  final RxBool isLoading = false.obs;

  // ==========================
  // API
  // ==========================

  static const String _registerUserUrl =
      'https://sportotekaapp.ru/api/register.php';

  static const String _registerClubUrl =
      'https://sportotekaapp.ru/api/register_club.php';

  static const String _createClubApplicationUrl =
      'https://sportotekaapp.ru/api/club_access/create.php';

  // ==========================
  // Клубная форма
  // ==========================

  void resetClubForm() {
    clubNameController.clear();
    clubDescriptionController.clear();
    clubAddressController.clear();
    clubEmailController.clear();
    clubPasswordController.clear();

    clubIsShowPassword.value = true;
    clubAgreedToTerms.value = false;
  }

  // ==========================
  // Обычная регистрация
  // ==========================

  Future<void> registerUser() async {
    if (isLoading.value) return;

    final firstName =
        firstNameController.text.trim();

    final lastName =
        lastNameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      Get.snackbar(
        'Ошибка',
        'Заполните все поля',
      );

      return;
    }

    if (!GetUtils.isEmail(email)) {
      Get.snackbar(
        'Ошибка',
        'Введите корректный e-mail',
      );

      return;
    }

    if (password.length < 6) {
      Get.snackbar(
        'Ошибка',
        'Пароль должен быть минимум 6 символов',
      );

      return;
    }

    isLoading.value = true;

    try {
      final response = await http
          .post(
            Uri.parse(_registerUserUrl),
            headers: const {
              'Content-Type':
                  'application/json; charset=UTF-8',
              'Accept':
                  'application/json',
            },
            body: jsonEncode(
              {
                'first_name': firstName,
                'last_name': lastName,
                'email': email,
                'password': password,
                'role': getApiRole(
                  selectedRole.value,
                ),
              },
            ),
          )
          .timeout(
            const Duration(
              seconds: 20,
            ),
          );

      final data =
          _safeJson(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: '
          '${data?['message'] ?? 'Ошибка сервера'}',
        );
      }

      if (data == null ||
          data['status'] != 'success') {
        Get.snackbar(
          'Ошибка',
          data?['message'] ??
              'Неизвестная ошибка',
        );

        return;
      }

      await _saveUserData(data);

      Get.snackbar(
        'Успех',
        'Регистрация прошла успешно',
      );

      Get.offAllNamed(
        AppRoutes.homeContainerScreen,
        arguments: {
          'tab': 0,
        },
      );
    } catch (e) {
      Get.snackbar(
        'Ошибка регистрации',
        _cleanError(e),
        duration:
            const Duration(seconds: 5),
      );
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  // ==========================
  // Клубная заявка
  // ==========================

  Future<void> submitClubApplication() async {
    if (isLoading.value) return;

    bool handedOffToClubAccess = false;

    final clubName =
        clubNameController.text.trim();

    final description =
        clubDescriptionController.text.trim();

    final address =
        clubAddressController.text.trim();

    final email =
        clubEmailController.text.trim();

    final password =
        clubPasswordController.text.trim();

    // --------------------------
    // Проверки
    // --------------------------

    if (clubName.isEmpty ||
        description.isEmpty ||
        address.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      Get.snackbar(
        'Ошибка',
        'Заполните все поля заявки',
      );

      return;
    }

    if (!GetUtils.isEmail(email)) {
      Get.snackbar(
        'Ошибка',
        'Введите корректный e-mail',
      );

      return;
    }

    if (password.length < 6) {
      Get.snackbar(
        'Ошибка',
        'Пароль должен быть минимум 6 символов',
      );

      return;
    }

    if (!clubAgreedToTerms.value) {
      Get.snackbar(
        'Требуется согласие',
        'Подтвердите Условия и Политику',
      );

      return;
    }

    isLoading.value = true;

    try {
      // =====================================================
      // 1. Создаём аккаунт клуба со статусом pending
      // =====================================================

      final registerResponse = await http
          .post(
            Uri.parse(
              _registerClubUrl,
            ),
            headers: const {
              'Content-Type':
                  'application/json; charset=UTF-8',
              'Accept':
                  'application/json',
            },
            body: jsonEncode(
              {
                'club_name': clubName,
                'club_description':
                    description,
                'club_address': address,
                'email': email,
                'password': password,
                'role': 'club',
                'status': 'pending',
              },
            ),
          )
          .timeout(
            const Duration(
              seconds: 20,
            ),
          );

      final registerData =
          _safeJson(
        registerResponse.body,
      );

      if (registerResponse.statusCode !=
          200) {
        throw Exception(
          'HTTP ${registerResponse.statusCode}: '
          '${registerData?['message'] ?? 'Ошибка сервера'}',
        );
      }

      if (registerData == null ||
          registerData['status'] !=
              'success') {
        Get.snackbar(
          'Ошибка',
          registerData?['message'] ??
              'Не удалось создать заявку клуба',
        );

        return;
      }

      final userId =
          _extractUserId(
        registerData,
      );

      // =====================================================
      // 2. Создаём заявку club_applications
      // =====================================================

      final applicationResponse =
          await http
              .post(
                Uri.parse(
                  _createClubApplicationUrl,
                ),
                headers: const {
                  'Content-Type':
                      'application/json; charset=UTF-8',
                  'Accept':
                      'application/json',
                },
                body: jsonEncode(
                  {
                    'user_id':
                        userId,
                    'club_name':
                        clubName,
                    'club_description':
                        description,
                    'club_address':
                        address,
                    'email':
                        email,
                  },
                ),
              )
              .timeout(
                const Duration(
                  seconds: 20,
                ),
              );

      final applicationData =
          _safeJson(
        applicationResponse.body,
      );

      if (applicationResponse.statusCode !=
              200 ||
          applicationData == null ||
          applicationData['status'] !=
              'success') {
        throw Exception(
          applicationData?['message'] ??
              'Клуб создан, но не удалось сохранить заявку. '
                  'Обратитесь в поддержку.',
        );
      }

      // =====================================================
      // 3. Определяем user_id
      // =====================================================

      final application =
          applicationData[
              'application'];

      int resolvedUserId =
          userId;

      if (resolvedUserId <= 0 &&
          application is Map) {
        resolvedUserId =
            int.tryParse(
                  '${application['user_id'] ?? 0}',
                ) ??
                0;
      }

      if (resolvedUserId <= 0) {
        throw Exception(
          'Клуб создан, но сервер не вернул user_id',
        );
      }

      // =====================================================
      // 4. Pending-клуб НЕ авторизуем
      // =====================================================

      await PrefUtils.clearAll();

      // =====================================================
      // 5. Сначала корректно закрываем dialog
      // =====================================================
      //
      // Раньше здесь выполнялся Get.back()
      // и сразу же Get.offAll().
      //
      // Из-за этого Flutter пытался уничтожить
      // Navigator/InheritedElement, пока у него
      // ещё оставались dependents:
      //
      // _dependents.isEmpty is not true
      //
      // Поэтому сначала полностью закрываем overlay.
      // =====================================================

      final bool overlayIsOpen =
          Get.isDialogOpen == true ||
              Get.isBottomSheetOpen ==
                  true;

      if (overlayIsOpen) {
        Get.back();

        // Даём GetX закрыть dialog.
        await Future<void>.delayed(
          const Duration(
            milliseconds: 300,
          ),
        );

        // И обязательно ждём завершения
        // текущего Flutter frame.
        await WidgetsBinding
            .instance.endOfFrame;
      }

      // Контроллер ещё жив —
      // можно безопасно убрать loading.
      if (!isClosed) {
        isLoading.value = false;
      }

      handedOffToClubAccess =
          true;

      // =====================================================
      // 6. Только теперь открываем Club Key
      // =====================================================

      Get.offAll<void>(
        () => ClubAccessScreen(
          userId:
              resolvedUserId,
          clubName:
              clubName,
          email:
              email,
        ),
        transition:
            Transition.noTransition,
        duration:
            Duration.zero,
      );

      return;
    } catch (e) {
      if (!isClosed) {
        Get.snackbar(
          'Ошибка',
          _cleanError(e),
          duration:
              const Duration(
            seconds: 5,
          ),
          snackPosition:
              SnackPosition.BOTTOM,
          margin:
              const EdgeInsets.all(
            12,
          ),
        );
      }
    } finally {
      // Если уже передали управление
      // ClubAccessScreen, контроллер SignUp
      // может уничтожаться.
      //
      // Поэтому повторно Rx не трогаем.
      if (!handedOffToClubAccess &&
          !isClosed) {
        isLoading.value = false;
      }
    }
  }

  // ==========================
  // USER ID
  // ==========================

  int _extractUserId(
    Map<String, dynamic> data,
  ) {
    final rawUser =
        data['user'];

    if (rawUser is Map) {
      final id =
          int.tryParse(
                '${rawUser['id'] ?? 0}',
              ) ??
              0;

      if (id > 0) {
        return id;
      }
    }

    return int.tryParse(
          '${data['user_id'] ?? data['id'] ?? 0}',
        ) ??
        0;
  }

  // ==========================
  // Сохранение обычного user
  // ==========================

  Future<void> _saveUserData(
    Map<String, dynamic> data,
  ) async {
    await PrefUtils.clearAll();

    final pref =
        PrefUtils();

    await pref.init();

    await PrefUtils.setIsSignIn(
      true,
    );

    final rawUser =
        data['user'];

    final Map<String, dynamic> user =
        rawUser is Map
            ? Map<String, dynamic>.from(
                rawUser,
              )
            : <String, dynamic>{};

    final userId =
        int.tryParse(
              '${user['id'] ?? 0}',
            ) ??
            0;

    if (userId > 0) {
      await PrefUtils.setUserId(
        userId,
      );
    }

    await pref.setUserRole(
      '${user['role'] ?? getApiRole(selectedRole.value)}',
    );

    await pref.setUserFirstName(
      '${user['first_name'] ?? ''}',
    );

    await pref.setUserLastName(
      '${user['last_name'] ?? ''}',
    );

    await pref.setUserEmail(
      '${user['email'] ?? ''}',
    );
  }

  // ==========================
  // Roles
  // ==========================

  String getApiRole(
    String role,
  ) {
    final normalized =
        role.trim().toLowerCase();

    const apiRoles = {
      'coach',
      'player',
      'parent',
      'user',
      'club',
    };

    if (apiRoles.contains(
      normalized,
    )) {
      return normalized;
    }

    switch (role.trim()) {
      case 'Тренер':
        return 'coach';

      case 'Игрок':
        return 'player';

      case 'Родитель':
        return 'parent';

      case 'Пользователь':
        return 'user';

      case 'Клуб':
        return 'club';

      default:
        return 'coach';
    }
  }

  // ==========================
  // Safe JSON
  // ==========================

  Map<String, dynamic>? _safeJson(
    String raw,
  ) {
    try {
      final value =
          jsonDecode(raw);

      if (value
          is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return Map<String, dynamic>.from(
          value,
        );
      }
    } catch (_) {
      // Не бросаем FormatException наружу.
    }

    return null;
  }

  // ==========================
  // Ошибка
  // ==========================

  String _cleanError(
    Object error,
  ) {
    var value =
        error.toString();

    if (value.startsWith(
      'Exception: ',
    )) {
      value =
          value.substring(
        'Exception: '.length,
      );
    }

    return value;
  }

  // ==========================
  // Dispose
  // ==========================

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();

    clubNameController.dispose();
    clubDescriptionController.dispose();
    clubAddressController.dispose();
    clubEmailController.dispose();
    clubPasswordController.dispose();

    super.onClose();
  }
}