// tracking_hero_widget.dart - Упрощенная версия
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/home_screen/home_screen_design.dart';

class TrackingHeroWidget extends StatelessWidget {
  final HomeScreenDesign design;
  final VoidCallback onOpenTracking;
  final bool isConnected; // true - устройство подключено, false - нет

  const TrackingHeroWidget({
    super.key,
    required this.design,
    required this.onOpenTracking,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(design.bannerRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isConnected
              ? [
                  const Color(0xFF0F766E),
                  design.primaryColor,
                ]
              : [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(design.bannerRadius),
          onTap: onOpenTracking,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Иконка
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Текст
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Трекер подключен' : 'Трекер не подключен',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected 
                            ? 'Устройство готово к работе' 
                            : 'Подключите датчик для отслеживания',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Кнопка действия
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isConnected ? 'Открыть' : 'Подключить',
                    style: TextStyle(
                      color: design.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}