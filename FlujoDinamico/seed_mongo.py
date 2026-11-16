"""
seed_mongo.py — Datos de prueba para BeaconFlow (MongoDB).

Genera los últimos 7 días de datos en las 3 colecciones que usa la app:
  - eventos_beacon : detecciones del beacon con RSSI
  - eventos_nfc    : ENTRADA / SALIDA de pacientes
  - logs_sistema   : logs INFO / WARNING / ERROR

Uso (desde la carpeta FlujoDinamico, con MongoDB corriendo):
    python seed_mongo.py              # agrega los datos
    python seed_mongo.py --limpiar    # borra las 3 colecciones y las vuelve a llenar

Requiere:  pip install pymongo
"""

import os
import sys
import random
from datetime import datetime, timedelta, timezone
from pymongo import MongoClient

MONGO_URI = os.environ.get('MONGO_URI', 'mongodb://127.0.0.1:27017/')
MONGO_DB = 'hospital_beaconflow'
DIAS = 7  # las gráficas de la app muestran 7 días

random.seed(42)  # mismos datos cada vez que lo corras

# (uid_hex, id_paciente, nombre, num_expediente, id_expediente, id_ingreso)
PACIENTES = [
    ('AB251607', 8,  'Valentina Juárez Pacheco', 'EXP-008', 8,  204),
    ('31B91507', 1,  'María González López',      'EXP-001', 1,  198),
    ('DF45E68B', 21, 'Marcelo Avila Garza',       'EXP-021', 11, 195),
]
ID_BEACON = 'BCN-01'


def a_utc(dt_local):
    """datetime local (naive) -> datetime UTC con zona horaria."""
    return dt_local.astimezone(timezone.utc)


def doc_tiempo(dt_local):
    """Campos de tiempo que la app guarda en cada documento."""
    return {
        'timestamp': a_utc(dt_local),
        'hora_local': dt_local.strftime('%H:%M:%S'),
        'fecha_local': dt_local.strftime('%Y-%m-%d'),
    }


def generar_beacon(dia):
    """Un evento cada 5 min de 07:00 a 21:00. Más detecciones en horas pico."""
    docs = []
    t = dia.replace(hour=7, minute=0, second=0, microsecond=0)
    fin = dia.replace(hour=21, minute=0, second=0, microsecond=0)
    while t <= fin:
        # probabilidad de detección: pico entre 9 y 13 h
        prob = 0.85 if 9 <= t.hour <= 13 else 0.45
        detectado = random.random() < prob
        # RSSI típico de BLE: -45 (muy cerca) a -90 (muy lejos); mejor en horas pico
        base = -58 if 9 <= t.hour <= 13 else -70
        rssi = int(random.gauss(base, 6)) if detectado else None
        docs.append({
            'id_beacon': ID_BEACON,
            'detectado': detectado,
            'rssi': rssi,
            **doc_tiempo(t),
        })
        t += timedelta(minutes=5)
    return docs


def generar_nfc(dia):
    """Entre 5 y 12 visitas por día; cada ENTRADA casi siempre tiene su SALIDA."""
    docs = []
    for _ in range(random.randint(5, 12)):
        uid, id_pac, nombre, num_exp, id_exp, id_ing = random.choice(PACIENTES)
        entrada = dia.replace(hour=random.randint(8, 18),
                              minute=random.randint(0, 59),
                              second=random.randint(0, 59), microsecond=0)
        base = {
            'uid_hex': uid, 'id_paciente': id_pac, 'nombre_paciente': nombre,
            'num_expediente': num_exp, 'id_expediente': id_exp, 'id_ingreso': id_ing,
        }
        docs.append({**base, 'accion': 'ENTRADA', **doc_tiempo(entrada)})
        if random.random() < 0.85:
            salida = entrada + timedelta(minutes=random.randint(20, 90))
            docs.append({**base, 'accion': 'SALIDA', **doc_tiempo(salida)})
    return docs


PLANTILLAS_LOG = [
    ('INFO',    'auth',       'Login exitoso: admin — rol ADMIN', None),
    ('INFO',    'auth',       'Logout: admin', None),
    ('INFO',    'ingresos',   'Paciente admitido en ingreso {n} por admin', None),
    ('INFO',    'alertas',    'Alerta {n} resuelta por admin', None),
    ('WARNING', 'auth',       'Login fallido: usuario "medico1" no autenticado', None),
    ('WARNING', 'admin',      'Eliminación paciente ID {n} por admin', None),
    ('ERROR',   'iot_nfc',    'UID no registrado: 9F3A22C1', 'Tarjeta no encontrada'),
    ('ERROR',   'iot_beacon', 'Error actualizando beacon BCN-01', 'timeout de conexión'),
]


def generar_logs(dia):
    docs = []
    for _ in range(random.randint(5, 10)):
        nivel, modulo, msg, detalle = random.choice(PLANTILLAS_LOG)
        t = dia.replace(hour=random.randint(7, 20), minute=random.randint(0, 59),
                        second=random.randint(0, 59), microsecond=0)
        t_doc = doc_tiempo(t)
        docs.append({
            'nivel': nivel, 'modulo': modulo,
            'mensaje': msg.format(n=random.randint(1, 200)),
            'id_usuario': None, 'detalle': detalle,
            'timestamp': t_doc['timestamp'], 'fecha_local': t_doc['fecha_local'],
        })
    return docs


def main():
    limpiar = '--limpiar' in sys.argv

    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
    try:
        client.admin.command('ping')
    except Exception as e:
        print(f'No pude conectar a MongoDB en {MONGO_URI}\n  -> {e}')
        print('Revisa que el servicio "MongoDB Server" esté iniciado (services.msc).')
        sys.exit(1)

    db = client[MONGO_DB]
    if limpiar:
        for col in ('eventos_beacon', 'eventos_nfc', 'logs_sistema'):
            db[col].drop()
        print('Colecciones borradas.')

    beacon, nfc, logs = [], [], []
    hoy = datetime.now().astimezone()
    for i in range(DIAS):
        dia = hoy - timedelta(days=DIAS - 1 - i)
        beacon += generar_beacon(dia)
        nfc += generar_nfc(dia)
        logs += generar_logs(dia)

    db.eventos_beacon.insert_many(beacon)
    db.eventos_nfc.insert_many(nfc)
    db.logs_sistema.insert_many(logs)

    print(f'Listo en la base "{MONGO_DB}":')
    print(f'  eventos_beacon: {len(beacon)}')
    print(f'  eventos_nfc:    {len(nfc)}')
    print(f'  logs_sistema:   {len(logs)}')


if __name__ == '__main__':
    main()