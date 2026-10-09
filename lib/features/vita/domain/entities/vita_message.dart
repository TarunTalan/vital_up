import 'package:equatable/equatable.dart';

enum VitaSender { vita, user }

/// Follow-up a Vita reply can offer as a button inside its bubble.
enum VitaAction {
  viewDietPlan('View Diet Plan', 'view_diet_plan'),
  updateDietPlan('Update My Plan', 'update_diet_plan'),
  viewAnalysis('View Health Analysis', 'view_analysis'),
  viewStressGuide('Open Stress Guide', 'view_stress_guide');

  final String label;

  /// Name used by the vita-chat edge function.
  final String wire;
  const VitaAction(this.label, this.wire);

  static VitaAction? fromWire(Object? value) {
    for (final action in values) {
      if (action.wire == value) return action;
    }
    return null;
  }
}

class VitaMessage extends Equatable {
  final VitaSender sender;
  final String text;

  /// Optional bullet points rendered under [text].
  final List<String> bullets;
  final VitaAction? action;

  /// Change for the meal planner, sent with [VitaAction.updateDietPlan].
  final String? planInstructions;
  final DateTime sentAt;

  /// A user message Vita couldn't answer (offline / error); can be retried.
  final bool failed;

  const VitaMessage({
    required this.sender,
    required this.text,
    required this.sentAt,
    this.bullets = const [],
    this.action,
    this.planInstructions,
    this.failed = false,
  });

  bool get isFromVita => sender == VitaSender.vita;

  VitaMessage copyWith({bool? failed}) => VitaMessage(
        sender: sender,
        text: text,
        sentAt: sentAt,
        bullets: bullets,
        action: action,
        planInstructions: planInstructions,
        failed: failed ?? this.failed,
      );

  Map<String, dynamic> toJson() => {
        's': sender.name,
        't': text,
        'at': sentAt.toIso8601String(),
        if (bullets.isNotEmpty) 'b': bullets,
        if (action != null) 'a': action!.wire,
        if (planInstructions != null) 'pi': planInstructions,
        if (failed) 'f': true,
      };

  factory VitaMessage.fromJson(Map<String, dynamic> json) => VitaMessage(
        sender: json['s'] == VitaSender.user.name
            ? VitaSender.user
            : VitaSender.vita,
        text: json['t'] is String ? json['t'] as String : '',
        sentAt: DateTime.tryParse(json['at'] is String ? json['at'] as String : '') ??
            DateTime.now(),
        bullets: json['b'] is List
            ? (json['b'] as List).whereType<String>().toList()
            : const [],
        action: VitaAction.fromWire(json['a']),
        planInstructions: json['pi'] is String ? json['pi'] as String : null,
        failed: json['f'] == true,
      );

  @override
  List<Object?> get props =>
      [sender, text, bullets, action, planInstructions, sentAt, failed];
}
