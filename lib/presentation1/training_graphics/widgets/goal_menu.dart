// lib/presentation/training_graphics/widgets/goal_menu.dart
import 'package:flutter/material.dart';

enum GoalType {
  vorota1,
  // Сюда можно добавить другие типы ворот в будущем
  // vorota2,
  // vorota3,
}

enum GoalView {
  back,
  front,
  left,
  right,
}

class GoalMenu extends StatelessWidget {
  const GoalMenu({
    super.key,
    required this.onSelectGoal,
  });

  final Function(String assetPath) onSelectGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Ворота',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Сетка предпросмотра ворот
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Строка с видами ворот
                const Text(
                  'Выберите вид ворот',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Грид из 4 кнопок для каждого вида
                Row(
                  children: [
                    _buildGoalButton(
                      view: GoalView.front,
                      label: 'Спереди',
                      icon: Icons.arrow_forward,
                    ),
                    const SizedBox(width: 8),
                    _buildGoalButton(
                      view: GoalView.back,
                      label: 'Сзади',
                      icon: Icons.arrow_back,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildGoalButton(
                      view: GoalView.left,
                      label: 'Слева',
                      icon: Icons.arrow_left,
                    ),
                    const SizedBox(width: 8),
                    _buildGoalButton(
                      view: GoalView.right,
                      label: 'Справа',
                      icon: Icons.arrow_right,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Подсказка
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white54,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Нажмите на канвас, чтобы разместить ворота',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalButton({
    required GoalView view,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          String assetPath;
          switch (view) {
            case GoalView.back:
              assetPath = 'assets/training/stamps/vorota1/back.svg';
              break;
            case GoalView.front:
              assetPath = 'assets/training/stamps/vorota1/front.svg';
              break;
            case GoalView.left:
              assetPath = 'assets/training/stamps/vorota1/left.svg';
              break;
            case GoalView.right:
              assetPath = 'assets/training/stamps/vorota1/right.svg';
              break;
          }
          onSelectGoal(assetPath);
        },
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}