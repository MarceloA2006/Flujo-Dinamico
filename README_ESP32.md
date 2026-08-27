# Flujo Óptimo — Sistema IoT Hospitalario
 
## Descripción general
 
Flujo Óptimo es un sistema de monitoreo hospitalario en tiempo real que combina hardware IoT con una aplicación web desarrollada en Flask. El sistema permite registrar automáticamente la entrada y salida de pacientes mediante tecnología NFC, y detectar la presencia de personal médico en consultorios mediante beacons BLE, actualizando el dashboard de la aplicación en tiempo real.
 
---
 
## Hardware utilizado
 
### ESP32
 
El ESP32 es un microcontrolador de bajo costo y bajo consumo energético diseñado específicamente para aplicaciones IoT. Cuenta con conectividad WiFi integrada (2.4 GHz) y Bluetooth Low Energy (BLE), lo que lo hace ideal para este proyecto ya que necesita comunicarse simultáneamente con la red local para enviar datos a Flask y con el beacon BLE para detectar su señal.
 
### PN532 — Lector NFC/RFID
 
El PN532 es un módulo lector de señales NFC y RFID. Su función en este proyecto es leer el identificador único (UID) de las tarjetas NFC asignadas a cada paciente y enviarlo al ESP32 para su procesamiento.
 
**Modos de comunicación disponibles:**
El módulo tiene dos filas de pines y dos switches físicos que determinan el protocolo de comunicación:
 
| Modo | Switches | Pines usados | Uso |
|------|----------|--------------|-----|
| I²C  | SW1=OFF, SW2=OFF | 4 pines (VCC, GND, SDA, SCL) | Este proyecto |
| SPI  | SW1=ON, SW2=OFF | 8 pines | Alta velocidad |
| UART | SW1=OFF, SW2=ON | 4 pines (TX, RX) | Comunicación serial |
 
**Este proyecto usa el modo I²C** con la siguiente conexión al ESP32:
 
```
PN532 VCC  →  ESP32 3.3V   (IMPORTANTE: NO conectar a 5V, daña el chip)
PN532 GND  →  ESP32 GND
PN532 SDA  →  ESP32 GPIO 21
PN532 SCL  →  ESP32 GPIO 22
```
 
**Advertencia:** El PN532 opera a 3.3V. Conectarlo a 5V daña permanentemente el chip de comunicación aunque el LED indicador siga encendido, ya que el LED está conectado directamente a VCC y no al chip.
 
**Preparación física del módulo:**
Los pines del PN532 vienen sin soldar de fábrica. Es necesario soldar los headers antes de conectarlo. La fila de 4 pines es suficiente para el modo I²C y ofrece una conexión más compacta conectarlos al ESP32 con cables de puente hembra a hembra.
 
### Beacon BLE — Feasycom FSC-BP104D
 
El beacon es un dispositivo Bluetooth Low Energy que transmite continuamente una señal de radio con un identificador único. En este proyecto funciona como indicador de presencia del médico en el consultorio.
 
**Datos de identificación del beacon:**
```
Protocolo:  iBeacon
UUID:       FDA50693-A4E2-4FB1-AFCF-C6EB07647825
Major:      10065
Minor:      26049
MAC:        DC:0D:30:48:30:EC
Intervalo:  300ms (configurado en app Feasycom)
```
 
**Configuración importante:** El beacon tiene múltiples slots de transmisión (iBeacon, Eddystone TLM, Eddystone URL). Para que el ESP32 lo detecte de manera confiable es necesario dejar activo solo el slot iBeacon y configurar el intervalo en 300ms desde la app FeasyBeacon.
 
---
 
## Librerías necesarias en Arduino IDE
 
| Librería | Versión | Función |
|----------|---------|---------|
| Adafruit PN532 | última | Maneja el lector NFC |
| Adafruit BusIO | última | Abstrae la comunicación I²C con el PN532 |
| NimBLE-Arduino | 1.4.2 | Escanea señales BLE del beacon |
| ArduinoJson | ≥ 6.x | Serializa los datos para enviarlos a Flask |
| ESP32 by Espressif Systems | 2.0.11 | Board package — gestiona WiFi y hardware del ESP32 |
 
**Importante:** Usar el board package de **Espressif Systems**, no el de Arduino. El de Arduino no es compatible con NimBLE y causa errores de inicialización BLE (`ESP_ERR_INVALID_STATE`). También usar NimBLE versión **1.4.2** específicamente — versiones superiores tienen cambios de API incompatibles.
 
---
 
## Funcionamiento del código Arduino
 
El sketch del ESP32 realiza tres tareas de forma concurrente en el loop principal:
 
### 1. Configuración inicial (setup)
```
NimBLE → WiFi → PN532
```
El orden de inicialización es crítico. NimBLE debe inicializarse **antes** que WiFi porque ambos comparten el mismo controlador de radio del ESP32. Si WiFi se inicializa primero, BLE falla con `ESP_ERR_INVALID_STATE`.
 
### 2. Lectura NFC (prioridad alta)
El PN532 escucha continuamente con un timeout de 100ms. Cuando detecta una tarjeta:
1. Lee el UID de 4 bytes (ej. `31B91507`)
2. Lo convierte a hexadecimal en mayúsculas
3. Aplica un cooldown de 5 segundos para evitar lecturas duplicadas
4. Envía un POST a Flask:
```json
POST http://IP_FLASK:5001/iot/nfc
{ "uid": "31B91507" }
```
 
### 3. Escaneo BLE (cada 5 segundos)
El ESP32 realiza un escaneo BLE pasivo de 1 segundo. El beacon se identifica por tres métodos en orden de prioridad:
1. **MAC address** — el más rápido y confiable
2. **Nombre del dispositivo** — si contiene "FSC" o "BP104"
3. **UUID iBeacon** — verifica UUID + Major + Minor en los Manufacturer Data
Después del escaneo envía el resultado a Flask:
```json
POST http://IP_FLASK:5001/iot/beacon
{ "id_beacon": "BCN-01", "detectado": true, "rssi": -56 }
```
 
### 4. Reconexión automática
Si se pierde la conexión WiFi, el ESP32 intenta reconectarse automáticamente antes de cada POST.
 
---
 
## Cómo Flask recibe y procesa la información
 
### Endpoint `/iot/nfc`
1. Recibe el UID de la tarjeta
2. Llama al SP `sp_registrar_nfc(uid)` → busca en la tabla `tarjetas_nfc` el paciente asociado
3. Llama a `sp_verificar_ingreso_activo` → verifica si el paciente ya tiene un ingreso `EN_ESPERA` en la BD
4. **Si no está en espera** → llama `sp_insertar_ingreso` → registra ENTRADA en sala de espera
5. **Si ya está en espera** → llama `sp_dar_alta_ingreso` → registra SALIDA
6. Actualiza la lista en memoria `_sala_espera`
### Endpoint `/iot/beacon`
1. Recibe el estado del beacon (detectado/no detectado) y el RSSI
2. Actualiza el diccionario `_beacon_estado` en memoria de Flask
3. Llama al SP `sp_actualizar_estado_beacon` → actualiza el estado en la BD
### Endpoint `/iot/estado` (polling)
El dashboard llama este endpoint cada 3 segundos. Flask responde con:
```json
{
  "beacon": { "detectado": true, "rssi": -56, "id_beacon": "BCN-01" },
  "sala_espera": [ { "nombre_completo": "María González", "min_espera": 12, ... } ],
  "contador_espera": 1
}
```
El JavaScript del dashboard recibe este JSON y actualiza la interfaz sin recargar la página.
 
---
 
## Flujo completo del sistema
 
```
Tarjeta NFC
    ↓ (acercar al PN532)
ESP32 lee UID
    ↓ (POST /iot/nfc)
Flask → sp_registrar_nfc → BD
    ↓ (toggle entrada/salida)
Ingreso registrado en tabla ingresos
    ↓ (vw_sala_espera)
Dashboard polling /iot/estado cada 3s
    ↓
Paciente aparece/desaparece en sala de espera
```
 
```
Beacon BLE transmite cada 300ms
    ↓ (ESP32 escanea cada 5s)
ESP32 detecta beacon por MAC/UUID
    ↓ (POST /iot/beacon)
Flask → sp_actualizar_estado_beacon → BD
    ↓
Dashboard muestra consultorio ACTIVO/LIBRE
```
 
---
 
## Configuración de red
 
El ESP32 y la computadora que corre Flask deben estar en la **misma red WiFi**. La IP de Flask en el sketch debe actualizarse cada vez que cambie la red:
 
 
```cpp
// En el sketch Arduino
#define WIFI_SSID   "nombre_red"
#define WIFI_PASSWORD "contraseña"
#define FLASK_IP    "IP_obtenida_arriba"
#define FLASK_PORT  5001
```
 
> **Nota sobre redes universitarias:** Las redes empresariales o universitarias a veces bloquean el tráfico entre dispositivos (client isolation). Si el ESP32 se conecta pero no llega a Flask, puede ser necesario usar un hotspot móvil. Al usar hotspot de iPhone activar **"Maximizar compatibilidad"** para forzar la banda 2.4 GHz, ya que el ESP32 no soporta 5 GHz.







