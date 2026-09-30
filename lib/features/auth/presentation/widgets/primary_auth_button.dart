// The app-wide buttons now live in `core/widgets/app_buttons.dart`.
// These aliases keep existing imports/call-sites compiling.
import 'package:vital_up/core/widgets/app_buttons.dart';

export 'package:vital_up/core/widgets/app_buttons.dart';

typedef PrimaryAuthButton = AppPrimaryButton;
typedef SecondaryAuthButton = AppSecondaryButton;
