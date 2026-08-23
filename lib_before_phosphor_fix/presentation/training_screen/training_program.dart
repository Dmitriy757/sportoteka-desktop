import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/training_screen/models/training_model.dart';



import 'active_training.dart';

class TrainingProgramScreen extends StatefulWidget {
  final TrainingProgram program;

  const TrainingProgramScreen({super.key, required this.program});

  @override
  State<TrainingProgramScreen> createState() => _TrainingProgramScreenState();
}

class _TrainingProgramScreenState extends State<TrainingProgramScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.program.title),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.program.exercises.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(widget.program.exercises[index].name),
                  subtitle: Text(widget.program.exercises[index].description),
                  onTap: () => _openExerciseDetail(context, widget.program.exercises[index]),
                );
              },
            ),
          ),
          _buildStartButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF2F8),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.program.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.program.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(Icons.timer, '${widget.program.totalDuration.inMinutes} мин'),
              _buildInfoItem(Icons.fitness_center, '${widget.program.exercises.length} упражнений'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _startTraining(context),
        child: const Text('Начать тренировку'),
      ),
    );
  }

  void _openExerciseDetail(BuildContext context, TrainingExercise exercise) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(exercise.description),
            const SizedBox(height: 16),
            if (exercise.image.isNotEmpty)
              Image.asset(exercise.image, height: 150),
          ],
        ),
      ),
    );
  }

  void _startTraining(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveTrainingScreen(program: widget.program),
      ),
    );
  }
}
