import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';

class OrderPage extends StatefulWidget {
  final String deviceId; 
  final String orderId;

  const OrderPage({super.key, required this.deviceId, required this.orderId});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final DatabaseReference _orderRef;
  StreamSubscription<DatabaseEvent>? _sub;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    final app = Firebase.app();
    final db = FirebaseDatabase.instanceFor(app: app, databaseURL: kDbUrl);
    _orderRef = db.ref('orders/${widget.deviceId}/${widget.orderId}');
    _sub = _orderRef.onValue.listen((event) {
      if (!mounted) return;
      final val = event.snapshot.value;
      if (val is Map) {
        setState(() => _order = Map<String, dynamic>.from(val as Map));
      } else {
        setState(() => _order = null);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;

    return Scaffold(
      appBar: AppBar(title: const Text('Bestelling')),
      body: o == null
          ? const Center(child: Text('Bestelling niet gevonden of verwijderd.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Code card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      children: [
                        const Text('Afhaalcode', style: TextStyle(fontSize: 16, color: Colors.black54)),
                        const SizedBox(height: 8),
                        Text(
                          (o['code'] ?? OrderStore.lastPickupCode ?? '—').toString(),
                          style: const TextStyle(fontSize: 36, letterSpacing: 4, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text('Order-ID: ${widget.orderId.substring(0, 6)}…', style: const TextStyle(color: Colors.black45)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Items
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Items:', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(height: 8),
                  _buildItemsList(o['items']),

                  const Spacer(),
                  const Text(
                    'Toon de code bij de vending machine om je bestelling op te halen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemsList(dynamic items) {
    if (items is! Map) return const Text('—');
    final m = Map<String, dynamic>.from(items);
    if (m.isEmpty) return const Text('—');

    final rows = m.entries.map((e) {
      final key = e.key.toString();
      final qty = (e.value as num?)?.toInt() ?? 0;
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(_prettyDutch(key)),
        trailing: Text('x$qty'),
      );
    }).toList();

    return Column(children: rows);
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
