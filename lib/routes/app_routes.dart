import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/about_us_screen/about_us_screen.dart';
import 'package:sportoteka/presentation/about_us_screen/binding/about_us_binding.dart';
import 'package:sportoteka/presentation/add_ground_screen/add_ground_screen.dart';
import 'package:sportoteka/presentation/add_ground_screen/binding/add_ground_binding.dart';
import 'package:sportoteka/presentation/add_new_card_screen/add_new_card_screen.dart';
import 'package:sportoteka/presentation/add_new_card_screen/binding/add_new_card_binding.dart';
import 'package:sportoteka/presentation/add_photos_screen/add_photos_screen.dart';
import 'package:sportoteka/presentation/add_photos_screen/binding/add_photos_binding.dart';
import 'package:sportoteka/presentation/app_navigation_screen/app_navigation_screen.dart';
import 'package:sportoteka/presentation/app_navigation_screen/binding/app_navigation_binding.dart';
import 'package:sportoteka/presentation/booking_details_one_screen/binding/booking_details_one_binding.dart';
import 'package:sportoteka/presentation/edit_player_screen/edit_player_screen.dart';
import 'package:sportoteka/presentation/profile_screen/my_programs_screen.dart';
import 'package:sportoteka/presentation/player_profile_screen/player_profile_screen.dart';
import 'package:sportoteka/presentation/my_team_screen/my_team_screen.dart';
import 'package:sportoteka/presentation/my_team_screen/binding/my_team_binding.dart';
import 'package:sportoteka/presentation/booking_details_one_screen/booking_details_one_screen.dart';
import 'package:sportoteka/presentation/booking_details_screen/binding/booking_details_binding.dart';
import 'package:sportoteka/presentation/booking_details_screen/booking_details_screen.dart';
import 'package:sportoteka/presentation/categories_screen/binding/categories_binding.dart';
import 'package:sportoteka/presentation/categories_screen/categories_screen.dart';
import 'package:sportoteka/presentation/confirm_delete_popup_screen/binding/confirm_delete_popup_binding.dart';
import 'package:sportoteka/presentation/confirm_delete_popup_screen/confirm_delete_popup_screen.dart';
import 'package:sportoteka/presentation/detail_screen/binding/detail_binding.dart';
import 'package:sportoteka/presentation/detail_screen/detail_screen.dart';
import 'package:sportoteka/presentation/edit_profile_screen/binding/edit_profile_binding.dart';
import 'package:sportoteka/presentation/edit_profile_screen/edit_profile_screen.dart';
import 'package:sportoteka/presentation/events_detail_screen/binding/events_detail_binding.dart';
import 'package:sportoteka/presentation/events_detail_screen/events_detail_screen.dart';
import 'package:sportoteka/presentation/events_detail_two_screen/binding/events_detail_two_binding.dart';
import 'package:sportoteka/presentation/events_detail_two_screen/events_detail_two_screen.dart';
import 'package:sportoteka/presentation/filter_screen/binding/filter_binding.dart';
import 'package:sportoteka/presentation/filter_screen/filter_screen.dart';
import 'package:sportoteka/presentation/foot_ball_screen/binding/foot_ball_binding.dart';
import 'package:sportoteka/presentation/foot_ball_screen/foot_ball_screen.dart';
import 'package:sportoteka/presentation/forgot_password_screen/binding/forgot_password_binding.dart';
import 'package:sportoteka/presentation/forgot_password_screen/forgot_password_screen.dart';
import 'package:sportoteka/presentation/ground_category_screen/binding/ground_category_binding.dart';
import 'package:sportoteka/presentation/ground_category_screen/ground_category_screen.dart';
import 'package:sportoteka/presentation/help_screen/binding/help_binding.dart';
import 'package:sportoteka/presentation/help_screen/help_screen.dart';
import 'package:sportoteka/presentation/history_complate_detail_screen/binding/history_complate_detail_binding.dart';
import 'package:sportoteka/presentation/history_complate_detail_screen/history_complate_detail_screen.dart';
import 'package:sportoteka/presentation/history_detail_screen/binding/history_detail_binding.dart';
import 'package:sportoteka/presentation/history_detail_screen/history_detail_screen.dart';
import 'package:sportoteka/presentation/home_container_screen/binding/home_container_binding.dart';
import 'package:sportoteka/presentation/home_container_screen/home_container_screen.dart';
import 'package:sportoteka/presentation/login_screen/binding/login_binding.dart';
import 'package:sportoteka/presentation/login_screen/login_screen.dart';
import 'package:sportoteka/presentation/my_booking_upcoming_tab_container_screen/binding/my_booking_upcoming_tab_container_binding.dart';
import 'package:sportoteka/presentation/my_booking_upcoming_tab_container_screen/my_booking_upcoming_tab_container_screen.dart';
import 'package:sportoteka/presentation/booking_screen/bookings_for_my_venues_screen.dart';

import 'package:sportoteka/presentation/my_grounds_screen/binding/my_grounds_binding.dart';
import 'package:sportoteka/presentation/my_grounds_screen/my_grounds_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/binding/my_profile_binding.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/nearby_you_screen/binding/nearby_you_binding.dart';
import 'package:sportoteka/presentation/nearby_you_screen/nearby_you_screen.dart';
import 'package:sportoteka/presentation/notification_screen/binding/notification_binding.dart';
import 'package:sportoteka/presentation/notification_screen/notification_screen.dart';
import 'package:sportoteka/presentation/onboarding_one_screen/binding/onboarding_one_binding.dart';
import 'package:sportoteka/presentation/onboarding_one_screen/onboarding_one_screen.dart';
import 'package:sportoteka/presentation/order_placed_screen/binding/order_placed_binding.dart';
import 'package:sportoteka/presentation/booking_screen/my_bookings_screen.dart';
import 'package:sportoteka/presentation/order_placed_screen/order_placed_screen.dart';
import 'package:sportoteka/presentation/password_changed_popup_screen/binding/password_changed_popup_binding.dart';
import 'package:sportoteka/presentation/password_changed_popup_screen/password_changed_popup_screen.dart';
import 'package:sportoteka/presentation/payment_screen/binding/payment_binding.dart';
import 'package:sportoteka/presentation/payment_screen/payment_screen.dart';
import 'package:sportoteka/presentation/popular_ground_screen/binding/popular_ground_binding.dart';
import 'package:sportoteka/presentation/popular_ground_screen/popular_ground_screen.dart';
import 'package:sportoteka/presentation/privacy_policy_screen/binding/privacy_policy_binding.dart';
import 'package:sportoteka/presentation/privacy_policy_screen/privacy_policy_screen.dart';
import 'package:sportoteka/presentation/profile_screen/binding/profile_binding.dart';
import 'package:sportoteka/presentation/profile_screen/profile_screen.dart';
import 'package:sportoteka/presentation/rate_us_experirnce_screen/binding/rate_us_experirnce_binding.dart';
import 'package:sportoteka/presentation/rate_us_experirnce_screen/rate_us_experirnce_screen.dart';
import 'package:sportoteka/presentation/reason_to_cancel_popup_screen/binding/reason_to_cancel_popup_binding.dart';
import 'package:sportoteka/presentation/reason_to_cancel_popup_screen/reason_to_cancel_popup_screen.dart';
import 'package:sportoteka/presentation/reset_password_screen/binding/reset_password_binding.dart';
import 'package:sportoteka/presentation/reset_password_screen/reset_password_screen.dart';
import 'package:sportoteka/presentation/review_screen/binding/review_binding.dart';
import 'package:sportoteka/presentation/review_screen/review_screen.dart';
import 'package:sportoteka/presentation/search_screen/binding/search_binding.dart';
import 'package:sportoteka/presentation/search_screen/search_screen.dart';
import 'package:sportoteka/presentation/select_date_time_screen/binding/select_date_time_binding.dart';
import 'package:sportoteka/presentation/select_date_time_screen/select_date_time_screen.dart';
import 'package:sportoteka/presentation/settings_screen/binding/settings_binding.dart';
import 'package:sportoteka/presentation/settings_screen/settings_screen.dart';
import 'package:sportoteka/presentation/sign_up_screen/binding/sign_up_binding.dart';
import 'package:sportoteka/presentation/sign_up_screen/sign_up_screen.dart';
import 'package:sportoteka/presentation/splash_screen/binding/splash_binding.dart';
import 'package:sportoteka/presentation/splash_screen/splash_screen.dart';
import 'package:sportoteka/presentation/success_popup_screen/binding/success_popup_binding.dart';
import 'package:sportoteka/presentation/success_popup_screen/success_popup_screen.dart';
import 'package:sportoteka/presentation/verification_screen/binding/verification_binding.dart';
import 'package:sportoteka/presentation/verification_screen/verification_screen.dart';
import 'package:sportoteka/presentation/write_a_review_screen/binding/write_a_review_binding.dart';
import 'package:sportoteka/presentation/write_a_review_screen/write_a_review_screen.dart';
import 'package:get/get.dart';
import 'package:sportoteka/presentation/add_player_screen/add_player_screen.dart';
import 'package:sportoteka/presentation/create_team_screen/create_team_screen.dart';
import 'package:sportoteka/presentation/my_schools_screen/my_schools_screen.dart';
import 'package:sportoteka/presentation/team_description_screen/team_description_screen.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_matches_screen.dart';
import 'package:sportoteka/presentation/team_management_screen/team_management_screen.dart';
import 'package:sportoteka/presentation/team_tickets_screen/team_tickets_screen.dart';
import 'package:sportoteka/presentation/club_dashboard_screen/club_dashboard_screen.dart'; 
import 'package:sportoteka/presentation/player_screen/player_self_assessment_screen.dart';
import 'package:sportoteka/presentation/subscription/subscription_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_rating_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_battles_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_quizzes_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_match_games_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_highlights_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_quizzes_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/quiz_detail_screen.dart';
import 'package:sportoteka/presentation/player_screen/player_match_detail_screen.dart';
import 'package:sportoteka/presentation/player_matches_screen/player_matches_screen.dart';
import 'package:sportoteka/presentation/club_workspace/club_workspace_screen.dart';

class AppRoutes {
  static const String loginScreen = '/login_screen';

  static const String splashScreen = '/splash_screen';
  static const String initialRoute = '/initialRoute'; 
  static const String onboardingOneScreen = '/onboarding_one_screen';

  static const String onboardingTwoScreen = '/onboarding_two_screen';

  static const String onboardingThreeScreen = '/onboarding_three_screen';

  static const String loginErrorScreen = '/login_error_screen';

  static const String loginFilledScreen = '/login_filled_screen';

  static const String signUpScreen = '/sign_up_screen';
  static const String myProgramsScreen = '/myProgramsScreen';
  static const String forgotPasswordScreen = '/forgot_password_screen';
  static const String addPlayerScreen = '/addPlayerScreen';
  static const String verificationScreen = '/verification_screen';
  static const String editPlayerScreen = '/edit_player_screen';

  static const String resetPasswordScreen = '/reset_password_screen';

  static const String passwordChangedPopupScreen =
      '/password_changed_popup_screen';

  static const String homePage = '/home_page';

  static const String homeContainerScreen = '/home_container_screen';

  static const String notificationEmptyScreen = '/notification_empty_screen';

  static const String notificationScreen = '/notification_screen';

  static const String searchScreen = '/search_screen';

  static const String searchFillScreen = '/search_fill_screen';

  static const String filterScreen = '/filter_screen';

  static const String searchResultScreen = '/search_result_screen';

  static const String categoriesScreen = '/categories_screen';

  static const String footBallScreen = '/foot_ball_screen';
  
  static const String subscriptionsScreen = '/subscriptionsScreen';


  static const String popularGroundScreen = '/popular_ground_screen';

  static const String nearbyYouScreen = '/nearby_you_screen';
  
  static const String playerProfileScreen = '/player_profile_screen';

  static const String detailScreen = '/detail_screen';

  static const String reviewScreen = '/review_screen';

  static const String writeAReviewScreen = '/write_a_review_screen';

  static const String selectDateTimeScreen = '/select_date_time_screen';

  static const String bookingDetailsOneScreen = '/booking_details_one_screen';
 
  

  static const String paymentScreen = '/payment_screen';

  static const String addNewCardScreen = '/add_new_card_screen';

  static const String orderPlacedScreen = '/order_placed_screen';

  static const String myBookingEmptyPage = '/my_booking_empty_page';

  static const String myTeamScreen = '/my_team_screen';

  static const String myBookingUpcomingPage = '/my_booking_upcoming_page';

  static const String myBookingUpcomingTabContainerScreen =
      '/my_booking_upcoming_tab_container_screen';

  static const String myBookingComplatedPage = '/my_booking_complated_page';
  static const String clubDashboardScreen = '/clubDashboardScreen';


  static const String createTeamScreen = '/createTeamScreen';
  static const String bookingDetailsScreen = '/booking_details_screen';

  static const String reasonToCancelPopupScreen =
      '/reason_to_cancel_popup_screen';

  static const String confirmDeletePopupScreen = '/confirm_delete_popup_screen';

  static const String eventsEmptyScreen = '/events_empty_screen';

  static const String eventsPage = '/events_page';

  static const String eventsDetailScreen = '/events_detail_screen';

  static const String eventsDetailTwoScreen = '/events_detail_two_screen';

  static const String historyEmptyPage = '/history_empty_page';

  static const String historyUpcomingPage = '/history_upcoming_page';

  static const String historyComplatePage = '/history_complate_page';

  static const String historyDetailScreen = '/history_detail_screen';

  static const String historyComplateDetailScreen =
      '/history_complate_detail_screen';

  static const String guestUserProfilePage = '/guest_user_profile_page';

  static const String profileScreen = '/profile_screen';

  static const String myProfileScreen = '/my_profile_screen';

  static const String editProfileScreen = '/edit_profile_screen';

  static const String settingsScreen = '/settings_screen';

  static const String privacyPolicyScreen = '/privacy_policy_screen';

  static const String helpScreen = '/help_screen';
  static const String bookingsForMyVenuesScreen = '/bookings_for_my_venues_screen';


  static const String aboutUsScreen = '/about_us_screen';

  static const String rateUsExperirnceScreen = '/rate_us_experirnce_screen';

  static const String myGroundsScreen = '/my_grounds_screen';

  static const String addGroundScreen = '/add_ground_screen';

  static const String groundCategoryScreen = '/ground_category_screen';

  static const String addPhotosScreen = '/add_photos_screen';

  static const String successPopupScreen = '/success_popup_screen';

  static const String appNavigationScreen = '/app_navigation_screen';

static const String myBookingsScreen = '/myBookingsScreen';

static const String mySchoolsScreen = '/mySchoolsScreen';


  static const String teamDescriptionScreen = '/teamDescriptionScreen';
  static const String teamMatchesScreen = '/teamMatchesScreen';
  static const String teamManagementScreen = '/teamManagementScreen';
  static const String teamTicketsScreen = '/teamTicketsScreen';  
static const String playerSelfAssessmentScreen = '/player-self-assessment';

static const teamRatingScreen = '/team-rating-screen';
static const playerChallengesScreen = '/player-challenges-screen';
static const playerBattlesScreen = '/player-battles-screen';
static const playerQuizzesScreen = '/player-quizzes-screen';
static const playerMatchGamesScreen = '/player-match-games-screen';
static const playerHighlightsScreen = '/player-highlights-screen';
static const createQuizScreen = '/create-quiz-screen';
static const teamChallengesScreen = '/team-challenges-screen';
static const teamQuizzesScreen = '/team-quizzes-screen';
static const quizDetailScreen = '/quiz-detail-screen';
static const String playerMatchesScreen = '/player_matches_screen';

  static List<GetPage> pages = [
    GetPage(
      transition: Transition.rightToLeft,
      name: loginScreen,
      page: () => LoginScreen(),
      bindings: [
        LoginBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: splashScreen,
      page: () => SplashScreen(),
      bindings: [
        SplashBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: onboardingOneScreen,
      page: () => OnboardingOneScreen(),
      bindings: [
        OnboardingOneBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: signUpScreen,
      page: () => SignUpScreen(),
      bindings: [
        SignUpBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: forgotPasswordScreen,
      page: () => ForgotPasswordScreen(),
      bindings: [
        ForgotPasswordBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: verificationScreen,
      page: () => VerificationScreen(),
      bindings: [
        VerificationBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: resetPasswordScreen,
      page: () => ResetPasswordScreen(),
      bindings: [
        ResetPasswordBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: passwordChangedPopupScreen,
      page: () => PasswordChangedPopupScreen(),
      bindings: [
        PasswordChangedPopupBinding(),
      ],
       
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: homeContainerScreen,
      page: () => HomeContainerScreen(),
      bindings: [
        HomeContainerBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: notificationScreen,
      page: () => NotificationScreen(),
      bindings: [
        NotificationBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: searchScreen,
      page: () => SearchScreen(),
      bindings: [
        SearchBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: filterScreen,
      page: () => FilterScreen(),
      bindings: [
        FilterBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: categoriesScreen,
      page: () => CategoriesScreen(),
      bindings: [
        CategoriesBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: footBallScreen,
      page: () => FootBallScreen(),
      bindings: [
        FootBallBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: popularGroundScreen,
      page: () => PopularGroundScreen(),
      bindings: [
        PopularGroundBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: nearbyYouScreen,
      page: () => NearbyYouScreen(),
      bindings: [
        NearbyYouBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: detailScreen,
      page: () => DetailScreen(),
      bindings: [
        DetailBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: reviewScreen,
      page: () => ReviewScreen(),
      bindings: [
        ReviewBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: writeAReviewScreen,
      page: () => WriteAReviewScreen(),
      bindings: [
        WriteAReviewBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: selectDateTimeScreen,
      page: () => SelectDateTimeScreen(),
      bindings: [
        SelectDateTimeBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: bookingDetailsOneScreen,
      page: () => BookingDetailsOneScreen(),
      bindings: [
        BookingDetailsOneBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: paymentScreen,
      page: () => PaymentScreen(),
      bindings: [
        PaymentBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: addNewCardScreen,
      page: () => AddNewCardScreen(),
      bindings: [
        AddNewCardBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: orderPlacedScreen,
      page: () => OrderPlacedScreen(),
      bindings: [
        OrderPlacedBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: myBookingUpcomingTabContainerScreen,
      page: () => MyBookingUpcomingTabContainerScreen(),
      bindings: [
        MyBookingUpcomingTabContainerBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: bookingDetailsScreen,
      page: () => BookingDetailsScreen(),
      bindings: [
        BookingDetailsBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: reasonToCancelPopupScreen,
      page: () => ReasonToCancelPopupScreen(),
      bindings: [
        ReasonToCancelPopupBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: confirmDeletePopupScreen,
      page: () => ConfirmDeletePopupScreen(),
      bindings: [
        ConfirmDeletePopupBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: eventsDetailScreen,
      page: () => EventsDetailScreen(),
      bindings: [
        EventsDetailBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: eventsDetailTwoScreen,
      page: () => EventsDetailTwoScreen(),
      bindings: [
        EventsDetailTwoBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: historyDetailScreen,
      page: () => HistoryDetailScreen(),
      bindings: [
        HistoryDetailBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: historyComplateDetailScreen,
      page: () => HistoryComplateDetailScreen(),
      bindings: [
        HistoryComplateDetailBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: profileScreen,
      page: () => ProfileScreen(),
      bindings: [
        ProfileBinding(),
      ],
    ),
      GetPage(
  transition: Transition.rightToLeft,
  name: AppRoutes.addPlayerScreen,
  page: () {
    final args = Get.arguments ?? {};
    final int teamId = int.tryParse((args['teamId'] ?? 0).toString()) ?? 0;
    final String teamName = (args['teamName'] ?? '').toString();

    if (teamId <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text("Ошибка")),
        body: const Center(child: Text("Не передан teamId для AddPlayerScreen")),
      );
    }

    return AddPlayerScreen(teamId: teamId, teamName: teamName);
  },
),
    GetPage(
      transition: Transition.rightToLeft,
      name: myProfileScreen,
      page: () => MyProfileScreen(),
      bindings: [
        MyProfileBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: editProfileScreen,
      page: () => EditProfileScreen(),
      bindings: [
        EditProfileBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: settingsScreen,
      page: () => SettingsScreen(),
      bindings: [
        SettingsBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: privacyPolicyScreen,
      page: () => PrivacyPolicyScreen(),
      bindings: [
        PrivacyPolicyBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: helpScreen,
      page: () => HelpScreen(),
      bindings: [
        HelpBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: aboutUsScreen,
      page: () => AboutUsScreen(),
      bindings: [
        AboutUsBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: rateUsExperirnceScreen,
      page: () => RateUsExperirnceScreen(),
      bindings: [
        RateUsExperirnceBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: myGroundsScreen,
      page: () => MyGroundsScreen(),
      bindings: [
        MyGroundsBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: addGroundScreen,
      page: () => AddGroundScreen(),
      bindings: [
        AddGroundBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: groundCategoryScreen,
      page: () => GroundCategoryScreen(),
      bindings: [
        GroundCategoryBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: addPhotosScreen,
      page: () => AddPhotosScreen(),
      bindings: [
        AddPhotosBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: successPopupScreen,
      page: () => SuccessPopupScreen(),
      bindings: [
        SuccessPopupBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: appNavigationScreen,
      page: () => AppNavigationScreen(),
      bindings: [
        AppNavigationBinding(),
      ],
    ),
    GetPage(
      transition: Transition.rightToLeft,
      name: initialRoute,
      page: () => SplashScreen(),
      bindings: [
        SplashBinding(),
      ],
    ),
  GetPage(
      transition: Transition.rightToLeft,
      name: myGroundsScreen,
      page: () => MyGroundsScreen(),
      bindings: [
        MyGroundsBinding(),
      ],
    ), // ← ЭТА ЗАПЯТАЯ ОБЯЗАТЕЛЬНА

    // Добавленный экран "Моя команда"
    GetPage(
      transition: Transition.rightToLeft,
      name: '/myTeamScreen',
      page: () => MyTeamScreen(),
      bindings: [
        MyTeamBinding(),
      ],
    ),
    
    GetPage(
  name: '/myProgramsScreen',
  page: () => const MyProgramsScreen(),
),
GetPage(
  transition: Transition.rightToLeft,
  name: AppRoutes.createTeamScreen,
  page: () => CreateTeamScreen(),
),

    GetPage(
  name: playerProfileScreen,
  page: () => PlayerProfileScreen(player: Get.arguments),
),
GetPage(
  name: AppRoutes.editPlayerScreen,
  page: () => EditPlayerScreen(), // ✅ БЕЗ аргументов
),

GetPage(
  transition: Transition.rightToLeft,
  name: AppRoutes.myBookingsScreen,
  page: () => const MyBookingsScreen(),
),
GetPage(
  name: AppRoutes.bookingsForMyVenuesScreen,
  page: () => const BookingsForMyVenuesScreen(),
),
GetPage(
  name: AppRoutes.mySchoolsScreen,
  page: () => MySchoolsScreen(),
  ),
  GetPage(
  name: AppRoutes.teamDescriptionScreen,
  page: () => const TeamDescriptionScreen(),
),
GetPage(
  name: AppRoutes.teamMatchesScreen,
  page: () => const TeamMatchesScreen(),
),
GetPage(
  name: AppRoutes.teamManagementScreen,
  page: () => const TeamManagementScreen(),
),
GetPage(
  name: AppRoutes.teamTicketsScreen,
  page: () => const TeamTicketsScreen(),
),
GetPage(
  name: AppRoutes.clubDashboardScreen,
  page: () => const ClubWorkspaceScreen(),
),

GetPage(
  name: AppRoutes.playerSelfAssessmentScreen,
  page: () => PlayerSelfAssessmentScreen(),
),

GetPage(
  name: AppRoutes.subscriptionsScreen,
  page: () => const SubscriptionScreen(), // Убрали 's' - теперь правильно
),
GetPage(
  name: AppRoutes.teamRatingScreen,
  page: () => const TeamRatingScreen(),
),
GetPage(
  name: AppRoutes.playerChallengesScreen,
  page: () => const PlayerChallengesScreen(),
),
GetPage(
  name: AppRoutes.playerBattlesScreen,
  page: () => const PlayerBattlesScreen(),
),
GetPage(
  name: AppRoutes.playerQuizzesScreen,
  page: () => const PlayerQuizzesScreen(),
),
GetPage(
  name: AppRoutes.playerMatchGamesScreen,
  page: () => const PlayerMatchGamesScreen(),
),
GetPage(
  name: AppRoutes.playerHighlightsScreen,
  page: () => const PlayerHighlightsScreen(),
),
GetPage(
  name: AppRoutes.createQuizScreen,
  page: () => const CreateQuizScreen(),
),
GetPage(
  name: AppRoutes.teamChallengesScreen,
  page: () => const TeamChallengesScreen(),
),
GetPage(
  name: AppRoutes.teamQuizzesScreen,
  page: () => const TeamQuizzesScreen(),
),
GetPage(
  name: AppRoutes.quizDetailScreen,
  page: () => const QuizDetailScreen(),
),GetPage(
  name: AppRoutes.playerMatchesScreen,
  page: () => const PlayerMatchesScreen(),
),
GetPage(
  name: '/club-workspace',
  page: () => const ClubWorkspaceScreen(),
),
      ];
}
