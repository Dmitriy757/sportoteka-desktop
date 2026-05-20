import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SportotekaWatchBanner extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onCta;   // Подробнее
  final VoidCallback? onBuy;   // Купить

  const SportotekaWatchBanner({
    super.key,
    required this.imageUrl,
    this.onCta,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0057FF), Color(0xFF00C6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Фото часов
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.watch, size: 80, color: Colors.white),
            ),
          ),

          // Затемнение для читаемости текста
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Текст и кнопка
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Спортотека One',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Все тренировки — на запястье\nAI‑тренер, AR‑режим, ЭКГ, рейтинг',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0057FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onCta ??
                      () {
                        showDialog(
                          context: context,
                          builder: (_) => _WatchDetailsDialog(onBuy: onBuy),
                        );
                      },
                  child: const Text('Подробнее'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchDetailsDialog extends StatelessWidget {
  final VoidCallback? onBuy;
  const _WatchDetailsDialog({this.onBuy});

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.white,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                const Text(
                  'Sportoteka One',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // фичи
                const Text('🧠 AI‑Тренер: анализ техники и советы'),
                const Text('🕶️ AR‑режим: виртуальные цели и баттлы'),
                const Text('❤️ Здоровье: ЭКГ, давление, SpO₂, сон'),
                const Text('⚽ 100+ режимов, VO₂ max, статистика'),
                const Text('🏆 Бейджи, ТОП недели, челленджи'),
                const Text('🛡️ SOS: обнаружение падений, контроль для детей'),
                const SizedBox(height: 16),
                const Text('Модели: Lite • Pro • Team Edition'),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 10),
                const Text(
                  'Описание',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sportoteka One — умные часы для спорта и здоровья. '
                  'От персонального AI‑тренера и AR‑челленджей до ЭКГ и мониторинга сна — '
                  'всё в одном устройстве. Работают автономно и синхронизируются с приложением.',
                  style: TextStyle(color: Colors.black87, height: 1.35),
                ),
                const SizedBox(height: 18),

                // CTA: КУПИТЬ
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onBuy != null) {
                      onBuy!();
                    } else {
                      // TODO: замените на реальный переход в магазин
                      // launchUrl(Uri.parse('https://sportotekaapp.ru/one'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Купить')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Купить'),
                ),
                const SizedBox(height: 8),

                // Закрыть
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
