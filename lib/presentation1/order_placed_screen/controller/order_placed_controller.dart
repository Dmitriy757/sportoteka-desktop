import 'package:sportoteka/core/app_export.dart';import 'package:sportoteka/presentation/order_placed_screen/models/order_placed_model.dart';/// A controller class for the OrderPlacedScreen.
///
/// This class manages the state of the OrderPlacedScreen, including the
/// current orderPlacedModelObj
class OrderPlacedController extends GetxController {Rx<OrderPlacedModel> orderPlacedModelObj = OrderPlacedModel().obs;

 }
