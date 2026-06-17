// ✅ Исправленный файл HomePage без ошибок: убраны margin у CustomIconButton и добавлены недостающие методы

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/widgets/app_bar/appbar_subtitle.dart';
import 'package:sportoteka/widgets/app_bar/appbar_subtitle_one.dart';
import 'package:sportoteka/widgets/app_bar/custom_app_bar.dart';
import 'package:sportoteka/widgets/custom_icon_button.dart';
import 'package:sportoteka/widgets/custom_search_view.dart';
import 'package:sportoteka/presentation/categories_screen/controller/categories_controller.dart';
import 'package:sportoteka/presentation/categories_screen/models/categories_item_model.dart';
import 'package:sportoteka/presentation/categories_screen/widgets/categories_item_widget.dart';
import 'package:sportoteka/presentation/nearby_you_screen/controller/nearby_you_controller.dart';
import 'package:sportoteka/presentation/nearby_you_screen/models/nearby_you_model.dart';
import 'package:sportoteka/presentation/popular_ground_screen/controller/popular_ground_controller.dart';
import 'package:sportoteka/presentation/popular_ground_screen/models/popularground_item_model.dart';
import 'controller/home_controller.dart';
import 'models/home_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController homeController = Get.put(HomeController(HomeModel().obs));
  final CategoriesController categoriesController = Get.put(CategoriesController());
  final NearbyYouController nearbyYouController = Get.put(NearbyYouController());
  final PopularGroundController popularGroundController = Get.put(PopularGroundController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appTheme.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            SizedBox(height: 16.v),
            _buildSearchBar(),
            SizedBox(height: 24.v),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.h),
      child: CustomAppBar(
        height: 72.v,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppbarSubtitleOne(text: "lbl_hello_jane".tr),
            SizedBox(height: 5.v),
            AppbarSubtitle(text: "lbl_good_morning".tr),
          ],
        ),
        actions: [
          CustomIconButton(
            child: CustomImageView(imagePath: ImageConstant.imgGroup9),
            onTap: () => Get.toNamed(AppRoutes.notificationScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.h),
      child: Row(
        children: [
          Expanded(
            child: CustomSearchView(
              controller: homeController.searchController,
              hintText: "lbl_search".tr,
              onTap: () => Get.toNamed(AppRoutes.searchScreen),
            ),
          ),
          SizedBox(width: 16.h),
          CustomIconButton(
            child: CustomImageView(imagePath: ImageConstant.imgGroup1171275017),
            onTap: () => Get.toNamed(AppRoutes.filterScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: EdgeInsets.only(bottom: 40.v),
      children: [
        _buildSectionHeader(
          title: "lbl_categories".tr,
          onViewAll: () => Get.toNamed(AppRoutes.categoriesScreen),
        ),
        _buildCategoriesGrid(),
        _buildSectionHeader(
          title: "lbl_popular_ground".tr,
          onViewAll: () => Get.toNamed(AppRoutes.popularGroundScreen),
        ),
        _buildPopularGroundList(),
        _buildSectionHeader(
          title: "lbl_nearby_you".tr,
          onViewAll: () => Get.toNamed(AppRoutes.nearbyYouScreen),
        ),
        _buildNearbyYouList(),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required VoidCallback onViewAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          GestureDetector(
            onTap: onViewAll,
            child: Padding(
              padding: EdgeInsets.only(bottom: 3.v),
              child: Text("lbl_view_all".tr, style: CustomTextStyles.bodyLargeGray60001),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    return Padding(
      padding: EdgeInsets.all(20.h),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.h,
          mainAxisExtent: 118.v,
        ),
        itemCount: categoriesController.categoriesData.length.clamp(0, 4),
        itemBuilder: (context, index) {
          final model = categoriesController.categoriesData[index];
          return GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.footBallScreen),
            child: CategoriesItemWidget(model),
          );
        },
      ),
    );
  }

  Widget _buildPopularGroundList() {
    return SizedBox(
      height: 260.v,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.h),
        scrollDirection: Axis.horizontal,
        itemCount: popularGroundController.populerGround.length.clamp(0, 2),
        separatorBuilder: (_, __) => SizedBox(width: 16.h),
        itemBuilder: (context, index) {
          final data = popularGroundController.populerGround[index];
          return _buildPopularGroundItem(data);
        },
      ),
    );
  }

  Widget _buildPopularGroundItem(PopulargroundItemModel data) {
    return GestureDetector(
      onTap: () {
        popularGroundController.currentimage = data.image!;
        popularGroundController.update();
        Get.toNamed(AppRoutes.detailScreen);
      },
      child: Container(
        width: 260.h,
        decoration: AppDecoration.fillGray.copyWith(
          color: appTheme.textfieldFillColor,
          borderRadius: BorderRadiusStyle.roundedBorder16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: data.image!,
              child: CustomImageView(
                imagePath: data.image,
                height: 126.v,
                width: double.infinity,
                radius: BorderRadius.circular(16.h),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title!, style: theme.textTheme.titleMedium),
                  SizedBox(height: 8.v),
                  _buildLocationInfo(data.location!),
                  SizedBox(height: 12.v),
                  _buildSportIcons(data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String location) {
    return Row(
      children: [
        CustomImageView(
          imagePath: ImageConstant.imgIcLocation,
          height: 20.adaptSize,
          width: 20.adaptSize,
        ),
        SizedBox(width: 8.h),
        Text(location, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildSportIcons(PopulargroundItemModel data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomImageView(
          imagePath: data.isBedMintan!
              ? ImageConstant.imgShuttlecock31
              : ImageConstant.imgShuttlecock1,
          height: 24.adaptSize,
          width: 24.adaptSize,
        ),
        CustomImageView(
          imagePath: data.iscricket!
              ? ImageConstant.imgBall1LightGreen400
              : ImageConstant.imgTennisBall1,
          height: 24.adaptSize,
          width: 24.adaptSize,
        ),
        CustomImageView(
          imagePath: data.isfootball!
              ? ImageConstant.imgBasketBall
              : ImageConstant.imgBasketBall,
          height: 24.adaptSize,
          width: 24.adaptSize,
        ),
      ],
    );
  }

  Widget _buildNearbyYouList() {
    return SizedBox(
      height: 200.v,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.h),
        scrollDirection: Axis.horizontal,
        itemCount: nearbyYouController.nearlyYoudata.length.clamp(0, 2),
        separatorBuilder: (_, __) => SizedBox(width: 16.h),
        itemBuilder: (context, index) {
          final data = nearbyYouController.nearlyYoudata[index];
          return _buildNearbyYouItem(data);
        },
      ),
    );
  }

  Widget _buildNearbyYouItem(NearbyYouModel data) {
    return GestureDetector(
      onTap: () {
        popularGroundController.currentimage = data.image!;
        popularGroundController.update();
        Get.toNamed(AppRoutes.detailScreen);
      },
      child: Container(
        width: 298.h,
        decoration: AppDecoration.fillGray.copyWith(
          color: appTheme.textfieldFillColor,
          borderRadius: BorderRadiusStyle.roundedBorder16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageWithDistance(data.image!, data.diatance!),
            Padding(
              padding: EdgeInsets.all(16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title!, style: theme.textTheme.titleMedium),
                  SizedBox(height: 8.v),
                  _buildLocationInfo(data.location!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWithDistance(String image, String distance) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        CustomImageView(
          imagePath: image,
          height: 163.v,
          width: double.infinity,
          radius: BorderRadius.circular(16.h),
        ),
        Container(
          margin: EdgeInsets.all(12.h),
          padding: EdgeInsets.symmetric(horizontal: 8.h, vertical: 2.v),
          decoration: AppDecoration.white.copyWith(
            borderRadius: BorderRadiusStyle.circleBorder10,
          ),
          child: Text(distance, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
