import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import '../../widgets/app_bar/custum_bottom_bar_controller.dart';
import '../../widgets/custom_elevated_button.dart';
import '../../widgets/custom_outlined_button.dart';

class LogOutDialogue extends StatefulWidget {
  const LogOutDialogue({super.key});

  @override
  State<LogOutDialogue> createState() => _LogOutDialogueState();
}

class _LogOutDialogueState extends State<LogOutDialogue> {
  late final CustomBottomBarController bottomBarController;

  @override
  void initState() {
    super.initState();
    // берём существующий контроллер, чтобы реально переключить таб
    bottomBarController = Get.isRegistered<CustomBottomBarController>()
        ? Get.find<CustomBottomBarController>()
        : Get.put(CustomBottomBarController());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 32.v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 4.v),
          Text(
            "Выйти?",
            style: theme.textTheme.titleMedium!.copyWith(
              color: appTheme.black900,
            ),
          ),
          SizedBox(height: 24.v),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomOutlinedButton(
                onPressed: () => Get.back(),
                width: 170.h,
                text: "lbl_cancel".tr,
                margin: EdgeInsets.only(right: 8.h),
              ),
              CustomElevatedButton(
                onPressed: () async {
                  // ✅ очищаем ВСЁ (userId/role/email/фото + signIn=false)
                  await PrefUtils.clearAll();

                  // ✅ если нужно вернуть таб на 0
                  bottomBarController.getIndex(0);

                  // ✅ на логин
                  Get.offAllNamed(AppRoutes.loginScreen);
                },
                width: 170.h,
                text: "Выход",
                margin: EdgeInsets.only(left: 8.h),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
