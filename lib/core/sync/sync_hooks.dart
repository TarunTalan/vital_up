/// What local stores tell the sync engine (implemented by SyncService).
abstract interface class SyncHooks {
  /// Something was added or edited locally; upload soon.
  void schedule();

  /// An entry with cloud id [id] in [table] was deleted locally.
  Future<void> recordDelete(String table, String id);
}
