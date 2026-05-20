import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/profile_screen/models/profile_model.dart';
import 'package:flutter/material.dart';

/// A controller class for the ProfileScreen.
class ProfileController extends GetxController {
  TextEditingController profileController = TextEditingController();
  TextEditingController profileController1 = TextEditingController();
  TextEditingController profileController2 = TextEditingController();
  TextEditingController profileController3 = TextEditingController();

  Rx<ProfileModel> profileModelObj = ProfileModel().obs;

  // ✅ Добавляем userId, который потом передадим в StudentsByTrainerScreen
  int currentUserId = 0;

  @override
  void onClose() {
    super.onClose();
    profileController.dispose();
    profileController1.dispose();
    profileController2.dispose();
    profileController3.dispose();
  }
}
