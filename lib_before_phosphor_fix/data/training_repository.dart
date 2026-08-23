import 'package:sportoteka/presentation/training_screen/models/training_model.dart';


class TrainingRepository {
  static TrainingProgram getProgramByType(String type) {
    // Здесь должна быть логика загрузки из API или базы данных
    // Это примерная реализация
    switch (type) {
      case 'football':
        return TrainingProgram(
          id: '1',
          title: 'Футбольная тренировка',
          description: 'Специальные упражнения для футболистов',
          image: 'assets/football.jpg',
          exercises: [
            TrainingExercise(
              id: '1',
              name: 'Разминка',
              description: 'Легкий бег и растяжка',
              duration: const Duration(minutes: 5),
              image: 'assets/warmup.jpg',
              videoUrl: '',
            ),
            // Другие упражнения...
          ],
        );
      // Другие типы тренировок...
      default:
        throw Exception('Unknown training type');
    }
  }

  static void saveCompletedTraining(TrainingProgram program) {
    // Сохранение завершенной тренировки
  }
}