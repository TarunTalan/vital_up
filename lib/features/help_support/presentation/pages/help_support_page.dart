import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import '../../data/datasources/faq_data.dart';
import '../../domain/entities/faq_item.dart';
import '../../domain/entities/support_ticket.dart';
import 'contact_support_page.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _searchController = TextEditingController();
  FaqCategory _selectedCategory = FaqCategory.all;
  final Set<String> _expandedFaqIds = {};
  final Map<String, bool?> _helpfulVotes =
      {}; // faqId -> true (thumbs up) / false (thumbs down)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FaqItem> get _filteredFaqs {
    final query = _searchController.text.trim().toLowerCase();
    return kFaqDatabase.where((item) {
      final matchesCategory =
          _selectedCategory == FaqCategory.all ||
          item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      final matchQuestion = item.question.toLowerCase().contains(query);
      final matchAnswer = item.answer.toLowerCase().contains(query);
      final matchTags = item.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );

      return matchQuestion || matchAnswer || matchTags;
    }).toList();
  }

  Future<void> _sendDirectEmail({
    String subject = 'Support Inquiry - VitalUp',
  }) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@vitalup.app',
      queryParameters: subject.isNotEmpty ? {'subject': subject} : null,
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(
          const ClipboardData(text: 'support@vitalup.app'),
        );
        if (mounted) {
          showSuccessSnackBar(
            context,
            'Support email copied to clipboard: support@vitalup.app',
          );
        }
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: 'support@vitalup.app'));
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Support email copied to clipboard: support@vitalup.app',
        );
      }
    }
  }

  void _contactSupport({String subject = ''}) {
    openContactSupport(
      context,
      initialCategory: SupportCategory.general,
      initialSubject: subject,
    );
  }

  void _openAssistant() => context.pushNamed('support-chat');

  void _toggleFaq(FaqItem faq) {
    setState(() {
      if (!_expandedFaqIds.remove(faq.id)) _expandedFaqIds.add(faq.id);
    });
    HapticFeedback.selectionClick();
  }

  void _vote(FaqItem faq, bool helpful) {
    setState(() => _helpfulVotes[faq.id] = helpful);
    HapticFeedback.lightImpact();
    if (helpful) {
      showSuccessSnackBar(context, 'Thanks for your feedback!');
    } else {
      _contactSupport(subject: 'Help Article Feedback: ${faq.question}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final faqs = _filteredFaqs;

    return AppScaffold(
      header: const AppPageHeader(title: 'Help & Support'),
      bodyPadding: EdgeInsets.fromLTRB(
        context.gutter,
        AppDimens.sectionGap,
        context.gutter,
        AppDimens.sectionGap + context.safePadding.bottom,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _searchController,
            hint: 'Search FAQs, topics, or errors...',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            suffix: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(
                      Icons.clear_rounded,
                      size: AppDimens.iconSm,
                      color: v.grayText,
                    ),
                    onPressed: () => setState(_searchController.clear),
                  ),
          ),
          const SizedBox(height: AppDimens.space16),
          _SupportActions(
            onAssistant: _openAssistant,
            onContact: _contactSupport,
          ),
          const SizedBox(height: AppDimens.sectionGap),
          const AppCaption('Topics & categories'),
          const SizedBox(height: AppDimens.space8),
          _CategoryChips(
            selected: _selectedCategory,
            onSelected: (cat) {
              setState(() => _selectedCategory = cat);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(height: AppDimens.sectionGap),
          Row(
            children: [
              const Expanded(child: AppCaption('Frequently asked questions')),
              const SizedBox(width: AppDimens.space8),
              Text(
                '${faqs.length} ${faqs.length == 1 ? 'article' : 'articles'}',
                style: context.text.labelSmall?.copyWith(color: v.grayText),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space8),
          if (faqs.isEmpty)
            _EmptySearchResults(onAssistant: _openAssistant)
          else
            for (final faq in faqs)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.space8),
                child: _FaqCard(
                  faq: faq,
                  expanded: _expandedFaqIds.contains(faq.id),
                  vote: _helpfulVotes[faq.id],
                  onToggle: () => _toggleFaq(faq),
                  onVote: (helpful) => _vote(faq, helpful),
                  onAction: faq.actionRoute == null
                      ? null
                      : () => context.pushNamed(faq.actionRoute!),
                ),
              ),
          const SizedBox(height: AppDimens.sectionGap),
          _StillNeedHelpCard(onEmail: _sendDirectEmail),
        ],
      ),
    );
  }
}

/// "Vital Assistant" + "Contact Team" entry cards — side by side, stacked on
/// very narrow screens so the copy never gets squeezed.
class _SupportActions extends StatelessWidget {
  final VoidCallback onAssistant;
  final VoidCallback onContact;

  const _SupportActions({required this.onAssistant, required this.onContact});

  @override
  Widget build(BuildContext context) {
    final assistant = _ActionCard(
      icon: Icons.smart_toy_rounded,
      title: 'Vital Assistant',
      subtitle: 'Chat for instant AI guidance & diagnostics',
      highlighted: true,
      onTap: onAssistant,
    );
    final contact = _ActionCard(
      icon: Icons.mail_outline_rounded,
      title: 'Contact Team',
      subtitle: 'Submit a ticket with category & description',
      onTap: onContact,
    );

    if (context.isSmallPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          assistant,
          const SizedBox(height: AppDimens.cardGap),
          contact,
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: assistant),
          const SizedBox(width: AppDimens.cardGap),
          Expanded(child: contact),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: highlighted,
      borderColor: highlighted ? context.vColors.primaryBorder : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(icon: Icon(icon)),
          const SizedBox(height: AppDimens.space12),
          Text(title, style: context.text.titleSmall),
          const SizedBox(height: AppDimens.space4),
          Text(
            subtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.vColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final FaqCategory selected;
  final ValueChanged<FaqCategory> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cat in FaqCategory.values) ...[
            if (cat != FaqCategory.values.first)
              const SizedBox(width: AppDimens.space8),
            ChoiceChip(
              avatar: Icon(cat.icon, size: AppDimens.iconXs),
              label: Text(cat.label),
              selected: cat == selected,
              showCheckmark: false,
              onSelected: (_) => onSelected(cat),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final FaqItem faq;
  final bool expanded;
  final bool? vote;
  final VoidCallback onToggle;
  final ValueChanged<bool> onVote;
  final VoidCallback? onAction;

  const _FaqCard({
    required this.faq,
    required this.expanded,
    required this.vote,
    required this.onToggle,
    required this.onVote,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: AppDimens.cardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    faq.category.icon,
                    size: AppDimens.iconMd,
                    color: primary,
                  ),
                  const SizedBox(width: AppDimens.space12),
                  Expanded(
                    child: Text(
                      faq.question,
                      style: context.text.titleSmall?.copyWith(
                        color: expanded ? primary : context.colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppDurations.medium,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: AppDimens.iconLg,
                      color: expanded ? primary : v.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.medium,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _FaqAnswer(
                    faq: faq,
                    vote: vote,
                    onVote: onVote,
                    onAction: onAction,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _FaqAnswer extends StatelessWidget {
  final FaqItem faq;
  final bool? vote;
  final ValueChanged<bool> onVote;
  final VoidCallback? onAction;

  const _FaqAnswer({
    required this.faq,
    required this.vote,
    required this.onVote,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final hasAction = faq.actionLabel != null && onAction != null;

    final feedback = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Helpful?',
          style: context.text.labelSmall?.copyWith(color: v.grayText),
        ),
        IconButton(
          tooltip: 'Helpful',
          visualDensity: VisualDensity.compact,
          iconSize: AppDimens.iconSm,
          icon: Icon(
            vote == true
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_up_alt_outlined,
            color: vote == true ? context.colors.primary : v.grayText,
          ),
          onPressed: () => onVote(true),
        ),
        IconButton(
          tooltip: 'Not helpful',
          visualDensity: VisualDensity.compact,
          iconSize: AppDimens.iconSm,
          icon: Icon(
            vote == false
                ? Icons.thumb_down_alt_rounded
                : Icons.thumb_down_alt_outlined,
            color: vote == false ? context.colors.error : v.grayText,
          ),
          onPressed: () => onVote(false),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.space16,
        0,
        AppDimens.space16,
        AppDimens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: AppDimens.space12),
          Text(
            faq.answer,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.space12),
          // Wraps the feedback under the action button on narrow cards.
          Wrap(
            alignment: hasAction
                ? WrapAlignment.spaceBetween
                : WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppDimens.space4,
            children: [
              if (hasAction)
                AppSecondaryButton(
                  label: faq.actionLabel!,
                  expand: false,
                  leadingIcon: const Icon(Icons.open_in_new_rounded),
                  onTap: onAction!,
                ),
              feedback,
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySearchResults extends StatelessWidget {
  final VoidCallback onAssistant;

  const _EmptySearchResults({required this.onAssistant});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    return AppCard(
      padding: AppDimens.cardPaddingLarge,
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: AppDimens.iconXxl,
            color: v.grayText,
          ),
          const SizedBox(height: AppDimens.space12),
          Text(
            'No matching articles found',
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            'Try different keywords or chat directly with Vital Assistant.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: v.grayText),
          ),
          const SizedBox(height: AppDimens.space16),
          AppPrimaryButton(
            label: 'Ask Vital Assistant',
            leadingIcon: const Icon(Icons.smart_toy_rounded),
            onTap: onAssistant,
          ),
        ],
      ),
    );
  }
}

class _StillNeedHelpCard extends StatelessWidget {
  final VoidCallback onEmail;

  const _StillNeedHelpCard({required this.onEmail});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconBadge(
                icon: Icon(Icons.support_agent_rounded),
                size: AppDimens.iconBadgeLarge,
              ),
              const SizedBox(width: AppDimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Still have questions?',
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Email our support team directly for fast assistance.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          AppSecondaryButton(
            label: 'Contact Support via Email',
            leadingIcon: const Icon(Icons.mail_outline_rounded),
            onTap: onEmail,
          ),
        ],
      ),
    );
  }
}
