"""
mongo_db.py — Conexión y operaciones con MongoDB para BeaconFlow.

Colecciones:
  - eventos_nfc    : registro de cada lectura NFC (entrada/salida paciente)
  - eventos_beacon : registro de cada detección del beacon con RSSI
  - logs_sistema   : errores y eventos del sistema Flask

Relación con PostgreSQL:
  - eventos_nfc.id_paciente    → pacientes.id_paciente (PostgreSQL)
  - eventos_nfc.id_ingreso     → ingresos.id_ingreso   (PostgreSQL)
  - eventos_beacon.id_beacon   → beacons.id_beacon     (PostgreSQL)
  - logs_sistema.id_usuario    → usuarios.id_usuario   (PostgreSQL)
"""

from pymongo import MongoClient, DESCENDING
from datetime import datetime, timezone
import os

# ════════════════════════════════════════════════════
#  Conexión
# ════════════════════════════════════════════════════
MONGO_URI = os.environ.get('MONGO_URI', 'mongodb://localhost:27017/')
MONGO_DB  = 'hospital_beaconflow'

_client = None
_db     = None


def get_mongo():
    """Devuelve la instancia de la base de datos MongoDB (singleton)."""
    global _client, _db
    if _db is None:
        _client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
        _db     = _client[MONGO_DB]
        _crear_indices()
    return _db


def _crear_indices():
    """Crea índices para optimizar las consultas más frecuentes."""
    db = _db
    # eventos_nfc: buscar por paciente y por fecha
    db.eventos_nfc.create_index([('id_paciente', 1)])
    db.eventos_nfc.create_index([('timestamp', DESCENDING)])
    db.eventos_nfc.create_index([('uid_hex', 1)])
    # eventos_beacon: buscar por beacon y por fecha
    db.eventos_beacon.create_index([('id_beacon', 1)])
    db.eventos_beacon.create_index([('timestamp', DESCENDING)])
    # logs_sistema: buscar por nivel y fecha
    db.logs_sistema.create_index([('nivel', 1)])
    db.logs_sistema.create_index([('timestamp', DESCENDING)])


# ════════════════════════════════════════════════════
#  EVENTOS NFC
# ════════════════════════════════════════════════════
def registrar_evento_nfc(uid_hex, id_paciente, nombre_paciente,
                          num_expediente, accion, id_ingreso=None,
                          id_expediente=None):
    """
    Registra una lectura NFC en MongoDB.
    accion: 'ENTRADA' | 'SALIDA'

    Relación PostgreSQL:
      id_paciente   → pacientes.id_paciente
      id_ingreso    → ingresos.id_ingreso
      id_expediente → expedientes.id_expediente
    """
    try:
        db = get_mongo()
        doc = {
            'uid_hex':        uid_hex,
            'id_paciente':    id_paciente,        # FK → PostgreSQL pacientes
            'nombre_paciente': nombre_paciente,
            'num_expediente': num_expediente,
            'id_expediente':  id_expediente,      # FK → PostgreSQL expedientes
            'id_ingreso':     id_ingreso,          # FK → PostgreSQL ingresos
            'accion':         accion,              # 'ENTRADA' | 'SALIDA'
            'timestamp':      datetime.now(timezone.utc),
            'hora_local':     datetime.now().strftime('%H:%M:%S'),
            'fecha_local':    datetime.now().strftime('%Y-%m-%d'),
        }
        db.eventos_nfc.insert_one(doc)
    except Exception as e:
        print(f"[MongoDB] Error registrar_evento_nfc: {e}")


def obtener_eventos_nfc(limite=100, id_paciente=None):
    """Obtiene los últimos eventos NFC, opcionalmente filtrados por paciente."""
    try:
        db    = get_mongo()
        filtro = {'id_paciente': id_paciente} if id_paciente else {}
        docs  = list(db.eventos_nfc.find(
            filtro,
            {'_id': 0},
            sort=[('timestamp', DESCENDING)],
            limit=limite
        ))
        return docs
    except Exception as e:
        print(f"[MongoDB] Error obtener_eventos_nfc: {e}")
        return []


def kpi_entradas_por_dia(dias=7):
    """
    KPI: conteo de entradas NFC por día en los últimos N días.
    Usado en gráfica de barras Highcharts.
    """
    try:
        db = get_mongo()
        pipeline = [
            {'$match': {'accion': 'ENTRADA'}},
            {'$group': {
                '_id':   '$fecha_local',
                'total': {'$sum': 1}
            }},
            {'$sort': {'_id': 1}},
            {'$limit': dias}
        ]
        return list(db.eventos_nfc.aggregate(pipeline))
    except Exception as e:
        print(f"[MongoDB] Error kpi_entradas_por_dia: {e}")
        return []


def kpi_tiempo_promedio_espera():
    """
    KPI: tiempo promedio entre ENTRADA y SALIDA del mismo ingreso.
    """
    try:
        db = get_mongo()
        pipeline = [
            {'$match': {'id_ingreso': {'$ne': None}}},
            {'$group': {
                '_id':       '$id_ingreso',
                'acciones':  {'$push': {'accion': '$accion', 'ts': '$timestamp'}}
            }}
        ]
        return list(db.eventos_nfc.aggregate(pipeline))
    except Exception as e:
        print(f"[MongoDB] Error kpi_tiempo_promedio_espera: {e}")
        return []


# ════════════════════════════════════════════════════
#  EVENTOS BEACON
# ════════════════════════════════════════════════════
def registrar_evento_beacon(id_beacon, detectado, rssi=None):
    """
    Registra el estado del beacon en MongoDB.

    Relación PostgreSQL:
      id_beacon → beacons.id_beacon
    """
    try:
        db = get_mongo()
        doc = {
            'id_beacon':  id_beacon,    # FK → PostgreSQL beacons
            'detectado':  detectado,
            'rssi':       rssi,
            'timestamp':  datetime.now(timezone.utc),
            'hora_local': datetime.now().strftime('%H:%M:%S'),
            'fecha_local': datetime.now().strftime('%Y-%m-%d'),
        }
        db.eventos_beacon.insert_one(doc)
    except Exception as e:
        print(f"[MongoDB] Error registrar_evento_beacon: {e}")


def obtener_eventos_beacon(limite=200, id_beacon=None):
    """Obtiene los últimos eventos de beacon."""
    try:
        db     = get_mongo()
        filtro = {'id_beacon': id_beacon} if id_beacon else {}
        docs   = list(db.eventos_beacon.find(
            filtro,
            {'_id': 0},
            sort=[('timestamp', DESCENDING)],
            limit=limite
        ))
        return docs
    except Exception as e:
        print(f"[MongoDB] Error obtener_eventos_beacon: {e}")
        return []


def kpi_rssi_promedio_por_hora():
    """
    KPI: RSSI promedio del beacon agrupado por hora del día.
    Usado en gráfica de línea Highcharts.
    """
    try:
        db = get_mongo()
        pipeline = [
            {'$match': {'detectado': True, 'rssi': {'$ne': None}}},
            {'$group': {
                '_id':        '$hora_local',
                'rssi_prom':  {'$avg': '$rssi'},
                'detecciones': {'$sum': 1}
            }},
            {'$sort': {'_id': 1}}
        ]
        return list(db.eventos_beacon.aggregate(pipeline))
    except Exception as e:
        print(f"[MongoDB] Error kpi_rssi_promedio_por_hora: {e}")
        return []


def kpi_detecciones_por_dia(dias=7):
    """
    KPI: número de detecciones del beacon por día.
    """
    try:
        db = get_mongo()
        pipeline = [
            {'$match': {'detectado': True}},
            {'$group': {
                '_id':   '$fecha_local',
                'total': {'$sum': 1}
            }},
            {'$sort': {'_id': 1}},
            {'$limit': dias}
        ]
        return list(db.eventos_beacon.aggregate(pipeline))
    except Exception as e:
        print(f"[MongoDB] Error kpi_detecciones_por_dia: {e}")
        return []


# ════════════════════════════════════════════════════
#  LOGS DEL SISTEMA
# ════════════════════════════════════════════════════
def registrar_log(nivel, modulo, mensaje, id_usuario=None, detalle=None):
    """
    Registra un log del sistema en MongoDB.
    nivel: 'INFO' | 'WARNING' | 'ERROR'

    Relación PostgreSQL:
      id_usuario → usuarios.id_usuario
    """
    try:
        db = get_mongo()
        doc = {
            'nivel':      nivel,
            'modulo':     modulo,
            'mensaje':    mensaje,
            'id_usuario': id_usuario,   # FK → PostgreSQL usuarios
            'detalle':    detalle,
            'timestamp':  datetime.now(timezone.utc),
            'fecha_local': datetime.now().strftime('%Y-%m-%d'),
        }
        db.logs_sistema.insert_one(doc)
    except Exception as e:
        print(f"[MongoDB] Error registrar_log: {e}")


def obtener_logs(limite=100, nivel=None):
    """Obtiene los últimos logs del sistema."""
    try:
        db     = get_mongo()
        filtro = {'nivel': nivel} if nivel else {}
        docs   = list(db.logs_sistema.find(
            filtro,
            {'_id': 0},
            sort=[('timestamp', DESCENDING)],
            limit=limite
        ))
        return docs
    except Exception as e:
        print(f"[MongoDB] Error obtener_logs: {e}")
        return []


def kpi_errores_por_dia(dias=7):
    """
    KPI: errores del sistema por día.
    """
    try:
        db = get_mongo()
        pipeline = [
            {'$match': {'nivel': 'ERROR'}},
            {'$group': {
                '_id':   '$fecha_local',
                'total': {'$sum': 1}
            }},
            {'$sort': {'_id': 1}},
            {'$limit': dias}
        ]
        return list(db.logs_sistema.aggregate(pipeline))
    except Exception as e:
        print(f"[MongoDB] Error kpi_errores_por_dia: {e}")
        return []


# ════════════════════════════════════════════════════
#  RESUMEN GENERAL (para dashboard de reportes)
# ════════════════════════════════════════════════════
def resumen_mongo():
    """Devuelve conteos generales de las 3 colecciones."""
    try:
        db = get_mongo()
        return {
            'total_eventos_nfc':     db.eventos_nfc.count_documents({}),
            'total_entradas':        db.eventos_nfc.count_documents({'accion': 'ENTRADA'}),
            'total_salidas':         db.eventos_nfc.count_documents({'accion': 'SALIDA'}),
            'total_eventos_beacon':  db.eventos_beacon.count_documents({}),
            'total_detecciones':     db.eventos_beacon.count_documents({'detectado': True}),
            'total_logs':            db.logs_sistema.count_documents({}),
            'total_errores':         db.logs_sistema.count_documents({'nivel': 'ERROR'}),
        }
    except Exception as e:
        print(f"[MongoDB] Error resumen_mongo: {e}")
        return {}
