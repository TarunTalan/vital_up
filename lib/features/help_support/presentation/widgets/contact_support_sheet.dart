import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import '../../domain/entities/support_ticket.dart';

const String _kSupportEmail = 'support@vitalup.app';

void showContactSupportSheet(
  BuildContext context, {
  SupportCategory initialCategory = SupportCategory.bug,
  String initialSubject = '',
  String initialDescription = '',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusSheet),
      ),
    ),
    builder: (modalContext) => _ContactSupportSheetContent(
      initialCategory: initialCategory,
      initialSubject: initialSubject,
      initialDescription: initialDescription,
    ),
  );
}

class _ContactSupportSheetContent extends StatefulWidget {
  final SupportCategory initialCategory;
  final String initialSubject;
  final String initialDescription;

  const _ContactSupportSheetContent({
    required this.initialCategory,
    required this.initialSubject,
    required this.initialDescription,
  });

  @override
  State<_ContactSupportSheetContent> createState() =>
      _ContactSupportSheetContentState();
}

class _ContactSupportSheetContentState
    extends State<_ContactSupportSheetContent> {
  late SupportCategory _selectedCategory;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _subjectController =
        TextEditingController(text: widget.initialSubject);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty) {
      showErrorSnackBar(context, 'Please enter a short subject');
      return;
    }

    if (description.isEmpty) {
      showErrorSnackBar(context, 'Please describe your issue or question');
      return;
    }

    setState(() => _isSubmitting = true);

    final ticket = SupportTicket(
      category: _selectedCategory,
      subject: subject,
      description: description,
      includeDiagnostics: _includeDiagnostics,
      appVersion: _appVersion ?? '1.0.0 (1)',
      osPlatform: Platform.operatingSystem,
      deviceModel: Platform.operatingSystemVersion,
    );

    final emailSubject =
        '[VitalUp ${_selectedCategory.label}] $subject';
    final emailBody = ticket.toFormattedEmailBody();

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      queryParameters: {
        'subject': emailSubject,
        'body': emailBody,
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _fallbackCopyToClipboard(emailBody);
      } else {
        if (mounted) {
          Navigator.pop(context);
          showSuccessSnackBar(
            context,
            'Support mail opened in your email client.',
          );
        }
      }
    } catch (e) {
      await _fallbackCopyToClipboard(emailBody);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _fallbackCopyToClipboard(String body) async {
    await Clipboard.setData(ClipboardData(text: body));
    if (mounted) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        'Ticket details copied to clipboard. You can paste into your email to $_kSupportEmail',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          AppDimens.space16,
          context.gutter,
          AppDimens.space16 + bottomInset,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimens.space8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSm),
                        ),
                        child: const Icon(
                          Icons.mail_outline_rounded,
                          color: AppColors.primary,
                          size: AppDimens.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppDimens.space12),
                      Text('Contact Support', style: context.text.titleLarge),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.space12),
              Text(
                'Our engineering and product team typically responds within 24 hours.',
                style: context.text.bodySmall?.copyWith(color: v.grayText),
              ),
              const SizedBox(height: AppDimens.space16),

              // Category Selector
              AppCaption('ISSUE CATEGORY'),
              const SizedBox(height: AppDimens.space8),
              Wrap(
                spacing: AppDimens.space8,
                runSpacing: AppDimens.space8,
                children: SupportCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon),
                        const SizedBox(width: AppDimens.space6),
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : context.colors.onSurface,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                        HapticFeedback.selectionClick();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimens.space8),
              Text(
                _selectedCategory.description,
                style: context.text.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppDimens.space16),

              // Subject Input
              AppCaption('SUBJECT'),
              const SizedBox(height: AppDimens.space8),
              AppTextField(
                controller: _subjectController,
                hint: 'e.g., GPS disconnects after 30 minutes',
                prefixIcon: Icons.title_rounded,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppDimens.space16),

              // Description Input
              AppCaption('DESCRIPTION & DETAILS'),
              const SizedBox(height: AppDimens.space8),
              Container(
                decoration: BoxDecoration(
                  color: v.glassFill,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(
                    color: v.glassBorder ?? AppColors.glassBorder,
                  ),
                ),
                padding: const EdgeInsets.all(AppDimens.space12),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 3,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText:
                        'Please describe what happened, steps to reproduce, or your question in detail...',
                    hintStyle: context.text.bodyMedium?.copyWith(
                      color: v.grayText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space16),

              // Include Diagnostics Toggle
              InkWell(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                onTap: () {
                  setState(() => _includeDiagnostics = !_includeDiagnostics);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.space4,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _includeDiagnostics,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(
                            () => _includeDiagnostics = val ?? true,
                          );
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Include Device & App Diagnostics',
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _appVersion != null
                                  ? 'App: v$_appVersion · OS: ${Platform.operatingSystem}'
                                  : 'Helps engineers reproduce and fix issues faster',
                              style: context.text.labelSmall?.copyWith(
                                color: v.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.space20),

              // Submit Button
              AppPrimaryButton(
                label: _isSubmitting ? 'Opening Mail...' : 'Send Support Email',
                leadingIcon: const Icon(Icons.send_rounded, size: AppDimens.iconSm),
                enabled: !_isSubmitting,
                onTap: () {
                  _submitTicket();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
