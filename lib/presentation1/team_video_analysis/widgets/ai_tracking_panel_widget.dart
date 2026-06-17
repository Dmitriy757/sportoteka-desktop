// lib/presentation/team_video_analysis/widgets/ai_tracking_panel_widget.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_tracking_controller.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';

class AiTrackingPanelWidget extends StatefulWidget {
  final AiTrackingController aiTracking;
  final bool showHeatmap;
  final VoidCallback onToggleAi;
  final Function(bool) onToggleHeatmap;
  final VoidCallback onBindTrack;
  final Function(int) onJumpToTime;
  final VoidCallback onExport;

  const AiTrackingPanelWidget({
    super.key,
    required this.aiTracking,
    required this.showHeatmap,
    required this.onToggleAi,
    required this.onToggleHeatmap,
    required this.onBindTrack,
    required this.onJumpToTime,
    required this.onExport,
  });

  @override
  State<AiTrackingPanelWidget> createState() => _AiTrackingPanelWidgetState();
}

class _AiTrackingPanelWidgetState extends State<AiTrackingPanelWidget> {
  @override
  void initState() {
    super.initState();
    // Подписываемся на изменения в контроллере
    widget.aiTracking.addListener(_onAiTrackingChanged);
  }

  @override
  void dispose() {
    // Отписываемся при уничтожении виджета
    widget.aiTracking.removeListener(_onAiTrackingChanged);
    super.dispose();
  }

  void _onAiTrackingChanged() {
    if (mounted) {
      setState(() {}); // Принудительно перерисовываем при изменениях
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      _buildStatsHeader(),
      const SizedBox(height: 16),
      _buildControlPanel(),
      const SizedBox(height: 20),
      _buildPlayerStats(),      // Добавлено!
      const SizedBox(height: 20),
      _buildDisplayOptions(),
      const SizedBox(height: 20),
      _buildTrackedPlayersList(),
    ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Трекинг',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Автоматический анализ движения',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: widget.aiTracking.isRunning,
                onChanged: (_) => widget.onToggleAi(),
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Треков', widget.aiTracking.tracks.length.toString()),
              _buildStatItem('Выбран', widget.aiTracking.selectedTrackId != null ? '1' : '0'),
              _buildStatItem('Точек', _getTotalPoints().toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: Icons.link_rounded,
                  label: 'Привязать',
                  onTap: widget.onBindTrack,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildControlButton(
                  icon: Icons.heat_pump_rounded,
                  label: 'Heatmap',
                  onTap: () => widget.onToggleHeatmap(!widget.showHeatmap),
                  isActive: widget.showHeatmap,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildControlButton(
                  icon: Icons.download_rounded,
                  label: 'Экспорт',
                  onTap: widget.onExport,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.aiTracking.selectedTrack != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.aiTracking.selectedTrack!.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.aiTracking.selectedTrack!.id}',
                        style: TextStyle(
                          color: widget.aiTracking.selectedTrack!.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.aiTracking.selectedTrack!.boundPlayerName ?? 'Не привязан',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${widget.aiTracking.selectedTrack!.points.length} точек · ${widget.aiTracking.selectedTrack!.speed?.toStringAsFixed(1) ?? '0.0'} км/ч',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onBindTrack,
                    icon: const Icon(Icons.link, size: 18),
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        // Добавляем визуальную обратную связь
        setState(() {
          // Небольшая анимация нажатия
        });
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? color : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? color : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Отображение',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildCheckboxTile(
            'Показывать треки',
            widget.aiTracking.showTrails,
            (v) => widget.aiTracking.showTrails = v,
          ),
          _buildCheckboxTile(
            'Показывать имена',
            widget.aiTracking.showLabels,
            (v) => widget.aiTracking.showLabels = v,
          ),
          _buildCheckboxTile(
            'Показывать скорость',
            widget.aiTracking.showSpeed,
            (v) {
              widget.aiTracking.showSpeed = v;
              widget.aiTracking.notifyListeners();
            },
          ),
          _buildCheckboxTile(
            'Показывать рамки',
            widget.aiTracking.showBoundingBoxes,
            (v) => widget.aiTracking.showBoundingBoxes = v,
          ),
          _buildCheckboxTile(
            'Только выбранный',
            widget.aiTracking.showOnlySelectedPlayer,
            (v) => widget.aiTracking.showOnlySelectedPlayer = v,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: (v) {
            onChanged(v ?? false);
            setState(() {}); // Принудительное обновление
          },
          activeColor: const Color(0xFF7C3AED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackedPlayersList() {
    if (widget.aiTracking.tracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'Нет активных треков',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Включите AI трекинг для отслеживания игроков',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Отслеживаемые игроки',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.aiTracking.tracks.map((track) => _buildTrackItem(track)).toList(),
      ],
    );
  }


Widget _buildPlayerStats() {
  if (widget.aiTracking.selectedTrack == null) return Container();
  
  final track = widget.aiTracking.selectedTrack!;
  final points = track.points;
  
  if (points.isEmpty) return Container();
  
  // Вычисляем дополнительные метрики
  double totalDistance = 0;
  double maxSpeed = 0;
  double avgSpeed = 0;
  
  for (int i = 1; i < points.length; i++) {
    final p1 = points[i-1].position;
    final p2 = points[i].position;
    final dist = sqrt(pow(p2.dx - p1.dx, 2) + pow(p2.dy - p1.dy, 2)) * 0.17;
    totalDistance += dist;
    
    if (points[i].speed > maxSpeed) {
      maxSpeed = points[i].speed;
    }
  }
  
  if (points.length > 1) {
    avgSpeed = totalDistance / ((points.last.timeMs - points.first.timeMs) / 1000) * 3.6;
  }
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF7C3AED).withOpacity(0.1),
          const Color(0xFF6D28D9).withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.sports_soccer,
                color: Color(0xFF7C3AED),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Статистика игрока',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              'Дистанция',
              '${totalDistance.toStringAsFixed(1)} м',
              Icons.straighten,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Макс. скорость',
              '${maxSpeed.toStringAsFixed(1)} км/ч',
              Icons.speed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard(
              'Ср. скорость',
              '${avgSpeed.toStringAsFixed(1)} км/ч',
              Icons.av_timer,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              'Время',
              _formatTime((points.last.timeMs - points.first.timeMs) / 1000),
              Icons.timer,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildStatCard(String label, String value, IconData icon) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    ),
  );
}

String _formatTime(double seconds) {
  int mins = seconds ~/ 60;
  int secs = seconds.toInt() % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}

  Widget _buildTrackItem(PlayerTrack track) {
    final isSelected = widget.aiTracking.selectedTrackId == track.id;
    final playerName = track.boundPlayerName ?? 'Не привязан';

    return GestureDetector(
      onTap: () {
        widget.aiTracking.selectTrackByTap(Offset.zero);
        setState(() {}); // Обновляем UI после выбора
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF7C3AED).withOpacity(0.3)
                : const Color(0xFFEDF2F7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (track.color).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${track.id}',
                  style: TextStyle(
                    color: track.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playerName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.points.length} точек · ${track.speed?.toStringAsFixed(1) ?? '0.0'} км/ч',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                if (track.points.isNotEmpty) {
                  widget.onJumpToTime(track.points.first.timeMs);
                }
              },
              icon: const Icon(Icons.timeline_rounded, size: 18),
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
      ),
    );
  }

  int _getTotalPoints() {
    return widget.aiTracking.tracks.fold(0, (sum, track) => sum + track.points.length);
  }
}