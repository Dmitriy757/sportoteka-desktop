import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/login_screen/login_screen.dart';

class OnboardingOneScreen extends StatefulWidget {
  const OnboardingOneScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingOneScreen> createState() => _OnboardingOneScreenState();
}

class _OnboardingOneScreenState extends State<OnboardingOneScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> onboardingData = const [
    {
      "title": "Цифровизация тренерской работы",
      "subtitle":
          "Забудьте о бумажных документах! Отслеживайте тренировки, сохраняйте данные и делитесь результатами.",
    },
    {
      "title": "Найди новые таланты",
      "subtitle":
          "Мы поможем вам найти и развивать новые таланты. Следите за ростом игроков и их прогрессом.",
    },
    {
      "title": "Покупка билетов",
      "subtitle":
          "Покупайте билеты на мероприятия прямо в приложении. Быстро и удобно!",
    },
  ];

  final List<String> onboardingImages = const [
    'assets/images/onboarding1.png',
    'assets/images/onboarding2.png',
    'assets/images/onboarding3.png',
  ];

  Future<void> _completeOnboarding() async {
    await PrefUtils.setIsIntro(false); // больше не показывать онбординг
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    // Если позже захочешь через GetX:
    // Get.offAllNamed(AppRoutes.loginScreen);
  }

  void _nextPage() async {
    if (_currentIndex < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              onboardingData[_currentIndex]['title'] ?? '',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              onboardingData[_currentIndex]['subtitle'] ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(),
                      Image.asset(
                        onboardingImages[index],
                        width: 280,
                        height: 280,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(onboardingData.length, (index) {
              final bool active = _currentIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? Colors.blue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              "Powered by FC Gomel",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: Text(
                  _currentIndex == onboardingData.length - 1 ? "Начать" : "Далее",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
