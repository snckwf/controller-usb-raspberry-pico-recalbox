/*
  controller_pico.ino - Controller USB in stile pad anni '90, 1 joystick + 4 pulsanti
  Scheda: Raspberry Pi Pico RP2040 (clone TZT con USB-C). Si presenta come gamepad USB standard, senza driver:
  PC Windows/Linux/Mac, Recalbox, RetroPie, Batocera, Android.

  Arduino IDE:
    - Gestore schede: "Raspberry Pi Pico/RP2040/RP2350" di Earle F. Philhower
    - Scheda: "Raspberry Pi Pico"  (vale anche per i cloni TZT con 2, 4 o 16 MB di flash)
    - Strumenti > USB Stack: "Pico SDK"   (e' quella predefinita)
    Nessuna libreria da installare: il gamepad USB (Joystick.h) e' gia' nel pacchetto della scheda.
    Primo caricamento: tieni premuto BOOTSEL mentre colleghi il cavo, poi Carica.

  Collegamenti (pulsanti verso GND, pull-up interne attive):
    Joystick KY-023   VRx -> GP26 (ADC0)   VRy -> GP27 (ADC1)   SW -> GP6
                      +5V del modulo -> 3V3(OUT) (pin 36)   GND -> GND
    Pulsante A (basso)    GP2 --[pulsante]-- GND
    Pulsante B (destra)   GP3 --[pulsante]-- GND
    Pulsante X (sinistra) GP4 --[pulsante]-- GND
    Pulsante Y (alto)     GP5 --[pulsante]-- GND
  ATTENZIONE: il joystick va alimentato dal 3V3(OUT), NON da VBUS/VSYS: gli ingressi del Pico sono a 3,3 V.
  (pulsanti 12x12 a 4 piedini: usare due piedini in diagonale, es. 1 e 4)

  Tasto FUNZIONE = clic del joystick (L3) tenuto premuto:
    L3 + A = L1      L3 + B = R1      L3 + X = SELECT (hotkey Recalbox)      L3 + Y = START
    L3 premuto e rilasciato da solo = clic L3 normale
    L3 tenuto da solo per 5 secondi = ricalibra il centro del joystick (il LED lampeggia)

  Pulsanti HID: 1 A, 2 B, 3 X, 4 Y, 5 L1, 6 R1, 7 SELECT, 8 START, 9 L3
  Assi: X/Y = joystick.  Croce digitale (hat): copia dello stick, utile nei giochi retro (CROCE_DA_STICK).

  Debug: Monitor seriale (qualsiasi velocita'), invia "d" per vedere i valori grezzi del joystick.
*/

#include <Joystick.h>

// ======================= CONFIGURAZIONE =======================
#define PIN_X    26
#define PIN_Y    27
#define PIN_SPIA  LED_BUILTIN

const uint8_t PIN_TASTI[5] = {2, 3, 4, 5, 6};   // A, B, X, Y, L3
enum { T_A = 0, T_B, T_X, T_Y, T_L3 };

#define CROCE_DA_STICK   1       // 1 = invia anche la croce digitale ricavata dallo stick
#define SOGLIA_CROCE     45      // % di corsa oltre cui la croce scatta
#define TAP_L3_MS        80      // durata del clic L3 inviato al rilascio
#define TAP_L3_MAX_MS    600     // oltre questo tempo il rilascio di L3 non genera il clic
#define RICALIBRA_MS     5000    // L3 tenuto da solo per questo tempo = ricalibrazione
#define ZONA_MORTA       120     // zona morta al centro (su 2048, ADC a 12 bit)
#define ANTIRIMBALZO_MS  10
#define PERIODO_MS       4       // 250 aggiornamenti al secondo

// Se un asse va al contrario o e' scambiato, cambia questi valori (verifica con joy.cpl o "d" sul monitor seriale).
#define SCAMBIA_XY  0
#define INVERTI_X   0
#define INVERTI_Y   0
// ==============================================================

int centro[2] = {2048, 2048};
const uint8_t PIN_ASSI[2] = {PIN_X, PIN_Y};

uint8_t statoTasti = 0, letturaPrec = 0;
unsigned long tCambio = 0, tInvio = 0, tDebug = 0;
bool l3Giu = false, comboUsata = false;
unsigned long tL3 = 0, fineTapL3 = 0;
bool ricalibrato = false;
bool debug = false;

int leggiAsse(uint8_t pin) {
  long s = 0;
  for (uint8_t i = 0; i < 8; i++) s += analogRead(pin);
  return (int)(s / 8);
}

void calibra() {
  for (uint8_t a = 0; a < 2; a++) {
    long s = 0;
    for (uint8_t i = 0; i < 64; i++) {
      s += analogRead(PIN_ASSI[a]);
      delay(1);
    }
    centro[a] = (int)(s / 64);
  }
}

// grezzo 0..4095 -> -511..511 con zona morta e scala separata sui due lati del centro
int scala(int grezzo, int c, bool inverti) {
  int v = grezzo - c;
  long r;
  if (abs(v) <= ZONA_MORTA) {
    r = 0;
  } else if (v > 0) {
    r = (long)(v - ZONA_MORTA) * 511L / max(1, 4095 - c - ZONA_MORTA);
  } else {
    r = (long)(v + ZONA_MORTA) * 511L / max(1, c - ZONA_MORTA);
  }
  r = constrain(r, -511L, 511L);
  return (int)(inverti ? -r : r);
}

uint8_t leggiTasti() {
  uint8_t b = 0;
  for (uint8_t i = 0; i < 5; i++)
    if (digitalRead(PIN_TASTI[i]) == LOW) b |= (1 << i);
  return b;
}

void lampeggia(uint8_t volte) {
  for (uint8_t i = 0; i < volte; i++) {
    digitalWrite(PIN_SPIA, HIGH);
    delay(80);
    digitalWrite(PIN_SPIA, LOW);
    delay(80);
  }
}

// angolo della croce digitale (-1 = ferma), 0 = su, 90 = destra, 180 = giu', 270 = sinistra
int angoloCroce(int x, int y) {
  const int s = 511 * SOGLIA_CROCE / 100;
  bool su = y < -s, giu = y > s, sx = x < -s, dx = x > s;
  if (su && dx) return 45;
  if (giu && dx) return 135;
  if (giu && sx) return 225;
  if (su && sx) return 315;
  if (su) return 0;
  if (dx) return 90;
  if (giu) return 180;
  if (sx) return 270;
  return -1;
}

void setup() {
  for (uint8_t i = 0; i < 5; i++) pinMode(PIN_TASTI[i], INPUT_PULLUP);
  pinMode(PIN_SPIA, OUTPUT);
  digitalWrite(PIN_SPIA, LOW);
  analogReadResolution(12);
  Serial.begin(115200);

  Joystick.begin();
  Joystick.useManualSend(true);

  delay(300);          // lascia assestare il potenziometro
  calibra();           // non toccare il joystick mentre colleghi il cavo
  lampeggia(2);
}

void loop() {
  unsigned long ora = millis();

  // ---- antirimbalzo pulsanti
  uint8_t l = leggiTasti();
  if (l != letturaPrec) {
    letturaPrec = l;
    tCambio = ora;
  }
  if (ora - tCambio >= ANTIRIMBALZO_MS) statoTasti = l;

  bool a  = statoTasti & (1 << T_A);
  bool b  = statoTasti & (1 << T_B);
  bool x  = statoTasti & (1 << T_X);
  bool y  = statoTasti & (1 << T_Y);
  bool l3 = statoTasti & (1 << T_L3);

  // ---- tasto funzione L3
  if (l3) {
    if (!l3Giu) {
      l3Giu = true;
      comboUsata = false;
      ricalibrato = false;
      tL3 = ora;
    }
    if (a || b || x || y) comboUsata = true;
    // ricalibrazione: L3 tenuto da solo per 5 secondi
    if (!comboUsata && !ricalibrato && ora - tL3 >= RICALIBRA_MS) {
      lampeggia(4);
      delay(400);
      calibra();
      lampeggia(4);
      ricalibrato = true;
      comboUsata = true;   // niente clic L3 al rilascio
    }
  } else if (l3Giu) {
    l3Giu = false;
    if (!comboUsata && ora - tL3 <= TAP_L3_MAX_MS) fineTapL3 = ora + TAP_L3_MS;
  }

  if (ora - tInvio < PERIODO_MS) return;
  tInvio = ora;

  // ---- pulsanti (numerati da 1)
  bool hid[10] = {false};
  if (l3) {
    hid[5] = a;      // L1
    hid[6] = b;      // R1
    hid[7] = x;      // SELECT
    hid[8] = y;      // START
  } else {
    hid[1] = a;
    hid[2] = b;
    hid[3] = x;
    hid[4] = y;
  }
  hid[9] = (long)(fineTapL3 - ora) > 0;   // L3
  for (uint8_t i = 1; i <= 9; i++) Joystick.button(i, hid[i]);

  // ---- assi
  int g[2];
  for (uint8_t i = 0; i < 2; i++) g[i] = leggiAsse(PIN_ASSI[i]);
#if SCAMBIA_XY
  int sx = scala(g[1], centro[1], INVERTI_X), sy = scala(g[0], centro[0], INVERTI_Y);
#else
  int sx = scala(g[0], centro[0], INVERTI_X), sy = scala(g[1], centro[1], INVERTI_Y);
#endif
  Joystick.X(sx + 512);          // 0..1023, centro 512
  Joystick.Y(sy + 512);
  Joystick.Z(512);
  Joystick.Zrotate(512);
  Joystick.sliderLeft(0);
  Joystick.sliderRight(0);
#if CROCE_DA_STICK
  Joystick.hat(angoloCroce(sx, sy));
#else
  Joystick.hat(-1);
#endif
  Joystick.send_now();

  // ---- LED: acceso mentre un pulsante e' premuto
  digitalWrite(PIN_SPIA, statoTasti ? HIGH : LOW);

  // ---- debug sul monitor seriale
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'd' || c == 'D') debug = !debug;
  }
  if (debug && ora - tDebug >= 100) {
    tDebug = ora;
    Serial.printf("grezzi X %4d Y %4d | centro %4d %4d | X %4d Y %4d | tasti ", g[0], g[1], centro[0], centro[1], sx, sy);
    Serial.println(statoTasti, BIN);
  }
}
