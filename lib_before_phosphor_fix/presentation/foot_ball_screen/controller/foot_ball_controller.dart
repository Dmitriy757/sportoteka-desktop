
/// A controller class for the FootBallScreen.
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/foot_ball_screen/models/foot_ball_model.dart';

import '../models/foot_ball_data.dart';

///
/// This class manages the state of the FootBallScreen, including the
/// current footBallModelObj
class FootBallController extends GetxController {
  List<FootBallModel> footBallList = FootBallData.getFootBollData();
}
