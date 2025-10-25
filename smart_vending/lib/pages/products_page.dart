import 'package:flutter/material.dart';
import '../models.dart';
import '../config.dart';
import '../cart.dart';
import '../demo_stock.dart';
import 'cart_page.dart';

class ProductsPage extends StatefulWidget {
  final VendingMachine machine;
  const ProductsPage({super.key, required this.machine});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  bool get _canOrderHere => true; 
  bool _isDemo(String id) => id != kLiveDeviceId;

  @override
  void initState() {
    super.initState();
    DemoStock.initIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final machineId = widget.machine.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.machine.name),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CartPage(deviceId: machineId)),
            ).then((_) => setState(() {})),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_outlined),
                if (Cart.totalItems(machineId) > 0)
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          Cart.totalItems(machineId).toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: widget.machine.products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final p = widget.machine.products[i];
          final key = p.dbKey ?? _guessKey(p.name) ?? '';
          final inCart = key.isEmpty ? 0 : Cart.countFor(machineId, key);

          final available = _isDemo(machineId)
              ? (key.isEmpty ? null : DemoStock.getAvailable(machineId, key))
              : p.availableQty;

          final trailingText = (available != null)
              ? '$inCart/$available'
              : (inCart > 0 ? '$inCart' : '—');

          final canAddMore = _canOrderHere && (available == null || inCart < available);

          return Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(
                '${p.name.split(' (').first} (${available ?? "-"})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(p.unit),
              trailing: Text(
                trailingText,
                style: TextStyle(color: canAddMore ? cs.primary : Colors.grey, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                if (!_canOrderHere) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deze machine accepteert geen bestellingen.')),
                  );
                  return;
                }
                final added = Cart.tryAdd(machineId, key.isEmpty ? p.name : key, available: available);
                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Niet genoeg voorraad beschikbaar.')),
                  );
                  return;
                }
                setState(() {});
                final baseName = p.name.split(' (').first;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Toegevoegd: $baseName')));
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton(
          onPressed: (Cart.totalItems(machineId) == 0)
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CartPage(deviceId: machineId)),
                  ).then((_) => setState(() {})),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(
            Cart.totalItems(machineId) == 0 ? 'Winkelwagen is leeg' : 'Afrekenen (${Cart.totalItems(machineId)})',
          ),
        ),
      ),
    );
  }

  String? _guessKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('melk')) return 'melk';
    if (n.contains('eier')) return 'eieren';
    if (n.contains('aardbei')) return 'aardbeien';
    if (n.contains('kaas')) return 'kaas';
    return null;
  }
}
