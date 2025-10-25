import 'package:google_maps_flutter/google_maps_flutter.dart';

class VendingMachine {
  final String id;               
  final String name;
  final LatLng position;
  final List<Product> products;
  final bool isArduinoLive;

  const VendingMachine({
    required this.id,
    required this.name,
    required this.position,
    required this.products,
    this.isArduinoLive = false,
  });
}

class Product {
  final String name;         
  final String unit;
  final double price;
  final String? dbKey;       // melk|eieren|aardbeien|kaas
  final int? availableQty;   // live/demo available quantity

  const Product(this.name, this.unit, this.price, {this.dbKey, this.availableQty});
}

// Demo machines (order-enabled)
const demoMachines = <VendingMachine>[
  VendingMachine(
    id: 'demo-ams',
    name: 'Boer & Kaas Amsterdam',
    position: LatLng(52.3727598, 4.8936041),
    products: [
      Product('Kaas', 'per 250g', 3.50, dbKey: 'kaas',      availableQty: 10),
      Product('Melk', '1L',       1.40, dbKey: 'melk',      availableQty: 12),
      Product('Eieren', 'per 6',  2.20, dbKey: 'eieren',    availableQty: 8),
      Product('Aardbeien', '250g',2.90, dbKey: 'aardbeien', availableQty: 6),
    ],
  ),
  VendingMachine(
    id: 'demo-rtd',
    name: 'Verse Melk Rotterdam',
    position: LatLng(51.9244201, 4.4777325),
    products: [
      Product('Melk', '1L',       1.35, dbKey: 'melk',      availableQty: 10),
      Product('Yoghurt', '500ml', 1.80, /* no dbKey */      availableQty: 7),
      Product('Kaas', 'per 250g', 3.30, dbKey: 'kaas',      availableQty: 5),
    ],
  ),
];
