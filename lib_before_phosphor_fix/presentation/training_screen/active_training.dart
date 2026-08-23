import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/training_screen/models/training_model.dart';


import 'package:sportoteka/data/training_repository.dart';


class ActiveTrainingScreen extends StatefulWidget {
  final TrainingProgram program;

  const ActiveTrainingScreen({super.key, required this.program});

  @override
  State<ActiveTrainingScreen> createState() => _ActiveTrainingScreenState();
}

class _ActiveTrainingScreenState extends State<ActiveTrainingScreen> {
  int _currentExerciseIndex = 0;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startExercise();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startExercise() {
    final currentExercise = widget.program.exercises[_currentExerciseIndex];
    setState(() {
      _remainingSeconds = currentExercise.duration.inSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _nextExercise();
        }
      });
    });
  }

  void _nextExercise() {
    _timer.cancel();
    if (_currentExerciseIndex < widget.program.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _isPaused = false;
      });
      _startExercise();
    } else {
      _completeTraining();
    }
  }

  void _completeTraining() {
    TrainingRepository.saveCompletedTraining(widget.program);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Тренировка завершена!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise = widget.program.exercises[_currentExerciseIndex];
    final progress = _remainingSeconds / currentExercise.duration.inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentExerciseIndex + 1}/${widget.program.exercises.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentExercise.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:'
                  '${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset(
                  currentExercise.image,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  currentExercise.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isPaused ? _resumeExercise : _pauseExercise,
                  child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                ),
                ElevatedButton(
                  onPressed: _nextExercise,
                  child: const Text('Пропустить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pauseExercise() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeExercise() {
    setState(() {
      _isPaused = false;
    });
  }
}