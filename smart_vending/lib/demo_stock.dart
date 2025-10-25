import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'config.dart';
import 'models.dart';


class DemoStock {
 
  static final Map<String, Map<String, int>> _stock = {};

  static bool _inited = false;

  static void initIfNeeded() {
    if (_inited) return;
    for (final vm in demoMachines) {
      final m = <String, int>{};
      for (final p in vm.products) {
        final key = p.dbKey;
        if (key == null) continue;
        final qty = p.availableQty ?? _defaultFor(key);
        m[key] = qty;
      }
      _stock[vm.id] = m;
    }
    _inited = true;
  }

  static int _defaultFor(String key) {
    switch (key) {
      case 'eieren': return 12;
      case 'melk': return 8;
      case 'aardbeien': return 6;
      case 'kaas': return 5;
      default: return 10;
    }
  }

  static int? getAvailable(String machineId, String key) {
    initIfNeeded();
    return _stock[machineId]?[key];
  }

  static void decrement(String machineId, Map<String, int> items) {
    initIfNeeded();
    final m = _stock[machineId];
    if (m == null) return;
    items.forEach((key, qty) {
      final cur = m[key] ?? 0;
      final next = cur - qty;
      m[key] = next < 0 ? 0 : next;
    });
  }

  static Future<void> syncToFirebase(String machineId) async {
    initIfNeeded();
    final app = Firebase.app();
    final db = FirebaseDatabase.instanceFor(app: app, databaseURL: kDbUrl);
    final ref = db.ref('devices/$machineId/stock');
    final m = _stock[machineId];
    if (m == null) return;
    await ref.set(m);
  }
}
