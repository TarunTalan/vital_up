import 'package:flutter/material.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_format_utils.dart';
import 'package:vital_up/features/activity_tracking/presentation/utils/activity_type_ui.dart';

/// Shows full stats for one session plus editable tag/note fields.
/// Call via [showSessionDetailSheet]; the returned future resolves with
/// (tag, note) if the user saved changes, or null if they dismissed it.
Future<(String?, String?)?> showSessionDetailSheet(
    BuildContext context, {
      required HistoryEntry entry,
    }) {
  return showModalBottomSheet<(String?, String?)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SessionDetailSheet(entry: entry),
  );
}

class _SessionDetailSheet extends StatefulWidget {
  final HistoryEntry entry;

  const _SessionDetailSheet({required this.entry});

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  late final TextEditingController _tagController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController(text: widget.entry.annotation?.tag ?? '');
    _noteController = TextEditingController(text: widget.entry.annotation?.note ?? '');
  }

  @override
  void dispose() {
    _tagController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.entry.session;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(activityTypeIcon(session.activityType), color: const Color(0xFF2BC7D8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.activityType.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatShortDate(session.startTime)} · ${formatTimeOfDay(session.startTime)}',
                  style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _DetailStat(label: 'Distance', value: '${formatDistanceKm(session.totalDistanceMeters)} km'),
                _DetailStat(
                  label: 'Duration',
                  value: formatDuration(Duration(seconds: session.totalDurationSeconds)),
                ),
                _DetailStat(label: 'Pace', value: '${formatPace(session.avgPaceSecondsPerKm)} /km'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DetailStat(label: 'Calories', value: '${session.calories} cal'),
                _DetailStat(
                  label: 'Steps',
                  value: session.stepCountReliable ? '${session.steps}' : '${session.steps}*',
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            if (!session.stepCountReliable) ...[
              const SizedBox(height: 4),
              const Text(
                '*Step count may be inaccurate for this session.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'TAG',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _tagController,
              decoration: InputDecoration(
                hintText: 'e.g. Morning run, Race day, Recovery',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'NOTE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'How did it feel?',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop((
                  _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
                  _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9A9A9A)),
          ),
        ],
      ),
    );
  }
}