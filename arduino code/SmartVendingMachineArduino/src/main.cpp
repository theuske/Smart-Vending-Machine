#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <TinyGPSPlus.h>
#include <WiFiManager.h>
#include <Preferences.h>
#include <ArduinoJson.h>

/* ===================== CONFIG (portal-overridable) ===================== */
String RTDB_BASE = "https://smartvendingmachine-2e3f8-default-rtdb.europe-west1.firebasedatabase.app"; 
String DEVICE_ID = "arduino-001";

/* ===================== Hardware pins ===================== */
// GPS (NEO-6M/7M/8M): GPS TX -> ESP32 RX2(16), GPS RX -> ESP32 TX2(17)
static const int GPS_RX = 16;  // ESP32 RX2
static const int GPS_TX = 17;  // ESP32 TX2 (optional if you don't send to GPS)

// Long-press button to GND to force config portal (avoid GPIO0/BOOT)
const int PIN_FORCE_PORTAL = 25;

/* ===================== Globals ===================== */
TinyGPSPlus gps;
HardwareSerial GPSser(2);
WiFiClientSecure secureClient;
Preferences prefs;

unsigned long lastPushMs = 0;
const unsigned long PUSH_INTERVAL_MS = 8000;

// ---- stock ----
int eieren = 12;
int melk   = 7;
int aardbeien = 6;
int kaas      = 4;


double lastLat = 51.441642, lastLng = 5.4697225;

/* ======== GPS quality thresholds ======== */
const float HDOP_MAX = 1.8f;   
const int   MINSATS  = 6;      
static float hdopToMeters(float hdop) { return hdop * 5.0f; }

/* ======== Mini median filter ======== */
const int MED_WIN = 5;
double latBuf[MED_WIN] = {0};
double lngBuf[MED_WIN] = {0};
int bufCount = 0, bufIdx = 0;

template <typename T>
static T medianOf(T *arr, int n) {
  T tmp[MED_WIN];
  for (int i = 0; i < n; i++) tmp[i] = arr[i];
  for (int i = 1; i < n; i++) {
    T key = tmp[i]; int j = i - 1;
    while (j >= 0 && tmp[j] > key) { tmp[j + 1] = tmp[j]; j--; }
    tmp[j + 1] = key;
  }
  return tmp[n / 2];
}

static void pushSample(double lat, double lng) {
  latBuf[bufIdx] = lat; lngBuf[bufIdx] = lng;
  bufIdx = (bufIdx + 1) % MED_WIN;
  if (bufCount < MED_WIN) bufCount++;
}
static bool haveMedian() { return bufCount >= 3; }

/* ===================== HTTP helpers ===================== */
bool httpPut(const String& pathJson, const String& body) {
  secureClient.setInsecure();
  HTTPClient http;
  if (!http.begin(secureClient, RTDB_BASE + pathJson)) return false;
  http.addHeader("Content-Type", "application/json");
  int code = http.PUT(body);
  Serial.printf("[HTTP] PUT %s -> %d\n", pathJson.c_str(), code);
  if (code > 0) Serial.println(http.getString());
  http.end();
  return code >= 200 && code < 300;
}
String httpGet(const String& pathJson) {
  secureClient.setInsecure();
  HTTPClient http;
  if (!http.begin(secureClient, RTDB_BASE + pathJson)) return "";
  int code = http.GET();
  String body = http.getString();
  Serial.printf("[HTTP] GET %s -> %d\n", pathJson.c_str(), code);
  http.end();
  if (code >= 200 && code < 300) return body;
  return "";
}
bool httpPatch(const String& pathJson, const String& body) {
  secureClient.setInsecure();
  HTTPClient http;
  if (!http.begin(secureClient, RTDB_BASE + pathJson)) return false;
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(body);
  Serial.printf("[HTTP] PATCH %s -> %d\n", pathJson.c_str(), code);
  if (code > 0) Serial.println(http.getString());
  http.end();
  return code >= 200 && code < 300;
}

/* ===================== JSON builder ===================== */
String makeJson(double lat, double lng, bool validFix, float hdop, int sats) {
  unsigned long updated = millis() / 1000;
  const float acc_m = hdopToMeters(hdop);

  String status;
  if (!validFix)            status = "no-fix";
  else if (sats < MINSATS)  status = "weak-fix";
  else if (hdop > HDOP_MAX) status = "poor-fix";
  else                      status = "online";

  String s = "{";
  s += "\"name\":\"Smart Vending\",";
  s += "\"lat\":" + String(lat, 6) + ",";
  s += "\"lng\":" + String(lng, 6) + ",";
  s += "\"hdop\":" + String(hdop, 2) + ",";
  s += "\"sats\":" + String(sats) + ",";
  s += "\"accuracy_m\":" + String(acc_m, 1) + ",";
  s += "\"status\":\"" + status + "\",";

  //keys
  s += "\"stock\":{";
  s +=   "\"eieren\":"    + String(eieren)    + ",";
  s +=   "\"melk\":"      + String(melk)      + ",";
  s +=   "\"aardbeien\":" + String(aardbeien) + ",";
  s +=   "\"kaas\":"      + String(kaas);
  s += "},";

  s += "\"updated_at\":" + String(updated);
  s += "}";
  return s;
}

/* ===================== Prefs ===================== */
void savePrefs() {
  prefs.begin("vending", false);
  prefs.putString("rtdb", RTDB_BASE);
  prefs.putString("devid", DEVICE_ID);
  prefs.end();
}
void loadPrefs() {
  prefs.begin("vending", true);
  RTDB_BASE = prefs.getString("rtdb", RTDB_BASE);
  DEVICE_ID = prefs.getString("devid", DEVICE_ID);
  prefs.end();
}

/* ===================== WiFi config portal ===================== */
void startConfigPortal(bool force = false) {
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_POWER_8_5dBm);

  WiFiManager wm;
  wm.setConfigPortalTimeout(180);  // 3 minutes
  wm.setClass("invert");           // dark theme

  WiFiManagerParameter p_rtdb("rtdb", "RTDB base (https://...)", RTDB_BASE.c_str(), 120);
  WiFiManagerParameter p_devid("devid", "Device ID", DEVICE_ID.c_str(), 40);
  wm.addParameter(&p_rtdb);
  wm.addParameter(&p_devid);

  bool ok = force
    ? wm.startConfigPortal("Vending-Setup", "12345678")
    : wm.autoConnect("Vending-Setup", "12345678");

  if (!ok) {
    Serial.println("WiFi config failed or timed out; restarting...");
    delay(1000);
    ESP.restart();
  }

  RTDB_BASE = String(p_rtdb.getValue());
  DEVICE_ID = String(p_devid.getValue());
  savePrefs();

  Serial.printf("WiFi OK: %s  RTDB=%s  DEV=%s\n",
                WiFi.localIP().toString().c_str(),
                RTDB_BASE.c_str(), DEVICE_ID.c_str());
}

/* ===================== Order processing ===================== */

void processPendingOrders() {
  if (WiFi.status() != WL_CONNECTED) return;

  String body = httpGet("/orders/" + DEVICE_ID + ".json");
  if (body.isEmpty() || body == "null") return;

  StaticJsonDocument<4096> doc;
  DeserializationError err = deserializeJson(doc, body);
  if (err) {
    Serial.printf("JSON parse error: %s\n", err.c_str());
    return;
  }

  for (JsonPair kv : doc.as<JsonObject>()) {
    String orderId = kv.key().c_str();
    JsonObject ord = kv.value();

    String status = ord["status"] | "";
    if (status != "pending") continue;  // only new orders

    JsonObject items = ord["items"];
    int q_melk      = items["melk"]      | 0;
    int q_eieren    = items["eieren"]    | 0;
    int q_aardbeien = items["aardbeien"] | 0;
    int q_kaas      = items["kaas"]      | 0;

    bool ok =
      q_melk      <= melk &&
      q_eieren    <= eieren &&
      q_aardbeien <= aardbeien &&
      q_kaas      <= kaas;

    if (!ok) {
      httpPatch("/orders/" + DEVICE_ID + "/" + orderId + ".json",
                "{\"status\":\"rejected\",\"reason\":\"out_of_stock\"}");
      continue;
    }

  
    httpPatch("/orders/" + DEVICE_ID + "/" + orderId + ".json", "{\"status\":\"accepted\"}");
    httpPatch("/orders/" + DEVICE_ID + "/" + orderId + ".json", "{\"status\":\"dispensing\"}");

    delay(1500);

    // decrement local stock
    melk      -= q_melk;      if (melk < 0) melk = 0;
    eieren    -= q_eieren;    if (eieren < 0) eieren = 0;
    aardbeien -= q_aardbeien; if (aardbeien < 0) aardbeien = 0;
    kaas      -= q_kaas;      if (kaas < 0) kaas = 0;

    // Patch device stock immediately so app sees it quickly
    String stockJson = String("{\"stock\":{\"eieren\":") + eieren +
                       ",\"melk\":" + melk +
                       ",\"aardbeien\":" + aardbeien +
                       ",\"kaas\":" + kaas + "}}";
    httpPatch("/devices/" + DEVICE_ID + ".json", stockJson);

    // mark done with server timestamp
    httpPatch("/orders/" + DEVICE_ID + "/" + orderId + ".json",
              "{\"status\":\"done\",\"completed_at\":{\".sv\":\"timestamp\"}}");
  }
}

/* ===================== Arduino setup/loop ===================== */
void setup() {
  Serial.begin(115200);
  delay(100);

  pinMode(PIN_FORCE_PORTAL, INPUT_PULLUP);
  loadPrefs();

  bool forcePortal = (digitalRead(PIN_FORCE_PORTAL) == LOW);
  startConfigPortal(forcePortal);

  GPSser.begin(9600, SERIAL_8N1, GPS_RX, GPS_TX);
  Serial.println("GPS serial started.");
}

void loop() {
  // Feed GPS parser
  while (GPSser.available()) gps.encode(GPSser.read());

  if (gps.location.isUpdated()) {
    const bool valid = gps.location.isValid();
    const double lat = gps.location.lat();
    const double lng = gps.location.lng();
    const int sats = gps.satellites.isValid() ? (int)gps.satellites.value() : 0;
    const float hdop = gps.hdop.isValid() ? (float)gps.hdop.hdop() / 100.0f : 99.0f;

    Serial.printf("GPS: %.6f, %.6f | valid=%d sats=%d hdop=%.2f\n",
                  lat, lng, valid, sats, hdop);

    if (valid && sats >= MINSATS && hdop <= HDOP_MAX) {
      pushSample(lat, lng);
      if (haveMedian()) {
        lastLat = medianOf(latBuf, bufCount);
        lastLng = medianOf(lngBuf, bufCount);
      } else {
        lastLat = lat; lastLng = lng;
      }
    }
  }

  
  static unsigned long pressedAt = 0;
  if (digitalRead(PIN_FORCE_PORTAL) == LOW) {
    if (pressedAt == 0) pressedAt = millis();
    if (millis() - pressedAt > 2000) {
      Serial.println("Re-opening config portal...");
      startConfigPortal(true);
      pressedAt = 0;
    }
  } else {
    pressedAt = 0;
  }

  // Periodic device state push (location + stock)
  const unsigned long now = millis();
  if (now - lastPushMs >= PUSH_INTERVAL_MS) {
    lastPushMs = now;

    const int sats = gps.satellites.isValid() ? (int)gps.satellites.value() : 0;
    const float hdop = gps.hdop.isValid() ? (float)gps.hdop.hdop() / 100.0f : 99.0f;
    const bool valid = gps.location.isValid();

    if (WiFi.status() != WL_CONNECTED) WiFi.reconnect();

    if (WiFi.status() == WL_CONNECTED) {
      String payload = makeJson(lastLat, lastLng, valid, hdop, sats);
      httpPut("/devices/" + DEVICE_ID + ".json", payload);
    } else {
      // bring up portal next cycle if needed
      startConfigPortal(false);
    }
  }

  // Poll for orders every 3s
  static unsigned long lastOrders = 0;
  if (millis() - lastOrders > 3000) {
    lastOrders = millis();
    processPendingOrders();
  }
}
