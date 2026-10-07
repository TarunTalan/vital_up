import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_section_header.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/widgets/challenge_tile.dart';
import 'package:vital_up/features/challenges/presentation/widgets/custom_challenge_wizard.dart';

/// Friend challenges: open invites, running and finished contests, and a
/// button to start a new one.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChallengesCubit, ChallengesState>(
      listenWhen: (prev, next) => next.messageId != prev.messageId,
      listener: (context, s) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.message!))),
      builder: (context, state) {
        final cubit = context.read<ChallengesCubit>();
        final challenges = state.challenges;
        final now = DateTime.now();
        bool open(Challenge c) => challengeIsOpen(c, now);
        final sections = challenges == null
            ? const <(String, List<Challenge>)>[]
            : [
                (
                  'Invites',
                  challenges
                      .where(
                        (c) =>
                            open(c) && c.myStatus == ParticipantStatus.invited,
                      )
                      .toList(),
                ),
                (
                  'Active',
                  challenges
                      .where(
                        (c) =>
                            open(c) && c.myStatus != ParticipantStatus.invited,
                      )
                      .toList(),
                ),
                ('History', challenges.where((c) => !open(c)).toList()),
              ];
        return AppScaffold(
          onRefresh: () async => cubit.load(),
          header: const AppPageHeader(title: 'Challenges'),
          bottomBar: AppPrimaryButton(
            label: 'New challenge',
            leadingIcon: const Icon(Icons.add_rounded, size: AppDimens.iconSm),
            onTap: () =>
                CustomChallengeWizard.show(context).then((_) => cubit.load()),
          ),
          body: challenges == null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimens.space48),
                  child: state.failed
                      ? LoadErrorView(onRetry: cubit.load)
                      : const Center(child: VitalUpLoader()),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (challenges.isEmpty)
                      const AppInfoNote(
                        message:
                            'Challenge friends to the most active minutes, '
                            'distance or workouts over 3, 7 or 14 days. '
                            'Workouts count once they are backed up.',
                        icon: Icons.flag_outlined,
                      ),
                    for (final (title, items) in sections)
                      if (items.isNotEmpty) ...[
                        AppSectionHeader(title, count: items.length),
                        for (final c in items) ...[
                          ChallengeTile(
                            challenge: c,
                            busy: state.busy.contains(c.id),
                          ),
                          const SizedBox(height: AppDimens.cardGap),
                        ],
                        const SizedBox(height: AppDimens.space12),
                      ],
                  ],
                ),
        );
      },
    );
  }
}
