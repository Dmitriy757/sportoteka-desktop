class TrainingProgram {
  final String id;
  final String title;
  final String description;
  final String image;
  final List<TrainingExercise> exercises;
  final Duration totalDuration;

  TrainingProgram({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.exercises,
  }) : totalDuration = exercises.fold(
          Duration.zero,
          (sum, exercise) => sum + exercise.duration,
        );
}

class TrainingExercise {
  final String id;
  final String name;
  final String description;
  final Duration duration;
  final String image;
  final String videoUrl;

  TrainingExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.image,
    required this.videoUrl,
  });
}