
/// A controller class for the GroundCategoryScreen.
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/ground_category_screen/models/ground_category_model.dart';

import '../models/ground_category_data.dart';

///
/// This class manages the state of the GroundCategoryScreen, including the
/// current groundCategoryModelObj
class GroundCategoryController extends GetxController {
 List<GroundCategoryModel> groundCategoryList = GroundCategoryData.getGroundCategoryData();
 int currentCategoryId = 4;
}
