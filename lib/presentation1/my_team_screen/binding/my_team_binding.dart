import 'package:get/get.dart';
import '../controller/my_team_controller.dart';

class MyTeamBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyTeamController());
  }
}