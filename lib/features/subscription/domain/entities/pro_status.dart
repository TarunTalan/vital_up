import 'package:equatable/equatable.dart';

/// Whether the signed-in user has VitalUp Pro, and the plan's details when
/// the store reported them (the server only knows yes / no and the end).
class ProStatus extends Equatable {
  final bool isPro;

  /// When the current period ends; null for lifetime or unknown.
  final DateTime? expiresAt;

  /// False once auto-renew is off (Pro still runs until [expiresAt]).
  final bool willRenew;

  /// In the free trial period.
  final bool isTrial;

  final String? productId;

  /// Store page where the user changes or cancels the plan.
  final String? managementUrl;

  const ProStatus({
    required this.isPro,
    this.expiresAt,
    this.willRenew = true,
    this.isTrial = false,
    this.productId,
    this.managementUrl,
  });

  static const free = ProStatus(isPro: false);

  /// Is the plan billed yearly? Read from the product id (Play base plans
  /// are `<subscription>:<base plan>`), so it also works for server rows.
  bool get isYearly {
    final id = productId?.toLowerCase() ?? '';
    return id.contains('year') || id.contains('annual');
  }

  @override
  List<Object?> get props => [
    isPro,
    expiresAt,
    willRenew,
    isTrial,
    productId,
    managementUrl,
  ];
}

enum ProPlanPeriod { monthly, annual, other }

/// One plan the store offers, with prices formatted by the store in the
/// user's currency. Never hardcode prices: they're set in Play Console.
class ProPlan extends Equatable {
  /// Package id in the RevenueCat offering; passed back to buy it.
  final String id;
  final ProPlanPeriod period;

  /// "₹1,499.00" for the whole period.
  final String price;

  /// Monthly equivalent for longer plans ("₹124.92"); null for monthly.
  final String? pricePerMonth;

  /// Free trial length in days when this user can still get one.
  final int? trialDays;

  /// Percent saved against paying monthly for a year; null when unknown.
  final int? savingsPercent;

  const ProPlan({
    required this.id,
    required this.period,
    required this.price,
    this.pricePerMonth,
    this.trialDays,
    this.savingsPercent,
  });

  bool get hasTrial => (trialDays ?? 0) > 0;

  @override
  List<Object?> get props => [
    id,
    period,
    price,
    pricePerMonth,
    trialDays,
    savingsPercent,
  ];
}
