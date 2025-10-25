import 'package:flutter/material.dart';
import '../config.dart';
import 'map_page.dart';
import 'order_page.dart';

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  void _openLatestOrder(BuildContext context) {
    final id = OrderStore.lastOrderId;
    final dev = OrderStore.lastDeviceId;
    if (id == null || dev == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je hebt nog geen bestelling.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPage(deviceId: dev, orderId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/smartvendinglogo.png', width: 88, fit: BoxFit.contain),
                  const SizedBox(height: 16),
                  Text(
                    'Welkom',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vind hieronder een vending\nmachine in de buurt.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/images/welkomimage.png', fit: BoxFit.cover),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapPage())),
                      child: const Text('Bestel bij vending machine'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _openLatestOrder(context),
                      label: const Text('Mijn bestelling'),
                    ),
                  ),
                  const SizedBox(height: 150),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
