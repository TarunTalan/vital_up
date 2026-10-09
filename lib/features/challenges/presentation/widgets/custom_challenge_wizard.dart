import 'package:flutter/material.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/community/domain/entities/friend.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/widgets/friend_tile.dart';

/// Metrics and lengths the server accepts for a challenge.
const _metrics = ChallengesRepository.creatableMetrics;
const _durations = ChallengesRepository.durations;

/// At most this many friends per challenge (server limit).
const _maxFriends = ChallengesRepository.maxFriends;

/// New challenge: what to compete on, for how long, and which friends.
/// Pops once the challenge is sent; callers reload their lists after.
class CustomChallengeWizard extends StatefulWidget {
  const CustomChallengeWizard({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomChallengeWizard()));
  }

  @override
  State<CustomChallengeWizard> createState() => _CustomChallengeWizardState();
}

class _CustomChallengeWizardState extends State<CustomChallengeWizard> {
  late Future<List<Friend>> _friends = _loadFriends();
  var _metric = ChallengeMetric.activeMinutes;
  var _days = 7;
  final _selected = <String>{};
  bool _sending = false;

  Future<List<Friend>> _loadFriends() async {
    final all = await sl<CommunityRepository>().getFriends();
    return all.where((f) => f.status == FriendStatus.accepted).toList();
  }

  void _toggle(Friend f) => setState(() {
    if (!_selected.remove(f.userId) && _selected.length < _maxFriends) {
      _selected.add(f.userId);
    }
  });

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    try {
      await sl<ChallengesRepository>().create(
        metric: _metric,
        days: _days,
        friendIds: _selected.toList(),
      );
      if (mounted) navigator.pop();
      if (rootContext.mounted) {
        showSuccessSnackBar(rootContext, 'Challenge sent');
      }
    } catch (e) {
      debugPrint('Sending a challenge failed: $e');
      if (mounted) {
        showErrorSnackBar(
          context,
          e is ChallengeException
              ? e.message
              : userMessage(
                  e,
                  fallback: "Couldn't send the challenge. Try again.",
                ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grey = context.vColors.grayText;
    return AppScaffold(
      header: const AppPageHeader(title: 'New challenge'),
      bottomBar: AppPrimaryButton(
        label: _selected.isEmpty
            ? 'Send challenge'
            : 'Send to ${_selected.length} '
                  '${_selected.length == 1 ? 'friend' : 'friends'}',
        leadingIcon: const Icon(Icons.send_rounded, size: AppDimens.iconSm),
        enabled: _selected.isNotEmpty,
        isLoading: _sending,
        onTap: _send,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader('Compete on'),
          for (final m in _metrics) ...[
            ChallengeOptionTile(
              icon: challengeMetricIcon(m),
              title: 'Most ${m.label.toLowerCase()}',
              selected: m == _metric,
              onTap: () => setState(() => _metric = m),
            ),
            const SizedBox(height: AppDimens.space8),
          ],
          const SizedBox(height: AppDimens.space16),

          const AppSectionHeader('Length'),
          Wrap(
            spacing: AppDimens.space8,
            children: [
              for (final d in _durations)
                ChoiceChip(
                  label: Text('$d days'),
                  selected: d == _days,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.sectionGap),

          AppSectionHeader(
            'Friends',
            count: _selected.isEmpty ? null : _selected.length,
          ),
          FutureBuilder<List<Friend>>(
            future: _friends,
            builder: (context, snap) {
              if (snap.hasError) {
                return LoadErrorView(
                  onRetry: () => setState(() {
                    _friends = _loadFriends();
                  }),
                );
              }
              final friends = snap.data;
              if (friends == null) {
                return const Padding(
                  padding: EdgeInsets.all(AppDimens.space24),
                  child: Center(child: VitalUpLoader()),
                );
              }
              if (friends.isEmpty) {
                return const AppInfoNote(
                  message:
                      'Add friends on the Friends page first, then '
                      'challenge them here.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pick up to $_maxFriends.',
                    style: context.text.bodySmall?.copyWith(color: grey),
                  ),
                  const SizedBox(height: AppDimens.space8),
                  for (final f in friends) ...[
                    FriendTile(
                      friend: f,
                      onTap: () => _toggle(f),
                      trailing: Checkbox(
                        value: _selected.contains(f.userId),
                        onChanged: (_) => _toggle(f),
                      ),
                    ),
                    const SizedBox(height: AppDimens.space8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
