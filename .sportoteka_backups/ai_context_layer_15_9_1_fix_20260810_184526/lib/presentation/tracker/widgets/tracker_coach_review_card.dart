import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/tracker/services/tracker_coach_review_api.dart';

class TrackerCoachReviewCard extends StatefulWidget {
  final int clubId;
  final int teamId;
  final int sessionId;
  final int playerId;
  final int coachId;

  const TrackerCoachReviewCard({
    super.key,
    required this.clubId,
    required this.teamId,
    required this.sessionId,
    required this.playerId,
    required this.coachId,
  });

  @override
  State<TrackerCoachReviewCard> createState() => _TrackerCoachReviewCardState();
}

class _TrackerCoachReviewCardState extends State<TrackerCoachReviewCard> {
  TrackerCoachReview? _review;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final review = await TrackerCoachReviewApi.getReview(
        sessionId: widget.sessionId,
        playerId: widget.playerId,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    var rating = _review?.rating ?? 7;
    final controller = TextEditingController(text: _review?.comment ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('Оценка тренера'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rating/10',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Slider(
                value: rating.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (value) {
                  setInnerState(() => rating = value.round());
                },
              ),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'rating': rating,
                'comment': controller.text.trim(),
              }),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _loading = true);

    try {
      final review = await TrackerCoachReviewApi.saveReview(
        clubId: widget.clubId,
        teamId: widget.teamId,
        sessionId: widget.sessionId,
        playerId: widget.playerId,
        coachId: widget.coachId,
        rating: result['rating'] as int,
        comment: result['comment'] as String,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F7EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _review == null ? '—' : '${_review!.rating}',
              style: const TextStyle(
                color: Color(0xFF087A3E),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Оценка тренера',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  _review?.comment.isNotEmpty == true
                      ? _review!.comment
                      : 'Оценка пока не добавлена.',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
                if (_error.isNotEmpty)
                  Text(_error, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
    );
  }
}
