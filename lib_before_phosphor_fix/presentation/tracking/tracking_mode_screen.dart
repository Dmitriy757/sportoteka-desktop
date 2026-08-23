import 'package:flutter/material.dart';
import 'tracking_device_setup_screen.dart';
import 'models/tracking_models.dart';

class TrackingModeScreen extends StatelessWidget {
  const TrackingModeScreen({super.key});

  static const Color primary = Color(0xFF12B76A);
  static const Color primaryDark = Color(0xFF067A46);
  static const Color bg = Color(0xFFFFFFFF);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF102027);
  static const Color muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: text,
        title: const Text(
          'Трекинг',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _heroCard(),
          const SizedBox(height: 18),
          const Text(
            'Выберите формат работы',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Подключайте трекеры и пульсометры, запускайте тренировку и записывайте телеметрию в Sportoteka.',
            style: TextStyle(
              fontSize: 14,
              color: muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _modeCard(
            context,
            title: 'Командная тренировка',
            subtitle:
                'Подключение датчиков для нескольких игроков команды, привязка устройств и запуск общей тренировки.',
            icon: Icons.groups_rounded,
            badge: 'Тренер / клуб',
            mode: TrackingMode.team,
          ),
          const SizedBox(height: 14),
          _modeCard(
            context,
            title: 'Индивидуальная тренировка',
            subtitle:
                'Подключение трекера и пульсометра для одного спортсмена с персональной записью метрик.',
            icon: Icons.person_rounded,
            badge: 'Игрок / тренер',
            mode: TrackingMode.individual,
          ),
          const SizedBox(height: 20),
          _infoBlock(),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, primary],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.monitor_heart_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sportoteka Tracking',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Живой мониторинг устройств, пульса и пространственных данных тренировки.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required TrackingMode mode,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackingDeviceSetupScreen(mode: mode),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFF1F3F6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: primary, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F3F6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Что будет доступно после подключения',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: text,
            ),
          ),
          SizedBox(height: 12),
          _Point('Сканирование и подключение BLE-устройств'),
          _Point('Привязка трекера и пульсометра к игроку'),
          _Point('Запуск командной или индивидуальной тренировки'),
          _Point('Live-метрики и запись сессии'),
          _Point('Тепловая карта после получения координат'),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String text;
  const _Point(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: TrackingModeScreen.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: TrackingModeScreen.muted,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}