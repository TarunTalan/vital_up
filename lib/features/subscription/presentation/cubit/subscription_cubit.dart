import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';

class SubscriptionState extends Equatable {
  final ProStatus status;

  /// False until the plan has been read once this session.
  final bool loaded;

  /// This device can buy Pro (store set up).
  final bool canPurchase;

  final List<ProPlan> plans;
  final bool plansLoading;

  /// Plans couldn't load (offline, store error); user-facing.
  final String? plansError;

  /// Plan being bought; null when no purchase is running.
  final String? buyingPlanId;
  final bool restoring;

  const SubscriptionState({
    this.status = ProStatus.free,
    this.loaded = false,
    this.canPurchase = false,
    this.plans = const [],
    this.plansLoading = false,
    this.plansError,
    this.buyingPlanId,
    this.restoring = false,
  });

  bool get isPro => status.isPro;
  bool get busy => buyingPlanId != null || restoring;

  /// Worth pointing a free user at Pro: it can be bought here.
  bool get canUpgrade => canPurchase && !isPro;

  SubscriptionState copyWith({
    ProStatus? status,
    bool? loaded,
    List<ProPlan>? plans,
    bool? plansLoading,
    String? Function()? plansError,
    String? Function()? buyingPlanId,
    bool? restoring,
  }) => SubscriptionState(
    status: status ?? this.status,
    loaded: loaded ?? this.loaded,
    canPurchase: canPurchase,
    plans: plans ?? this.plans,
    plansLoading: plansLoading ?? this.plansLoading,
    plansError: plansError == null ? this.plansError : plansError(),
    buyingPlanId: buyingPlanId == null ? this.buyingPlanId : buyingPlanId(),
    restoring: restoring ?? this.restoring,
  );

  @override
  List<Object?> get props => [
    status,
    loaded,
    canPurchase,
    plans,
    plansLoading,
    plansError,
    buyingPlanId,
    restoring,
  ];
}

/// App-wide VitalUp Pro state (one instance, provided in `main.dart`).
/// Follows the signed-in user: identifies them to the store and re-reads
/// the plan on every sign-in, and drops to free on sign-out.
class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionRepository _repository;
  final Stream<String?> userIds;

  StreamSubscription<String?>? _userSub;
  StreamSubscription<ProStatus>? _storeSub;
  String? _userId;

  SubscriptionCubit(this._repository, {required this.userIds})
    : super(SubscriptionState(canPurchase: _repository.canPurchase));

  static const _plansTimeout = Duration(seconds: 15);

  @override
  void emit(SubscriptionState state) {
    if (!isClosed) super.emit(state);
  }

  /// Starts following the signed-in user. Call once.
  void start() {
    _userSub ??= userIds.distinct().listen(
      _onUser,
      onError: (Object e) => debugPrint('Plan auth error: ${e.runtimeType}'),
    );
    // Renewals, refunds and purchases elsewhere: re-read store and server.
    _storeSub ??= _repository.changes.listen((_) => refresh());
  }

  Future<void> _onUser(String? userId) async {
    _userId = userId;
    if (userId == null) {
      emit(SubscriptionState(canPurchase: state.canPurchase));
      await _repository.identify(null);
      return;
    }
    await _repository.identify(userId);
    if (_userId != userId) return;
    await refresh();
  }

  /// Re-reads the plan. A failure keeps what's shown.
  Future<void> refresh({bool force = false}) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final status = await _repository
          .status(forceRefresh: force)
          .withLoadTimeout(_plansTimeout);
      // Signed out or switched account meanwhile.
      if (_userId != userId) return;
      emit(state.copyWith(status: status, loaded: true));
    } catch (e) {
      debugPrint('Plan refresh failed: ${e.runtimeType}');
    }
  }

  /// Loads the plans on sale; kept once loaded.
  Future<void> loadPlans({bool force = false}) async {
    if (!state.canPurchase || state.plansLoading) return;
    if (state.plans.isNotEmpty && !force) return;
    emit(state.copyWith(plansLoading: true, plansError: () => null));
    try {
      final plans = await _repository.plans().withLoadTimeout(_plansTimeout);
      emit(
        state.copyWith(
          plans: plans,
          plansLoading: false,
          plansError: () =>
              plans.isEmpty ? "Plans aren't available right now." : null,
        ),
      );
    } catch (e) {
      debugPrint('Plans failed to load: $e');
      emit(
        state.copyWith(
          plansLoading: false,
          plansError: () =>
              userMessage(e, fallback: "Couldn't load the plans. Try again."),
        ),
      );
    }
  }

  Future<PurchaseOutcome?> purchase(String planId) async {
    if (state.busy) return null;
    emit(state.copyWith(buyingPlanId: () => planId));
    final outcome = await _repository.purchase(planId);
    _apply(outcome);
    emit(state.copyWith(buyingPlanId: () => null));
    return outcome;
  }

  Future<PurchaseOutcome?> restore() async {
    if (state.busy) return null;
    emit(state.copyWith(restoring: true));
    final outcome = await _repository.restore();
    _apply(outcome);
    emit(state.copyWith(restoring: false));
    return outcome;
  }

  void _apply(PurchaseOutcome outcome) {
    if (outcome is PurchaseCompleted) {
      emit(state.copyWith(status: outcome.status, loaded: true));
    }
  }

  @override
  Future<void> close() async {
    await _userSub?.cancel();
    await _storeSub?.cancel();
    return super.close();
  }
}
