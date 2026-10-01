import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import '../../data/datasources/faq_data.dart';
import '../../domain/entities/faq_item.dart';
import '../../domain/entities/support_ticket.dart';
import '../widgets/contact_support_sheet.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _searchController = TextEditingController();
  FaqCategory _selectedCategory = FaqCategory.all;
  final Set<String> _expandedFaqIds = {};
  final Map<String, bool?> _helpfulVotes = {}; // faqId -> true (thumbs up) / false (thumbs down)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FaqItem> get _filteredFaqs {
    final query = _searchController.text.trim().toLowerCase();
    return kFaqDatabase.where((item) {
      final matchesCategory = _selectedCategory == FaqCategory.all ||
          item.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      final matchQuestion = item.question.toLowerCase().contains(query);
      final matchAnswer = item.answer.toLowerCase().contains(query);
      final matchTags = item.tags.any((tag) => tag.toLowerCase().contains(query));

      return matchQuestion || matchAnswer || matchTags;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final faqs = _filteredFaqs;

    return AppScaffold(
      header: AppPageHeader(
        title: 'Help & Support',
        action: IconButton(
          tooltip: 'Email Support Team',
          icon: const Icon(Icons.mail_outline_rounded),
          onPressed: () {
            showContactSupportSheet(
              context,
              initialCategory: SupportCategory.general,
            );
          },
        ),
      ),
      padBody: false,
      scrollable: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.sectionGap,
          context.gutter,
          AppDimens.sectionGap + context.safePadding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Search Bar
            _buildSearchBar(context),
            const SizedBox(height: AppDimens.space16),

            // 2. Quick Action Cards (Chatbot + Contact Support)
            _buildSupportActionCards(context),
            const SizedBox(height: AppDimens.sectionGap),

            // 3. Category Filter Chips
            AppCaption('TOPICS & CATEGORIES'),
            const SizedBox(height: AppDimens.space8),
            _buildCategoryChips(),
            const SizedBox(height: AppDimens.space16),

            // 4. FAQ Accordion List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppCaption('FREQUENTLY ASKED QUESTIONS'),
                Text(
                  '${faqs.length} ${faqs.length == 1 ? 'article' : 'articles'}',
                  style: context.text.labelSmall?.copyWith(color: v.grayText),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.space8),

            if (faqs.isEmpty)
              _buildEmptySearchResults(context)
            else
              ...faqs.map((faq) => _buildFaqCard(context, faq)),

            const SizedBox(height: AppDimens.sectionGap),

            // 5. Still need help footer
            _buildStillNeedHelpCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final v = context.vColors;
    return Container(
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder ?? AppColors.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurface,
        ),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: v.grayText),
          hintText: 'Search FAQs, topics, or errors...',
          hintStyle: context.text.bodyMedium?.copyWith(color: v.grayText),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppDimens.space12),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: AppDimens.iconSm),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSupportActionCards(BuildContext context) {
    final v = context.vColors;

    return Row(
      children: [
        // AI Assistant Card
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              onTap: () => context.pushNamed('support-chat'),
              child: Container(
                padding: const EdgeInsets.all(AppDimens.space16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withAlpha(35),
                      AppColors.primary.withAlpha(15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(70),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimens.space8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: AppColors.buttonText,
                        size: AppDimens.iconMd,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space10),
                    Text(
                      'Vital Assistant',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Chat for instant AI guidance & diagnostics',
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.space12),

        // Email Support Card
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusCard),
              onTap: () {
                showContactSupportSheet(
                  context,
                  initialCategory: SupportCategory.general,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(AppDimens.space16),
                decoration: BoxDecoration(
                  color: v.glassFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(
                    color: v.glassBorder ?? AppColors.glassBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimens.space8),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withAlpha(40),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: const Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.primary,
                        size: AppDimens.iconMd,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space10),
                    Text(
                      'Contact Team',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimens.space2),
                    Text(
                      'Submit ticket with category & description',
                      style: context.text.labelSmall?.copyWith(
                        color: v.grayText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final v = context.vColors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: FaqCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.space8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.icon),
                  const SizedBox(width: AppDimens.space4),
                  Text(cat.label),
                ],
              ),
              selected: isSelected,
              selectedColor: AppColors.primary.withAlpha(45),
              backgroundColor: v.glassFill,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : (v.glassBorder ?? Colors.transparent),
              ),
              labelStyle: context.text.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : context.colors.onSurface,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategory = cat);
                  HapticFeedback.selectionClick();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqCard(BuildContext context, FaqItem faq) {
    final v = context.vColors;
    final isExpanded = _expandedFaqIds.contains(faq.id);
    final userVote = _helpfulVotes[faq.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space10),
      child: AppCard(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedFaqIds.remove(faq.id);
                  } else {
                    _expandedFaqIds.add(faq.id);
                  }
                });
                HapticFeedback.selectionClick();
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space6,
                      vertical: AppDimens.space2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Text(
                      faq.category.icon,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space10),
                  Expanded(
                    child: Text(
                      faq.question,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isExpanded ? AppColors.primary : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.space8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? AppColors.primary : v.grayText,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: AppDimens.space12),
              Divider(
                color: v.divider,
                height: AppDimens.borderThin,
                thickness: AppDimens.borderThin,
              ),
              const SizedBox(height: AppDimens.space12),
              Text(
                faq.answer,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurface,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppDimens.space12),

              // Action button & Helpful buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (faq.actionLabel != null && faq.actionRoute != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space10,
                          vertical: AppDimens.space4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppColors.primary.withAlpha(25),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                        ),
                      ),
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: AppDimens.iconSm,
                      ),
                      label: Text(
                        faq.actionLabel!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        context.pushNamed(faq.actionRoute!);
                      },
                    )
                  else
                    const SizedBox.shrink(),

                  // Thumbs up / down feedback
                  Row(
                    children: [
                      Text(
                        'Helpful?',
                        style: context.text.labelSmall?.copyWith(color: v.grayText),
                      ),
                      const SizedBox(width: AppDimens.space6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: Icon(
                          userVote == true
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          color: userVote == true
                              ? AppColors.primary
                              : v.grayText,
                        ),
                        onPressed: () {
                          setState(() => _helpfulVotes[faq.id] = true);
                          HapticFeedback.lightImpact();
                          showSuccessSnackBar(context, 'Thanks for your feedback! 👍');
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: Icon(
                          userVote == false
                              ? Icons.thumb_down_alt_rounded
                              : Icons.thumb_down_alt_outlined,
                          color: userVote == false
                              ? AppColors.error
                              : v.grayText,
                        ),
                        onPressed: () {
                          setState(() => _helpfulVotes[faq.id] = false);
                          HapticFeedback.lightImpact();
                          showContactSupportSheet(
                            context,
                            initialCategory: SupportCategory.general,
                            initialSubject: 'Help Article Feedback: ${faq.question}',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults(BuildContext context) {
    final v = context.vColors;
    return AppCard(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.space24),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: AppDimens.space12),
          Text(
            'No matching articles found',
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimens.space6),
          Text(
            'Try different keywords or chat directly with Vital Assistant.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: v.grayText),
          ),
          const SizedBox(height: AppDimens.space16),
          AppPrimaryButton(
            label: 'Ask Vital Assistant',
            leadingIcon: const Icon(Icons.smart_toy_rounded, size: AppDimens.iconSm),
            onTap: () => context.pushNamed('support-chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildStillNeedHelpCard(BuildContext context) {
    final v = context.vColors;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space16),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder ?? AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimens.space10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: AppDimens.iconLg,
            ),
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still have questions?',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimens.space2),
                Text(
                  'Our dedicated support team is here to assist you.',
                  style: context.text.labelSmall?.copyWith(color: v.grayText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.buttonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space8,
              ),
            ),
            onPressed: () {
              showContactSupportSheet(
                context,
                initialCategory: SupportCategory.general,
              );
            },
            child: const Text(
              'Contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
