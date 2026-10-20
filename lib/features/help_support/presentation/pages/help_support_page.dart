import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
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

/// Opens a help link's screen. A link to a screen that no longer exists
/// shows a short message instead of crashing.
void openSupportRoute(BuildContext context, String routeName) {
  try {
    context.pushNamed(routeName);
  } catch (e) {
    debugPrint('Help link to unknown route "$routeName": $e');
    showErrorSnackBar(context, "That screen isn't available.");
  }
}

/// Articles in [category] that match [query], best first. Each word of the
/// query counts on its own (so "sleep not syncing" finds the sync article);
/// a word matches a word in the question, answer or tags by its start.
/// Every word must match when the query has one or two; otherwise the
/// articles matching the most words are shown.
List<FaqItem> searchFaqs(
  List<FaqItem> faqs,
  String query, {
  FaqCategory category = FaqCategory.all,
}) {
  final inCategory = [
    for (final f in faqs)
      if (category == FaqCategory.all || f.category == category) f,
  ];
  final words = _searchWords(query).where((w) => !_stopWords.contains(w));
  final terms = words.toSet().toList();
  if (terms.isEmpty) return inCategory;

  final scored = <(FaqItem, int)>[];
  for (final faq in inCategory) {
    final text = _searchWords(
      '${faq.question} ${faq.tags.join(' ')} ${faq.answer}',
    );
    final hits = terms.where((t) => text.any((w) => _wordMatches(w, t))).length;
    if (hits > 0) scored.add((faq, hits));
  }
  if (scored.isEmpty) return const [];
  final best = scored.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
  final needed = terms.length <= 2 ? terms.length : best;
  return [
    for (final (faq, hits) in scored..sort((a, b) => b.$2.compareTo(a.$2)))
      if (hits >= needed) faq,
  ];
}

/// "sync" finds "syncing" and "syncing" finds "sync" (4+ letters, so
/// "to" doesn't match "today").
bool _wordMatches(String word, String term) =>
    word.startsWith(term) || (word.length >= 4 && term.startsWith(word));

final _searchWordRe = RegExp(r"[\p{L}\p{N}]+", unicode: true);

List<String> _searchWords(String text) => [
  for (final m in _searchWordRe.allMatches(text.toLowerCase())) m.group(0)!,
];

const _stopWords = {
  'a',
  'an',
  'the',
  'i',
  'my',
  'me',
  'is',
  'it',
  'to',
  'do',
  'does',
  'how',
  'what',
  'why',
  'can',
  'not',
  'no',
  'of',
  'on',
  'in',
  'and',
  'or',
  'for',
  'with',
  'app',
  'vitalup',
  'working',
  'work',
  'doesn',
  't',
  'cant',
  'won',
};

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

  List<FaqItem> get _filteredFaqs => searchFaqs(
    kFaqDatabase,
    _searchController.text,
    category: _selectedCategory,
  );

  Future<void> _sendDirectEmail({
    String subject = 'Support Inquiry - VitalUp',
  }) async {
    var launched = false;
    try {
      launched = await launchUrl(
        supportMailUri(subject: subject),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Support mail not opened: $e');
    }
    if (launched) return;
    try {
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
      if (mounted) {
        showSuccessSnackBar(context, 'Support email address copied.');
      }
    } catch (e) {
      debugPrint('Clipboard unavailable: $e');
      if (mounted) {
        showErrorSnackBar(context, 'No email app found. Email $kSupportEmail');
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

  /// Vita answers app questions too; a search with no articles is sent
  /// to it as the first message.
  void _askVita({String question = ''}) {
    final text = sanitizeText(question, maxLength: InputLimits.search);
    try {
      context.pushNamed('vita-chat', extra: text.isEmpty ? null : text);
    } catch (e) {
      debugPrint('Vita chat not opened: $e');
      showErrorSnackBar(context, "That screen isn't available.");
    }
  }

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
      showSuccessSnackBar(context, 'Thanks for your feedback.');
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
            hint: 'Search help articles',
            prefixIcon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            inputFormatters: InputFormatters.text(InputLimits.search),
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
          _AskVitaCard(onTap: _askVita),
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
            _EmptySearchResults(
              onAskVita: () => _askVita(question: _searchController.text),
            )
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
                      : () => openSupportRoute(context, faq.actionRoute!),
                ),
              ),
          const SizedBox(height: AppDimens.sectionGap),
          _StillNeedHelpCard(
            onContact: _contactSupport,
            onEmail: _sendDirectEmail,
          ),
        ],
      ),
    );
  }
}

/// Opens Vita, which answers questions about the app as well as health.
class _AskVitaCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AskVitaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: true,
      borderColor: context.vColors.primaryBorder,
      onTap: onTap,
      showChevron: true,
      child: Row(
        children: [
          AppIconBadge(
            color: VitaColors.accent,
            icon: SvgPicture.asset(
              'assets/icons/nav/vita.svg',
              width: AppDimens.iconSm,
              height: AppDimens.iconSm,
              colorFilter: ColorFilter.mode(
                AppIconBadge.glyphColor(context, VitaColors.accent),
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ask Vita',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  'Questions about the app or your health',
                  style: context.text.bodySmall?.copyWith(
                    color: context.vColors.grayText,
                    height: 1.3,
                  ),
                ),
              ],
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
  final VoidCallback onAskVita;

  const _EmptySearchResults({required this.onAskVita});

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
            'Try other words, or ask Vita your question.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: v.grayText),
          ),
          const SizedBox(height: AppDimens.space16),
          AppPrimaryButton(
            label: 'Ask Vita',
            leadingIcon: SvgPicture.asset(
              'assets/icons/nav/vita.svg',
              width: AppDimens.iconSm,
              height: AppDimens.iconSm,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            onTap: onAskVita,
          ),
        ],
      ),
    );
  }
}

class _StillNeedHelpCard extends StatelessWidget {
  final VoidCallback onContact;
  final VoidCallback onEmail;

  const _StillNeedHelpCard({required this.onContact, required this.onEmail});

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
                      'Submit a ticket or email our support desk directly.',
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
          AppPrimaryButton(
            label: 'Open Contact Form',
            leadingIcon: const Icon(Icons.edit_note_rounded),
            onTap: onContact,
          ),
          const SizedBox(height: AppDimens.space10),
          InkWell(
            onTap: onEmail,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    size: AppDimens.iconSm,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppDimens.space6),
                  Text(
                    'Direct contact: $kSupportEmail',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
