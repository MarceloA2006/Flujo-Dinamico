# BeaconFlow — Sistema Hospitalario IoT

## Descripción General

BeaconFlow es un sistema de monitoreo hospitalario en tiempo real que integra hardware IoT con una aplicación web desarrollada en Flask. Permite registrar automáticamente la entrada y salida de pacientes mediante tecnología NFC, detectar la presencia de médicos en consultorios mediante beacons BLE, y visualizar toda la información en dashboards dinámicos con actualización automática.

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                         HARDWARE IoT                            │
│                                                                 │
│   PN532 (NFC) ──► ESP32 ◄── Beacon BLE (Feasycom FSC-BP104D)   │
│                    │                                            │
│              WiFi 2.4 GHz                                       │
└────────────────────┼────────────────────────────────────────────┘
                     │ HTTP POST (JSON)
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND — Flask 2.3.3                      │
│                                                                 │
│   /iot/nfc ──► procesar UID ──► sp_registrar_nfc               │
│   /iot/beacon ──► actualizar estado ──► sp_actualizar_beacon    │
│   /iot/estado ──► polling JS ◄── vw_sala_espera                │
└───────────┬─────────────────────────────┬───────────────────────┘
            │                             │
            ▼                             ▼
┌───────────────────────┐   ┌─────────────────────────────┐
│  PostgreSQL 18         │   │  MongoDB (hospital_beaconflow)│
│  Base: hospital_iot    │   │                             │
│  ≥15 Stored Procedures │   │  eventos_nfc                │
│  ≥10 Views             │   │  eventos_beacon             │
│  ≥10 Triggers          │   │  logs_sistema               │
└───────────────────────┘   └─────────────────────────────┘
            │                             │
            └─────────────┬───────────────┘
                          ▼
            ┌─────────────────────────┐
            │   Dashboards — Jinja2   │
            │   + Polling JS (3-5s)   │
            │   + Highcharts          │
            └─────────────────────────┘
```

---

## Stack Tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| Backend | Flask | 2.3.3 |
| Base de datos relacional | PostgreSQL | 18.1 |
| Base de datos documental | MongoDB | 7.x |
| Conector PostgreSQL | psycopg3 (psycopg[binary]) | 3.1.18 |
| Conector MongoDB | pymongo | 4.x |
| Microcontrolador | ESP32 (Espressif) | Board 2.0.11 |
| Lector NFC | PN532 | I²C mode |
| Beacon BLE | Feasycom FSC-BP104D | iBeacon |
| Biblioteca BLE Arduino | NimBLE-Arduino | 1.4.2 |
| Gráficas | Highcharts | CDN |
| Templates | Jinja2 | 3.x |

---

## Integración PostgreSQL — Flask

### Conexión y gestión de la sesión (`db.py`)

Flask se conecta a PostgreSQL usando **psycopg3** con una conexión por request almacenada en el contexto de Flask (`g`):

```python
def get_db():
    if 'db' not in g:
        g.db = psycopg.connect(
            host='localhost', port=5432,
            dbname='hospital_iot',
            user='hospital_admin', password='...',
            row_factory=psycopg.rows.dict_row,  # devuelve dicts en lugar de tuplas
        )
        g.db.autocommit = False
    return g.db
```

El parámetro `row_factory=dict_row` hace que cada fila de resultado sea un diccionario Python, lo que permite acceder a los campos por nombre en los templates Jinja2.

### Cómo se llaman los Stored Procedures

psycopg3 presenta un problema con PostgreSQL 18: infiere los tipos de los parámetros como `unknown`, lo que impide que el motor de base de datos resuelva qué SP invocar. La solución implementada es **interpolar los valores directamente en el SQL** como literales, más pasar `NULL` por cada parámetro `OUT` explícitamente:

```python
def _lit(v):
    """Convierte valor Python → literal SQL seguro."""
    if v is None:         return 'NULL'
    if isinstance(v, bool): return 'TRUE' if v else 'FALSE'
    if isinstance(v, int):  return str(v)
    escaped = str(v).replace("'", "''")  # escape de comillas simples
    return f"'{escaped}'"

def call_sp(nombre, params=()):
    n_out = _SP_OUT_PARAMS.get(nombre, 1)  # cuántos OUT params tiene el SP
    literales = [_lit(v) for v in params] + ['NULL'] * n_out
    sql = f"CALL {nombre}({','.join(literales)})"
    cur.execute(sql)
    row = cur.fetchone()  # los OUT params regresan como columnas
    return dict(row)
```

Los SPs que devuelven conjuntos de filas usan **REFCURSOR** — se llaman dentro de una transacción explícita `BEGIN/COMMIT` porque los cursores de PostgreSQL solo existen durante una transacción activa:

```python
def call_sp_cursor(nombre, params=()):
    cur.execute("BEGIN")
    cur.execute(sql, valores)
    row = cur.fetchone()
    cursor_name = row['p_cursor']   # nombre del cursor abierto
    cur.execute(f'FETCH ALL FROM "{cursor_name}"')
    rows = cur.fetchall()
    cur.execute("COMMIT")
    return [dict(r) for r in rows]
```

### Cómo cada sección de la página usa PostgreSQL

| Sección | Mecanismo | SP / View |
|---|---|---|
| Dashboard — KPIs superiores | `query("SELECT * FROM vw_dashboard_kpis")` | `vw_dashboard_kpis` |
| Dashboard — Sala de espera | `query("SELECT * FROM vw_sala_espera")` | `vw_sala_espera` |
| Dashboard — Ocupación áreas | `query("SELECT * FROM vw_ocupacion_areas")` | `vw_ocupacion_areas` |
| Pacientes — listado | `query("SELECT * FROM vw_pacientes")` | `vw_pacientes` |
| Pacientes — CRUD | `call_sp('sp_insertar_paciente', ...)` | `sp_insertar_paciente` |
| Expedientes — detalle | `call_sp_cursor('sp_obtener_expediente_detalle', (id,))` | `sp_obtener_expediente_detalle` |
| Ingresos — listado | `query("SELECT * FROM vw_ingresos_activos")` | `vw_ingresos_activos` |
| Triajes | `call_sp_cursor('sp_obtener_triajes')` | `sp_obtener_triajes` |
| Médicos | `call_sp_cursor('sp_obtener_medicos')` | `sp_obtener_medicos` |
| Beacons | `call_sp_cursor('sp_obtener_beacons')` | `sp_obtener_beacons` |
| KPIs — 15 indicadores | `query("SELECT * FROM vw_kpi_*")` | 15 views `vw_kpi_*` |
| NFC — registro entrada/salida | `call_sp('sp_registrar_nfc', (uid,))` | `sp_registrar_nfc` |
| Beacon — actualizar estado | `call_sp('sp_actualizar_estado_beacon', ...)` | `sp_actualizar_estado_beacon` |
| Logs — bitácora | `query("SELECT * FROM vw_logs")` | `vw_logs` |

---

## Stored Procedures — Implementación

Los SPs encapsulan toda la lógica de negocio en la base de datos, garantizando integridad y separando responsabilidades. Todos usan parámetros `IN` para entrada y `OUT` para devolver resultados:

### Estructura típica de un SP de inserción

```sql
CREATE OR REPLACE PROCEDURE public.sp_insertar_paciente(
    IN  p_nombre      VARCHAR, IN  p_apellidop  VARCHAR,
    IN  p_apellidom   VARCHAR, IN  p_telefono   VARCHAR,
    IN  p_email       VARCHAR, IN  p_curp       VARCHAR,
    IN  p_fecha_nac   DATE,    IN  p_sexo       CHAR(1),
    IN  p_tipo_sangre VARCHAR, IN  p_foto       TEXT,
    OUT p_resultado   TEXT,    OUT p_id_paciente INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO pacientes(nombre, apellidop, ...)
    VALUES(p_nombre, p_apellidop, ...)
    RETURNING id_paciente INTO p_id_paciente;
    p_resultado := 'OK';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;
```

### SP crítico — `sp_registrar_nfc`

Este SP es el núcleo del sistema IoT. Recibe el UID de la tarjeta NFC y devuelve todos los datos del paciente asociado:

```sql
CREATE OR REPLACE PROCEDURE public.sp_registrar_nfc(
    IN  p_uid_hex        VARCHAR,
    OUT p_id_paciente    INTEGER,
    OUT p_nombre         TEXT,
    OUT p_foto           TEXT,
    OUT p_num_expediente VARCHAR,
    OUT p_id_expediente  INTEGER,
    OUT p_medico_titular VARCHAR,
    OUT p_resultado      TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT p.id_paciente, p.nombre||' '||p.apellidop,
           p.foto, e.num_expediente, e.id_expediente, e.cedula_medico_titular
    INTO p_id_paciente, p_nombre, p_foto, p_num_expediente,
         p_id_expediente, p_medico_titular
    FROM tarjetas_nfc t
    JOIN pacientes p   ON p.id_paciente = t.id_paciente
    JOIN expedientes e ON e.id_paciente = p.id_paciente AND e.activo = TRUE
    WHERE t.uid_hex = p_uid_hex;

    IF NOT FOUND THEN
        p_resultado := 'Error: UID no registrado en tarjetas_nfc.';
    ELSE
        p_resultado := 'OK';
    END IF;
END;
$$;
```

---

## Views — Implementación

Las vistas encapsulan queries complejos y son la única fuente de datos para reportes. Está **prohibido** usar queries directos para reportes.

### `vw_sala_espera`

Muestra únicamente los pacientes con estado `EN_ESPERA`, calculando el tiempo de espera en minutos en tiempo real:

```sql
CREATE OR REPLACE VIEW public.vw_sala_espera AS
SELECT p.id_paciente,
       p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS nombre_completo,
       COALESCE(p.foto, 'https://ui-avatars.com/api/?name='||p.nombre) AS foto,
       e.num_expediente,
       i.id_ingreso,
       TO_CHAR(i.fecha_ingreso,'HH24:MI') AS hora_ingreso,
       ROUND(EXTRACT(EPOCH FROM (NOW()-i.fecha_ingreso))/60)::INTEGER AS min_espera
FROM   ingresos i
JOIN   expedientes e ON e.id_expediente = i.id_expediente
JOIN   pacientes   p ON p.id_paciente   = e.id_paciente
WHERE  i.estado::text = 'EN_ESPERA'::text
ORDER  BY i.fecha_ingreso;
```

El campo `min_espera` se recalcula en cada consulta usando `NOW()`, por lo que siempre refleja el tiempo actual sin necesidad de actualizaciones.

### `vw_ingresos_activos`

Combina ingresos con datos de paciente, médico y área para la tabla de ingresos:

```sql
CREATE OR REPLACE VIEW public.vw_ingresos_activos AS
SELECT i.id_ingreso,
       p.nombre||' '||p.apellidop AS paciente,
       e.num_expediente AS expediente,
       COALESCE(p.foto,'https://ui-avatars.com/...') AS foto,
       i.tipo_ingreso, i.motivo_ingreso, i.estado,
       i.tiempo_espera_min, i.cedula_medico,
       m.nombre||' '||m.apellidop AS medico,
       a.nombre_area AS area_actual,
       ROUND(EXTRACT(EPOCH FROM (NOW()-i.fecha_ingreso))/60)::INTEGER AS min_desde_ingreso,
       TO_CHAR(i.fecha_ingreso,'YYYY-MM-DD HH24:MI') AS fecha_ingreso,
       i.id_expediente
FROM ingresos i
JOIN expedientes e ON e.id_expediente = i.id_expediente
JOIN pacientes   p ON p.id_paciente   = e.id_paciente
LEFT JOIN medicos m ON m.cedula_medico = i.cedula_medico
LEFT JOIN areas   a ON a.id_area = i.id_area_actual;
```

---

## Triggers — Implementación

Los triggers implementan lógica automática que se ejecuta en la base de datos sin intervención de Flask.

### Trigger de auditoría (`trg_log_pacientes`)

Se ejecuta automáticamente después de cada INSERT, UPDATE o DELETE en la tabla `pacientes` y registra la acción en `log_acceso`:

```sql
CREATE OR REPLACE FUNCTION public.fn_log_pacientes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT id_usuario, 'DELETE', 'pacientes',
               OLD.id_paciente, NOW(),
               'Eliminación: '||OLD.nombre||' '||OLD.apellidop
        FROM usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN COALESCE(NEW, OLD);
END; $$;

CREATE TRIGGER trg_log_pacientes
AFTER INSERT OR UPDATE OR DELETE ON pacientes
FOR EACH ROW EXECUTE FUNCTION fn_log_pacientes();
```

### Trigger de validación clínica (`trg_validar_triaje`)

Impide registrar un triaje ROJO sin los signos vitales obligatorios:

```sql
CREATE OR REPLACE FUNCTION public.fn_validar_triaje()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.nivel_triaje = 'ROJO' THEN
        IF NEW.frecuencia_cardiaca IS NULL OR
           NEW.presion_sistolica   IS NULL OR
           NEW.saturacion_o2       IS NULL THEN
            RAISE EXCEPTION 'Triaje ROJO requiere signos vitales completos';
        END IF;
    END IF;
    IF NEW.glasgow IS NOT NULL AND (NEW.glasgow < 3 OR NEW.glasgow > 15) THEN
        RAISE EXCEPTION 'Glasgow debe estar entre 3 y 15';
    END IF;
    RETURN NEW;
END; $$;

CREATE TRIGGER trg_validar_triaje
BEFORE INSERT OR UPDATE ON triajes
FOR EACH ROW EXECUTE FUNCTION fn_validar_triaje();
```

### Trigger de integridad (`trg_validar_ingreso_unico`)

Impide que un mismo expediente tenga dos ingresos `EN_ESPERA` simultáneos:

```sql
CREATE OR REPLACE FUNCTION public.fn_validar_ingreso_unico()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_count INTEGER;
BEGIN
    IF NEW.estado = 'EN_ESPERA' THEN
        SELECT COUNT(*) INTO v_count
        FROM ingresos
        WHERE id_expediente = NEW.id_expediente
          AND estado = 'EN_ESPERA'
          AND id_ingreso != COALESCE(NEW.id_ingreso, -1);
        IF v_count > 0 THEN
            RAISE EXCEPTION 'El expediente ya tiene un ingreso EN_ESPERA activo';
        END IF;
    END IF;
    RETURN NEW;
END; $$;
```

---

## Integración MongoDB — Flask

### Conexión (`mongo_db.py`)

MongoDB se conecta mediante **pymongo** usando un singleton para reutilizar la conexión. La base de datos `hospital_beaconflow` y sus colecciones se crean automáticamente la primera vez que se inserta un documento:

```python
from pymongo import MongoClient, DESCENDING

MONGO_URI = 'mongodb://localhost:27017/'
MONGO_DB  = 'hospital_beaconflow'

_client = None
_db     = None

def get_mongo():
    global _client, _db
    if _db is None:
        _client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=3000)
        _db     = _client[MONGO_DB]
        _crear_indices()   # índices para optimizar queries
    return _db
```

### Las tres colecciones y su relación con PostgreSQL

La integración entre PostgreSQL y MongoDB se implementa mediante **IDs compartidos**. Cada documento en MongoDB incluye los IDs de sus entidades relacionadas en PostgreSQL, haciendo posible que Flask enriquezca los datos de ambas fuentes:

#### `eventos_nfc`

```python
{
    'uid_hex':         '31B91507',
    'id_paciente':     21,        # → pacientes.id_paciente  (PostgreSQL)
    'nombre_paciente': 'Marcelo Avila Garza',
    'num_expediente':  'EXP-021',
    'id_expediente':   11,        # → expedientes.id_expediente (PostgreSQL)
    'id_ingreso':      8,         # → ingresos.id_ingreso  (PostgreSQL)
    'accion':          'ENTRADA', # 'ENTRADA' | 'SALIDA'
    'timestamp':       ISODate("2026-04-30T23:53:04Z"),
    'hora_local':      '18:53:04',
    'fecha_local':     '2026-04-30'
}
```

#### `eventos_beacon`

```python
{
    'id_beacon':   'BCN-01',  # → beacons.id_beacon (PostgreSQL)
    'detectado':   True,
    'rssi':        -56,
    'timestamp':   ISODate("..."),
    'hora_local':  '18:53:09',
    'fecha_local': '2026-04-30'
}
```

#### `logs_sistema`

```python
{
    'nivel':      'INFO',         # 'INFO' | 'WARNING' | 'ERROR'
    'modulo':     'auth',
    'mensaje':    'Login exitoso: admin — rol ADMIN',
    'id_usuario': 1,              # → usuarios.id_usuario (PostgreSQL)
    'detalle':    None,
    'timestamp':  ISODate("..."),
    'fecha_local': '2026-04-30'
}
```

### Cómo se insertan los datos en MongoDB

Los datos se registran automáticamente en tres puntos del flujo IoT dentro de `app.py`:

**1. Al recibir un POST de beacon:**
```python
@app.route('/iot/beacon', methods=['POST'])
def iot_beacon():
    # ... actualizar estado en PostgreSQL ...
    registrar_evento_beacon(id_beacon, detectado, rssi)  # → MongoDB
```

**2. Al registrar una ENTRADA NFC:**
```python
_sala_espera.append(pac)
registrar_evento_nfc(uid_hex, id_paciente, nombre, expediente,
                     'ENTRADA', id_ingreso, id_expediente)  # → MongoDB
```

**3. Al registrar acciones del sistema (login, errores, eliminaciones):**
```python
registrar_log('INFO',    'auth',  f'Login exitoso: {username}')
registrar_log('WARNING', 'admin', f'Eliminación paciente ID {id}')
registrar_log('ERROR',   'iot_nfc', f'UID no registrado: {uid_hex}')
```

---

## Aggregation Pipeline — KPIs desde MongoDB

Los datos de MongoDB para las gráficas Highcharts se obtienen mediante el **aggregation pipeline**, que procesa documentos en etapas encadenadas:

### Entradas NFC por día

```python
def kpi_entradas_por_dia(dias=7):
    pipeline = [
        {'$match': {'accion': 'ENTRADA'}},          # filtrar solo entradas
        {'$group': {
            '_id':   '$fecha_local',                 # agrupar por día
            'total': {'$sum': 1}                     # contar documentos
        }},
        {'$sort':  {'_id': 1}},                      # ordenar cronológicamente
        {'$limit': dias}                             # últimos N días
    ]
    return list(db.eventos_nfc.aggregate(pipeline))
```

### RSSI promedio por hora

```python
def kpi_rssi_promedio_por_hora():
    pipeline = [
        {'$match': {'detectado': True, 'rssi': {'$ne': None}}},
        {'$group': {
            '_id':         '$hora_local',            # agrupar por hora
            'rssi_prom':   {'$avg': '$rssi'},        # promedio RSSI
            'detecciones': {'$sum': 1}
        }},
        {'$sort': {'_id': 1}}
    ]
    return list(db.eventos_beacon.aggregate(pipeline))
```

---

## Cómo se generan las Gráficas Highcharts

El flujo tiene dos partes: Flask sirve los datos como JSON y el JavaScript del template los consume para renderizar las gráficas.

### Endpoint de datos (`/admin/graficas/datos`)

```python
@app.route('/admin/graficas/datos')
def graficas_datos():
    entradas_dia = kpi_entradas_por_dia(dias=7)    # MongoDB
    rssi_hora    = kpi_rssi_promedio_por_hora()    # MongoDB
    beacon_dia   = kpi_detecciones_por_dia(dias=7) # MongoDB
    return jsonify({
        'entradas_por_dia': [{'fecha': d['_id'], 'total': d['total']}
                             for d in entradas_dia],
        'rssi_por_hora':    [{'hora': d['_id'],
                              'rssi_prom': round(d['rssi_prom'], 1),
                              'detecciones': d['detecciones']}
                             for d in rssi_hora],
    })
```

### Consumo en el template

```javascript
fetch('/admin/graficas/datos')
  .then(r => r.json())
  .then(data => {
    // Gráfica 1: Línea de series — actividad IoT por día
    Highcharts.chart('chart-linea', {
      series: [{
        name: 'Registros NFC',
        data: data.entradas_por_dia.map(d => d.total)
      }, {
        name: 'Detecciones Beacon',
        data: data.beacon_por_dia.map(d => d.total)
      }]
    });

    // Gráfica 2: Pie — distribución de eventos NFC
    Highcharts.chart('chart-pie', {
      series: [{ data: [
        { name: 'Entradas', y: totalEntradas },
        { name: 'Salidas',  y: totalSalidas  }
      ]}]
    });

    // Gráfica 3: Barras — RSSI por hora del día
    Highcharts.chart('chart-barras', {
      series: [{
        data: data.rssi_por_hora.map(d => Math.abs(d.rssi_prom))
      }]
    });
  });
```

---

## KPIs desde PostgreSQL

Los 15 KPIs se calculan en tiempo real mediante views de PostgreSQL. Flask hace una query directa a cada view y pasa el resultado al template:

```python
@app.route('/admin/kpis')
def admin_kpis():
    def sq(sql):
        try: return query(sql, fetchone=True) or {}
        except: return {}
    def sqa(sql):
        try: return query(sql) or []
        except: return []

    return render_template('admin/kpis.html',
        kpi_ejecutivo = sq("SELECT * FROM vw_kpi_resumen_ejecutivo"),
        t_espera      = sq("SELECT * FROM vw_kpi_tiempo_espera_promedio"),
        ing_diario    = sq("SELECT * FROM vw_kpi_ingresos_diario"),
        productividad = sqa("SELECT * FROM vw_kpi_productividad_medico"),
        # ... 11 KPIs más
    )
```

Cada view encapsula la fórmula de cálculo. Ejemplo de KPI 1 — tiempo de espera:

```sql
CREATE OR REPLACE VIEW public.vw_kpi_tiempo_espera_promedio AS
SELECT
    ROUND(AVG(tiempo_espera_min)::NUMERIC, 1) AS tiempo_espera_prom_min,
    MIN(tiempo_espera_min)                     AS tiempo_minimo_min,
    MAX(tiempo_espera_min)                     AS tiempo_maximo_min,
    COUNT(*)                                   AS total_ingresos_medidos
FROM ingresos
WHERE estado = 'ALTA'
  AND tiempo_espera_min IS NOT NULL;
```

---

## Flujo completo del ESP32 hacia la página

### 1. Hardware — detección

**NFC:** El PN532 conectado por I²C (SDA=GPIO21, SCL=GPIO22) escucha continuamente con un timeout de 100ms. Cuando detecta una tarjeta, lee su UID de 4 bytes y lo convierte a hexadecimal en mayúsculas (`31B91507`).

**BLE:** NimBLE escanea durante 1 segundo cada 5 segundos buscando el beacon por tres métodos en orden: MAC address exacta, nombre del dispositivo, o UUID iBeacon en los Manufacturer Data.

### 2. ESP32 — transmisión HTTP

```cpp
// NFC → Flask
StaticJsonDocument<48> doc;
doc["uid"] = "31B91507";
// POST http://192.168.x.x:5001/iot/nfc

// BLE → Flask
StaticJsonDocument<96> doc;
doc["id_beacon"] = "BCN-01";
doc["detectado"] = true;
doc["rssi"]      = -56;
// POST http://192.168.x.x:5001/iot/beacon
```

### 3. Flask — procesamiento del NFC (`/iot/nfc`)

```
POST /iot/nfc  { "uid": "31B91507" }
        │
        ▼
call_sp('sp_registrar_nfc', ('31B91507',))
        │
        ▼
PostgreSQL busca en tarjetas_nfc → pacientes → expedientes
        │
        ├─► ¿Tiene ingreso EN_ESPERA? (sp_verificar_ingreso_activo)
        │
        ├── NO → ENTRADA:
        │         sp_insertar_ingreso()      → crea ingreso EN_ESPERA
        │         sp_abrir_estancia()        → registra área actual
        │         sp_registrar_evento()      → log en PostgreSQL
        │         _sala_espera.append(pac)   → actualiza memoria Flask
        │         registrar_evento_nfc()     → inserta en MongoDB
        │
        └── SÍ → SALIDA:
                  sp_dar_alta_ingreso()      → cambia estado a ALTA
                  sp_cerrar_estancia()       → registra salida del área
                  sp_registrar_evento()      → log en PostgreSQL
                  _sala_espera.remove(pac)   → actualiza memoria Flask
                  registrar_evento_nfc()     → inserta en MongoDB
```

### 4. Flask — procesamiento del Beacon (`/iot/beacon`)

```
POST /iot/beacon  { "id_beacon": "BCN-01", "detectado": true, "rssi": -56 }
        │
        ▼
_beacon_estado = { detectado: True, rssi: -56, ... }  → memoria Flask
        │
        ▼
call_sp('sp_actualizar_estado_beacon', ('BCN-01', 'ACTIVO'))  → PostgreSQL
        │
        ▼
registrar_evento_beacon('BCN-01', True, -56)  → MongoDB
```

### 5. Dashboard — actualización en tiempo real (Polling)

El JavaScript del dashboard hace un GET a `/iot/estado` cada 3 segundos:

```javascript
setInterval(() => {
  fetch('/iot/estado')
    .then(r => r.json())
    .then(data => {
      // data.beacon.detectado  → actualiza dot verde/gris del beacon
      // data.sala_espera       → reconstruye lista de pacientes en espera
      // data.contador_espera   → actualiza el contador del badge
    });
}, 3000);
```

El endpoint `/iot/estado` consulta la vista `vw_sala_espera` de PostgreSQL en cada llamada:

```python
@app.route('/iot/estado')
def iot_estado():
    sala = query("SELECT * FROM vw_sala_espera") or []
    return jsonify({
        'beacon':          _beacon_estado,        # de memoria Flask
        'sala_espera':     [dict(r) for r in sala], # de PostgreSQL
        'contador_espera': len(sala)
    })
```

---

## Resumen del flujo de datos completo

```
Tarjeta NFC acercada al PN532
    │
    ▼
ESP32 lee UID (31B91507) → POST /iot/nfc
    │
    ▼
Flask → sp_registrar_nfc → PostgreSQL identifica paciente
    │
    ├─► sp_insertar_ingreso → tabla ingresos (EN_ESPERA)
    ├─► registrar_evento_nfc → MongoDB eventos_nfc
    └─► _sala_espera en memoria actualizada
    │
    ▼
Dashboard JS polling /iot/estado cada 3s
    │
    ▼
Flask → SELECT * FROM vw_sala_espera → PostgreSQL
    │
    ▼
JSON → JavaScript reconstruye la lista de pacientes en pantalla
    │
    ▼
Paciente visible en sala de espera en tiempo real
```

```
Beacon BLE transmite cada 300ms
    │
ESP32 escanea cada 5s → detecta MAC dc:0d:30:48:30:ec
    │
    ▼
POST /iot/beacon { detectado: true, rssi: -56 }
    │
    ▼
Flask → sp_actualizar_estado_beacon → PostgreSQL (estado=ACTIVO)
    ├─► _beacon_estado en memoria actualizado
    └─► registrar_evento_beacon → MongoDB eventos_beacon
    │
    ▼
Dashboard JS polling /iot/estado cada 3s
    │
    ▼
dot del beacon cambia de gris a verde animado en pantalla
```

---

## Exportación de colecciones MongoDB

Para evidencia de entrega, exportar las colecciones en formato JSON:

```bash
mongoexport --db hospital_beaconflow --collection eventos_nfc    --out eventos_nfc.json
mongoexport --db hospital_beaconflow --collection eventos_beacon --out eventos_beacon.json
mongoexport --db hospital_beaconflow --collection logs_sistema   --out logs_sistema.json
```

---

## Configuración del sistema

### Variables de conexión (`app.py`)

```python
app.config.update(
    DB_HOST     = 'localhost',
    DB_PORT     = 5432,
    DB_NAME     = 'hospital_iot',
    DB_USER     = 'hospital_admin',
    DB_PASSWORD = '...',
)
```

### Variables de conexión ESP32 (`hospital_esp32_final.ino`)

```cpp
#define WIFI_SSID      "nombre_red"
#define WIFI_PASSWORD  "contraseña"
#define FLASK_IP       "IP_del_servidor"
#define FLASK_PORT     5001
#define BEACON_MAC     "dc:0d:30:48:30:ec"
#define BEACON_UUID    "FDA50693A4E24FB1AFCFC6EB07647825"
#define BEACON_MAJOR   10065
#define BEACON_MINOR   26049
```

### Iniciar el sistema

```bash
# 1. PostgreSQL (ya corre como servicio)
# 2. MongoDB
brew services start mongodb-community

# 3. Flask
cd FlujoDinamico
python3 app.py
# Disponible en http://localhost:5001
```
