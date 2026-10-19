import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';

/// The app store side of Pro. [RevenueCatBilling] in the app; tests fake it.
abstract class StoreBilling {
  /// Can this build sell Pro here at all?
  bool get available;

  Future<void> identify(String? userId);

  Future<ProStatus> status();

  Stream<ProStatus> get changes;

  Future<List<ProPlan>> plans();

  Future<PurchaseOutcome> purchase(String planId);

  Future<PurchaseOutcome> restore();
}

/// RevenueCat over Google Play Billing. The RevenueCat app user id is the
/// Supabase user id, so the webhook can find the account; nothing else
/// about the user (email, name, health data) is sent to RevenueCat.
///
/// Off without an API key (`REVENUECAT_GOOGLE_API_KEY` in `.env`) and on
/// iOS until an App Store key and products exist.
class RevenueCatBilling implements StoreBilling {
  final String? apiKey;
  final String entitlement;

  RevenueCatBilling({this.apiKey, this.entitlement = 'pro'});

  final _changes = StreamController<ProStatus>.broadcast();
  final Map<String, Package> _packages = {};
  bool _configured = false;
  Future<void>? _identifying;

  @override
  bool get available =>
      (apiKey?.isNotEmpty ?? false) &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<ProStatus> get changes => _changes.stream;

  @override
  Future<void> identify(String? userId) {
    // Auth events can arrive back to back (initial session, then a token
    // refresh): one logIn at a time.
    final previous = _identifying ?? Future<void>.value();
    return _identifying = previous.then((_) => _identify(userId));
  }

  Future<void> _identify(String? userId) async {
    if (!available) return;
    try {
      if (!_configured) {
        // Signed out: nothing to buy, so don't create an anonymous customer.
        if (userId == null) return;
        await Purchases.setLogLevel(kDebugMode ? LogLevel.info : LogLevel.error);
        await Purchases.configure(
          PurchasesConfiguration(apiKey!)..appUserID = userId,
        );
        Purchases.addCustomerInfoUpdateListener(
          (info) => _changes.add(_toStatus(info)),
        );
        _configured = true;
        return;
      }
      if (userId != null) {
        await Purchases.logIn(userId);
      } else if (!await Purchases.isAnonymous) {
        await Purchases.logOut();
      }
      _packages.clear();
    } catch (e) {
      debugPrint('RevenueCat identify failed: ${e.runtimeType}');
    }
  }

  @override
  Future<ProStatus> status() async {
    if (!_configured) return ProStatus.free;
    // Cached by the SDK, so this works offline too.
    return _toStatus(await Purchases.getCustomerInfo());
  }

  ProStatus _toStatus(CustomerInfo info) {
    final pro = info.entitlements.active[entitlement];
    if (pro == null) {
      return ProStatus(isPro: false, managementUrl: info.managementURL);
    }
    return ProStatus(
      isPro: true,
      expiresAt: DateTime.tryParse(pro.expirationDate ?? '')?.toLocal(),
      willRenew: pro.willRenew,
      isTrial: pro.periodType == PeriodType.trial,
      productId: pro.productIdentifier,
      managementUrl: info.managementURL,
    );
  }

  @override
  Future<List<ProPlan>> plans() async {
    if (!_configured) return const [];
    final offering = (await Purchases.getOfferings()).current;
    if (offering == null) return const [];
    _packages
      ..clear()
      ..addEntries(offering.availablePackages.map((p) => MapEntry(p.identifier, p)));
    final monthly = offering.monthly?.storeProduct;
    final plans = offering.availablePackages.map((p) {
      final product = p.storeProduct;
      final period = switch (p.packageType) {
        PackageType.monthly => ProPlanPeriod.monthly,
        PackageType.annual => ProPlanPeriod.annual,
        _ => ProPlanPeriod.other,
      };
      return ProPlan(
        id: p.identifier,
        period: period,
        price: product.priceString,
        pricePerMonth: period == ProPlanPeriod.annual
            ? product.pricePerMonthString
            : null,
        trialDays: _trialDays(product.defaultOption?.freePhase?.billingPeriod),
        savingsPercent: period == ProPlanPeriod.annual && monthly != null
            ? yearlySavingsPercent(
                monthly: monthly.price,
                yearly: product.price,
                sameCurrency: monthly.currencyCode == product.currencyCode,
              )
            : null,
      );
    }).toList();
    // Yearly first, then monthly, then anything else.
    plans.sort((a, b) => _order(a.period).compareTo(_order(b.period)));
    return plans;
  }

  static int _order(ProPlanPeriod period) => switch (period) {
    ProPlanPeriod.annual => 0,
    ProPlanPeriod.monthly => 1,
    ProPlanPeriod.other => 2,
  };

  static int? _trialDays(Period? period) {
    if (period == null || period.value <= 0) return null;
    return switch (period.unit) {
      PeriodUnit.day => period.value,
      PeriodUnit.week => period.value * 7,
      PeriodUnit.month => period.value * 30,
      PeriodUnit.year => period.value * 365,
      PeriodUnit.unknown => null,
    };
  }

  /// Whole percent saved by a year at [yearly] against twelve months at
  /// [monthly]; null when there's no real saving to show.
  @visibleForTesting
  static int? yearlySavingsPercent({
    required double monthly,
    required double yearly,
    bool sameCurrency = true,
  }) {
    if (!sameCurrency || monthly <= 0 || yearly <= 0) return null;
    final percent = ((1 - yearly / (monthly * 12)) * 100).floor();
    return percent >= 5 ? percent : null;
  }

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    if (!_configured) return const PurchaseFailed(_unavailable);
    try {
      var package = _packages[planId];
      if (package == null) {
        await plans();
        package = _packages[planId];
      }
      if (package == null) return const PurchaseFailed(_planGone);
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final status = _toStatus(result.customerInfo);
      return status.isPro ? PurchaseCompleted(status) : const PurchasePending();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('Purchase failed: $code');
      return switch (code) {
        PurchasesErrorCode.purchaseCancelledError => const PurchaseCancelled(),
        PurchasesErrorCode.paymentPendingError => const PurchasePending(),
        // Bought before (another install, a reinstall): bring it back.
        PurchasesErrorCode.productAlreadyPurchasedError => await restore(),
        _ => PurchaseFailed(_message(code)),
      };
    }
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (!_configured) return const PurchaseFailed(_unavailable);
    try {
      final status = _toStatus(await Purchases.restorePurchases());
      return status.isPro
          ? PurchaseCompleted(status)
          : const PurchaseFailed('No Pro plan found for this Google account.');
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('Restore failed: $code');
      return PurchaseFailed(_message(code));
    }
  }

  static const _unavailable = "Pro isn't available on this device yet.";
  static const _planGone = "This plan isn't available. Try again later.";

  static String _message(PurchasesErrorCode code) => switch (code) {
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.offlineConnectionError =>
      "You're offline. Try again when connected.",
    PurchasesErrorCode.purchaseNotAllowedError =>
      "Purchases aren't allowed on this device.",
    PurchasesErrorCode.productNotAvailableForPurchaseError => _planGone,
    PurchasesErrorCode.receiptAlreadyInUseError ||
    PurchasesErrorCode.receiptInUseByOtherSubscriberError =>
      'This plan belongs to another VitalUp account.',
    PurchasesErrorCode.storeProblemError =>
      'Google Play had a problem. Try again.',
    _ => "Couldn't complete the purchase. Try again.",
  };
}
