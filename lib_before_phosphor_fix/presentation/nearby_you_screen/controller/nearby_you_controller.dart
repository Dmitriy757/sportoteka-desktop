
/// A controller class for the NearbyYouScreen.
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/nearby_you_screen/models/nearby_you_model.dart';

import '../models/nearby_model_data.dart';

///
/// This class manages the state of the NearbyYouScreen, including the
/// current nearbyYouModelObj
class NearbyYouController extends GetxController {
 List<NearbyYouModel> nearlyYoudata = NearbyYouData.getNearbyYouData();
}
