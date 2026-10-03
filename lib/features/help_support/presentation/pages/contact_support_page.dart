import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import '../../domain/entities/support_ticket.dart';

const String _kSupportEmail = 'support@vitalup.app';

/// `contact-support` route extra: prefills the ticket form.
class ContactSupportArgs {
  final SupportCategory initialCategory;
  final String initialSubject;
  final String initialDescription;

  const ContactSupportArgs({
    this.initialCategory = SupportCategory.bug,
    this.initialSubject = '',
    this.initialDescription = '',
  });
}

/// Opens the [ContactSupportPage], optionally prefilled.
void openContactSupport(
  BuildContext context, {
  SupportCategory initialCategory = SupportCategory.general,
  String initialSubject = '',
  String initialDescription = '',
}) {
  context.pushNamed(
    'contact-support',
    extra: ContactSupportArgs(
      initialCategory: initialCategory,
      initialSubject: initialSubject,
      initialDescription: initialDescription,
    ),
  );
}

/// Support ticket form — category, subject, description and optional
/// diagnostics, sent through the user's email client.
class ContactSupportPage extends StatefulWidget {
  final ContactSupportArgs args;

  const ContactSupportPage({super.key, this.args = const ContactSupportArgs()});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  late SupportCategory _selectedCategory;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.args.initialCategory;
    _subjectController = TextEditingController(
      text: widget.args.initialSubject,
    );
    _descriptionController = TextEditingController(
      text: widget.args.initialDescription,
    );
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
    final rawSubject = _subjectController.text.trim();
    final subject = rawSubject.isNotEmpty
        ? rawSubject
        : _selectedCategory.label;
    final description = _descriptionController.text.trim();

    if (description.isEmpty) {
      showErrorSnackBar(context, 'Please describe your issue or question');
      return;
    }

    FocusScope.of(context).unfocus();
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

    final emailSubject = '[VitalUp ${_selectedCategory.label}] $subject';
    final emailBody = ticket.toFormattedEmailBody();

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _kSupportEmail,
      queryParameters: {'subject': emailSubject, 'body': emailBody},
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _fallbackCopyToClipboard(emailBody);
      } else if (mounted) {
        showSuccessSnackBar(
          context,
          'Support mail opened in your email client.',
        );
        context.pop();
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
      showSuccessSnackBar(
        context,
        'Ticket details copied to clipboard. You can paste into your email to $_kSupportEmail',
      );
      context.pop();
    }
  }

  Future<void> _openDirectEmail() async {
    final Uri emailUri = Uri(scheme: 'mailto', path: _kSupportEmail);
    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await _fallbackCopyToClipboard(_kSupportEmail);
      }
    } catch (_) {
      if (mounted) await _fallbackCopyToClipboard(_kSupportEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const AppPageHeader(
        title: 'Contact Support',
        subtitle: 'We typically respond within 24 hours',
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppPrimaryButton(
            label: 'Send Support Email',
            leadingIcon: const Icon(Icons.send_rounded),
            isLoading: _isSubmitting,
            onTap: _submitTicket,
          ),
          const SizedBox(height: AppDimens.space10),
          InkWell(
            onTap: _openDirectEmail,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.space12,
                vertical: AppDimens.space4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    size: AppDimens.iconSm,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: AppDimens.space6),
                  Text(
                    'Direct contact: $_kSupportEmail',
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category Dropdown
          AppDropdownField<SupportCategory>(
            label: 'Issue category',
            value: _selectedCategory,
            items: SupportCategory.values,
            itemLabel: (cat) => cat.label,
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCategory = val);
              }
            },
          ),
          const SizedBox(height: AppDimens.sectionGap),

          AppTextField(
            controller: _subjectController,
            label: 'Subject (optional)',
            hint: 'e.g., GPS disconnects after 30 minutes',
            prefixIcon: Icons.title_rounded,
            maxLength: 100,
            showCounter: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimens.space16),

          AppTextField(
            controller: _descriptionController,
            label: 'Description & details',
            hint:
                'Please describe what happened, steps to reproduce, or your question in detail...',
            multiline: true,
            minLines: 5,
            maxLength: 1000,
            showCounter: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimens.sectionGap),

          // Include Diagnostics Toggle
          AppCard(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: _includeDiagnostics,
              onChanged: (val) =>
                  setState(() => _includeDiagnostics = val ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Include Device & App Diagnostics',
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
