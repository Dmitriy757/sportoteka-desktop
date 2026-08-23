import 'package:flutter/material.dart';

/// A controller class for the SearchScreen.
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/search_screen/models/search_model.dart';

///
/// This class manages the state of the SearchScreen, including the
/// current searchModelObj
class SearchControllers extends GetxController {
  TextEditingController searchController = TextEditingController();

  List<SearchModel> searchModelList = [];

  @override
  void onClose() {
    super.onClose();
    searchController.clear();
  }
}
