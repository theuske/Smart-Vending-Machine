import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../config.dart';
import '../models.dart';
import '../demo_stock.dart';
import 'products_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const Duration _liveTTL = Duration(seconds: 25);

  final _controller = Completer<GoogleMapController>();
  final _nlCenter = const LatLng(52.1326, 5.2913);

  Set<Marker> _markers = {};
  final bool onlyArduinoClickable = false; 

  late final DatabaseReference _liveRef;
  VendingMachine? _arduinoVm;

  int? _lastSeenUpdatedAt;
  DateTime? _lastClientEventAt;

  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _ttlTimer;

  @override
  void initState() {
    super.initState();
    DemoStock.initIfNeeded();
    _markers = demoMachines.map(_vmToMarker).toSet();

    final app = Firebase.app();
    final db = FirebaseDatabase.instanceFor(app: app, databaseURL: kDbUrl);
    _liveRef = db.ref('devices/$kLiveDeviceId');

    _sub = _liveRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value == null) {
        _arduinoVm = null;
        _lastSeenUpdatedAt = null;
        _lastClientEventAt = null;
        _rebuildMarkers();
        return;
      }

      final raw = event.snapshot.value;
      if (raw is! Map) return;
      final data = Map<String, dynamic>.from(raw as Map);

      final updatedAt = (data['updated_at'] as num?)?.toInt();
      if (updatedAt != null && updatedAt != _lastSeenUpdatedAt) {
        _lastSeenUpdatedAt = updatedAt;
        _lastClientEventAt = DateTime.now();
      }

      final vm = VendingMachine(
        id: kLiveDeviceId,
        name: (data['name'] ?? 'Smart Vending') as String,
        position: LatLng(
          (data['lat'] as num?)?.toDouble() ?? 51.441642,
          (data['lng'] as num?)?.toDouble() ?? 5.4697225,
        ),
        products: _mapStockToProducts(data['stock']),
        isArduinoLive: true,
      );

      _arduinoVm = vm;
      _rebuildMarkers();
      _flyTo(vm.position);
    });

    _ttlTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _rebuildMarkers();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ttlTimer?.cancel();
    super.dispose();
  }

  bool _isLiveFresh() {
    if (_lastClientEventAt == null) return false;
    final age = DateTime.now().difference(_lastClientEventAt!);
    return age <= _liveTTL;
  }

  List<Product> _mapStockToProducts(dynamic stock) {
    if (stock is Map) {
      final m = Map<String, dynamic>.from(stock);
      return m.entries.map<Product>((e) {
        final key = e.key.toString();
        final qty = (e.value as num?)?.toInt() ?? 0;
        final displayName = _dutchNameForKey(key);
        return Product('$displayName ($qty)', 'stuks', 0.0, dbKey: key, availableQty: qty);
      }).toList();
    }
    return const [
      Product('Eieren', 'per 10', 3.00, dbKey: 'eieren', availableQty: 10),
      Product('Melk', '1L', 1.50, dbKey: 'melk', availableQty: 10),
    ];
  }

  String _dutchNameForKey(String key) {
    switch (key) {
      case 'melk': return 'Melk';
      case 'eieren': return 'Eieren';
      case 'aardbeien': return 'Aardbeien';
      case 'kaas': return 'Kaas';
      default: return key;
    }
  }

  void _rebuildMarkers() {
    final set = <Marker>{...demoMachines.map(_vmToMarker)};
    if (_arduinoVm != null && _isLiveFresh()) {
      set.add(_vmToMarker(_arduinoVm!));
    }
    setState(() => _markers = set);
  }

  Future<void> _flyTo(LatLng target) async {
    if (!_controller.isCompleted) return;
    final c = await _controller.future;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 12)),
    );
  }

  Marker _vmToMarker(VendingMachine vm) {
    final isSupportedPlatform = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final canTap = isSupportedPlatform;
    final isArduino = vm.id == kLiveDeviceId;
    final snippet = isArduino
        ? (_lastClientEventAt == null
            ? 'Offline'
            : (DateTime.now().difference(_lastClientEventAt!).inSeconds <= _liveTTL.inSeconds
                ? 'Live'
                : 'Offline'))
        : 'Demo';

    return Marker(
      markerId: MarkerId(vm.id),
      position: vm.position,
      infoWindow: InfoWindow(
        title: vm.name,
        snippet: snippet,
        onTap: canTap ? () => _openProducts(vm) : null,
      ),
      onTap: canTap ? () => _openProducts(vm) : null,
      icon: isArduino
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  void _openProducts(VendingMachine vm) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(machine: vm)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vending machines')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _map(),
        ),
      ),
    );
  }

  Widget _map() {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isSupported = isMobile || kIsWeb;

    if (isSupported) {
      return GoogleMap(
        initialCameraPosition: CameraPosition(target: _nlCenter, zoom: 6.7),
        onMapCreated: (c) => _controller.complete(c),
        zoomControlsEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        markers: _markers,
      );
    }
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Text(
        'Kaartvoorbeeld (desktop)\nOpen op Android/iOS of Web voor Google Maps',
        textAlign: TextAlign.center,
      ),
    );
  }
}
