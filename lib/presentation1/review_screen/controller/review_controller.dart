import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/review_screen/models/review_model.dart';

import '../models/review_item_model.dart';

/// A controller class for the ReviewScreen.
///
/// This class manages the state of the ReviewScreen, including the
/// current reviewModelObj
class ReviewController extends GetxController {
 List<ReviewItemModel> reviewList = ReviewModel.getReviewList();
}
