import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/add_personal_training_screen/add_personal_training_screen.dart';

class FeedPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);

  static const danger = Color(0xFFE74C3C);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class TrainingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> training;

  const TrainingDetailScreen({
    super.key,
    required this.training,
  });

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  bool _isDeleting = false;

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  String _safe(dynamic v) => (v ?? '').toString().trim();

  double _parseRating(dynamic value) {
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }

  Future<void> _deleteTraining() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Удалить тренировку',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить эту тренировку?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(
                color: FeedPalette.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    try {
      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/delete_personal_training.php'),
        body: {'id': widget.training['id'].toString()},
      );

      if (!mounted) return;
      setState(() => _isDeleting = false);

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при удалении')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка соединения с сервером')),
      );
    }
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPersonalTrainingScreen(training: widget.training),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.training;

    final type = _safe(t['type']).isNotEmpty ? _safe(t['type']) : 'Тренировка';
    final sport = _safe(t['sport']).isNotEmpty ? _safe(t['sport']) : 'Спорт';
    final duration = _safe(t['duration']);
    final goal = _safe(t['goal']);
    final comment = _safe(t['comment']);
    final rating = _parseRating(t['rating']);
    final date = _parseDate(t['date']);

    final dateText =
        date != null ? DateFormat('dd.MM.yyyy').format(date) : 'Без даты';

    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FeedPalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Детали тренировки',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            onPressed: _openEdit,
            icon: Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: _isDeleting ? null : _deleteTraining,
            icon: Container(
              decoration: BoxDecoration(
                color: FeedPalette.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FeedPalette.border),
              ),
              padding: const EdgeInsets.all(8),
              child: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.delete_outline,
                      color: FeedPalette.danger,
                      size: 18,
                    ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildTopCard(
            type: type,
            sport: sport,
            dateText: dateText,
            rating: rating,
            duration: duration,
          ),
          const SizedBox(height: 12),

          _buildSectionTitle('Основная информация'),
          const SizedBox(height: 8),
          _whiteCard(
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.sports_soccer_rounded,
                  title: 'Вид спорта',
                  value: sport,
                ),
                _divider(),
                _buildInfoRow(
                  icon: Icons.category_rounded,
                  title: 'Тип тренировки',
                  value: type,
                ),
                _divider(),
                _buildInfoRow(
                  icon: Icons.calendar_today_rounded,
                  title: 'Дата',
                  value: dateText,
                ),
                _divider(),
                _buildInfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Длительность',
                  value: duration.isEmpty ? '-' : '$duration мин',
                ),
                _divider(),
                _buildInfoRow(
                  icon: Icons.star_rounded,
                  title: 'Оценка',
                  value: rating.toStringAsFixed(1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _buildSectionTitle('Цель'),
          const SizedBox(height: 8),
          _whiteCard(
            child: _buildTextBlock(
              icon: Icons.flag_rounded,
              text: goal.isNotEmpty ? goal : 'Цель не указана',
            ),
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSectionTitle('Комментарий'),
            const SizedBox(height: 8),
            _whiteCard(
              child: _buildTextBlock(
                icon: Icons.chat_bubble_outline_rounded,
                text: comment,
              ),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _deleteTraining,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(_isDeleting ? 'Удаление...' : 'Удалить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FeedPalette.danger,
                    side: const BorderSide(color: FeedPalette.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: FeedPalette.greenGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openEdit,
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      'Редактировать',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard({
    required String type,
    required String sport,
    required String dateText,
    required double rating,
    required String duration,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FeedPalette.primaryGreen.withOpacity(0.12),
            FeedPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: FeedPalette.greenGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: FeedPalette.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: FeedPalette.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: FeedPalette.border),
                ),
                child: Text(
                  sport,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: FeedPalette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(Icons.calendar_today_rounded, dateText),
              _metaChip(
                Icons.schedule_rounded,
                duration.isEmpty ? '-' : '$duration мин',
              ),
              _metaChip(Icons.star_rounded, rating.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FeedPalette.primaryGreen),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: FeedPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: FeedPalette.text,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: FeedPalette.superLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: FeedPalette.primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    color: FeedPalette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlock({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: FeedPalette.greenGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: FeedPalette.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: FeedPalette.border,
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}