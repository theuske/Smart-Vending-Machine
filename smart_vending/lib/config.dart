

const String kDbUrl =
    'https://smartvendingmachine-2e3f8-default-rtdb.europe-west1.firebasedatabase.app';

/// Real ESP32 device id in RTDB
const String kLiveDeviceId = 'arduino-001';

/// Keeps the last order placed in this app session
class OrderStore {
  static String? lastOrderId;
  static String? lastPickupCode;
  static String? lastDeviceId;
}
