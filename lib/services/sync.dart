/// 数据同步的预留层。
/// 后面如果要上云同步（自建服务端），实现一个 SyncAdapter 接进 SyncManager 就行，
/// 业务代码不用动。当前用 OfflineAdapter，啥也不干。
library;

import '../models/models.dart';

abstract class SyncAdapter {
  String get name;

  /// 把本地改动推上去。返回远端版本号之类的，随便定义
  Future<String?> push(List<Txn> txns, List<DayNote> notes);

  /// 拉远端数据，返回 null 表示没网/没配置/懒得理
  Future<RemoteSnapshot?> pull();

  Future<bool> test() async => false;
}

class RemoteSnapshot {
  final List<Txn> txns;
  final List<DayNote> notes;
  final String revision;

  RemoteSnapshot({required this.txns, required this.notes, required this.revision});
}

/// 无同步时的空实现
class OfflineAdapter extends SyncAdapter {
  @override
  String get name => 'offline';

  @override
  Future<String?> push(List<Txn> txns, List<DayNote> notes) async => null;

  @override
  Future<RemoteSnapshot?> pull() async => null;
}

class SyncManager {
  SyncAdapter adapter = OfflineAdapter();

  static final SyncManager _i = SyncManager._();
  static SyncManager get instance => _i;
  SyncManager._();

  bool get enabled => adapter is! OfflineAdapter;

  // 以后接云的时候在这里做队列/冲突合并，现在先空着
  Future<void> syncUp(List<Txn> txns, List<DayNote> notes) async {
    if (!enabled) return;
    try {
      await adapter.push(txns, notes);
    } catch (_) {
      // 同步失败不打扰用户，下回再说
    }
  }
}
