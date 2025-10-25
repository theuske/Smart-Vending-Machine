class Cart {
  // counts per machine id (so cart is per machine, not global)
  static final Map<String, Map<String, int>> _byMachine = {};

  static Map<String, int> _bucket(String machineId) =>
      _byMachine.putIfAbsent(machineId, () => <String, int>{});

  static int totalItems(String machineId) =>
      _bucket(machineId).values.fold(0, (a, b) => a + b);

  static Map<String, int> items(String machineId) =>
      Map.unmodifiable(_bucket(machineId));

  static int countFor(String machineId, String key) =>
      _bucket(machineId)[key] ?? 0;

  static bool tryAdd(String machineId, String nameOrKey, {int? available}) {
    final key = _guessKey(nameOrKey) ?? nameOrKey;
    final bucket = _bucket(machineId);
    final current = bucket[key] ?? 0;
    if (available != null && current >= available) return false;
    bucket[key] = current + 1;
    return true;
  }

  static void dec(String machineId, String key) {
    final bucket = _bucket(machineId);
    if (!bucket.containsKey(key)) return;
    final v = (bucket[key] ?? 0) - 1;
    if (v <= 0) {
      bucket.remove(key);
    } else {
      bucket[key] = v;
    }
  }

  static void remove(String machineId, String key) => _bucket(machineId).remove(key);
  static void clear(String machineId) => _bucket(machineId).clear();

  static String? _guessKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('melk')) return 'melk';
    if (n.contains('eier')) return 'eieren';
    if (n.contains('aardbei')) return 'aardbeien';
    if (n.contains('kaas')) return 'kaas';
    return null;
  }
}
