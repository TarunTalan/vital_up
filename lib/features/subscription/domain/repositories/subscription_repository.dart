import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';

/// What happened to a purchase or restore.
sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

class PurchaseCompleted extends PurchaseOutcome {
  final ProStatus status;
  const PurchaseCompleted(this.status);
}

/// The user closed the store sheet. Not an error: say nothing.
class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

/// Paid with a slow method (cash, bank transfer): Pro starts once the
/// store confirms the payment.
class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

class PurchaseFailed extends PurchaseOutcome {
  /// User-facing, short.
  final String message;
  const PurchaseFailed(this.message);
}

/// VitalUp Pro: the store (RevenueCat) for buying and the plan's details,
/// the server (`subscriptions`, kept by the RevenueCat webhook) for what
/// the AI functions actually allow.
abstract class SubscriptionRepository {
  /// False when this build or device can't sell Pro (no store key, iOS
  /// for now). Pro granted on the server still counts.
  bool get canPurchase;

  /// Starts the store SDK for [userId] (null = signed out). Safe to call
  /// again on every sign-in.
  Future<void> identify(String? userId);

  /// Store and server combined: Pro if either says so. Offline, the last
  /// known answers are used.
  Future<ProStatus> status({bool forceRefresh = false});

  /// Store updates (renewal, refund, purchase on another device).
  Stream<ProStatus> get changes;

  /// Plans on sale, yearly first. Empty when the store has none.
  Future<List<ProPlan>> plans();

  Future<PurchaseOutcome> purchase(String planId);

  Future<PurchaseOutcome> restore();

  /// Asks the server to re-read the store now, so the AI functions see a
  /// new purchase before the webhook arrives. Never throws.
  Future<void> syncServer();

  /// Today's photo scans left on the free plan; -1 with Pro.
  Future<int> remainingFreeScans();
}
