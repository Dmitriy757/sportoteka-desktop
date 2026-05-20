import 'package:flutter/material.dart';

/// A controller class for the VerificationScreen.
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/verification_screen/models/verification_model.dart';
import 'package:sms_autofill/sms_autofill.dart';

///
/// This class manages the state of the VerificationScreen, including the
/// current verificationModelObj
class VerificationController extends GetxController with CodeAutoFill {
  Rx<TextEditingController> otpController = TextEditingController().obs;

  Rx<VerificationModel> verificationModelObj = VerificationModel().obs;

  @override
  void codeUpdated() {
    otpController.value.text = code ?? '';
  }

  @override
  void onInit() {
    super.onInit();
    // listenForCode();
  }
}
