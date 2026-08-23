import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/payment_screen/models/payment_model.dart';

import '../models/payment_data.dart';

/// A controller class for the PaymentScreen.
///
/// This class manages the state of the PaymentScreen, including the
/// current paymentModelObj
class PaymentController extends GetxController {
  List<PaymentModel> paymentData= PaymentData.getPaymentData();
int selectedPaymentMethod = 0;
}