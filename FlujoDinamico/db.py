"""
db.py — psycopg v3.
En PostgreSQL 18 los CALL requieren pasar NULL por cada parámetro OUT.
Usamos interpolación literal para evitar el problema de tipos unknown.
"""

import psycopg
import psycopg.rows
from flask import g, current_app


def get_db():
    if 'db' not in g:
        g.db = psycopg.connect(
            host=current_app.config['DB_HOST'],
            port=current_app.config['DB_PORT'],
            dbname=current_app.config['DB_NAME'],
            user=current_app.config['DB_USER'],
            password=current_app.config['DB_PASSWORD'],
            row_factory=psycopg.rows.dict_row,
        )
        g.db.autocommit = False
    return g.db


def close_db(e=None):
    db = g.pop('db', None)
    if db is not None:
        db.close()


def query(sql, params=None, fetchone=False, commit=False):
    """Ejecuta SQL directo — para SELECTs sobre views."""
    conn = get_db()
    with conn.cursor() as cur:
        cur.execute(sql, params)
        if commit:
            conn.commit()
            return cur.rowcount
        if fetchone:
            return cur.fetchone()
        return cur.fetchall()


def _lit(v):
    """Convierte valor Python a literal SQL seguro."""
    if v is None:
        return 'NULL'
    if isinstance(v, bool):
        return 'TRUE' if v else 'FALSE'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(v)
    escaped = str(v).replace("'", "''")
    return f"'{escaped}'"


# Mapa de SPs con sus parámetros OUT para agregar NULL al final
# Formato: 'nombre_sp': numero_de_out_params
_SP_OUT_PARAMS = {
    'sp_login':                      3,  # p_password_hash, p_rol, p_resultado
    'sp_login_usuario':              3,
    'sp_insertar_expediente':        3,
    'sp_insertar_paciente':          2,  # p_resultado, p_id_paciente
    'sp_actualizar_paciente':        1,
    'sp_eliminar_paciente':          1,
    'sp_obtener_pacientes':          1,
    'sp_insertar_medico':            1,
    'sp_actualizar_medico':          1,
    'sp_eliminar_medico':            1,
    'sp_obtener_medicos':            1,
    'sp_insertar_area':              1,
    'sp_actualizar_area':            1,
    'sp_eliminar_area':              1,
    'sp_obtener_areas':              1,
    'sp_insertar_beacon':            1,
    'sp_actualizar_beacon':          1,
    'sp_eliminar_beacon':            1,
    'sp_obtener_beacons':            1,
    'sp_obtener_beacon':             1,
    'sp_actualizar_estado_beacon':   1,
    'sp_insertar_ingreso':           2,  # p_id_ingreso, p_resultado
    'sp_dar_alta_ingreso':           1,
    'sp_obtener_ingresos':           1,
    'sp_registrar_nfc':              7,  # p_id_paciente, p_nombre, p_foto, p_num_expediente, p_id_expediente, p_medico_titular, p_resultado
    'sp_insertar_usuario':           1,
    'sp_toggle_usuario':             2,  # p_activo, p_resultado
    'sp_eliminar_usuario':           1,
    'sp_obtener_usuarios':           1,
    'sp_insertar_tarjeta_nfc':       1,
    'sp_eliminar_tarjeta_nfc':       1,
    'sp_resolver_alerta':            1,
    'sp_abrir_estancia':             1,
    'sp_cerrar_estancia':            1,
    'sp_registrar_evento':           1,
    'sp_obtener_area_de_beacon':     2,  # p_id_area, p_resultado
    'sp_obtener_especialidades':     1,
    'sp_obtener_tipos_area':         1,
    'sp_obtener_pisos':              1,
    'sp_obtener_roles':              1,
    'sp_obtener_modelos_beacon':     1,
    'sp_obtener_areas_lista':        1,
    'sp_obtener_medicos_activos':    1,
    'sp_obtener_expediente_detalle': 1,
    'sp_obtener_ingresos_expediente':1,
    'sp_obtener_triajes_expediente': 1,
    'sp_obtener_alergias_expediente':1,
    'sp_obtener_consultorios':       1,
    'sp_obtener_ingreso_detalle':    1,
    'sp_obtener_timeline_ingreso':   1,
    'sp_obtener_estancias_ingreso':  1,
    'sp_obtener_pacientes_lista':    1,
    'sp_obtener_medico':             1,
    'sp_obtener_triajes':            1,
    'sp_verificar_ingreso_activo':   2,  # p_id_ingreso, p_resultado
}


def call_sp(nombre, params=()):
    """
    Llama un SP con interpolación literal + NULLs para parámetros OUT.
    En PostgreSQL 18 CALL requiere pasar NULL por cada OUT param.
    """
    conn = get_db()
    n_out = _SP_OUT_PARAMS.get(nombre, 1)
    literales = [_lit(v) for v in params] + ['NULL'] * n_out
    sql = f"CALL {nombre}({','.join(literales)})"
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            conn.commit()
            try:
                row = cur.fetchone()
                return dict(row) if row else {}
            except Exception:
                return {}
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        raise e


def call_sp_cursor(nombre, params=()):
    """
    Llama un SP que abre un REFCURSOR + NULL para el OUT param.
    """
    conn = get_db()
    # Los SPs de cursor tienen siempre 1 OUT param (el refcursor)
    literales = [_lit(v) for v in params] + ['NULL']
    sql = f"CALL {nombre}({','.join(literales)})"
    try:
        with conn.cursor() as cur:
            cur.execute("BEGIN")
            cur.execute(sql)
            row = cur.fetchone()
            if not row:
                cur.execute("ROLLBACK")
                return []
            vals = list(row.values()) if isinstance(row, dict) else list(row)
            cursor_name = vals[0]
            if not cursor_name:
                cur.execute("ROLLBACK")
                return []
            cur.execute(f'FETCH ALL FROM "{cursor_name}"')
            rows = cur.fetchall() or []
            cur.execute("COMMIT")
            return [dict(r) for r in rows]
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        raise e