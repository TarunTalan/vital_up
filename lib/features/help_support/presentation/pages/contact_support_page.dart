import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/services/email_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';
import '../../domain/entities/support_ticket.dart';

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
/// diagnostics, sent to support@vitalup.live with confirmation to the user.
class ContactSupportPage extends StatefulWidget {
  final ContactSupportArgs args;

  const ContactSupportPage({super.key, this.args = const ContactSupportArgs()});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  late SupportCategory _selectedCategory;
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;
  bool _includeDiagnostics = true;
  bool _isSubmitting = false;
  String? _appVersion;
  String? _emailError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final initialEmail = user?.email ?? '';
    final initialName = (user?.userMetadata?['full_name'] as String?) ??
        (user?.userMetadata?['name'] as String?) ??
        (user?.userMetadata?['username'] as String?) ??
        '';

    _selectedCategory = widget.args.initialCategory;
    _emailController = TextEditingController(text: initialEmail);
    _nameController = TextEditingController(text: initialName);
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
    } catch (e) {
      debugPrint('Package info unavailable: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final trimmed = email.trim();
    return trimmed.isNotEmpty &&
        trimmed.contains('@') &&
        trimmed.contains('.') &&
        !trimmed.startsWith('@') &&
        !trimmed.endsWith('@');
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;

    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }

    final cleanSubject = SupportTicketRules.cleanSubject(_subjectController.text);
    final subject =
        cleanSubject.isNotEmpty ? cleanSubject : _selectedCategory.label;
    final description =
        SupportTicketRules.cleanDescription(_descriptionController.text);

    final error =
        SupportTicketRules.validateDescription(_descriptionController.text);
    if (error != null) {
      setState(() => _descriptionError = error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final user = Supabase.instance.client.auth.currentUser;
    final userName = _nameController.text.trim();
    final appVer = _appVersion ?? '1.0.0 (1)';
    final platform = Platform.operatingSystem;
    final device = Platform.operatingSystemVersion;

    try {
      final emailService = sl<EmailService>();
      final dispatched = await emailService.submitSupportTicket(
        userEmail: email,
        userName: userName.isNotEmpty ? userName : null,
        userId: user?.id,
        category: _selectedCategory.label,
        subject: subject,
        description: description,
        includeDiagnostics: _includeDiagnostics,
        appVersion: appVer,
        osPlatform: platform,
        deviceModel: device,
      );

      if (dispatched) {
        if (mounted) {
          showSuccessSnackBar(
            context,
            'Support ticket sent to $kSupportEmail! A confirmation was emailed to $email.',
          );
          context.pop();
        }
        return;
      }
    } catch (e) {
      debugPrint('Autonomous email submission error: $e');
    }

    // Fallback if Edge function or offline network failed
    final ticket = SupportTicket(
      category: _selectedCategory,
      subject: subject,
      description: description,
      userEmail: email,
      includeDiagnostics: _includeDiagnostics,
      appVersion: appVer,
      osPlatform: platform,
      deviceModel: device,
    );

    final emailSubject = '[VitalUp ${_selectedCategory.label}] $subject';
    final emailBody = ticket.toFormattedEmailBody();
    final emailUri = supportMailUri(subject: emailSubject, body: emailBody);

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await _copyTicket(emailBody);
      } else if (mounted) {
        showSuccessSnackBar(
          context,
          'Your email app is open. Tap send to complete submission.',
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Support mail not opened: $e');
      await _copyTicket(emailBody);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// No mail app / offline: copy ticket so details are preserved.
  Future<void> _copyTicket(String body) async {
    try {
      await Clipboard.setData(ClipboardData(text: body));
    } catch (e) {
      debugPrint('Clipboard unavailable: $e');
      if (mounted) showErrorSnackBar(context, 'Unable to send. Email $kSupportEmail');
      return;
    }
    if (mounted) {
      showSuccessSnackBar(context, 'Ticket copied! You can paste and email it to $kSupportEmail.');
      context.pop();
    }
  }

  Future<void> _openDirectEmail() async {
    var launched = false;
    try {
      launched = await launchUrl(
        supportMailUri(),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Support mail not opened: $e');
    }
    if (launched) return;
    try {
      await Clipboard.setData(const ClipboardData(text: kSupportEmail));
      if (mounted) showSuccessSnackBar(context, 'Support email address copied.');
    } catch (e) {
      debugPrint('Clipboard unavailable: $e');
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
            label: 'Submit Support Ticket',
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Contact Info
          AppTextField(
            controller: _emailController,
            label: 'Your Contact Email',
            hint: 'e.g., name@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            error: _emailError,
            onChanged: (_) {
              if (_emailError != null) {
                setState(() => _emailError = null);
              }
            },
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimens.space16),

          AppTextField(
            controller: _nameController,
            label: 'Your Name (optional)',
            hint: 'e.g., Alex Johnson',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimens.space16),

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
            maxLength: SupportTicketRules.subjectMax,
            inputFormatters: InputFormatters.text(SupportTicketRules.subjectMax),
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
            maxLength: SupportTicketRules.descriptionMax,
            inputFormatters: InputFormatters.text(
              SupportTicketRules.descriptionMax,
              multiline: true,
            ),
            keyboardType: TextInputType.multiline,
            error: _descriptionError,
            onChanged: (_) {
              if (_descriptionError != null) {
                setState(() => _descriptionError = null);
              }
            },
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
