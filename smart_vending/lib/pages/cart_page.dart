import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import '../cart.dart';
import '../demo_stock.dart';
import 'order_page.dart';

class CartPage extends StatefulWidget {
  final String deviceId; 
  const CartPage({super.key, required this.deviceId});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final DatabaseReference _ordersRef;

  @override
  void initState() {
    super.initState();
    final app = Firebase.app();
    final db = FirebaseDatabase.instanceFor(app: app, databaseURL: kDbUrl);
    _ordersRef = db.ref('orders/${widget.deviceId}');
  }

  String _genPickupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; 
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _checkout() async {
    final items = Cart.items(widget.deviceId);
    if (items.isEmpty) return;

    final pickupCode = _genPickupCode();
    final order = {
      'status': 'pending',
      'items': items,
      'code': pickupCode,
      'created_at': {'.sv': 'timestamp'},
    };

    try {
      final newRef = _ordersRef.push();
      await newRef.set(order);
      final orderId = newRef.key!;
      if (!mounted) return;

   
      if (widget.deviceId != kLiveDeviceId) {
        DemoStock.decrement(widget.deviceId, items);
        await DemoStock.syncToFirebase(widget.deviceId);
      }

      // Save for "Mijn bestelling"
      OrderStore.lastOrderId = orderId;
      OrderStore.lastPickupCode = pickupCode;
      OrderStore.lastDeviceId = widget.deviceId;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bestelling geplaatst!')),
      );
      Cart.clear(widget.deviceId);
      setState(() {});
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OrderPage(deviceId: widget.deviceId, orderId: orderId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout bij afrekenen: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = Cart.items(widget.deviceId).entries.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Winkelwagen')),
      body: entries.isEmpty
          ? const Center(child: Text('Je winkelwagen is leeg.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final e = entries[i];
                final key = e.key;
                final qty = e.value;

                return Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(_prettyDutch(key), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Aantal: $qty'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            Cart.dec(widget.deviceId, key);
                            setState(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: () {
                            Cart.remove(widget.deviceId, key);
                            setState(() {});
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton(
          onPressed: entries.isEmpty ? null : _checkout,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Afrekenen'),
        ),
      ),
    );
  }

  String _prettyDutch(String key) {
    switch (key) {
      case 'melk': return 'Melk';
      case 'eieren': return 'Eieren';
      case 'aardbeien': return 'Aardbeien';
      case 'kaas': return 'Kaas';
      default: return key;
    }
  }
}
