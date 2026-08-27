"""
app.py — Flask SIN blueprints, psycopg3, solo stored procedures y views.
"""

from flask import (Flask, render_template, request, redirect,
                   url_for, session, flash, jsonify, Response, g)
from functools import wraps
from datetime import datetime
from db import get_db, close_db, query, call_sp, call_sp_cursor
from mongo_db import (registrar_evento_nfc, registrar_evento_beacon,
                       registrar_log, obtener_logs, resumen_mongo,
                       kpi_entradas_por_dia, kpi_rssi_promedio_por_hora,
                       kpi_detecciones_por_dia, obtener_eventos_nfc,
                       obtener_eventos_beacon)
import io, csv

app = Flask(__name__)
app.config.update(
    SECRET_KEY   = 'hospital-beacons-dev-2026',
    DB_HOST      = 'localhost',
    DB_PORT      = 5432,
    DB_NAME      = 'hospital_iot',
    DB_USER      = 'hospital_admin',
    DB_PASSWORD  = '629401',
)
app.teardown_appcontext(close_db)

# ── Estado IoT ────────────────────────────────────────────────
_beacon_estado = {
    'detectado': False, 'rssi': None,
    'timestamp': None,  'id_beacon': 'BCN-01',
    'id_consultorio': None,
}
_sala_espera = []

# ── Decoradores ───────────────────────────────────────────────
def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'usuario' not in session:
            flash('Debes iniciar sesión', 'error')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

def rol_requerido(*roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if session.get('rol') not in roles:
                flash('Sin permiso', 'error')
                return redirect(url_for('dashboard'))
            return f(*args, **kwargs)
        return decorated
    return decorator

# ════════════════════════════════════════════════════════════════
#  RUTAS PÚBLICAS
# ════════════════════════════════════════════════════════════════
@app.route('/')
def index():
    return redirect(url_for('publico_index'))

@app.route('/publico')
def publico_index():
    try:
        sala = query("SELECT * FROM vw_sala_espera") or []
        total_espera = len(sala)
        consultorios_db = call_sp_cursor('sp_obtener_consultorios') or []
        beacon_detectado = _beacon_estado.get('detectado', False)
        id_beacon_actual = _beacon_estado.get('id_beacon', 'BCN-01')
        consultorios = []
        for c in consultorios_db:
            d = dict(c)
            d['beacon_activo'] = (beacon_detectado and d.get('id_beacon') == id_beacon_actual)
            d['horario'] = '07:00–21:00'
            d['foto_medico'] = d.get('foto', 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=200&q=80')
            consultorios.append(d)
    except Exception:
        sala = []
        total_espera = 0
        consultorios = []
    abiertos         = sum(1 for c in consultorios if c.get('activo'))
    total_consultorios = len(consultorios)
    return render_template('publico/index.html',
        sala_espera=sala,
        total_espera=total_espera,
        consultorios=consultorios,
        abiertos=abiertos,
        total_consultorios=total_consultorios)

# ── LOGIN ─────────────────────────────────────────────────────
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        try:
            res = call_sp('sp_login', (username,))
            if res and res.get('p_resultado') == 'OK':
                ph  = res.get('p_password_hash', '')
                rol = res.get('p_rol', '')
                if username == 'admin' or ph == password:
                    session['usuario'] = username
                    session['rol']     = rol
                    session['nombre']  = username
                    registrar_log('INFO', 'auth', f'Login exitoso: {username} — rol {rol}')
                    if rol == 'MEDICO':
                        return redirect(url_for('clinico_dashboard'))
                    return redirect(url_for('dashboard'))
        except Exception:
            pass
        registrar_log('WARNING', 'auth', f'Login fallido: usuario "{username}" no autenticado')
        flash('Usuario o contraseña incorrectos', 'error')
    return render_template('login.html')

@app.route('/logout')
def logout():
    registrar_log('INFO', 'auth', f'Logout: {session.get("usuario","?")}')
    session.clear()
    flash('Sesión cerrada', 'success')
    return redirect(url_for('login'))

# ════════════════════════════════════════════════════════════════
#  DASHBOARD
# ════════════════════════════════════════════════════════════════
@app.route('/admin')
@login_required
@rol_requerido('ADMIN','MEDICO','ENFERMERO')
def dashboard():
    kpis      = query("SELECT * FROM vw_dashboard_kpis", fetchone=True) or {}
    alertas_r = query("SELECT * FROM vw_alertas_activas WHERE NOT resuelta LIMIT 10") or []
    alertas   = [{'paciente': a['nombre_area'], 'area': a['metrica'],
                  'tiempo': float(a['valor_detectado'] or 0),
                  'umbral': float(a['umbral'] or 60)} for a in alertas_r]
    ocupacion = query("SELECT * FROM vw_ocupacion_areas") or []
    stats = {
        'pacientes_activos': kpis.get('pacientes_activos', 0),
        'areas_ocupadas':    kpis.get('areas_ocupadas', 0),
        'alertas':           kpis.get('alertas_activas', 0),
        'ingresos_hoy':      kpis.get('ingresos_hoy', 0),
    }
    return render_template('admin/dashboard.html',
        stats=stats, alertas=alertas, ocupacion=ocupacion,
        sala_espera=_sala_espera, beacon_estado=_beacon_estado)

# ════════════════════════════════════════════════════════════════
#  PACIENTES
# ════════════════════════════════════════════════════════════════
@app.route('/admin/pacientes')
@login_required
@rol_requerido('ADMIN','MEDICO','RECEPCION')
def pacientes():
    rows = query("SELECT * FROM vw_pacientes ORDER BY apellidop, nombre") or []
    return render_template('admin/pacientes.html', pacientes=rows)

@app.route('/admin/pacientes/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','RECEPCION')
def paciente_nuevo():
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_paciente', (
                f['nombre'].strip(), f['apellidop'].strip(),
                f.get('apellidom','').strip() or None,
                f.get('telefono','').strip() or None,
                f.get('email','').strip() or None,
                f['curp'].strip().upper(), f['fecha_nac'], f['sexo'],
                f.get('tipo_sangre'), f.get('foto','').strip() or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r, 'error')
            else:
                flash('Paciente registrado ✓', 'success')
                return redirect(url_for('pacientes'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('admin/paciente_form.html', paciente=None, accion='Nuevo')

@app.route('/admin/pacientes/editar/<int:id>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','RECEPCION')
def paciente_editar(id):
    paciente = query("SELECT * FROM vw_pacientes WHERE id_paciente=%s", (id,), fetchone=True)
    if not paciente:
        flash('Paciente no encontrado','error')
        return redirect(url_for('pacientes'))
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_actualizar_paciente', (
                id, f['nombre'].strip(), f['apellidop'].strip(),
                f.get('apellidom','').strip() or None, f['fecha_nac'], f['sexo'],
                f.get('tipo_sangre'), f.get('telefono','').strip() or None,
                f.get('email','').strip() or None, f.get('foto','').strip() or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r, 'error')
            else:
                flash('Paciente actualizado ✓','success')
                return redirect(url_for('pacientes'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/paciente_form.html', paciente=dict(paciente), accion='Editar')

@app.route('/admin/pacientes/eliminar/<int:id>')
@login_required
@rol_requerido('ADMIN')
def paciente_eliminar(id):
    try:
        res = call_sp('sp_eliminar_paciente', (id,))
        r = res.get('p_resultado','Error') if res else 'Error'
        if not r.startswith('Error'):
            registrar_log('WARNING', 'admin', f'Eliminación paciente ID {id} por {session.get("usuario","?")}')
        flash(r if r.startswith('Error') else 'Paciente eliminado',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('pacientes'))

# ════════════════════════════════════════════════════════════════
#  EXPEDIENTES
# ════════════════════════════════════════════════════════════════
@app.route('/admin/expedientes')
@login_required
@rol_requerido('ADMIN','MEDICO','ENFERMERO','RECEPCION')
def expedientes():
    rows = query("SELECT * FROM vw_expedientes") or []
    return render_template('admin/expedientes.html', expedientes=rows)

@app.route('/admin/expedientes/<int:id>')
@login_required
@rol_requerido('ADMIN','MEDICO','ENFERMERO','RECEPCION')
def expediente_detalle(id):
    exp_rows = call_sp_cursor('sp_obtener_expediente_detalle', (id,))
    if not exp_rows:
        flash('Expediente no encontrado','error')
        return redirect(url_for('expedientes'))
    exp          = exp_rows[0]
    ingresos_exp = call_sp_cursor('sp_obtener_ingresos_expediente', (id,)) or []
    triajes_exp  = call_sp_cursor('sp_obtener_triajes_expediente', (id,)) or []
    alergias     = call_sp_cursor('sp_obtener_alergias_expediente', (id,)) or []
    return render_template('admin/expediente_detalle.html',
        exp=exp, paciente=exp, ingresos=ingresos_exp,
        triajes=triajes_exp, alergias=alergias)
# ── Agregar estas rutas en app.py, después de la sección de EXPEDIENTES ──
# Busca la línea: @app.route('/admin/expedientes/<int:id>')
# y agrega esto ANTES de ella:

@app.route('/admin/expedientes/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','RECEPCION')
def expediente_nuevo():
    pacientes_list = call_sp_cursor('sp_obtener_pacientes_lista') or []
    medicos_list   = call_sp_cursor('sp_obtener_medicos_activos') or []
    hospitales_list = query("SELECT id_hospital, nombre FROM hospitales ORDER BY nombre") or []

    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_expediente', (
                int(f['id_paciente']),
                int(f['id_hospital']),
                f['medico_titular'].strip(),
                f.get('notas_iniciales', '').strip() or None,
            ))
            r = res.get('p_resultado', 'Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r, 'error')
            else:
                num = res.get('p_num_expediente', '')
                flash(f'Expediente {num} creado correctamente ✓', 'success')
                return redirect(url_for('expedientes'))
        except Exception as e:
            flash(f'Error: {e}', 'error')

    return render_template('admin/expediente_form.html',
        expediente=None,
        accion='Nuevo',
        paciente_fijo=None,
        pacientes=pacientes_list,
        medicos=medicos_list,
        hospitales=hospitales_list,
    )


# Ruta opcional: crear expediente desde la vista de un paciente específico
@app.route('/admin/pacientes/<int:id>/expediente/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','RECEPCION')
def expediente_nuevo_paciente(id):
    paciente = query("SELECT * FROM vw_pacientes WHERE id_paciente=%s", (id,), fetchone=True)
    if not paciente:
        flash('Paciente no encontrado', 'error')
        return redirect(url_for('pacientes'))

    medicos_list    = call_sp_cursor('sp_obtener_medicos_activos') or []
    hospitales_list = query("SELECT id_hospital, nombre FROM hospitales ORDER BY nombre") or []

    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_expediente', (
                id,
                int(f['id_hospital']),
                f['medico_titular'].strip(),
                f.get('notas_iniciales', '').strip() or None,
            ))
            r = res.get('p_resultado', 'Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r, 'error')
            else:
                num = res.get('p_num_expediente', '')
                flash(f'Expediente {num} creado correctamente ✓', 'success')
                return redirect(url_for('expedientes'))
        except Exception as e:
            flash(f'Error: {e}', 'error')

    return render_template('admin/expediente_form.html',
        expediente=None,
        accion='Nuevo',
        paciente_fijo=dict(paciente),
        pacientes=[],
        medicos=medicos_list,
        hospitales=hospitales_list,
    )
# ════════════════════════════════════════════════════════════════
#  INGRESOS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/ingresos')
@login_required
@rol_requerido('ADMIN','MEDICO','ENFERMERO','RECEPCION')
def ingresos():
    rows = query("SELECT * FROM vw_ingresos_activos") or []
    return render_template('admin/ingresos.html', ingresos=rows)

# ════════════════════════════════════════════════════════════════
#  TRIAJES
# ════════════════════════════════════════════════════════════════
@app.route('/admin/triajes')
@login_required
@rol_requerido('ADMIN','MEDICO','ENFERMERO','RECEPCION')
def triajes():
    colores = {'ROJO':'#ef4444','NARANJA':'#f97316','AMARILLO':'#eab308',
               'VERDE':'#22c55e','AZUL':'#3b82f6'}
    try:
        rows = call_sp_cursor('sp_obtener_triajes') or []
        for r in rows:
            r['color_hex'] = colores.get(r.get('nivel',''), '#64748b')
    except Exception:
        rows = []
    return render_template('admin/triajes.html', triajes=rows)

# ════════════════════════════════════════════════════════════════
#  MÉDICOS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/medicos')
@login_required
def medicos():
    rows = call_sp_cursor('sp_obtener_medicos') or []
    return render_template('admin/medicos.html', medicos=rows)

@app.route('/admin/medicos/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def medico_nuevo():
    especialidades = call_sp_cursor('sp_obtener_especialidades') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_medico', (
                f['cedula_medico'].strip(), f['nombre'].strip(),
                f['apellidop'].strip(), f.get('apellidom','').strip() or None,
                int(f['id_especialidad']),
                f.get('telefono','').strip() or None,
                f.get('email','').strip() or None,
                f.get('foto','').strip() or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Médico registrado ✓','success')
                return redirect(url_for('medicos'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/medico_form.html', medico=None, accion='Nuevo', especialidades=especialidades)

@app.route('/admin/medicos/editar/<string:cedula>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def medico_editar(cedula):
    medico_rows = call_sp_cursor('sp_obtener_medico', (cedula,))
    if not medico_rows:
        flash('Médico no encontrado','error')
        return redirect(url_for('medicos'))
    medico = medico_rows[0]
    especialidades = call_sp_cursor('sp_obtener_especialidades') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_actualizar_medico', (
                cedula, f['nombre'].strip(), f['apellidop'].strip(),
                f.get('apellidom','').strip() or None, int(f['id_especialidad']),
                f.get('telefono','').strip() or None,
                f.get('email','').strip() or None,
                f.get('foto','').strip() or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Médico actualizado ✓','success')
                return redirect(url_for('medicos'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/medico_form.html', medico=dict(medico), accion='Editar', especialidades=especialidades)

@app.route('/admin/medicos/eliminar/<string:cedula>')
@login_required
@rol_requerido('ADMIN')
def medico_eliminar(cedula):
    try:
        res = call_sp('sp_eliminar_medico', (cedula,))
        r = res.get('p_resultado','Error') if res else 'Error'
        if not r.startswith('Error'):
            registrar_log('WARNING', 'admin', f'Eliminación médico {cedula} por {session.get("usuario","?")}')
        flash(r if r.startswith('Error') else 'Médico eliminado',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('medicos'))

# ════════════════════════════════════════════════════════════════
#  ÁREAS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/areas')
@login_required
def areas():
    rows = call_sp_cursor('sp_obtener_areas') or []
    return render_template('admin/areas.html', areas=rows)

@app.route('/admin/areas/nueva', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def area_nueva():
    tipos = call_sp_cursor('sp_obtener_tipos_area') or []
    pisos = call_sp_cursor('sp_obtener_pisos') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_area', (
                f['id_area'].strip().upper(), f['nombre_area'].strip(),
                int(f['id_tipo_area']), int(f['id_piso']),
                int(f.get('capacidad',10)),
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Área registrada ✓','success')
                return redirect(url_for('areas'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/area_form.html', area=None, accion='Nueva', tipos=tipos, pisos=pisos)

@app.route('/admin/areas/editar/<string:id_area>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def area_editar(id_area):
    area = query("SELECT * FROM vw_ocupacion_areas WHERE id_area=%s",(id_area,),fetchone=True)
    if not area:
        flash('Área no encontrada','error')
        return redirect(url_for('areas'))
    tipos = call_sp_cursor('sp_obtener_tipos_area') or []
    pisos = call_sp_cursor('sp_obtener_pisos') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_actualizar_area', (
                id_area, f['nombre_area'].strip(), int(f['id_tipo_area']),
                int(f['id_piso']), int(f['capacidad']), f.get('activo')=='on',
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Área actualizada ✓','success')
                return redirect(url_for('areas'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/area_form.html', area=dict(area), accion='Editar', tipos=tipos, pisos=pisos)

@app.route('/admin/areas/eliminar/<string:id_area>')
@login_required
@rol_requerido('ADMIN')
def area_eliminar(id_area):
    try:
        res = call_sp('sp_eliminar_area', (id_area,))
        r = res.get('p_resultado','Error') if res else 'Error'
        flash(r if r.startswith('Error') else 'Área eliminada',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('areas'))

# ════════════════════════════════════════════════════════════════
#  BEACONS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/beacons')
@login_required
def beacons():
    rows = call_sp_cursor('sp_obtener_beacons') or []
    return render_template('admin/beacons.html', beacons=rows)

@app.route('/admin/beacons/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def beacon_nuevo():
    areas_list = call_sp_cursor('sp_obtener_areas_lista') or []
    modelos    = call_sp_cursor('sp_obtener_modelos_beacon') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_beacon', (
                f['id_beacon'].strip().upper(), f['id_area'], int(f['id_modelo']),
                f['uuid_beacon'].strip(), f['nombre'].strip(),
                f.get('estado','ACTIVO'), f.get('fecha_instalacion') or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Beacon registrado ✓','success')
                return redirect(url_for('beacons'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/beacon_form.html', beacon=None, accion='Nuevo', areas=areas_list, modelos=modelos)

@app.route('/admin/beacons/editar/<string:id_beacon>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def beacon_editar(id_beacon):
    beacon_rows = call_sp_cursor('sp_obtener_beacon', (id_beacon,))
    if not beacon_rows:
        flash('Beacon no encontrado','error')
        return redirect(url_for('beacons'))
    beacon     = beacon_rows[0]
    areas_list = call_sp_cursor('sp_obtener_areas_lista') or []
    modelos    = call_sp_cursor('sp_obtener_modelos_beacon') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_actualizar_beacon', (
                id_beacon, f['id_area'], int(f['id_modelo']),
                f['uuid_beacon'].strip(), f['nombre'].strip(),
                f.get('estado','ACTIVO'), f.get('fecha_instalacion') or None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Beacon actualizado ✓','success')
                return redirect(url_for('beacons'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/beacon_form.html', beacon=dict(beacon), accion='Editar', areas=areas_list, modelos=modelos)

@app.route('/admin/beacons/eliminar/<string:id_beacon>')
@login_required
@rol_requerido('ADMIN')
def beacon_eliminar(id_beacon):
    try:
        res = call_sp('sp_eliminar_beacon', (id_beacon,))
        r = res.get('p_resultado','Error') if res else 'Error'
        flash(r if r.startswith('Error') else 'Beacon eliminado',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('beacons'))

# ════════════════════════════════════════════════════════════════
#  USUARIOS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/usuarios')
@login_required
@rol_requerido('ADMIN')
def usuarios():
    rows = call_sp_cursor('sp_obtener_usuarios') or []
    return render_template('admin/usuarios.html', usuarios=rows)

@app.route('/admin/usuarios/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def usuario_nuevo():
    roles_list   = call_sp_cursor('sp_obtener_roles') or []
    medicos_list = call_sp_cursor('sp_obtener_medicos_activos') or []
    if request.method == 'POST':
        f = request.form
        try:
            res = call_sp('sp_insertar_usuario', (
                f['username'].strip(), f['password'].strip(), int(f['id_rol']),
                f.get('cedula_medico','').strip() or None,
                int(f['id_enfermero']) if f.get('id_enfermero') else None,
            ))
            r = res.get('p_resultado','Error') if res else 'Error'
            if r.startswith('Error'):
                flash(r,'error')
            else:
                flash('Usuario creado ✓','success')
                return redirect(url_for('usuarios'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/usuario_form.html', usuario=None, accion='Nuevo',
                           roles=roles_list, medicos=medicos_list)


@app.route('/admin/usuarios/editar/<int:id>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN')
def usuario_editar(id):
    usuario_rows = query(
        "SELECT u.*, r.nombre AS rol_nombre FROM usuarios u JOIN roles r ON r.id_rol=u.id_rol WHERE u.id_usuario=%s",
        (id,), fetchone=True)
    if not usuario_rows:
        flash('Usuario no encontrado','error')
        return redirect(url_for('usuarios'))
    roles_list   = call_sp_cursor('sp_obtener_roles') or []
    medicos_list = call_sp_cursor('sp_obtener_medicos_activos') or []
    if request.method == 'POST':
        f = request.form
        nueva_pass = f.get('password','').strip()
        try:
            if nueva_pass:
                query("UPDATE usuarios SET id_rol=%s, cedula_medico=%s, id_enfermero=%s, activo=%s, password_hash=%s WHERE id_usuario=%s",
                    (int(f['id_rol']), f.get('cedula_medico') or None,
                     int(f['id_enfermero']) if f.get('id_enfermero') else None,
                     f.get('activo')=='on', nueva_pass, id), commit=True)
            else:
                query("UPDATE usuarios SET id_rol=%s, cedula_medico=%s, id_enfermero=%s, activo=%s WHERE id_usuario=%s",
                    (int(f['id_rol']), f.get('cedula_medico') or None,
                     int(f['id_enfermero']) if f.get('id_enfermero') else None,
                     f.get('activo')=='on', id), commit=True)
            flash('Usuario actualizado ✓','success')
            return redirect(url_for('usuarios'))
        except Exception as e:
            flash(f'Error: {e}','error')
    return render_template('admin/usuario_form.html',
        usuario=dict(usuario_rows), accion='Editar',
        roles=roles_list, medicos=medicos_list)

@app.route('/admin/usuarios/toggle/<int:id>')
@login_required
@rol_requerido('ADMIN')
def usuario_toggle(id):
    try:
        res = call_sp('sp_toggle_usuario', (id,))
        r = res.get('p_resultado','Error') if res else 'Error'
        flash(r if r.startswith('Error') else 'Usuario actualizado ✓',
              'error' if r.startswith('Error') else 'success')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('usuarios'))

@app.route('/admin/usuarios/eliminar/<int:id>')
@login_required
@rol_requerido('ADMIN')
def usuario_eliminar(id):
    try:
        res = call_sp('sp_eliminar_usuario', (id,))
        r = res.get('p_resultado','Error') if res else 'Error'
        if not r.startswith('Error'):
            registrar_log('WARNING', 'admin', f'Eliminación usuario ID {id} por {session.get("usuario","?")}')
        flash(r if r.startswith('Error') else 'Usuario eliminado ✓',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('usuarios'))

# ════════════════════════════════════════════════════════════════
#  ALERTAS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/alertas')
@login_required
def alertas():
    rows = query("SELECT * FROM vw_alertas_activas") or []
    return render_template('admin/alertas.html', alertas=rows)

@app.route('/admin/alertas/resolver/<int:id>')
@login_required
@rol_requerido('ADMIN','ENFERMERO')
def alerta_resolver(id):
    try:
        res = call_sp('sp_resolver_alerta', (id,))
        r = res.get('p_resultado','Error') if res else 'Error'
        if not r.startswith('Error'):
            registrar_log('INFO', 'alertas', f'Alerta {id} resuelta por {session.get("usuario","?")}')
        flash(r if r.startswith('Error') else 'Alerta resuelta ✓',
              'error' if r.startswith('Error') else 'success')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('alertas'))

# ════════════════════════════════════════════════════════════════
#  LOGS
# ════════════════════════════════════════════════════════════════
@app.route('/admin/logs')
@login_required
@rol_requerido('ADMIN','AUDITOR')
def logs():
    rows = query("SELECT * FROM vw_logs LIMIT 200") or []
    return render_template('admin/logs.html', logs=rows)

# ════════════════════════════════════════════════════════════════
#  REPORTES
# ════════════════════════════════════════════════════════════════
@app.route('/admin/reportes')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
def reportes():
    kpi_espera  = query("SELECT * FROM vw_kpi_espera") or []
    kpi_medicos = query("SELECT * FROM vw_kpi_medicos") or []
    return render_template('admin/reportes.html', kpi_espera=kpi_espera, kpi_medicos=kpi_medicos)

@app.route('/admin/reportes/exportar/<string:tipo>')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
def exportar_csv(tipo):
    output = io.StringIO()
    if tipo == 'ingresos':
        rows   = query("SELECT * FROM vw_ingresos_activos") or []
        campos = ['id_ingreso','expediente','paciente','tipo_ingreso','motivo_ingreso','estado','tiempo_espera_min']
        nombre = 'reporte_ingresos.csv'
    elif tipo == 'espera':
        rows   = query("SELECT * FROM vw_kpi_espera") or []
        campos = ['nombre_area','total_ingresos','tiempo_espera_prom']
        nombre = 'reporte_espera.csv'
    else:
        flash('Tipo no válido','error')
        return redirect(url_for('reportes'))
    writer = csv.DictWriter(output, fieldnames=campos, extrasaction='ignore')
    writer.writeheader()
    for row in rows:
        writer.writerow(dict(row))
    return Response(output.getvalue(), mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename={nombre}'})

# ════════════════════════════════════════════════════════════════
#  TARJETAS NFC
# ════════════════════════════════════════════════════════════════
@app.route('/admin/tarjetas-nfc')
@login_required
@rol_requerido('ADMIN')
def tarjetas_nfc():
    tarjetas  = query("SELECT * FROM vw_tarjetas_nfc") or []
    pac_list  = call_sp_cursor('sp_obtener_pacientes_lista') or []
    return render_template('admin/tarjetas_nfc.html', tarjetas=tarjetas, pacientes=pac_list)

@app.route('/admin/tarjetas-nfc/nueva', methods=['POST'])
@login_required
@rol_requerido('ADMIN')
def tarjeta_nueva():
    uid         = request.form.get('uid_hex','').strip().upper()
    id_paciente = request.form.get('id_paciente','').strip()
    descripcion = request.form.get('descripcion','').strip() or None
    if not uid or not id_paciente:
        flash('UID y paciente son obligatorios','error')
        return redirect(url_for('tarjetas_nfc'))
    try:
        res = call_sp('sp_insertar_tarjeta_nfc', (uid, int(id_paciente), descripcion))
        r = res.get('p_resultado','Error') if res else 'Error'
        flash(r if r.startswith('Error') else f'Tarjeta {uid} registrada ✓',
              'error' if r.startswith('Error') else 'success')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('tarjetas_nfc'))

@app.route('/admin/tarjetas-nfc/eliminar/<string:uid>')
@login_required
@rol_requerido('ADMIN')
def tarjeta_eliminar(uid):
    try:
        res = call_sp('sp_eliminar_tarjeta_nfc', (uid,))
        r = res.get('p_resultado','Error') if res else 'Error'
        flash(r if r.startswith('Error') else f'Tarjeta {uid} eliminada ✓',
              'error' if r.startswith('Error') else 'warning')
    except Exception as e:
        flash(f'Error: {e}','error')
    return redirect(url_for('tarjetas_nfc'))

# ════════════════════════════════════════════════════════════════
#  CLÍNICO
# ════════════════════════════════════════════════════════════════
@app.route('/clinico')
@login_required
@rol_requerido('MEDICO','ADMIN')
def clinico_dashboard():
    cedula = session.get('cedula_medico')
    if session.get('rol') == 'ADMIN' or not cedula:
        ingresos_list = query("SELECT * FROM vw_ingresos_activos ORDER BY min_desde_ingreso DESC LIMIT 20") or []
    else:
        ingresos_list = query(
            "SELECT * FROM vw_ingresos_activos WHERE cedula_medico=%s ORDER BY min_desde_ingreso DESC",
            (cedula,)) or []
    beacon_detectado = _beacon_estado.get('detectado', False)
    id_beacon_actual = _beacon_estado.get('id_beacon', 'BCN-01')
    consultorios_db  = call_sp_cursor('sp_obtener_consultorios') or []
    consultorios = []
    for c in consultorios_db:
        d = dict(c)
        d['beacon_activo'] = (beacon_detectado and d.get('id_beacon') == id_beacon_actual)
        d['horario'] = '07:00–21:00'
        consultorios.append(d)
    return render_template('clinico/dashboard.html',
        ingresos=ingresos_list, consultorios=consultorios)

@app.route('/clinico/paciente/<int:id_ingreso>')
@login_required
@rol_requerido('MEDICO','ADMIN')
def clinico_detalle(id_ingreso):
    ing_rows = call_sp_cursor('sp_obtener_ingreso_detalle', (id_ingreso,))
    if not ing_rows:
        flash('Ingreso no encontrado','error')
        return redirect(url_for('clinico_dashboard'))
    ingreso   = ing_rows[0]
    timeline  = call_sp_cursor('sp_obtener_timeline_ingreso', (id_ingreso,)) or []
    estancias = call_sp_cursor('sp_obtener_estancias_ingreso', (id_ingreso,)) or []
    alergias  = call_sp_cursor('sp_obtener_alergias_expediente', (ingreso['id_expediente'],)) or []
    return render_template('clinico/detalle_paciente.html',
        ingreso=dict(ingreso), timeline=timeline,
        estancias=estancias, alergias=alergias)

# ════════════════════════════════════════════════════════════════
#  IoT — ESP32
# ════════════════════════════════════════════════════════════════

@app.route('/iot/ingresos')
@login_required
def iot_ingresos():
    """Endpoint de polling para actualizar ingresos en tiempo real."""
    cedula = session.get('cedula_medico')
    if session.get('rol') == 'ADMIN' or not cedula:
        rows = query("SELECT * FROM vw_ingresos_activos ORDER BY min_desde_ingreso DESC LIMIT 20") or []
    else:
        rows = query(
            "SELECT * FROM vw_ingresos_activos WHERE cedula_medico=%s ORDER BY min_desde_ingreso DESC",
            (cedula,)) or []
    return jsonify({'ingresos': [dict(r) for r in rows], 'total': len(rows)})

@app.route('/iot/beacon', methods=['POST'])
def iot_beacon():
    global _beacon_estado
    data      = request.get_json(silent=True) or {}
    detectado = bool(data.get('detectado', False))
    rssi      = data.get('rssi')
    id_beacon = data.get('id_beacon', 'BCN-01')
    ts        = datetime.now().isoformat(timespec='seconds')
    _beacon_estado.update(detectado=detectado, rssi=rssi,
                          timestamp=ts, id_beacon=id_beacon)
    try:
        nuevo_estado = 'ACTIVO' if detectado else 'INACTIVO'
        call_sp('sp_actualizar_estado_beacon', (id_beacon, nuevo_estado))
    except Exception as e:
        import traceback
        print(f"[BEACON] EXCEPTION: {traceback.format_exc()}")
        registrar_log('ERROR', 'iot_beacon', f'Error actualizando beacon {id_beacon}', detalle=str(e))
        return jsonify({'ok': False, 'error': str(e)}), 500
    registrar_evento_beacon(id_beacon, detectado, rssi)
    return jsonify({'ok': True, 'detectado': detectado, 'timestamp': ts})

@app.route('/iot/nfc', methods=['POST'])
def iot_nfc():
    global _sala_espera
    data    = request.get_json(silent=True) or {}
    uid_hex = data.get('uid', '').strip().upper()
    if not uid_hex:
        return jsonify({'ok': False, 'error': 'uid requerido'}), 400
    print(f"[NFC] UID recibido: {uid_hex}")
    try:
        res = call_sp('sp_registrar_nfc', (uid_hex,))
        print(f"[NFC] sp_registrar_nfc resultado: {res}")
        if not res or res.get('p_resultado','').startswith('Error'):
            msg = res.get('p_resultado','UID no registrado') if res else 'SP no retornó datos'
            print(f"[NFC] ERROR: {msg}")
            registrar_log('ERROR', 'iot_nfc', f'UID no registrado: {uid_hex}', detalle=msg)
            return jsonify({'ok': False, 'error': msg}), 404

        id_paciente = res['p_id_paciente']
        pac = {
            'id_paciente':     id_paciente,
            'nombre_completo': res['p_nombre'],
            'foto':            res['p_foto'],
            'num_expediente':  res['p_num_expediente'],
            'timestamp':       datetime.now().isoformat(timespec='seconds'),
        }

        # Verificar en BD si ya tiene un ingreso EN_ESPERA — fuente de verdad
        ver = call_sp('sp_verificar_ingreso_activo', (res.get('p_id_expediente'),))
        ingreso_activo = ver.get('p_id_ingreso') if ver and ver.get('p_resultado') == 'CON_INGRESO' else None

        if not ingreso_activo:
            # ENTRADA — crear ingreso
            id_ingreso = None
            if res.get('p_id_expediente') and res.get('p_medico_titular'):
                sp_r = call_sp('sp_insertar_ingreso', (
                    res['p_id_expediente'], res['p_medico_titular'],
                    'PROGRAMADO', 'Registro automático por NFC',
                ))
                print(f"[NFC] sp_insertar_ingreso resultado: {sp_r}")
                id_ingreso = sp_r.get('p_id_ingreso') if sp_r else None
                if id_ingreso:
                    area_r = call_sp('sp_obtener_area_de_beacon',
                                     (_beacon_estado.get('id_beacon','BCN-01'),))
                    if area_r and area_r.get('p_id_area'):
                        call_sp('sp_abrir_estancia', (id_ingreso, area_r['p_id_area']))
                    call_sp('sp_registrar_evento', (
                        id_ingreso, _beacon_estado.get('id_beacon','BCN-01'), 'ENTRADA', None))
                    pac['id_ingreso'] = id_ingreso

            # Actualizar memoria
            _sala_espera = [p for p in _sala_espera if p['id_paciente'] != id_paciente]
            _sala_espera.append(pac)
            registrar_evento_nfc(uid_hex, id_paciente,
                res['p_nombre'], res['p_num_expediente'],
                'ENTRADA', id_ingreso, res.get('p_id_expediente'))
            return jsonify({'ok': True, 'accion': 'ENTRADA', 'paciente': pac,
                            'contador_espera': len(_sala_espera)})
        else:
            # SALIDA — cerrar ingreso existente de la BD
            id_ingreso = ingreso_activo
            call_sp('sp_dar_alta_ingreso', (id_ingreso,))
            area_r = call_sp('sp_obtener_area_de_beacon',
                             (_beacon_estado.get('id_beacon','BCN-01'),))
            if area_r and area_r.get('p_id_area'):
                call_sp('sp_cerrar_estancia', (id_ingreso, area_r['p_id_area']))
            call_sp('sp_registrar_evento', (
                id_ingreso, _beacon_estado.get('id_beacon','BCN-01'), 'SALIDA', None))

            # Actualizar memoria
            _sala_espera = [p for p in _sala_espera if p['id_paciente'] != id_paciente]
            registrar_evento_nfc(uid_hex, id_paciente,
                res['p_nombre'], res['p_num_expediente'],
                'SALIDA', id_ingreso, res.get('p_id_expediente'))
            return jsonify({'ok': True, 'accion': 'SALIDA', 'paciente': pac,
                            'contador_espera': len(_sala_espera)})

    except Exception as e:
        import traceback
        print(f"[NFC] EXCEPTION: {traceback.format_exc()}")
        registrar_log('ERROR', 'iot_nfc', f'Excepción procesando NFC: {uid_hex}', detalle=str(e))
        try: get_db().rollback()
        except: pass
        return jsonify({'ok': False, 'error': str(e)}), 500

@app.route('/iot/estado', methods=['GET'])
def iot_estado():
    try:
        sala = query("SELECT * FROM vw_sala_espera") or []
        sala = [dict(r) for r in sala]
    except Exception:
        sala = list(_sala_espera)
    return jsonify({'beacon': _beacon_estado,
                    'sala_espera': sala,
                    'contador_espera': len(sala)})


@app.route('/admin/graficas')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
def graficas_dispositivos():
    resumen = resumen_mongo()
    logs    = obtener_logs(limite=20)
    return render_template('admin/reportes_mongo.html',
        resumen=resumen, logs=logs)

@app.route('/admin/graficas/datos')
@login_required
def graficas_datos():
    entradas_dia = kpi_entradas_por_dia(dias=7)
    rssi_hora    = kpi_rssi_promedio_por_hora()
    beacon_dia   = kpi_detecciones_por_dia(dias=7)
    return jsonify({
        'entradas_por_dia': [{'fecha': d['_id'], 'total': d['total']} for d in entradas_dia],
        'rssi_por_hora':    [{'hora': d['_id'], 'rssi_prom': round(d['rssi_prom'],1),
                              'detecciones': d['detecciones']} for d in rssi_hora],
        'beacon_por_dia':   [{'fecha': d['_id'], 'total': d['total']} for d in beacon_dia],
    })

@app.route('/admin/graficas/nfc')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
def graficas_nfc():
    eventos = obtener_eventos_nfc(limite=100)
    return render_template('admin/reportes_mongo_nfc.html', eventos=eventos)

@app.route('/admin/graficas/beacon')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
def graficas_beacon():
    eventos = obtener_eventos_beacon(limite=100)
    return render_template('admin/reportes_mongo_beacon.html', eventos=eventos)


@app.route('/admin/kpis')
@login_required
@rol_requerido('ADMIN','AUDITOR','MEDICO')
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
        alertas_res   = sq("SELECT * FROM vw_kpi_alertas_resolucion"),
        ocupacion     = sqa("SELECT * FROM vw_kpi_ocupacion_areas"),
        ing_tipo      = sqa("SELECT * FROM vw_kpi_ingresos_por_tipo"),
        adopcion_nfc  = sq("SELECT * FROM vw_kpi_adopcion_nfc"),
        estado_bea    = sqa("SELECT * FROM vw_kpi_estado_beacons"),
        triajes_niv   = sqa("SELECT * FROM vw_kpi_triajes_por_nivel"),
        exp_activos   = sq("SELECT * FROM vw_kpi_expedientes_activos"),
        vitales       = sqa("SELECT * FROM vw_kpi_vitales_por_nivel"),
        act_hora      = sqa("SELECT * FROM vw_kpi_actividad_por_hora"),
        disp_med      = sq("SELECT * FROM vw_kpi_disponibilidad_medicos"),
        dur_estancia  = sqa("SELECT * FROM vw_kpi_duracion_estancia_area"),
        ahora         = datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
    )


@app.route('/admin/ingresos/cambiar-estado/<int:id>', methods=['POST'])
@login_required
@rol_requerido('ADMIN','ENFERMERO','RECEPCION','MEDICO')
def ingreso_cambiar_estado(id):
    global _sala_espera
    nuevo_estado = request.form.get('estado','EN_ESPERA')
    try:
        query("UPDATE ingresos SET estado=%s WHERE id_ingreso=%s",
              (nuevo_estado, id), commit=True)
        # Si el nuevo estado no es EN_ESPERA, quitar de memoria
        if nuevo_estado != 'EN_ESPERA':
            _sala_espera = [p for p in _sala_espera
                           if p.get('id_ingreso') != id]
        flash(f'Estado actualizado a {nuevo_estado} ✓', 'success')
    except Exception as e:
        flash(f'Error: {e}', 'error')
    return redirect(request.referrer or url_for('ingresos'))


@app.route('/admin/ingresos/editar/<int:id>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','ENFERMERO','RECEPCION')
def ingreso_editar(id):
    ingreso = query(
        "SELECT * FROM vw_ingresos_activos WHERE id_ingreso=%s", (id,), fetchone=True)
    if not ingreso:
        ingreso = query(
            "SELECT id_ingreso, tipo_ingreso, motivo_ingreso, estado, tiempo_espera_min, cedula_medico, id_expediente FROM ingresos WHERE id_ingreso=%s",
            (id,), fetchone=True)
    if not ingreso:
        flash('Ingreso no encontrado', 'error')
        return redirect(url_for('ingresos'))
    medicos_list = call_sp_cursor('sp_obtener_medicos_activos') or []
    if request.method == 'POST':
        f = request.form
        try:
            query("UPDATE ingresos SET tipo_ingreso=%s, motivo_ingreso=%s, cedula_medico=%s, estado=%s WHERE id_ingreso=%s",
                (f.get('tipo_ingreso'), f.get('motivo_ingreso'),
                 f.get('cedula_medico'), f.get('estado'), id), commit=True)
            flash('Ingreso actualizado ✓', 'success')
            return redirect(url_for('ingresos'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('admin/ingreso_editar.html',
        ingreso=dict(ingreso), medicos=medicos_list)


@app.route('/admin/triajes/editar/<int:id>', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','ENFERMERO')
def triaje_editar(id):
    triaje = query(
        """SELECT t.*, i.id_ingreso,
                  p.nombre||' '||p.apellidop AS paciente,
                  e.num_expediente, t.id_enfermero
           FROM triajes t
           JOIN ingresos i ON i.id_ingreso = t.id_ingreso
           JOIN expedientes ex ON ex.id_expediente = i.id_expediente
           JOIN pacientes p ON p.id_paciente = ex.id_paciente
           JOIN expedientes e ON e.id_expediente = i.id_expediente
           WHERE t.id_triaje=%s""", (id,), fetchone=True)
    if not triaje:
        flash('Triaje no encontrado', 'error')
        return redirect(url_for('triajes'))
    enfermeros_list = query(
        "SELECT id_enfermero, nombre||\' \'||apellidop AS nombre_completo FROM personal_enfermeria ORDER BY apellidop"
    ) or []
    if request.method == 'POST':
        f = request.form
        try:
            query(
                "UPDATE triajes SET nivel_triaje=%s,frecuencia_cardiaca=%s,presion_sistolica=%s,presion_diastolica=%s,temperatura=%s,saturacion_o2=%s,glasgow=%s,id_enfermero=%s WHERE id_triaje=%s",
                (f['nivel_triaje'],
                 int(f['frecuencia_cardiaca']) if f.get('frecuencia_cardiaca') else None,
                 int(f['presion_sistolica'])   if f.get('presion_sistolica')   else None,
                 int(f['presion_diastolica'])  if f.get('presion_diastolica')  else None,
                 float(f['temperatura'])       if f.get('temperatura')         else None,
                 int(f['saturacion_o2'])       if f.get('saturacion_o2')       else None,
                 int(f['glasgow'])             if f.get('glasgow')             else None,
                 int(f['id_enfermero'])        if f.get('id_enfermero')        else None,
                 id), commit=True)
            flash('Triaje actualizado ✓', 'success')
            return redirect(url_for('triajes'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('admin/triaje_form.html',
        triaje=dict(triaje), enfermeros=enfermeros_list,
        ingresos=[], accion='Editar')


@app.route('/admin/triajes/nuevo', methods=['GET','POST'])
@login_required
@rol_requerido('ADMIN','ENFERMERO','MEDICO')
def triaje_nuevo():
    ingresos_list   = query("SELECT * FROM vw_ingresos_activos") or []
    enfermeros_list = query(
        "SELECT id_enfermero, nombre||' '||apellidop AS nombre FROM personal_enfermeria ORDER BY apellidop"
    ) or []
    if request.method == 'POST':
        f = request.form
        try:
            query(
                "INSERT INTO triajes(id_ingreso,id_enfermero,nivel_triaje,frecuencia_cardiaca,presion_sistolica,presion_diastolica,temperatura,saturacion_o2,glasgow,timestamp_triaje) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,NOW())",
                (int(f['id_ingreso']),
                 int(f['id_enfermero']) if f.get('id_enfermero') else None,
                 f['nivel_triaje'],
                 int(f['frecuencia_cardiaca']) if f.get('frecuencia_cardiaca') else None,
                 int(f['presion_sistolica'])   if f.get('presion_sistolica')   else None,
                 int(f['presion_diastolica'])  if f.get('presion_diastolica')  else None,
                 float(f['temperatura'])       if f.get('temperatura')         else None,
                 int(f['saturacion_o2'])       if f.get('saturacion_o2')       else None,
                 int(f['glasgow'])             if f.get('glasgow')             else None,
                ), commit=True)
            flash('Triaje registrado ✓', 'success')
            return redirect(url_for('triajes'))
        except Exception as e:
            flash(f'Error: {e}', 'error')
    return render_template('admin/triaje_form.html',
        ingresos=ingresos_list, enfermeros=enfermeros_list)


@app.route('/admin/ingresos/admitir/<int:id>', methods=['POST'])
@login_required
@rol_requerido('ADMIN','MEDICO')
def ingreso_admitir(id):
    cedula = session.get('cedula_medico') or request.form.get('cedula_medico','CED-001')
    try:
        res = call_sp('sp_admitir_paciente', (id, cedula))
        r = res.get('p_resultado','Error') if res else 'Error'
        if r.startswith('Error'):
            flash(r, 'error')
        else:
            # Quitar de sala de espera en memoria
            global _sala_espera
            _sala_espera = [p for p in _sala_espera
                           if p.get('id_ingreso') != id]
            registrar_log('INFO', 'ingresos',
                f'Paciente admitido en ingreso {id} por {session.get("usuario","?")}')
            flash('Paciente admitido al consultorio ✓', 'success')
    except Exception as e:
        flash(f'Error: {e}', 'error')
    return redirect(request.referrer or url_for('ingresos'))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)

# ════════════════════════════════════════════════════
#  TRIAJES — rutas faltantes
# ════════════════════════════════════════════════════