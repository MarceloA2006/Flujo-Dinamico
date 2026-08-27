--
-- PostgreSQL database dump
--

\restrict ySzwEXCOrOEvSst9rhVd0X0pCe5QyRclkY4PRV8AO6V4xk73ca932gtw7D3Bvri

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: hospital_admin
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO hospital_admin;

--
-- Name: fn_calcular_duracion_estancia(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_calcular_duracion_estancia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Al cerrar una estancia (timestamp_salida se llena)
    IF NEW.timestamp_salida IS NOT NULL AND OLD.timestamp_salida IS NULL THEN
        NEW.duracion_min := ROUND(
            EXTRACT(EPOCH FROM (NEW.timestamp_salida - NEW.timestamp_entrada)) / 60.0,
        2);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_calcular_duracion_estancia() OWNER TO hospital_admin;

--
-- Name: fn_log_beacons(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_beacons() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'INSERT', 'beacons',
               NULL, NOW(),
               'Nuevo beacon registrado: '||NEW.id_beacon||' — '||NEW.nombre
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'UPDATE', 'beacons',
               NULL, NOW(),
               'Beacon '||NEW.id_beacon||' actualizado — estado: '||NEW.estado
        FROM usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_log_beacons() OWNER TO hospital_admin;

--
-- Name: fn_log_ingresos(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_ingresos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'INSERT', 'ingresos',
               NEW.id_ingreso, NOW(),
               'Nuevo ingreso tipo '||NEW.tipo_ingreso||' - '||NEW.motivo_ingreso
        FROM   usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'UPDATE', 'ingresos',
               NEW.id_ingreso, NOW(),
               'Estado ingreso '||NEW.id_ingreso||' cambio a '||NEW.estado
        FROM   usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_log_ingresos() OWNER TO hospital_admin;

--
-- Name: fn_log_medicos(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_medicos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'INSERT', 'medicos',
               NULL, NOW(),
               'Nuevo médico: '||NEW.nombre||' '||NEW.apellidop||
               ' — Cédula: '||NEW.cedula_medico
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'UPDATE', 'medicos',
               NULL, NOW(),
               'Actualización médico cédula '||NEW.cedula_medico
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'DELETE', 'medicos',
               NULL, NOW(),
               'Eliminación médico: '||OLD.nombre||' '||OLD.apellidop
        FROM usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION public.fn_log_medicos() OWNER TO hospital_admin;

--
-- Name: fn_log_pacientes(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_pacientes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'INSERT', 'pacientes',
               NEW.id_paciente, NOW(),
               'Nuevo paciente: '||NEW.nombre||' '||NEW.apellidop
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'UPDATE', 'pacientes',
               NEW.id_paciente, NOW(),
               'Actualización paciente ID '||NEW.id_paciente
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'DELETE', 'pacientes',
               OLD.id_paciente, NOW(),
               'Eliminación paciente: '||OLD.nombre||' '||OLD.apellidop
        FROM usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION public.fn_log_pacientes() OWNER TO hospital_admin;

--
-- Name: fn_log_triajes(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_triajes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                           id_registro, timestamp_accion, detalle)
    SELECT COALESCE(id_usuario,1), TG_OP, 'triajes',
           NEW.id_triaje, NOW(),
           'Triaje nivel '||NEW.nivel_triaje||
           ' para ingreso '||NEW.id_ingreso
    FROM usuarios WHERE username = current_user LIMIT 1;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_log_triajes() OWNER TO hospital_admin;

--
-- Name: fn_log_usuarios(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_log_usuarios() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'INSERT', 'usuarios',
               NEW.id_usuario, NOW(),
               'Nuevo usuario creado: '||NEW.username
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'UPDATE', 'usuarios',
               NEW.id_usuario, NOW(),
               'Usuario '||NEW.username||' actualizado — activo: '||NEW.activo::TEXT
        FROM usuarios WHERE username = current_user LIMIT 1;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                               id_registro, timestamp_accion, detalle)
        SELECT COALESCE(id_usuario,1), 'DELETE', 'usuarios',
               OLD.id_usuario, NOW(),
               'Usuario eliminado: '||OLD.username
        FROM usuarios WHERE username = current_user LIMIT 1;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;


ALTER FUNCTION public.fn_log_usuarios() OWNER TO hospital_admin;

--
-- Name: fn_validar_capacidad_area(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_validar_capacidad_area() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_capacidad  INTEGER;
    v_ocupacion  INTEGER;
    v_nombre     VARCHAR;
BEGIN
    SELECT a.capacidad, a.nombre_area
    INTO   v_capacidad, v_nombre
    FROM   areas a WHERE a.id_area = NEW.id_area;

    IF v_capacidad IS NOT NULL THEN
        SELECT COUNT(*) INTO v_ocupacion
        FROM   estancias
        WHERE  id_area = NEW.id_area
          AND  timestamp_salida IS NULL
          AND  id_estancia != COALESCE(NEW.id_estancia, -1);

        IF v_ocupacion >= v_capacidad THEN
            RAISE EXCEPTION
                'Área "%" ha alcanzado su capacidad máxima de % pacientes',
                v_nombre, v_capacidad;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_capacidad_area() OWNER TO hospital_admin;

--
-- Name: fn_validar_ingreso_unico(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_validar_ingreso_unico() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NEW.estado = 'EN_ESPERA' THEN
        SELECT COUNT(*) INTO v_count
        FROM ingresos
        WHERE id_expediente = NEW.id_expediente
          AND estado = 'EN_ESPERA'
          AND id_ingreso != COALESCE(NEW.id_ingreso, -1);

        IF v_count > 0 THEN
            RAISE EXCEPTION
                'El expediente % ya tiene un ingreso EN_ESPERA activo',
                NEW.id_expediente;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_ingreso_unico() OWNER TO hospital_admin;

--
-- Name: fn_validar_rol_usuario(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_validar_rol_usuario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.id_rol = (SELECT id_rol FROM roles WHERE nombre='MEDICO') THEN
        IF NEW.cedula_medico IS NULL THEN
            RAISE EXCEPTION 'Usuario con rol MEDICO debe tener cedula_medico';
        END IF;
        IF NEW.id_enfermero IS NOT NULL THEN
            RAISE EXCEPTION 'Usuario con rol MEDICO no puede tener id_enfermero';
        END IF;
    END IF;
    IF NEW.id_rol = (SELECT id_rol FROM roles WHERE nombre='ENFERMERO') THEN
        IF NEW.id_enfermero IS NULL THEN
            RAISE EXCEPTION 'Usuario con rol ENFERMERO debe tener id_enfermero';
        END IF;
        IF NEW.cedula_medico IS NOT NULL THEN
            RAISE EXCEPTION 'Usuario con rol ENFERMERO no puede tener cedula_medico';
        END IF;
    END IF;
    IF NEW.id_rol NOT IN (
        SELECT id_rol FROM roles WHERE nombre IN ('MEDICO','ENFERMERO')
    ) THEN
        IF NEW.cedula_medico IS NOT NULL OR NEW.id_enfermero IS NOT NULL THEN
            RAISE NOTICE 'OK [C5]: Usuario ENFERMERO con cedula_medico rechazado por trigger: Usuario con rol ENFERMERO no puede tener cedula_medico';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_rol_usuario() OWNER TO hospital_admin;

--
-- Name: fn_validar_triaje(); Type: FUNCTION; Schema: public; Owner: hospital_admin
--

CREATE FUNCTION public.fn_validar_triaje() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Triaje ROJO requiere signos vitales obligatorios
    IF NEW.nivel_triaje = 'ROJO' THEN
        IF NEW.frecuencia_cardiaca IS NULL OR
           NEW.presion_sistolica   IS NULL OR
           NEW.saturacion_o2       IS NULL THEN
            RAISE EXCEPTION
                'Triaje ROJO requiere frecuencia cardiaca, presión sistólica y saturación O2';
        END IF;
    END IF;
    -- Glasgow debe estar entre 3 y 15
    IF NEW.glasgow IS NOT NULL AND (NEW.glasgow < 3 OR NEW.glasgow > 15) THEN
        RAISE EXCEPTION 'Glasgow debe estar entre 3 y 15, valor recibido: %', NEW.glasgow;
    END IF;
    -- Temperatura corporal razonable
    IF NEW.temperatura IS NOT NULL AND
       (NEW.temperatura < 34.0 OR NEW.temperatura > 42.0) THEN
        RAISE EXCEPTION 'Temperatura fuera de rango clínico: %°C', NEW.temperatura;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_triaje() OWNER TO hospital_admin;

--
-- Name: sp_abrir_estancia(integer, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_abrir_estancia(IN p_id_ingreso integer, IN p_id_area character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO estancias(id_ingreso, id_area, timestamp_entrada, fuente_verdad)
    VALUES(p_id_ingreso, p_id_area, NOW(), 'BEACON');
    p_resultado := 'OK';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_abrir_estancia(IN p_id_ingreso integer, IN p_id_area character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_area(character varying, character varying, integer, integer, integer, boolean); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_area(IN p_id_area character varying, IN p_nombre_area character varying, IN p_id_tipo_area integer, IN p_id_piso integer, IN p_capacidad integer, IN p_activo boolean, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE areas
    SET nombre_area=p_nombre_area, id_tipo_area=p_id_tipo_area,
        id_piso=p_id_piso, capacidad=p_capacidad, activo=p_activo
    WHERE id_area = p_id_area;
    IF NOT FOUND THEN
        p_resultado := 'Error: Área no encontrada.';
    ELSE
        p_resultado := 'Área actualizada correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_area(IN p_id_area character varying, IN p_nombre_area character varying, IN p_id_tipo_area integer, IN p_id_piso integer, IN p_capacidad integer, IN p_activo boolean, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_beacon(character varying, character varying, integer, character varying, character varying, character varying, date); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_beacon(IN p_id_beacon character varying, IN p_id_area character varying, IN p_id_modelo integer, IN p_uuid_beacon character varying, IN p_nombre character varying, IN p_estado character varying, IN p_fecha_instalacion date, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE beacons
    SET id_area=p_id_area, id_modelo=p_id_modelo,
        uuid_beacon=p_uuid_beacon, nombre=p_nombre,
        estado=p_estado, fecha_instalacion=p_fecha_instalacion
    WHERE id_beacon = p_id_beacon;
    IF NOT FOUND THEN
        p_resultado := 'Error: Beacon no encontrado.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_beacon(IN p_id_beacon character varying, IN p_id_area character varying, IN p_id_modelo integer, IN p_uuid_beacon character varying, IN p_nombre character varying, IN p_estado character varying, IN p_fecha_instalacion date, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_estado_beacon(character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_estado_beacon(IN p_id_beacon character varying, IN p_estado character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE beacons SET estado = p_estado WHERE id_beacon = p_id_beacon;
    IF NOT FOUND THEN
        p_resultado := 'Error: Beacon no encontrado.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_estado_beacon(IN p_id_beacon character varying, IN p_estado character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_estado_ingreso(integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_estado_ingreso(IN p_id_ingreso integer, IN p_nuevo_estado character varying, IN p_id_area_salida character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ingresos WHERE id_ingreso = p_id_ingreso) THEN
        p_resultado := 'Error: Ingreso no encontrado.';
        RETURN;
    END IF;

    UPDATE ingresos
    SET estado      = p_nuevo_estado,
        fecha_egreso = CASE
                         WHEN p_nuevo_estado IN ('COMPLETADO','ALTA') THEN NOW()
                         ELSE fecha_egreso
                       END
    WHERE id_ingreso = p_id_ingreso;

    IF p_id_area_salida IS NOT NULL THEN
        UPDATE estancias
        SET timestamp_salida = NOW()
        WHERE id_ingreso      = p_id_ingreso
          AND id_area         = p_id_area_salida
          AND timestamp_salida IS NULL;
    END IF;

    p_resultado := 'Estado actualizado correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_estado_ingreso(IN p_id_ingreso integer, IN p_nuevo_estado character varying, IN p_id_area_salida character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_medico(character varying, character varying, character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_medico(IN p_cedula character varying, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_id_especialidad integer, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE medicos
    SET nombre=p_nombre, apellidop=p_apellidop, apellidom=p_apellidom,
        id_especialidad=p_id_especialidad, telefono=p_telefono,
        email=p_email, foto=p_foto
    WHERE cedula_medico = p_cedula;
    IF NOT FOUND THEN
        p_resultado := 'Error: Médico no encontrado.';
    ELSE
        p_resultado := 'Médico actualizado correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_medico(IN p_cedula character varying, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_id_especialidad integer, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_paciente(integer, character varying, character varying, character varying, date, character, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_paciente(IN p_id_paciente integer, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_telefono character varying, IN p_email character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pacientes
    SET nombre      = p_nombre,
        apellidop   = p_apellidop,
        apellidom   = p_apellidom,
        fecha_nac   = p_fecha_nac,
        sexo        = p_sexo,
        tipo_sangre = p_tipo_sangre,
        telefono    = p_telefono,
        email       = p_email
    WHERE id_paciente = p_id_paciente;

    IF NOT FOUND THEN
        p_resultado := 'Error: Paciente no encontrado.';
        RETURN;
    END IF;

    p_resultado := 'Paciente actualizado correctamente.';

EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_paciente(IN p_id_paciente integer, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_telefono character varying, IN p_email character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_paciente(integer, character varying, character varying, character varying, date, character, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_paciente(IN p_id_paciente integer, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE pacientes
    SET nombre      = p_nombre,
        apellidop   = p_apellidop,
        apellidom   = p_apellidom,
        fecha_nac   = p_fecha_nac,
        sexo        = p_sexo,
        tipo_sangre = p_tipo_sangre,
        telefono    = p_telefono,
        email       = p_email,
        foto        = p_foto
    WHERE id_paciente = p_id_paciente;

    IF NOT FOUND THEN
        p_resultado := 'Error: Paciente no encontrado.';
        RETURN;
    END IF;

    -- Auditoría
    CALL sp_log_paciente('UPDATE', p_id_paciente,
        'Actualizacion paciente ID ' || p_id_paciente);

    p_resultado := 'Paciente actualizado correctamente.';

EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_paciente(IN p_id_paciente integer, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_actualizar_triaje(integer, integer, integer, integer, numeric, integer, integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_actualizar_triaje(IN p_id_triaje integer, IN p_frecuencia_cardiaca integer, IN p_presion_sistolica integer, IN p_presion_diastolica integer, IN p_temperatura numeric, IN p_saturacion_o2 integer, IN p_glasgow integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nivel VARCHAR(10);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM triajes WHERE id_triaje = p_id_triaje) THEN
        p_resultado := 'Error: Triaje no encontrado.';
        RETURN;
    END IF;

    -- Recalcular nivel inline
    IF (p_frecuencia_cardiaca < 40  OR p_frecuencia_cardiaca > 140) OR
       (p_presion_sistolica   < 80  OR p_presion_sistolica   > 200) OR
       (p_saturacion_o2       < 90) OR
       (p_glasgow             < 9)  OR
       (p_temperatura > 39.5 OR p_temperatura < 35) THEN
        v_nivel := 'ROJO';

    ELSIF (p_frecuencia_cardiaca BETWEEN 40  AND 49  OR p_frecuencia_cardiaca BETWEEN 121 AND 140) OR
          (p_presion_sistolica   BETWEEN 80  AND 89  OR p_presion_sistolica   BETWEEN 180 AND 200) OR
          (p_saturacion_o2       BETWEEN 90  AND 92) OR
          (p_glasgow             BETWEEN 9   AND 12) OR
          (p_temperatura BETWEEN 39.1 AND 39.5 OR p_temperatura BETWEEN 35.0 AND 35.9) THEN
        v_nivel := 'NARANJA';

    ELSIF (p_frecuencia_cardiaca BETWEEN 50  AND 59  OR p_frecuencia_cardiaca BETWEEN 101 AND 120) OR
          (p_presion_sistolica   BETWEEN 90  AND 99  OR p_presion_sistolica   BETWEEN 160 AND 179) OR
          (p_saturacion_o2       BETWEEN 93  AND 94) OR
          (p_glasgow             BETWEEN 13  AND 14) OR
          (p_temperatura BETWEEN 38.5 AND 39.0) THEN
        v_nivel := 'AMARILLO';

    ELSIF (p_frecuencia_cardiaca BETWEEN 60 AND 100)  AND
          (p_presion_sistolica   BETWEEN 100 AND 139) AND
          (p_presion_diastolica  BETWEEN 60  AND 89)  AND
          (p_saturacion_o2       >= 95)               AND
          (p_glasgow             = 15)                AND
          (p_temperatura BETWEEN 36.0 AND 37.5) THEN
        v_nivel := 'VERDE';

    ELSE
        v_nivel := 'AZUL';
    END IF;

    UPDATE triajes
    SET frecuencia_cardiaca = p_frecuencia_cardiaca,
        presion_sistolica   = p_presion_sistolica,
        presion_diastolica  = p_presion_diastolica,
        temperatura         = p_temperatura,
        saturacion_o2       = p_saturacion_o2,
        glasgow             = p_glasgow,
        nivel_triaje        = v_nivel
    WHERE id_triaje = p_id_triaje;

    p_resultado := 'Triaje actualizado correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_actualizar_triaje(IN p_id_triaje integer, IN p_frecuencia_cardiaca integer, IN p_presion_sistolica integer, IN p_presion_diastolica integer, IN p_temperatura numeric, IN p_saturacion_o2 integer, IN p_glasgow integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_admitir_paciente(integer, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_admitir_paciente(IN p_id_ingreso integer, IN p_cedula_medico character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE ingresos
    SET estado = 'EN_ATENCION',
        cedula_medico = p_cedula_medico
    WHERE id_ingreso = p_id_ingreso
      AND estado = 'EN_ESPERA';

    IF NOT FOUND THEN
        p_resultado := 'Error: Ingreso no encontrado o ya no está en espera.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_admitir_paciente(IN p_id_ingreso integer, IN p_cedula_medico character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_cerrar_estancia(integer, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_cerrar_estancia(IN p_id_ingreso integer, IN p_id_area character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE estancias
    SET timestamp_salida = NOW(),
        duracion_min = ROUND(
            EXTRACT(EPOCH FROM (NOW() - timestamp_entrada)) / 60.0, 2)
    WHERE id_estancia = (
        SELECT id_estancia FROM estancias
        WHERE id_ingreso = p_id_ingreso AND id_area = p_id_area
          AND timestamp_salida IS NULL
        ORDER BY timestamp_entrada DESC LIMIT 1
    );
    p_resultado := 'OK';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_cerrar_estancia(IN p_id_ingreso integer, IN p_id_area character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_dar_alta_ingreso(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_dar_alta_ingreso(IN p_id_ingreso integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE ingresos
    SET estado = 'ALTA',
        fecha_egreso = NOW(),
        tiempo_espera_min = ROUND(
            EXTRACT(EPOCH FROM (NOW() - fecha_ingreso)) / 60.0, 2)
    WHERE id_ingreso = p_id_ingreso;
    IF NOT FOUND THEN
        p_resultado := 'Error: Ingreso no encontrado.';
    ELSE
        p_resultado := 'Alta registrada correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_dar_alta_ingreso(IN p_id_ingreso integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_area(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_area(IN p_id_area character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM areas WHERE id_area = p_id_area;
    IF NOT FOUND THEN
        p_resultado := 'Error: Área no encontrada.';
    ELSE
        p_resultado := 'Área eliminada correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_area(IN p_id_area character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_beacon(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_beacon(IN p_id_beacon character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM beacons WHERE id_beacon = p_id_beacon;
    IF NOT FOUND THEN
        p_resultado := 'Error: Beacon no encontrado.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_beacon(IN p_id_beacon character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_medico(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_medico(IN p_cedula character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM medicos WHERE cedula_medico = p_cedula;
    IF NOT FOUND THEN
        p_resultado := 'Error: Médico no encontrado.';
    ELSE
        p_resultado := 'Médico eliminado correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_medico(IN p_cedula character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_paciente(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_paciente(IN p_id_paciente integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Triajes de ingresos del paciente
    DELETE FROM triajes
    WHERE id_ingreso IN (
        SELECT i.id_ingreso FROM ingresos i
        JOIN expedientes e ON e.id_expediente = i.id_expediente
        WHERE e.id_paciente = p_id_paciente
    );

    -- 2. Estancias de ingresos del paciente
    DELETE FROM estancias
    WHERE id_ingreso IN (
        SELECT i.id_ingreso FROM ingresos i
        JOIN expedientes e ON e.id_expediente = i.id_expediente
        WHERE e.id_paciente = p_id_paciente
    );

    -- 3. Ingresos del paciente
    DELETE FROM ingresos
    WHERE id_expediente IN (
        SELECT id_expediente FROM expedientes
        WHERE id_paciente = p_id_paciente
    );

    -- 4. Tarjetas NFC del paciente
    DELETE FROM tarjetas_nfc
    WHERE id_paciente = p_id_paciente;

    -- 5. Expedientes del paciente
    DELETE FROM expedientes
    WHERE id_paciente = p_id_paciente;

    -- 6. Finalmente el paciente
    DELETE FROM pacientes
    WHERE id_paciente = p_id_paciente;

    IF NOT FOUND THEN
        p_resultado := 'Error: Paciente no encontrado.';
    ELSE
        p_resultado := 'OK';
    END IF;

EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_paciente(IN p_id_paciente integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_tarjeta_nfc(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_tarjeta_nfc(IN p_uid_hex character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM tarjetas_nfc WHERE uid_hex = p_uid_hex;
    IF NOT FOUND THEN
        p_resultado := 'Error: Tarjeta no encontrada.';
    ELSE
        p_resultado := 'Tarjeta eliminada correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_tarjeta_nfc(IN p_uid_hex character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_eliminar_usuario(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_eliminar_usuario(IN p_id_usuario integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM usuarios
    WHERE id_usuario = p_id_usuario AND username != 'admin';
    IF NOT FOUND THEN
        p_resultado := 'Error: Usuario no encontrado o es admin principal.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_eliminar_usuario(IN p_id_usuario integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_area(character varying, character varying, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_area(IN p_id_area character varying, IN p_nombre_area character varying, IN p_id_tipo_area integer, IN p_id_piso integer, IN p_capacidad integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO areas(id_area, nombre_area, id_tipo_area, id_piso, capacidad, activo)
    VALUES(p_id_area, p_nombre_area, p_id_tipo_area, p_id_piso, p_capacidad, true);
    p_resultado := 'Área registrada correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_insertar_area(IN p_id_area character varying, IN p_nombre_area character varying, IN p_id_tipo_area integer, IN p_id_piso integer, IN p_capacidad integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_beacon(character varying, character varying, integer, character varying, character varying, character varying, date); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_beacon(IN p_id_beacon character varying, IN p_id_area character varying, IN p_id_modelo integer, IN p_uuid_beacon character varying, IN p_nombre character varying, IN p_estado character varying, IN p_fecha_instalacion date, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO beacons(id_beacon, id_area, id_modelo, uuid_beacon,
                        nombre, estado, fecha_instalacion)
    VALUES(p_id_beacon, p_id_area, p_id_modelo, p_uuid_beacon,
           p_nombre, p_estado, p_fecha_instalacion);
    p_resultado := 'OK';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_insertar_beacon(IN p_id_beacon character varying, IN p_id_area character varying, IN p_id_modelo integer, IN p_uuid_beacon character varying, IN p_nombre character varying, IN p_estado character varying, IN p_fecha_instalacion date, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_expediente(integer, integer, character varying, text); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_expediente(IN p_id_paciente integer, IN p_id_hospital integer, IN p_medico_titular character varying, IN p_notas_iniciales text, OUT p_resultado text, OUT p_id_expediente integer, OUT p_num_expediente character varying)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_siguiente integer;
BEGIN
    -- Verificar que el paciente existe
    IF NOT EXISTS (SELECT 1 FROM pacientes WHERE id_paciente = p_id_paciente) THEN
        p_resultado      := 'Error: Paciente no encontrado.';
        p_id_expediente  := NULL;
        p_num_expediente := NULL;
        RETURN;
    END IF;
 
    -- Verificar que el paciente no tenga ya un expediente activo
    IF EXISTS (SELECT 1 FROM expedientes WHERE id_paciente = p_id_paciente AND activo = true) THEN
        p_resultado      := 'Error: El paciente ya tiene un expediente activo.';
        p_id_expediente  := NULL;
        p_num_expediente := NULL;
        RETURN;
    END IF;
 
    -- Verificar que el médico existe
    IF NOT EXISTS (SELECT 1 FROM medicos WHERE cedula_medico = p_medico_titular) THEN
        p_resultado      := 'Error: Médico no encontrado.';
        p_id_expediente  := NULL;
        p_num_expediente := NULL;
        RETURN;
    END IF;
 
    -- Generar número de expediente: EXP-XXX correlativo
    SELECT COALESCE(MAX(CAST(SUBSTRING(num_expediente FROM 5) AS integer)), 0) + 1
    INTO v_siguiente
    FROM expedientes
    WHERE num_expediente ~ '^EXP-[0-9]+$';
 
    p_num_expediente := 'EXP-' || LPAD(v_siguiente::text, 3, '0');
 
    -- Insertar expediente
    INSERT INTO expedientes (num_expediente, id_paciente, id_hospital,
                             medico_titular, fecha_apertura, activo, notas_iniciales)
    VALUES (p_num_expediente, p_id_paciente, p_id_hospital,
            p_medico_titular, CURRENT_DATE, true, p_notas_iniciales)
    RETURNING id_expediente INTO p_id_expediente;
 
    p_resultado := 'Expediente creado correctamente.';
 
EXCEPTION WHEN OTHERS THEN
    p_resultado      := 'Error: ' || SQLERRM;
    p_id_expediente  := NULL;
    p_num_expediente := NULL;
END;
$_$;


ALTER PROCEDURE public.sp_insertar_expediente(IN p_id_paciente integer, IN p_id_hospital integer, IN p_medico_titular character varying, IN p_notas_iniciales text, OUT p_resultado text, OUT p_id_expediente integer, OUT p_num_expediente character varying) OWNER TO hospital_admin;

--
-- Name: sp_insertar_ingreso(integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_ingreso(IN p_id_expediente integer, IN p_cedula_medico character varying, IN p_tipo_ingreso character varying, IN p_motivo character varying, OUT p_id_ingreso integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ingresos(id_expediente, cedula_medico, tipo_ingreso,
                         motivo_ingreso, estado, fecha_ingreso)
    VALUES(p_id_expediente, p_cedula_medico, p_tipo_ingreso,
           p_motivo, 'EN_ESPERA', NOW())
    RETURNING id_ingreso INTO p_id_ingreso;
    p_resultado := 'Ingreso registrado correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
    p_id_ingreso := NULL;
END;
$$;


ALTER PROCEDURE public.sp_insertar_ingreso(IN p_id_expediente integer, IN p_cedula_medico character varying, IN p_tipo_ingreso character varying, IN p_motivo character varying, OUT p_id_ingreso integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_medico(character varying, character varying, character varying, character varying, integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_medico(IN p_cedula character varying, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_id_especialidad integer, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM medicos WHERE cedula_medico = p_cedula) THEN
        p_resultado := 'Error: Ya existe un médico con esa cédula.';
        RETURN;
    END IF;
    INSERT INTO medicos(cedula_medico, nombre, apellidop, apellidom,
                        id_especialidad, telefono, email, activo, foto)
    VALUES(p_cedula, p_nombre, p_apellidop, p_apellidom,
           p_id_especialidad, p_telefono, p_email, true, p_foto);
    p_resultado := 'Médico registrado correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_insertar_medico(IN p_cedula character varying, IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_id_especialidad integer, IN p_telefono character varying, IN p_email character varying, IN p_foto character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_paciente(character varying, character varying, character varying, character varying, character varying, character varying, date, character, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_paciente(IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_telefono character varying, IN p_email character varying, IN p_curp character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, OUT p_resultado text, OUT p_id_paciente integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pacientes WHERE curp = p_curp) THEN
        p_resultado   := 'Error: Ya existe un paciente con ese CURP.';
        p_id_paciente := NULL;
        RETURN;
    END IF;

    INSERT INTO pacientes
        (curp, nombre, apellidop, apellidom, fecha_nac, sexo, tipo_sangre, telefono, email)
    VALUES
        (p_curp, p_nombre, p_apellidop, p_apellidom, p_fecha_nac, p_sexo, p_tipo_sangre, p_telefono, p_email)
    RETURNING id_paciente INTO p_id_paciente;

    p_resultado := 'Paciente registrado correctamente.';

EXCEPTION WHEN OTHERS THEN
    p_resultado   := 'Error: ' || SQLERRM;
    p_id_paciente := NULL;
END;
$$;


ALTER PROCEDURE public.sp_insertar_paciente(IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_telefono character varying, IN p_email character varying, IN p_curp character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, OUT p_resultado text, OUT p_id_paciente integer) OWNER TO hospital_admin;

--
-- Name: sp_insertar_paciente(character varying, character varying, character varying, character varying, character varying, character varying, date, character, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_paciente(IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_telefono character varying, IN p_email character varying, IN p_curp character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_foto character varying, OUT p_resultado text, OUT p_id_paciente integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pacientes WHERE curp = p_curp) THEN
        p_resultado   := 'Error: Ya existe un paciente con ese CURP.';
        p_id_paciente := NULL;
        RETURN;
    END IF;

    INSERT INTO pacientes
        (curp, nombre, apellidop, apellidom, fecha_nac,
         sexo, tipo_sangre, telefono, email, foto)
    VALUES
        (p_curp, p_nombre, p_apellidop, p_apellidom, p_fecha_nac,
         p_sexo, p_tipo_sangre, p_telefono, p_email, p_foto)
    RETURNING id_paciente INTO p_id_paciente;

    -- Auditoría
    CALL sp_log_paciente('INSERT', p_id_paciente,
        'Nuevo paciente: ' || p_nombre || ' ' || p_apellidop);

    p_resultado := 'Paciente registrado correctamente.';

EXCEPTION WHEN OTHERS THEN
    p_resultado   := 'Error: ' || SQLERRM;
    p_id_paciente := NULL;
END;
$$;


ALTER PROCEDURE public.sp_insertar_paciente(IN p_nombre character varying, IN p_apellidop character varying, IN p_apellidom character varying, IN p_telefono character varying, IN p_email character varying, IN p_curp character varying, IN p_fecha_nac date, IN p_sexo character, IN p_tipo_sangre character varying, IN p_foto character varying, OUT p_resultado text, OUT p_id_paciente integer) OWNER TO hospital_admin;

--
-- Name: sp_insertar_tarjeta_nfc(character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_tarjeta_nfc(IN p_uid_hex character varying, IN p_id_paciente integer, IN p_descripcion character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM tarjetas_nfc WHERE uid_hex = p_uid_hex) THEN
        p_resultado := 'Error: El UID ya está registrado.';
        RETURN;
    END IF;
    INSERT INTO tarjetas_nfc(uid_hex, id_paciente, descripcion, fecha_registro)
    VALUES(p_uid_hex, p_id_paciente, p_descripcion, NOW());
    p_resultado := 'Tarjeta registrada correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_insertar_tarjeta_nfc(IN p_uid_hex character varying, IN p_id_paciente integer, IN p_descripcion character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_insertar_triaje(integer, integer, integer, integer, integer, numeric, integer, integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_triaje(IN p_id_ingreso integer, IN p_id_enfermero integer, IN p_frecuencia_cardiaca integer, IN p_presion_sistolica integer, IN p_presion_diastolica integer, IN p_temperatura numeric, IN p_saturacion_o2 integer, IN p_glasgow integer, OUT p_resultado text, OUT p_id_triaje integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nivel    VARCHAR(10);
    v_id_triaje INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ingresos WHERE id_ingreso = p_id_ingreso) THEN
        p_resultado := 'Error: El ingreso no existe.';
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM personal_enfermeria
        WHERE id_enfermero = p_id_enfermero AND activo = true
    ) THEN
        p_resultado := 'Error: El enfermero no existe o está inactivo.';
        RETURN;
    END IF;

    -- Calcular nivel de urgencia inline (misma lógica que fn_calcular_nivel_urgencia de B)
    IF (p_frecuencia_cardiaca < 40  OR p_frecuencia_cardiaca > 140) OR
       (p_presion_sistolica   < 80  OR p_presion_sistolica   > 200) OR
       (p_saturacion_o2       < 90) OR
       (p_glasgow             < 9)  OR
       (p_temperatura > 39.5 OR p_temperatura < 35) THEN
        v_nivel := 'ROJO';

    ELSIF (p_frecuencia_cardiaca BETWEEN 40  AND 49  OR p_frecuencia_cardiaca BETWEEN 121 AND 140) OR
          (p_presion_sistolica   BETWEEN 80  AND 89  OR p_presion_sistolica   BETWEEN 180 AND 200) OR
          (p_saturacion_o2       BETWEEN 90  AND 92) OR
          (p_glasgow             BETWEEN 9   AND 12) OR
          (p_temperatura BETWEEN 39.1 AND 39.5 OR p_temperatura BETWEEN 35.0 AND 35.9) THEN
        v_nivel := 'NARANJA';

    ELSIF (p_frecuencia_cardiaca BETWEEN 50  AND 59  OR p_frecuencia_cardiaca BETWEEN 101 AND 120) OR
          (p_presion_sistolica   BETWEEN 90  AND 99  OR p_presion_sistolica   BETWEEN 160 AND 179) OR
          (p_saturacion_o2       BETWEEN 93  AND 94) OR
          (p_glasgow             BETWEEN 13  AND 14) OR
          (p_temperatura BETWEEN 38.5 AND 39.0) THEN
        v_nivel := 'AMARILLO';

    ELSIF (p_frecuencia_cardiaca BETWEEN 60 AND 100)  AND
          (p_presion_sistolica   BETWEEN 100 AND 139) AND
          (p_presion_diastolica  BETWEEN 60  AND 89)  AND
          (p_saturacion_o2       >= 95)               AND
          (p_glasgow             = 15)                AND
          (p_temperatura BETWEEN 36.0 AND 37.5) THEN
        v_nivel := 'VERDE';

    ELSE
        v_nivel := 'AZUL';
    END IF;

    INSERT INTO triajes (
        id_ingreso, id_enfermero, nivel_triaje,
        frecuencia_cardiaca, presion_sistolica, presion_diastolica,
        temperatura, saturacion_o2, glasgow
    ) VALUES (
        p_id_ingreso, p_id_enfermero, v_nivel,
        p_frecuencia_cardiaca, p_presion_sistolica, p_presion_diastolica,
        p_temperatura, p_saturacion_o2, p_glasgow
    )
    RETURNING id_triaje INTO v_id_triaje;

    -- Pasar ingreso a EN_ATENCION si estaba en espera
    UPDATE ingresos
    SET estado = 'EN_ATENCION'
    WHERE id_ingreso = p_id_ingreso AND estado = 'EN_ESPERA';

    p_resultado := 'Triaje registrado correctamente.';
    p_id_triaje := v_id_triaje;

EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
    p_id_triaje := NULL;
END;
$$;


ALTER PROCEDURE public.sp_insertar_triaje(IN p_id_ingreso integer, IN p_id_enfermero integer, IN p_frecuencia_cardiaca integer, IN p_presion_sistolica integer, IN p_presion_diastolica integer, IN p_temperatura numeric, IN p_saturacion_o2 integer, IN p_glasgow integer, OUT p_resultado text, OUT p_id_triaje integer) OWNER TO hospital_admin;

--
-- Name: sp_insertar_usuario(character varying, character varying, integer, character varying, integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_insertar_usuario(IN p_username character varying, IN p_password_hash character varying, IN p_id_rol integer, IN p_cedula_medico character varying, IN p_id_enfermero integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM usuarios WHERE username = p_username) THEN
        p_resultado := 'Error: El username ya existe.';
        RETURN;
    END IF;
    INSERT INTO usuarios(username, password_hash, id_rol,
                         cedula_medico, id_enfermero, activo)
    VALUES(p_username, p_password_hash, p_id_rol,
           p_cedula_medico, p_id_enfermero, true);
    p_resultado := 'Usuario creado correctamente.';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_insertar_usuario(IN p_username character varying, IN p_password_hash character varying, IN p_id_rol integer, IN p_cedula_medico character varying, IN p_id_enfermero integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_log_paciente(text, integer, text); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_log_paciente(IN p_accion text, IN p_id_registro integer, IN p_detalle text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_usuario integer;
BEGIN
    -- Busca el id_usuario que corresponde al usuario actual de la sesión
    SELECT id_usuario INTO v_id_usuario
    FROM usuarios
    WHERE username = current_user
    LIMIT 1;

    -- Fallback: si la conexión viene de hospital_admin u otro rol
    -- sin fila en usuarios, usa el id 1 (admin del sistema)
    IF v_id_usuario IS NULL THEN
        v_id_usuario := 1;
    END IF;

    INSERT INTO log_acceso(id_usuario, accion, tabla_afectada,
                           id_registro, timestamp_accion, detalle)
    VALUES(v_id_usuario, p_accion, 'pacientes',
           p_id_registro, NOW(), p_detalle);

EXCEPTION WHEN OTHERS THEN
    -- El log nunca debe romper la operación principal
    NULL;
END;
$$;


ALTER PROCEDURE public.sp_log_paciente(IN p_accion text, IN p_id_registro integer, IN p_detalle text) OWNER TO hospital_admin;

--
-- Name: sp_login(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_login(IN p_username character varying, OUT p_password_hash character varying, OUT p_rol character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT u.password_hash, r.nombre
    INTO   p_password_hash, p_rol
    FROM   usuarios u JOIN roles r ON r.id_rol = u.id_rol
    WHERE  u.username = p_username AND u.activo = true;
    IF NOT FOUND THEN
        p_resultado := 'Error: Usuario no encontrado.';
    ELSE
        p_resultado := 'OK';
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_login(IN p_username character varying, OUT p_password_hash character varying, OUT p_rol character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_login_usuario(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_login_usuario(IN p_username character varying, OUT p_id_usuario integer, OUT p_password_hash character varying, OUT p_rol character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT u.id_usuario, u.password_hash, r.nombre
    INTO   p_id_usuario, p_password_hash, p_rol
    FROM   usuarios u
    JOIN   roles r ON r.id_rol = u.id_rol
    WHERE  u.username = p_username AND u.activo = true;

    IF NOT FOUND THEN
        p_resultado := 'Error: Usuario no encontrado o inactivo.';
    ELSE
        p_resultado := 'OK';
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_login_usuario(IN p_username character varying, OUT p_id_usuario integer, OUT p_password_hash character varying, OUT p_rol character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_obtener_alergias_expediente(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_alergias_expediente(IN p_id_expediente integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT ca.nombre AS alergia, ca.tipo, ap.severidad, ap.observaciones
        FROM   alergias_paciente ap
        JOIN   cat_alergias ca ON ca.id_alergia = ap.id_alergia
        JOIN   expedientes e ON e.id_paciente = ap.id_paciente
        WHERE  e.id_expediente = p_id_expediente;
END;
$$;


ALTER PROCEDURE public.sp_obtener_alergias_expediente(IN p_id_expediente integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_area_de_beacon(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_area_de_beacon(IN p_id_beacon character varying, OUT p_id_area character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id_area INTO p_id_area
    FROM   beacons WHERE id_beacon = p_id_beacon LIMIT 1;
    IF NOT FOUND THEN
        p_resultado := 'Error: Beacon no encontrado.';
        p_id_area   := NULL;
    ELSE
        p_resultado := 'OK';
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_obtener_area_de_beacon(IN p_id_beacon character varying, OUT p_id_area character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_obtener_areas(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_areas(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT a.id_area, a.nombre_area, ta.nombre AS tipo,
               a.capacidad, a.activo,
               COALESCE(aa.personas_actuales, 0) AS ocupacion_actual,
               pi.nombre_piso
        FROM   areas a
        JOIN   tipos_area ta ON ta.id_tipo_area = a.id_tipo_area
        LEFT JOIN pisos pi ON pi.id_piso = a.id_piso
        LEFT JOIN (
            SELECT id_area, COUNT(*) AS personas_actuales
            FROM   asignaciones_area WHERE activo = true GROUP BY id_area
        ) aa ON aa.id_area = a.id_area
        ORDER  BY a.nombre_area;
END;
$$;


ALTER PROCEDURE public.sp_obtener_areas(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_areas_lista(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_areas_lista(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_area, nombre_area FROM areas ORDER BY nombre_area;
END;
$$;


ALTER PROCEDURE public.sp_obtener_areas_lista(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_beacon(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_beacon(IN p_id_beacon character varying, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT * FROM beacons WHERE id_beacon = p_id_beacon;
END;
$$;


ALTER PROCEDURE public.sp_obtener_beacon(IN p_id_beacon character varying, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_beacons(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_beacons(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT b.id_beacon, b.nombre, b.uuid_beacon, b.estado,
               TO_CHAR(b.fecha_instalacion,'YYYY-MM-DD') AS fecha_instalacion,
               a.nombre_area AS area,
               mb.protocolo, mb.fabricante, mb.modelo
        FROM   beacons b
        JOIN   areas a ON a.id_area = b.id_area
        JOIN   modelos_beacon mb ON mb.id_modelo = b.id_modelo
        ORDER  BY b.id_beacon;
END;
$$;


ALTER PROCEDURE public.sp_obtener_beacons(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_consultorios(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_consultorios(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT c.id_consultorio, c.numero, c.nombre,
               esp.nombre AS especialidad,
               m.nombre||' '||m.apellidop AS medico,
               m.cedula_medico AS cedula,
               COALESCE(m.foto,
                   'https://ui-avatars.com/api/?name='||m.nombre||'+'||m.apellidop
                   ||'&background=4f46e5&color=fff&size=128') AS foto,
               c.activo, b.id_beacon
        FROM   consultorios c
        JOIN   areas a ON a.id_area = c.id_area
        LEFT JOIN medicos m ON m.cedula_medico = c.cedula_medico
        LEFT JOIN especialidades esp ON esp.id_especialidad = m.id_especialidad
        LEFT JOIN beacons b ON b.id_area = c.id_area
        WHERE  c.activo = true
        ORDER  BY c.numero;
END;
$$;


ALTER PROCEDURE public.sp_obtener_consultorios(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_especialidades(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_especialidades(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_especialidad, nombre FROM especialidades ORDER BY nombre;
END;
$$;


ALTER PROCEDURE public.sp_obtener_especialidades(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_estancias_ingreso(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_estancias_ingreso(IN p_id_ingreso integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT a.nombre_area AS area,
               TO_CHAR(es.timestamp_entrada,'YYYY-MM-DD HH24:MI') AS entrada,
               TO_CHAR(es.timestamp_salida, 'YYYY-MM-DD HH24:MI') AS salida,
               es.duracion_min, es.fuente_verdad AS fuente
        FROM   estancias es JOIN areas a ON a.id_area = es.id_area
        WHERE  es.id_ingreso = p_id_ingreso
        ORDER  BY es.timestamp_entrada;
END;
$$;


ALTER PROCEDURE public.sp_obtener_estancias_ingreso(IN p_id_ingreso integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_expediente_detalle(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_expediente_detalle(IN p_id_expediente integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT e.*,
               p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS paciente_nombre,
               p.curp, p.tipo_sangre, p.sexo, p.telefono, p.email,
               COALESCE(p.foto,
                   'https://ui-avatars.com/api/?name='||p.nombre||'+'||p.apellidop
                   ||'&background=6366f1&color=fff&size=128') AS foto,
               m.nombre||' '||m.apellidop AS medico_nombre
        FROM   expedientes e
        JOIN   pacientes p ON p.id_paciente = e.id_paciente
        JOIN   medicos m ON m.cedula_medico = e.medico_titular
        WHERE  e.id_expediente = p_id_expediente;
END;
$$;


ALTER PROCEDURE public.sp_obtener_expediente_detalle(IN p_id_expediente integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_ingreso_detalle(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_ingreso_detalle(IN p_id_ingreso integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT i.id_ingreso, ex.num_expediente AS expediente,
               p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS paciente,
               COALESCE(p.foto,
                   'https://ui-avatars.com/api/?name='||p.nombre||'+'||p.apellidop
                   ||'&background=6366f1&color=fff&size=128') AS foto,
               m.nombre||' '||m.apellidop AS medico,
               i.tipo_ingreso, i.motivo_ingreso, i.estado, i.tiempo_espera_min,
               ROUND(EXTRACT(EPOCH FROM (NOW()-i.fecha_ingreso))/60) AS min_desde_ingreso,
               a.nombre_area AS area_actual,
               i.id_expediente, i.cedula_medico
        FROM   ingresos i
        JOIN   expedientes ex ON ex.id_expediente = i.id_expediente
        JOIN   pacientes p ON p.id_paciente = ex.id_paciente
        JOIN   medicos m ON m.cedula_medico = i.cedula_medico
        LEFT JOIN estancias es ON es.id_ingreso = i.id_ingreso AND es.timestamp_salida IS NULL
        LEFT JOIN areas a ON a.id_area = es.id_area
        WHERE  i.id_ingreso = p_id_ingreso;
END;
$$;


ALTER PROCEDURE public.sp_obtener_ingreso_detalle(IN p_id_ingreso integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_ingresos(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_ingresos(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT i.id_ingreso, e.num_expediente AS expediente,
               p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS paciente,
               COALESCE(p.foto,
                   'https://ui-avatars.com/api/?name='||p.nombre||'+'||p.apellidop
                   ||'&background=6366f1&color=fff&size=128') AS foto,
               m.nombre||' '||m.apellidop AS medico,
               i.tipo_ingreso, i.motivo_ingreso,
               TO_CHAR(i.fecha_ingreso,'YYYY-MM-DD HH24:MI') AS fecha_ingreso,
               i.estado, i.tiempo_espera_min
        FROM   ingresos i
        JOIN   expedientes e ON e.id_expediente = i.id_expediente
        JOIN   pacientes   p ON p.id_paciente   = e.id_paciente
        JOIN   medicos     m ON m.cedula_medico  = i.cedula_medico
        ORDER  BY i.fecha_ingreso DESC;
END;
$$;


ALTER PROCEDURE public.sp_obtener_ingresos(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_ingresos_expediente(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_ingresos_expediente(IN p_id_expediente integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT i.id_ingreso, i.tipo_ingreso, i.motivo_ingreso,
               TO_CHAR(i.fecha_ingreso,'YYYY-MM-DD HH24:MI') AS fecha_ingreso,
               i.estado, i.tiempo_espera_min,
               m.nombre||' '||m.apellidop AS medico
        FROM   ingresos i JOIN medicos m ON m.cedula_medico = i.cedula_medico
        WHERE  i.id_expediente = p_id_expediente
        ORDER  BY i.fecha_ingreso DESC;
END;
$$;


ALTER PROCEDURE public.sp_obtener_ingresos_expediente(IN p_id_expediente integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_medico(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_medico(IN p_cedula character varying, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT m.*, esp.nombre AS especialidad_nombre
        FROM   medicos m
        JOIN   especialidades esp ON esp.id_especialidad = m.id_especialidad
        WHERE  m.cedula_medico = p_cedula;
END;
$$;


ALTER PROCEDURE public.sp_obtener_medico(IN p_cedula character varying, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_medicos(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_medicos(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT m.cedula_medico, m.nombre, m.apellidop, m.apellidom,
               esp.nombre AS especialidad,
               m.telefono, m.email, m.activo,
               COALESCE(m.foto,
                   'https://ui-avatars.com/api/?name='||m.nombre||'+'||m.apellidop
                   ||'&background=4f46e5&color=fff&size=128') AS foto
        FROM   medicos m
        JOIN   especialidades esp ON esp.id_especialidad = m.id_especialidad
        ORDER  BY m.apellidop, m.nombre;
END;
$$;


ALTER PROCEDURE public.sp_obtener_medicos(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_medicos_activos(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_medicos_activos(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT cedula_medico,
               nombre||' '||apellidop AS nombre
        FROM   medicos WHERE activo = true ORDER BY apellidop;
END;
$$;


ALTER PROCEDURE public.sp_obtener_medicos_activos(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_modelos_beacon(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_modelos_beacon(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_modelo, fabricante, modelo, protocolo
        FROM   modelos_beacon ORDER BY fabricante;
END;
$$;


ALTER PROCEDURE public.sp_obtener_modelos_beacon(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_pacientes(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_pacientes(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
    SELECT p.id_paciente, p.curp, p.nombre, p.apellidop, p.apellidom,
           p.fecha_nac, p.sexo, p.tipo_sangre, p.telefono, p.email,
           p.foto,
           e.num_expediente AS expediente
    FROM pacientes p
    LEFT JOIN expedientes e ON e.id_paciente = p.id_paciente
    ORDER BY p.id_paciente;
END;
$$;


ALTER PROCEDURE public.sp_obtener_pacientes(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_pacientes_lista(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_pacientes_lista(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT p.id_paciente,
               p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS nombre_completo,
               e.num_expediente
        FROM   pacientes p
        LEFT JOIN expedientes e ON e.id_paciente=p.id_paciente AND e.activo=true
        ORDER  BY p.apellidop, p.nombre;
END;
$$;


ALTER PROCEDURE public.sp_obtener_pacientes_lista(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_pisos(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_pisos(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_piso, nombre_piso AS nombre FROM pisos ORDER BY nombre_piso;
END;
$$;


ALTER PROCEDURE public.sp_obtener_pisos(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_roles(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_roles(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_rol, nombre FROM roles ORDER BY nombre;
END;
$$;


ALTER PROCEDURE public.sp_obtener_roles(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_timeline_ingreso(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_timeline_ingreso(IN p_id_ingreso integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT TO_CHAR(ev.timestamp_evento,'YYYY-MM-DD HH24:MI') AS timestamp_evento,
               tev.nombre AS evento, b.id_beacon AS beacon,
               a.nombre_area AS area, ev.rssi_signal
        FROM   eventos ev
        JOIN   tipos_evento tev ON tev.id_tipo_evento = ev.id_tipo_evento
        LEFT JOIN beacons b ON b.id_beacon = ev.id_beacon
        LEFT JOIN areas a ON a.id_area = b.id_area
        WHERE  ev.id_ingreso = p_id_ingreso
        ORDER  BY ev.timestamp_evento;
END;
$$;


ALTER PROCEDURE public.sp_obtener_timeline_ingreso(IN p_id_ingreso integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_tipos_area(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_tipos_area(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT id_tipo_area, nombre FROM tipos_area ORDER BY nombre;
END;
$$;


ALTER PROCEDURE public.sp_obtener_tipos_area(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_triajes(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_triajes(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT t.id_triaje, e.num_expediente AS expediente,
               p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,'') AS paciente,
               COALESCE(p.foto,
                   'https://ui-avatars.com/api/?name='||p.nombre||'+'||p.apellidop
                   ||'&background=6366f1&color=fff&size=128') AS foto,
               t.nivel_triaje AS nivel,
               t.frecuencia_cardiaca, t.presion_sistolica, t.presion_diastolica,
               t.temperatura, t.saturacion_o2, t.glasgow,
               TO_CHAR(t.timestamp_triaje,'YYYY-MM-DD HH24:MI') AS timestamp_triaje,
               t.id_ingreso, t.id_enfermero,
               COALESCE(pe.nombre||' '||pe.apellidop, '—') AS enfermero
        FROM   triajes t
        JOIN   ingresos i ON i.id_ingreso = t.id_ingreso
        JOIN   expedientes ex ON ex.id_expediente = i.id_expediente
        JOIN   pacientes p ON p.id_paciente = ex.id_paciente
        JOIN   expedientes e ON e.id_expediente = i.id_expediente
        LEFT JOIN personal_enfermeria pe ON pe.id_enfermero = t.id_enfermero
        ORDER  BY t.timestamp_triaje DESC;
END;
$$;


ALTER PROCEDURE public.sp_obtener_triajes(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_triajes_expediente(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_triajes_expediente(IN p_id_expediente integer, OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT t.id_triaje, t.nivel_triaje AS nivel,
               TO_CHAR(t.timestamp_triaje,'YYYY-MM-DD HH24:MI') AS timestamp_triaje,
               t.frecuencia_cardiaca, t.presion_sistolica, t.presion_diastolica,
               t.temperatura, t.saturacion_o2, t.glasgow,
               COALESCE(pe.nombre||' '||pe.apellidop, '—') AS enfermero
        FROM   triajes t
        JOIN   ingresos i ON i.id_ingreso = t.id_ingreso
        LEFT JOIN personal_enfermeria pe ON pe.id_enfermero = t.id_enfermero
        WHERE  i.id_expediente = p_id_expediente
        ORDER  BY t.timestamp_triaje DESC;
END;
$$;


ALTER PROCEDURE public.sp_obtener_triajes_expediente(IN p_id_expediente integer, OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_obtener_usuarios(); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_obtener_usuarios(OUT p_resultado refcursor)
    LANGUAGE plpgsql
    AS $$
BEGIN
    OPEN p_resultado FOR
        SELECT u.id_usuario, u.username, r.nombre AS rol,
               u.cedula_medico, u.id_enfermero, u.activo
        FROM   usuarios u
        JOIN   roles r ON r.id_rol = u.id_rol
        ORDER  BY u.username;
END;
$$;


ALTER PROCEDURE public.sp_obtener_usuarios(OUT p_resultado refcursor) OWNER TO hospital_admin;

--
-- Name: sp_registrar_evento(integer, character varying, character varying, smallint); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_registrar_evento(IN p_id_ingreso integer, IN p_id_beacon character varying, IN p_tipo_nombre character varying, IN p_rssi smallint, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_tipo INTEGER;
BEGIN
    SELECT id_tipo_evento INTO v_id_tipo
    FROM tipos_evento WHERE nombre = p_tipo_nombre LIMIT 1;

    IF v_id_tipo IS NULL THEN
        p_resultado := 'Error: Tipo de evento no encontrado.';
        RETURN;
    END IF;

    INSERT INTO eventos(id_ingreso, id_beacon, id_tipo_evento,
                        timestamp_evento, rssi_signal)
    VALUES(p_id_ingreso, p_id_beacon, v_id_tipo, NOW(), p_rssi);
    p_resultado := 'OK';
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_registrar_evento(IN p_id_ingreso integer, IN p_id_beacon character varying, IN p_tipo_nombre character varying, IN p_rssi smallint, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_registrar_nfc(character varying); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_registrar_nfc(IN p_uid_hex character varying, OUT p_id_paciente integer, OUT p_nombre text, OUT p_foto text, OUT p_num_expediente character varying, OUT p_id_expediente integer, OUT p_medico_titular character varying, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT p.id_paciente,
           p.nombre||' '||p.apellidop||COALESCE(' '||p.apellidom,''),
           COALESCE(p.foto,
               'https://ui-avatars.com/api/?name='||p.nombre||'+'||p.apellidop
               ||'&background=6366f1&color=fff&size=128'),
           e.num_expediente,
           e.id_expediente,
           e.medico_titular
    INTO   p_id_paciente, p_nombre, p_foto,
           p_num_expediente, p_id_expediente, p_medico_titular
    FROM   tarjetas_nfc t
    JOIN   pacientes p ON p.id_paciente = t.id_paciente
    LEFT JOIN expedientes e ON e.id_paciente = p.id_paciente AND e.activo = true
    WHERE  t.uid_hex = p_uid_hex
    LIMIT  1;

    IF NOT FOUND THEN
        p_resultado := 'Error: UID no registrado en tarjetas_nfc.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_registrar_nfc(IN p_uid_hex character varying, OUT p_id_paciente integer, OUT p_nombre text, OUT p_foto text, OUT p_num_expediente character varying, OUT p_id_expediente integer, OUT p_medico_titular character varying, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_resolver_alerta(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_resolver_alerta(IN p_id_alerta integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE alertas_saturacion
    SET resuelta = true, timestamp_resolucion = NOW()
    WHERE id_alerta = p_id_alerta;
    IF NOT FOUND THEN
        p_resultado := 'Error: Alerta no encontrada.';
    ELSE
        p_resultado := 'Alerta resuelta correctamente.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_resolver_alerta(IN p_id_alerta integer, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_toggle_usuario(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_toggle_usuario(IN p_id_usuario integer, OUT p_activo boolean, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE usuarios SET activo = NOT activo
    WHERE id_usuario = p_id_usuario AND username != 'admin'
    RETURNING activo INTO p_activo;
    IF NOT FOUND THEN
        p_resultado := 'Error: Usuario no encontrado o es admin.';
    ELSE
        p_resultado := 'OK';
    END IF;
EXCEPTION WHEN OTHERS THEN
    p_resultado := 'Error: ' || SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_toggle_usuario(IN p_id_usuario integer, OUT p_activo boolean, OUT p_resultado text) OWNER TO hospital_admin;

--
-- Name: sp_verificar_ingreso_activo(integer); Type: PROCEDURE; Schema: public; Owner: hospital_admin
--

CREATE PROCEDURE public.sp_verificar_ingreso_activo(IN p_id_expediente integer, OUT p_id_ingreso integer, OUT p_resultado text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    SELECT id_ingreso INTO p_id_ingreso
    FROM   ingresos
    WHERE  id_expediente = p_id_expediente
      AND  estado = 'EN_ESPERA'
    ORDER  BY fecha_ingreso DESC
    LIMIT  1;

    IF NOT FOUND THEN
        p_id_ingreso := NULL;
        p_resultado  := 'SIN_INGRESO';
    ELSE
        p_resultado  := 'CON_INGRESO';
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_verificar_ingreso_activo(IN p_id_expediente integer, OUT p_id_ingreso integer, OUT p_resultado text) OWNER TO hospital_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alergias_paciente; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.alergias_paciente (
    id_paciente integer NOT NULL,
    id_alergia integer NOT NULL,
    severidad character varying(20) NOT NULL,
    observaciones character varying(200),
    CONSTRAINT alergias_paciente_severidad_check CHECK (((severidad)::text = ANY (ARRAY[('LEVE'::character varying)::text, ('MODERADA'::character varying)::text, ('SEVERA'::character varying)::text, ('ANAFILACTICA'::character varying)::text])))
);


ALTER TABLE public.alergias_paciente OWNER TO hospital_admin;

--
-- Name: alertas_saturacion; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.alertas_saturacion (
    id_alerta integer NOT NULL,
    id_umbral integer NOT NULL,
    id_area character varying(10) NOT NULL,
    timestamp_alerta timestamp without time zone DEFAULT now() NOT NULL,
    valor_detectado numeric(8,2) NOT NULL,
    resuelta boolean DEFAULT false NOT NULL,
    timestamp_resolucion timestamp without time zone,
    CONSTRAINT alertas_saturacion_check CHECK ((timestamp_resolucion >= timestamp_alerta))
);


ALTER TABLE public.alertas_saturacion OWNER TO hospital_admin;

--
-- Name: alertas_saturacion_id_alerta_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.alertas_saturacion ALTER COLUMN id_alerta ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.alertas_saturacion_id_alerta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: antecedentes; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.antecedentes (
    id_antecedente integer NOT NULL,
    id_expediente integer NOT NULL,
    tipo character varying(40) NOT NULL,
    descripcion character varying(300) NOT NULL,
    fecha_registro date DEFAULT CURRENT_DATE NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT antecedentes_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('CRONICO'::character varying)::text, ('QUIRURGICO'::character varying)::text, ('FAMILIAR'::character varying)::text, ('ALERGICO'::character varying)::text, ('TRAUMATICO'::character varying)::text, ('OTRO'::character varying)::text])))
);


ALTER TABLE public.antecedentes OWNER TO hospital_admin;

--
-- Name: antecedentes_id_antecedente_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.antecedentes ALTER COLUMN id_antecedente ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.antecedentes_id_antecedente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: area_servicio; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.area_servicio (
    id_area character varying(10) NOT NULL,
    id_servicio integer NOT NULL
);


ALTER TABLE public.area_servicio OWNER TO hospital_admin;

--
-- Name: areas; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.areas (
    id_area character varying(10) NOT NULL,
    id_piso integer NOT NULL,
    id_tipo_area integer NOT NULL,
    nombre_area character varying(100) NOT NULL,
    capacidad integer NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT areas_capacidad_check CHECK ((capacidad > 0))
);


ALTER TABLE public.areas OWNER TO hospital_admin;

--
-- Name: aseguradoras; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.aseguradoras (
    id_aseguradora integer NOT NULL,
    nombre character varying(150) NOT NULL,
    tipo character varying(30) NOT NULL,
    telefono character varying(20),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT aseguradoras_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('PUBLICA'::character varying)::text, ('PRIVADA'::character varying)::text])))
);


ALTER TABLE public.aseguradoras OWNER TO hospital_admin;

--
-- Name: aseguradoras_id_aseguradora_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.aseguradoras ALTER COLUMN id_aseguradora ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.aseguradoras_id_aseguradora_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: asignaciones_area; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.asignaciones_area (
    id_asignacion integer NOT NULL,
    id_enfermero integer NOT NULL,
    id_area character varying(10) NOT NULL,
    id_turno integer NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT asignaciones_area_check CHECK ((fecha_fin >= fecha_inicio))
);


ALTER TABLE public.asignaciones_area OWNER TO hospital_admin;

--
-- Name: asignaciones_area_id_asignacion_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.asignaciones_area ALTER COLUMN id_asignacion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.asignaciones_area_id_asignacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: beacons; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.beacons (
    id_beacon character varying(10) NOT NULL,
    id_area character varying(10) NOT NULL,
    id_modelo integer NOT NULL,
    uuid_beacon character varying(50) NOT NULL,
    nombre character varying(100) NOT NULL,
    estado character varying(20) DEFAULT 'ACTIVO'::character varying NOT NULL,
    fecha_instalacion date,
    CONSTRAINT beacons_estado_check CHECK (((estado)::text = ANY (ARRAY[('ACTIVO'::character varying)::text, ('INACTIVO'::character varying)::text, ('MANTENIMIENTO'::character varying)::text])))
);


ALTER TABLE public.beacons OWNER TO hospital_admin;

--
-- Name: cat_alergias; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.cat_alergias (
    id_alergia integer NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo character varying(40) NOT NULL,
    CONSTRAINT cat_alergias_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('MEDICAMENTO'::character varying)::text, ('ALIMENTO'::character varying)::text, ('AMBIENTAL'::character varying)::text, ('LATEX'::character varying)::text, ('OTRO'::character varying)::text])))
);


ALTER TABLE public.cat_alergias OWNER TO hospital_admin;

--
-- Name: cat_alergias_id_alergia_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.cat_alergias ALTER COLUMN id_alergia ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cat_alergias_id_alergia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cat_diagnosticos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.cat_diagnosticos (
    id_diagnostico integer NOT NULL,
    codigo_cie10 character varying(10) NOT NULL,
    nombre character varying(200) NOT NULL,
    categoria character varying(100)
);


ALTER TABLE public.cat_diagnosticos OWNER TO hospital_admin;

--
-- Name: cat_diagnosticos_id_diagnostico_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.cat_diagnosticos ALTER COLUMN id_diagnostico ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.cat_diagnosticos_id_diagnostico_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: citas; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.citas (
    id_cita integer NOT NULL,
    id_horario integer NOT NULL,
    id_expediente integer NOT NULL,
    fecha_cita date NOT NULL,
    hora_cita time without time zone NOT NULL,
    id_estado integer NOT NULL,
    motivo character varying(255) NOT NULL,
    observaciones text,
    fecha_registro timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.citas OWNER TO hospital_admin;

--
-- Name: citas_id_cita_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.citas ALTER COLUMN id_cita ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.citas_id_cita_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: consultorios; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.consultorios (
    id_consultorio integer NOT NULL,
    id_area character varying(10) NOT NULL,
    cedula_medico character varying(20),
    nombre character varying(80) NOT NULL,
    numero character varying(10) NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.consultorios OWNER TO hospital_admin;

--
-- Name: consultorios_id_consultorio_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.consultorios ALTER COLUMN id_consultorio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.consultorios_id_consultorio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contactos_emergencia; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.contactos_emergencia (
    id_contacto integer NOT NULL,
    id_paciente integer NOT NULL,
    nombre character varying(120) NOT NULL,
    parentesco character varying(50) NOT NULL,
    telefono character varying(20) NOT NULL,
    es_principal boolean DEFAULT false NOT NULL
);


ALTER TABLE public.contactos_emergencia OWNER TO hospital_admin;

--
-- Name: contactos_emergencia_id_contacto_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.contactos_emergencia ALTER COLUMN id_contacto ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.contactos_emergencia_id_contacto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: diagnosticos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.diagnosticos (
    id_reg_dx integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_diagnostico integer NOT NULL,
    cedula_medico character varying(20) NOT NULL,
    tipo character varying(20) NOT NULL,
    timestamp_dx timestamp without time zone DEFAULT now() NOT NULL,
    notas text,
    CONSTRAINT diagnosticos_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('PRESUNTIVO'::character varying)::text, ('DEFINITIVO'::character varying)::text, ('DIFERENCIAL'::character varying)::text])))
);


ALTER TABLE public.diagnosticos OWNER TO hospital_admin;

--
-- Name: diagnosticos_id_reg_dx_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.diagnosticos ALTER COLUMN id_reg_dx ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.diagnosticos_id_reg_dx_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dias_semana; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.dias_semana (
    id_dia smallint NOT NULL,
    nombre character varying(15) NOT NULL,
    CONSTRAINT dias_semana_id_dia_check CHECK (((id_dia >= 1) AND (id_dia <= 7)))
);


ALTER TABLE public.dias_semana OWNER TO hospital_admin;

--
-- Name: edificios; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.edificios (
    id_edificio integer NOT NULL,
    id_hospital integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255)
);


ALTER TABLE public.edificios OWNER TO hospital_admin;

--
-- Name: edificios_id_edificio_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.edificios_id_edificio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.edificios_id_edificio_seq OWNER TO hospital_admin;

--
-- Name: edificios_id_edificio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.edificios_id_edificio_seq OWNED BY public.edificios.id_edificio;


--
-- Name: especialidades; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.especialidades (
    id_especialidad integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(200)
);


ALTER TABLE public.especialidades OWNER TO hospital_admin;

--
-- Name: especialidades_id_especialidad_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.especialidades ALTER COLUMN id_especialidad ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.especialidades_id_especialidad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estados_cita; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.estados_cita (
    id_estado integer NOT NULL,
    nombre character varying(40) NOT NULL,
    descripcion character varying(150)
);


ALTER TABLE public.estados_cita OWNER TO hospital_admin;

--
-- Name: estados_cita_id_estado_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.estados_cita ALTER COLUMN id_estado ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.estados_cita_id_estado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estancias; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.estancias (
    id_estancia integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_area character varying(10) NOT NULL,
    timestamp_entrada timestamp without time zone NOT NULL,
    timestamp_salida timestamp without time zone,
    duracion_min numeric(8,2),
    fuente_verdad character varying(10) DEFAULT 'BEACON'::character varying NOT NULL,
    CONSTRAINT estancias_check CHECK ((timestamp_salida > timestamp_entrada)),
    CONSTRAINT estancias_duracion_min_check CHECK ((duracion_min >= (0)::numeric)),
    CONSTRAINT estancias_fuente_verdad_check CHECK (((fuente_verdad)::text = ANY (ARRAY[('BEACON'::character varying)::text, ('MANUAL'::character varying)::text, ('SISTEMA'::character varying)::text])))
);


ALTER TABLE public.estancias OWNER TO hospital_admin;

--
-- Name: estancias_id_estancia_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.estancias ALTER COLUMN id_estancia ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.estancias_id_estancia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: eventos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.eventos (
    id_evento bigint NOT NULL,
    id_ingreso integer NOT NULL,
    id_beacon character varying(10) NOT NULL,
    id_tipo_evento integer NOT NULL,
    timestamp_evento timestamp without time zone DEFAULT now() NOT NULL,
    rssi_signal smallint,
    CONSTRAINT eventos_rssi_signal_check CHECK (((rssi_signal >= '-120'::integer) AND (rssi_signal <= 0)))
);


ALTER TABLE public.eventos OWNER TO hospital_admin;

--
-- Name: eventos_id_evento_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.eventos ALTER COLUMN id_evento ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.eventos_id_evento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: expedientes; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.expedientes (
    id_expediente integer NOT NULL,
    num_expediente character varying(30) NOT NULL,
    id_paciente integer NOT NULL,
    id_hospital integer NOT NULL,
    medico_titular character varying(20) NOT NULL,
    fecha_apertura date DEFAULT CURRENT_DATE NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    notas_iniciales text
);


ALTER TABLE public.expedientes OWNER TO hospital_admin;

--
-- Name: expedientes_id_expediente_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.expedientes ALTER COLUMN id_expediente ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.expedientes_id_expediente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: historial_estados_ingreso; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.historial_estados_ingreso (
    id_historial integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_usuario integer NOT NULL,
    timestamp_cambio timestamp without time zone DEFAULT now() NOT NULL,
    estado_anterior character varying(30) NOT NULL,
    estado_nuevo character varying(30) NOT NULL,
    motivo text,
    ip_origen character varying(45)
);


ALTER TABLE public.historial_estados_ingreso OWNER TO hospital_admin;

--
-- Name: historial_estados_ingreso_id_historial_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.historial_estados_ingreso_id_historial_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historial_estados_ingreso_id_historial_seq OWNER TO hospital_admin;

--
-- Name: historial_estados_ingreso_id_historial_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.historial_estados_ingreso_id_historial_seq OWNED BY public.historial_estados_ingreso.id_historial;


--
-- Name: horarios_medico; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.horarios_medico (
    id_horario integer NOT NULL,
    id_consultorio integer NOT NULL,
    id_turno integer NOT NULL,
    id_dia smallint NOT NULL,
    max_pacientes smallint NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT horarios_medico_max_pacientes_check CHECK ((max_pacientes > 0))
);


ALTER TABLE public.horarios_medico OWNER TO hospital_admin;

--
-- Name: horarios_medico_id_horario_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.horarios_medico ALTER COLUMN id_horario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.horarios_medico_id_horario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hospitales; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.hospitales (
    id_hospital integer NOT NULL,
    nombre character varying(150) NOT NULL,
    direccion character varying(255) NOT NULL,
    telefono character varying(20),
    rfc character varying(15),
    tipo_hospital character varying(50) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT hospitales_tipo_hospital_check CHECK (((tipo_hospital)::text = ANY (ARRAY[('PUBLICO'::character varying)::text, ('PRIVADO'::character varying)::text, ('MIXTO'::character varying)::text])))
);


ALTER TABLE public.hospitales OWNER TO hospital_admin;

--
-- Name: hospitales_id_hospital_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.hospitales_id_hospital_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hospitales_id_hospital_seq OWNER TO hospital_admin;

--
-- Name: hospitales_id_hospital_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.hospitales_id_hospital_seq OWNED BY public.hospitales.id_hospital;


--
-- Name: ingresos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.ingresos (
    id_ingreso integer NOT NULL,
    id_expediente integer NOT NULL,
    cedula_medico character varying(20) NOT NULL,
    id_cita integer,
    tipo_ingreso character varying(20) NOT NULL,
    motivo_ingreso character varying(255) NOT NULL,
    fecha_ingreso timestamp without time zone DEFAULT now() NOT NULL,
    estado character varying(20) DEFAULT 'EN_ESPERA'::character varying NOT NULL,
    fecha_egreso timestamp without time zone,
    tiempo_espera_min numeric(8,2),
    CONSTRAINT ingresos_check CHECK ((fecha_egreso > fecha_ingreso)),
    CONSTRAINT ingresos_estado_check CHECK (((estado)::text = ANY (ARRAY[('EN_ESPERA'::character varying)::text, ('EN_ATENCION'::character varying)::text, ('COMPLETADO'::character varying)::text, ('ALTA'::character varying)::text, ('TRASLADADO'::character varying)::text]))),
    CONSTRAINT ingresos_tiempo_espera_min_check CHECK ((tiempo_espera_min >= (0)::numeric)),
    CONSTRAINT ingresos_tipo_ingreso_check CHECK (((tipo_ingreso)::text = ANY (ARRAY[('URGENCIA'::character varying)::text, ('PROGRAMADO'::character varying)::text, ('TRASLADO'::character varying)::text, ('REINGRESO'::character varying)::text])))
);


ALTER TABLE public.ingresos OWNER TO hospital_admin;

--
-- Name: ingresos_id_ingreso_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.ingresos ALTER COLUMN id_ingreso ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.ingresos_id_ingreso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: log_acceso; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.log_acceso (
    id_log bigint NOT NULL,
    id_usuario integer NOT NULL,
    accion character varying(100) NOT NULL,
    tabla_afectada character varying(60) NOT NULL,
    id_registro bigint,
    timestamp_accion timestamp without time zone DEFAULT now() NOT NULL,
    detalle text
);


ALTER TABLE public.log_acceso OWNER TO hospital_admin;

--
-- Name: log_acceso_id_log_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.log_acceso ALTER COLUMN id_log ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.log_acceso_id_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mantenimientos_beacon; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.mantenimientos_beacon (
    id_mantenimiento integer NOT NULL,
    id_beacon character varying(10) NOT NULL,
    fecha_inicio timestamp without time zone NOT NULL,
    fecha_fin timestamp without time zone,
    tipo_mantenimiento character varying(50) NOT NULL,
    descripcion character varying(255),
    responsable character varying(100) NOT NULL,
    CONSTRAINT mantenimientos_beacon_check CHECK ((fecha_fin > fecha_inicio)),
    CONSTRAINT mantenimientos_beacon_tipo_mantenimiento_check CHECK (((tipo_mantenimiento)::text = ANY (ARRAY[('PREVENTIVO'::character varying)::text, ('CORRECTIVO'::character varying)::text, ('CALIBRACION'::character varying)::text])))
);


ALTER TABLE public.mantenimientos_beacon OWNER TO hospital_admin;

--
-- Name: mantenimientos_beacon_id_mantenimiento_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.mantenimientos_beacon_id_mantenimiento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mantenimientos_beacon_id_mantenimiento_seq OWNER TO hospital_admin;

--
-- Name: mantenimientos_beacon_id_mantenimiento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.mantenimientos_beacon_id_mantenimiento_seq OWNED BY public.mantenimientos_beacon.id_mantenimiento;


--
-- Name: medicos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.medicos (
    cedula_medico character varying(20) NOT NULL,
    nombre character varying(60) NOT NULL,
    apellidop character varying(60) NOT NULL,
    apellidom character varying(60),
    id_especialidad integer NOT NULL,
    telefono character varying(20),
    email character varying(100),
    activo boolean DEFAULT true NOT NULL,
    foto text,
    CONSTRAINT medicos_email_check CHECK (((email)::text ~~ '%@%'::text))
);


ALTER TABLE public.medicos OWNER TO hospital_admin;

--
-- Name: metricas_consultorio; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.metricas_consultorio (
    id_metrica_cons integer NOT NULL,
    id_consultorio integer NOT NULL,
    fecha date NOT NULL,
    citas_programadas integer DEFAULT 0 NOT NULL,
    citas_realizadas integer DEFAULT 0 NOT NULL,
    citas_canceladas integer DEFAULT 0 NOT NULL,
    CONSTRAINT metricas_consultorio_citas_canceladas_check CHECK ((citas_canceladas >= 0)),
    CONSTRAINT metricas_consultorio_citas_programadas_check CHECK ((citas_programadas >= 0)),
    CONSTRAINT metricas_consultorio_citas_realizadas_check CHECK ((citas_realizadas >= 0))
);


ALTER TABLE public.metricas_consultorio OWNER TO hospital_admin;

--
-- Name: metricas_consultorio_id_metrica_cons_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.metricas_consultorio ALTER COLUMN id_metrica_cons ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.metricas_consultorio_id_metrica_cons_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: metricas_diarias; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.metricas_diarias (
    id_metrica integer NOT NULL,
    id_area character varying(10) NOT NULL,
    fecha date NOT NULL,
    total_ingresos integer DEFAULT 0 NOT NULL,
    tiempo_espera_prom numeric(6,2),
    tiempo_estancia_prom numeric(6,2),
    CONSTRAINT metricas_diarias_tiempo_espera_prom_check CHECK ((tiempo_espera_prom >= (0)::numeric)),
    CONSTRAINT metricas_diarias_tiempo_estancia_prom_check CHECK ((tiempo_estancia_prom >= (0)::numeric)),
    CONSTRAINT metricas_diarias_total_ingresos_check CHECK ((total_ingresos >= 0))
);


ALTER TABLE public.metricas_diarias OWNER TO hospital_admin;

--
-- Name: metricas_diarias_id_metrica_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.metricas_diarias ALTER COLUMN id_metrica ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.metricas_diarias_id_metrica_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: metricas_medico; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.metricas_medico (
    id_metrica_med integer NOT NULL,
    cedula_medico character varying(20) NOT NULL,
    fecha date NOT NULL,
    total_pacientes integer DEFAULT 0 NOT NULL,
    tiempo_consulta_prom numeric(6,2),
    CONSTRAINT metricas_medico_tiempo_consulta_prom_check CHECK ((tiempo_consulta_prom >= (0)::numeric)),
    CONSTRAINT metricas_medico_total_pacientes_check CHECK ((total_pacientes >= 0))
);


ALTER TABLE public.metricas_medico OWNER TO hospital_admin;

--
-- Name: metricas_medico_id_metrica_med_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.metricas_medico ALTER COLUMN id_metrica_med ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.metricas_medico_id_metrica_med_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: modelos_beacon; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.modelos_beacon (
    id_modelo integer NOT NULL,
    fabricante character varying(100) NOT NULL,
    modelo character varying(100) NOT NULL,
    protocolo character varying(30) NOT NULL,
    rango_metros smallint NOT NULL,
    CONSTRAINT modelos_beacon_protocolo_check CHECK (((protocolo)::text = ANY (ARRAY[('BLE'::character varying)::text, ('WiFi'::character varying)::text, ('UWB'::character varying)::text, ('NFC'::character varying)::text, ('RFID'::character varying)::text]))),
    CONSTRAINT modelos_beacon_rango_metros_check CHECK ((rango_metros > 0))
);


ALTER TABLE public.modelos_beacon OWNER TO hospital_admin;

--
-- Name: modelos_beacon_id_modelo_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.modelos_beacon_id_modelo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.modelos_beacon_id_modelo_seq OWNER TO hospital_admin;

--
-- Name: modelos_beacon_id_modelo_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.modelos_beacon_id_modelo_seq OWNED BY public.modelos_beacon.id_modelo;


--
-- Name: pacientes; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.pacientes (
    id_paciente integer NOT NULL,
    curp character varying(18) NOT NULL,
    nombre character varying(60) NOT NULL,
    apellidop character varying(60) NOT NULL,
    apellidom character varying(60),
    fecha_nac date NOT NULL,
    sexo character(1) NOT NULL,
    tipo_sangre character varying(5),
    telefono character varying(20),
    email character varying(100),
    foto character varying(255),
    CONSTRAINT pacientes_curp_check CHECK ((length((curp)::text) = 18)),
    CONSTRAINT pacientes_email_check CHECK (((email)::text ~~ '%@%'::text)),
    CONSTRAINT pacientes_fecha_nac_check CHECK ((fecha_nac < CURRENT_DATE)),
    CONSTRAINT pacientes_sexo_check CHECK ((sexo = ANY (ARRAY['M'::bpchar, 'F'::bpchar]))),
    CONSTRAINT pacientes_tipo_sangre_check CHECK (((tipo_sangre)::text = ANY (ARRAY[('A+'::character varying)::text, ('A-'::character varying)::text, ('B+'::character varying)::text, ('B-'::character varying)::text, ('AB+'::character varying)::text, ('AB-'::character varying)::text, ('O+'::character varying)::text, ('O-'::character varying)::text])))
);


ALTER TABLE public.pacientes OWNER TO hospital_admin;

--
-- Name: pacientes_id_paciente_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.pacientes ALTER COLUMN id_paciente ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pacientes_id_paciente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: permisos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.permisos (
    id_permiso integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(200),
    modulo character varying(60) NOT NULL
);


ALTER TABLE public.permisos OWNER TO hospital_admin;

--
-- Name: permisos_id_permiso_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.permisos ALTER COLUMN id_permiso ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.permisos_id_permiso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: personal_enfermeria; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.personal_enfermeria (
    id_enfermero integer NOT NULL,
    nombre character varying(60) NOT NULL,
    apellidop character varying(60) NOT NULL,
    apellidom character varying(60),
    cedula character varying(20) NOT NULL,
    nivel character varying(30) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT personal_enfermeria_nivel_check CHECK (((nivel)::text = ANY (ARRAY[('GENERAL'::character varying)::text, ('ESPECIALISTA'::character varying)::text, ('JEFE_PISO'::character varying)::text, ('SUPERVISOR'::character varying)::text])))
);


ALTER TABLE public.personal_enfermeria OWNER TO hospital_admin;

--
-- Name: personal_enfermeria_id_enfermero_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.personal_enfermeria ALTER COLUMN id_enfermero ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.personal_enfermeria_id_enfermero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: pisos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.pisos (
    id_piso integer NOT NULL,
    id_edificio integer NOT NULL,
    numero_piso integer NOT NULL,
    nombre_piso character varying(80) NOT NULL,
    CONSTRAINT pisos_numero_piso_check CHECK ((numero_piso >= 0))
);


ALTER TABLE public.pisos OWNER TO hospital_admin;

--
-- Name: pisos_id_piso_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.pisos_id_piso_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pisos_id_piso_seq OWNER TO hospital_admin;

--
-- Name: pisos_id_piso_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.pisos_id_piso_seq OWNED BY public.pisos.id_piso;


--
-- Name: rol_permiso; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.rol_permiso (
    id_rol integer NOT NULL,
    id_permiso integer NOT NULL
);


ALTER TABLE public.rol_permiso OWNER TO hospital_admin;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.roles (
    id_rol integer NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion character varying(200)
);


ALTER TABLE public.roles OWNER TO hospital_admin;

--
-- Name: roles_id_rol_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.roles ALTER COLUMN id_rol ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.roles_id_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: seguros_paciente; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.seguros_paciente (
    id_seguro integer NOT NULL,
    id_paciente integer NOT NULL,
    id_aseguradora integer NOT NULL,
    num_poliza character varying(50) NOT NULL,
    vigencia_desde date NOT NULL,
    vigencia_hasta date NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT seguros_paciente_check CHECK ((vigencia_hasta > vigencia_desde))
);


ALTER TABLE public.seguros_paciente OWNER TO hospital_admin;

--
-- Name: seguros_paciente_id_seguro_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.seguros_paciente ALTER COLUMN id_seguro ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.seguros_paciente_id_seguro_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: servicios; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.servicios (
    id_servicio integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.servicios OWNER TO hospital_admin;

--
-- Name: servicios_id_servicio_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.servicios_id_servicio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.servicios_id_servicio_seq OWNER TO hospital_admin;

--
-- Name: servicios_id_servicio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.servicios_id_servicio_seq OWNED BY public.servicios.id_servicio;


--
-- Name: sesiones; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.sesiones (
    id_sesion bigint NOT NULL,
    id_usuario integer NOT NULL,
    token_hash character varying(255) NOT NULL,
    ip_origen character varying(45),
    timestamp_inicio timestamp without time zone DEFAULT now() NOT NULL,
    timestamp_fin timestamp without time zone,
    activa boolean DEFAULT true NOT NULL,
    CONSTRAINT sesiones_check CHECK ((timestamp_fin > timestamp_inicio))
);


ALTER TABLE public.sesiones OWNER TO hospital_admin;

--
-- Name: sesiones_id_sesion_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.sesiones ALTER COLUMN id_sesion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sesiones_id_sesion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tarjetas_nfc; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.tarjetas_nfc (
    uid_hex character varying(20) NOT NULL,
    id_paciente integer NOT NULL,
    descripcion character varying(100),
    fecha_registro timestamp without time zone DEFAULT now()
);


ALTER TABLE public.tarjetas_nfc OWNER TO hospital_admin;

--
-- Name: tipos_area; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.tipos_area (
    id_tipo_area integer NOT NULL,
    nombre character varying(60) NOT NULL,
    descripcion character varying(200)
);


ALTER TABLE public.tipos_area OWNER TO hospital_admin;

--
-- Name: tipos_area_id_tipo_area_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.tipos_area_id_tipo_area_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tipos_area_id_tipo_area_seq OWNER TO hospital_admin;

--
-- Name: tipos_area_id_tipo_area_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.tipos_area_id_tipo_area_seq OWNED BY public.tipos_area.id_tipo_area;


--
-- Name: tipos_evento; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.tipos_evento (
    id_tipo_evento integer NOT NULL,
    nombre character varying(20) NOT NULL,
    genera_estancia boolean DEFAULT false NOT NULL,
    CONSTRAINT tipos_evento_nombre_check CHECK (((nombre)::text = ANY (ARRAY[('ENTRADA'::character varying)::text, ('SALIDA'::character varying)::text, ('PASO'::character varying)::text, ('ALERTA'::character varying)::text])))
);


ALTER TABLE public.tipos_evento OWNER TO hospital_admin;

--
-- Name: tipos_evento_id_tipo_evento_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.tipos_evento ALTER COLUMN id_tipo_evento ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tipos_evento_id_tipo_evento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: triajes; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.triajes (
    id_triaje integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_enfermero integer,
    nivel_triaje character varying(10) NOT NULL,
    frecuencia_cardiaca smallint,
    presion_sistolica smallint,
    presion_diastolica smallint,
    temperatura numeric(4,1),
    saturacion_o2 smallint,
    glasgow smallint,
    timestamp_triaje timestamp without time zone DEFAULT now() NOT NULL,
    observaciones text,
    CONSTRAINT triajes_glasgow_check CHECK (((glasgow >= 3) AND (glasgow <= 15))),
    CONSTRAINT triajes_nivel_triaje_check CHECK (((nivel_triaje)::text = ANY ((ARRAY['ROJO'::character varying, 'NARANJA'::character varying, 'AMARILLO'::character varying, 'VERDE'::character varying, 'AZUL'::character varying])::text[])))
);


ALTER TABLE public.triajes OWNER TO hospital_admin;

--
-- Name: triajes_id_triaje_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

CREATE SEQUENCE public.triajes_id_triaje_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.triajes_id_triaje_seq OWNER TO hospital_admin;

--
-- Name: triajes_id_triaje_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: hospital_admin
--

ALTER SEQUENCE public.triajes_id_triaje_seq OWNED BY public.triajes.id_triaje;


--
-- Name: turnos; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.turnos (
    id_turno integer NOT NULL,
    nombre character varying(40) NOT NULL,
    hora_inicio time without time zone NOT NULL,
    hora_fin time without time zone NOT NULL,
    CONSTRAINT turnos_check CHECK (((hora_fin > hora_inicio) OR ((nombre)::text = 'NOCTURNO'::text) OR ((nombre)::text = 'GUARDIA_24H'::text))),
    CONSTRAINT turnos_nombre_check CHECK (((nombre)::text = ANY (ARRAY[('MATUTINO'::character varying)::text, ('VESPERTINO'::character varying)::text, ('NOCTURNO'::character varying)::text, ('GUARDIA_24H'::character varying)::text])))
);


ALTER TABLE public.turnos OWNER TO hospital_admin;

--
-- Name: turnos_id_turno_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.turnos ALTER COLUMN id_turno ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.turnos_id_turno_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: umbrales_alerta; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.umbrales_alerta (
    id_umbral integer NOT NULL,
    id_hospital integer NOT NULL,
    id_area character varying(10),
    nombre_metrica character varying(80) NOT NULL,
    valor_umbral numeric(8,2) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT umbrales_alerta_valor_umbral_check CHECK ((valor_umbral > (0)::numeric))
);


ALTER TABLE public.umbrales_alerta OWNER TO hospital_admin;

--
-- Name: umbrales_alerta_id_umbral_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.umbrales_alerta ALTER COLUMN id_umbral ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.umbrales_alerta_id_umbral_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: hospital_admin
--

CREATE TABLE public.usuarios (
    id_usuario integer NOT NULL,
    username character varying(60) NOT NULL,
    password_hash character varying(255) NOT NULL,
    id_rol integer NOT NULL,
    cedula_medico character varying(20),
    id_enfermero integer,
    id_hospital integer NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.usuarios OWNER TO hospital_admin;

--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: hospital_admin
--

ALTER TABLE public.usuarios ALTER COLUMN id_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuarios_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: vw_alertas_activas; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_alertas_activas AS
 SELECT al.id_alerta,
    a.nombre_area,
    u.nombre_metrica AS metrica,
    al.valor_detectado,
    u.valor_umbral AS umbral,
    to_char(al.timestamp_alerta, 'YYYY-MM-DD HH24:MI'::text) AS timestamp_alerta,
    al.resuelta,
    to_char(al.timestamp_resolucion, 'YYYY-MM-DD HH24:MI'::text) AS timestamp_resolucion
   FROM ((public.alertas_saturacion al
     JOIN public.areas a ON (((a.id_area)::text = (al.id_area)::text)))
     JOIN public.umbrales_alerta u ON ((u.id_umbral = al.id_umbral)))
  ORDER BY al.resuelta, al.timestamp_alerta DESC;


ALTER VIEW public.vw_alertas_activas OWNER TO hospital_admin;

--
-- Name: vw_dashboard_kpis; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_dashboard_kpis AS
 SELECT ( SELECT count(*) AS count
           FROM public.pacientes) AS pacientes_activos,
    ( SELECT count(DISTINCT asignaciones_area.id_area) AS count
           FROM public.asignaciones_area
          WHERE asignaciones_area.activo) AS areas_ocupadas,
    ( SELECT count(*) AS count
           FROM public.alertas_saturacion
          WHERE (NOT alertas_saturacion.resuelta)) AS alertas_activas,
    ( SELECT count(*) AS count
           FROM public.ingresos
          WHERE ((ingresos.fecha_ingreso)::date = CURRENT_DATE)) AS ingresos_hoy;


ALTER VIEW public.vw_dashboard_kpis OWNER TO hospital_admin;

--
-- Name: vw_expedientes; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_expedientes AS
 SELECT e.id_expediente,
    e.num_expediente,
    ((((p.nombre)::text || ' '::text) || (p.apellidop)::text) || COALESCE((' '::text || (p.apellidom)::text), ''::text)) AS paciente,
    COALESCE(p.foto, ((((('https://ui-avatars.com/api/?name='::text || (p.nombre)::text) || '+'::text) || (p.apellidop)::text) || '&background=6366f1&color=fff&size=128'::text))::character varying) AS foto,
    (((m.nombre)::text || ' '::text) || (m.apellidop)::text) AS medico,
    to_char((e.fecha_apertura)::timestamp with time zone, 'YYYY-MM-DD'::text) AS fecha_apertura,
    e.activo,
    p.id_paciente
   FROM ((public.expedientes e
     JOIN public.pacientes p ON ((p.id_paciente = e.id_paciente)))
     JOIN public.medicos m ON (((m.cedula_medico)::text = (e.medico_titular)::text)))
  ORDER BY e.fecha_apertura DESC;


ALTER VIEW public.vw_expedientes OWNER TO hospital_admin;

--
-- Name: vw_ingresos_activos; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_ingresos_activos AS
 SELECT i.id_ingreso,
    e.num_expediente AS expediente,
    ((((p.nombre)::text || ' '::text) || (p.apellidop)::text) || COALESCE((' '::text || (p.apellidom)::text), ''::text)) AS paciente,
    COALESCE(p.foto, ((((('https://ui-avatars.com/api/?name='::text || (p.nombre)::text) || '+'::text) || (p.apellidop)::text) || '&background=6366f1&color=fff&size=128'::text))::character varying) AS foto,
    (((m.nombre)::text || ' '::text) || (m.apellidop)::text) AS medico,
    i.tipo_ingreso,
    i.motivo_ingreso,
    i.estado,
    i.tiempo_espera_min,
    round((EXTRACT(epoch FROM (now() - (i.fecha_ingreso)::timestamp with time zone)) / (60)::numeric)) AS min_desde_ingreso,
    a.nombre_area AS area_actual,
    i.id_expediente,
    i.cedula_medico
   FROM (((((public.ingresos i
     JOIN public.expedientes e ON ((e.id_expediente = i.id_expediente)))
     JOIN public.pacientes p ON ((p.id_paciente = e.id_paciente)))
     JOIN public.medicos m ON (((m.cedula_medico)::text = (i.cedula_medico)::text)))
     LEFT JOIN public.estancias es ON (((es.id_ingreso = i.id_ingreso) AND (es.timestamp_salida IS NULL))))
     LEFT JOIN public.areas a ON (((a.id_area)::text = (es.id_area)::text)))
  WHERE ((i.estado)::text = ANY ((ARRAY['EN_ESPERA'::character varying, 'EN_ATENCION'::character varying])::text[]));


ALTER VIEW public.vw_ingresos_activos OWNER TO hospital_admin;

--
-- Name: vw_kpi_actividad_por_hora; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_actividad_por_hora AS
 SELECT (EXTRACT(hour FROM fecha_ingreso))::integer AS hora,
    count(*) AS total_ingresos
   FROM public.ingresos
  GROUP BY ((EXTRACT(hour FROM fecha_ingreso))::integer)
  ORDER BY ((EXTRACT(hour FROM fecha_ingreso))::integer);


ALTER VIEW public.vw_kpi_actividad_por_hora OWNER TO hospital_admin;

--
-- Name: vw_kpi_adopcion_nfc; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_adopcion_nfc AS
 SELECT count(DISTINCT p.id_paciente) AS total_pacientes,
    count(DISTINCT t.id_paciente) AS pacientes_con_nfc,
    (count(DISTINCT p.id_paciente) - count(DISTINCT t.id_paciente)) AS pacientes_sin_nfc,
    round((((count(DISTINCT t.id_paciente))::numeric * 100.0) / (NULLIF(count(DISTINCT p.id_paciente), 0))::numeric), 1) AS tasa_adopcion_pct
   FROM (public.pacientes p
     LEFT JOIN public.tarjetas_nfc t ON ((t.id_paciente = p.id_paciente)));


ALTER VIEW public.vw_kpi_adopcion_nfc OWNER TO hospital_admin;

--
-- Name: vw_kpi_alertas_resolucion; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_alertas_resolucion AS
 SELECT count(*) FILTER (WHERE (NOT resuelta)) AS alertas_activas,
    count(*) FILTER (WHERE resuelta) AS alertas_resueltas,
    count(*) AS total_alertas,
    round((((count(*) FILTER (WHERE resuelta))::numeric * 100.0) / (NULLIF(count(*), 0))::numeric), 1) AS tasa_resolucion_pct
   FROM public.alertas_saturacion;


ALTER VIEW public.vw_kpi_alertas_resolucion OWNER TO hospital_admin;

--
-- Name: vw_kpi_disponibilidad_medicos; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_disponibilidad_medicos AS
 SELECT count(*) FILTER (WHERE activo) AS medicos_activos,
    count(*) FILTER (WHERE (NOT activo)) AS medicos_inactivos,
    count(*) AS total_medicos,
    round((((count(*) FILTER (WHERE activo))::numeric * 100.0) / (NULLIF(count(*), 0))::numeric), 1) AS tasa_disponibilidad_pct
   FROM public.medicos;


ALTER VIEW public.vw_kpi_disponibilidad_medicos OWNER TO hospital_admin;

--
-- Name: vw_kpi_duracion_estancia_area; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_duracion_estancia_area AS
 SELECT a.nombre_area,
    count(es.id_estancia) AS total_estancias,
    round(avg(es.duracion_min), 1) AS duracion_prom_min,
    round(max(es.duracion_min), 1) AS duracion_max_min
   FROM (public.estancias es
     JOIN public.areas a ON (((a.id_area)::text = (es.id_area)::text)))
  WHERE (es.duracion_min IS NOT NULL)
  GROUP BY a.nombre_area
  ORDER BY (round(avg(es.duracion_min), 1)) DESC;


ALTER VIEW public.vw_kpi_duracion_estancia_area OWNER TO hospital_admin;

--
-- Name: vw_kpi_espera; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_espera AS
 SELECT a.nombre_area,
    count(i.id_ingreso) AS total_ingresos,
    round(avg(i.tiempo_espera_min), 1) AS tiempo_espera_prom
   FROM ((public.ingresos i
     JOIN public.estancias es ON ((es.id_ingreso = i.id_ingreso)))
     JOIN public.areas a ON (((a.id_area)::text = (es.id_area)::text)))
  GROUP BY a.nombre_area
  ORDER BY (count(i.id_ingreso)) DESC;


ALTER VIEW public.vw_kpi_espera OWNER TO hospital_admin;

--
-- Name: vw_kpi_estado_beacons; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_estado_beacons AS
 SELECT estado,
    count(*) AS total,
    round((((count(*))::numeric * 100.0) / sum(count(*)) OVER ()), 1) AS porcentaje
   FROM public.beacons
  GROUP BY estado;


ALTER VIEW public.vw_kpi_estado_beacons OWNER TO hospital_admin;

--
-- Name: vw_kpi_expedientes_activos; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_expedientes_activos AS
 SELECT count(*) FILTER (WHERE activo) AS expedientes_activos,
    count(*) FILTER (WHERE (NOT activo)) AS expedientes_cerrados,
    count(*) AS total_expedientes,
    round((((count(*) FILTER (WHERE activo))::numeric * 100.0) / (NULLIF(count(*), 0))::numeric), 1) AS tasa_activos_pct
   FROM public.expedientes;


ALTER VIEW public.vw_kpi_expedientes_activos OWNER TO hospital_admin;

--
-- Name: vw_kpi_ingresos_diario; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_ingresos_diario AS
 SELECT count(*) FILTER (WHERE ((fecha_ingreso)::date = CURRENT_DATE)) AS ingresos_hoy,
    count(*) FILTER (WHERE ((fecha_ingreso)::date = (CURRENT_DATE - 1))) AS ingresos_ayer,
    count(*) FILTER (WHERE (date_trunc('week'::text, fecha_ingreso) = date_trunc('week'::text, now()))) AS ingresos_semana,
    count(*) FILTER (WHERE (date_trunc('month'::text, fecha_ingreso) = date_trunc('month'::text, now()))) AS ingresos_mes
   FROM public.ingresos;


ALTER VIEW public.vw_kpi_ingresos_diario OWNER TO hospital_admin;

--
-- Name: vw_kpi_ingresos_por_tipo; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_ingresos_por_tipo AS
 SELECT tipo_ingreso,
    count(*) AS total,
    round((((count(*))::numeric * 100.0) / sum(count(*)) OVER ()), 1) AS porcentaje
   FROM public.ingresos
  WHERE (date_trunc('month'::text, fecha_ingreso) = date_trunc('month'::text, now()))
  GROUP BY tipo_ingreso
  ORDER BY (count(*)) DESC;


ALTER VIEW public.vw_kpi_ingresos_por_tipo OWNER TO hospital_admin;

--
-- Name: vw_kpi_medicos; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_medicos AS
 SELECT (((m.nombre)::text || ' '::text) || (m.apellidop)::text) AS medico,
    esp.nombre AS especialidad,
    count(i.id_ingreso) AS total_ingresos,
    round(avg(i.tiempo_espera_min), 1) AS espera_prom
   FROM ((public.ingresos i
     JOIN public.medicos m ON (((m.cedula_medico)::text = (i.cedula_medico)::text)))
     JOIN public.especialidades esp ON ((esp.id_especialidad = m.id_especialidad)))
  GROUP BY m.cedula_medico, m.nombre, m.apellidop, esp.nombre
  ORDER BY (count(i.id_ingreso)) DESC;


ALTER VIEW public.vw_kpi_medicos OWNER TO hospital_admin;

--
-- Name: vw_kpi_ocupacion_areas; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_ocupacion_areas AS
 SELECT a.nombre_area,
    a.capacidad,
    COALESCE(oc.personas_actuales, (0)::bigint) AS ocupacion_actual,
    round((((COALESCE(oc.personas_actuales, (0)::bigint))::numeric / (NULLIF(a.capacidad, 0))::numeric) * (100)::numeric), 1) AS tasa_ocupacion_pct
   FROM (public.areas a
     LEFT JOIN ( SELECT asignaciones_area.id_area,
            count(*) AS personas_actuales
           FROM public.asignaciones_area
          WHERE (asignaciones_area.activo = true)
          GROUP BY asignaciones_area.id_area) oc ON (((oc.id_area)::text = (a.id_area)::text)))
  WHERE (a.activo = true)
  ORDER BY (round((((COALESCE(oc.personas_actuales, (0)::bigint))::numeric / (NULLIF(a.capacidad, 0))::numeric) * (100)::numeric), 1)) DESC;


ALTER VIEW public.vw_kpi_ocupacion_areas OWNER TO hospital_admin;

--
-- Name: vw_kpi_productividad_medico; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_productividad_medico AS
 SELECT (((m.nombre)::text || ' '::text) || (m.apellidop)::text) AS medico,
    esp.nombre AS especialidad,
    count(i.id_ingreso) AS ingresos_mes,
    round(avg(i.tiempo_espera_min), 1) AS espera_promedio_min
   FROM ((public.ingresos i
     JOIN public.medicos m ON (((m.cedula_medico)::text = (i.cedula_medico)::text)))
     JOIN public.especialidades esp ON ((esp.id_especialidad = m.id_especialidad)))
  WHERE (date_trunc('month'::text, i.fecha_ingreso) = date_trunc('month'::text, now()))
  GROUP BY m.cedula_medico, m.nombre, m.apellidop, esp.nombre
  ORDER BY (count(i.id_ingreso)) DESC;


ALTER VIEW public.vw_kpi_productividad_medico OWNER TO hospital_admin;

--
-- Name: vw_kpi_resumen_ejecutivo; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_resumen_ejecutivo AS
 SELECT ( SELECT count(*) AS count
           FROM public.pacientes) AS total_pacientes,
    ( SELECT count(*) AS count
           FROM public.medicos
          WHERE medicos.activo) AS medicos_activos,
    ( SELECT count(*) AS count
           FROM public.ingresos
          WHERE ((ingresos.estado)::text = 'EN_ESPERA'::text)) AS pacientes_en_espera,
    ( SELECT count(*) AS count
           FROM public.ingresos
          WHERE ((ingresos.fecha_ingreso)::date = CURRENT_DATE)) AS ingresos_hoy,
    ( SELECT round(avg(ingresos.tiempo_espera_min), 1) AS round
           FROM public.ingresos
          WHERE (((ingresos.estado)::text = 'ALTA'::text) AND (ingresos.tiempo_espera_min IS NOT NULL))) AS espera_prom_min,
    ( SELECT count(*) AS count
           FROM public.alertas_saturacion
          WHERE (NOT alertas_saturacion.resuelta)) AS alertas_activas,
    ( SELECT count(*) AS count
           FROM public.beacons
          WHERE ((beacons.estado)::text = 'ACTIVO'::text)) AS beacons_activos,
    ( SELECT count(*) AS count
           FROM public.tarjetas_nfc) AS tarjetas_nfc_registradas,
    ( SELECT count(*) AS count
           FROM public.expedientes
          WHERE expedientes.activo) AS expedientes_abiertos;


ALTER VIEW public.vw_kpi_resumen_ejecutivo OWNER TO hospital_admin;

--
-- Name: vw_kpi_tiempo_espera_promedio; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_tiempo_espera_promedio AS
 SELECT round(avg(tiempo_espera_min), 1) AS tiempo_espera_prom_min,
    min(tiempo_espera_min) AS tiempo_minimo_min,
    max(tiempo_espera_min) AS tiempo_maximo_min,
    count(*) AS total_ingresos_medidos
   FROM public.ingresos
  WHERE (((estado)::text = 'ALTA'::text) AND (tiempo_espera_min IS NOT NULL));


ALTER VIEW public.vw_kpi_tiempo_espera_promedio OWNER TO hospital_admin;

--
-- Name: vw_kpi_triajes_por_nivel; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_triajes_por_nivel AS
 SELECT nivel_triaje,
    count(*) AS total,
    round((((count(*))::numeric * 100.0) / sum(count(*)) OVER ()), 1) AS porcentaje
   FROM public.triajes
  WHERE (timestamp_triaje >= (now() - '30 days'::interval))
  GROUP BY nivel_triaje
  ORDER BY
        CASE nivel_triaje
            WHEN 'ROJO'::text THEN 1
            WHEN 'NARANJA'::text THEN 2
            WHEN 'AMARILLO'::text THEN 3
            WHEN 'VERDE'::text THEN 4
            WHEN 'AZUL'::text THEN 5
            ELSE NULL::integer
        END;


ALTER VIEW public.vw_kpi_triajes_por_nivel OWNER TO hospital_admin;

--
-- Name: vw_kpi_vitales_por_nivel; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_kpi_vitales_por_nivel AS
 SELECT nivel_triaje,
    count(*) AS total_triajes,
    round(avg(frecuencia_cardiaca), 0) AS fc_prom,
    round(avg(presion_sistolica), 0) AS ps_prom,
    round(avg(temperatura), 1) AS temp_prom,
    round(avg(saturacion_o2), 1) AS sato2_prom,
    round(avg(glasgow), 1) AS glasgow_prom
   FROM public.triajes
  GROUP BY nivel_triaje
  ORDER BY nivel_triaje;


ALTER VIEW public.vw_kpi_vitales_por_nivel OWNER TO hospital_admin;

--
-- Name: vw_logs; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_logs AS
 SELECT la.id_log,
    COALESCE(u.username, ((la.id_usuario)::text)::character varying) AS usuario,
    la.accion,
    la.tabla_afectada,
    la.id_registro,
    to_char(la.timestamp_accion, 'YYYY-MM-DD HH24:MI:SS'::text) AS timestamp_accion,
    la.detalle
   FROM (public.log_acceso la
     LEFT JOIN public.usuarios u ON ((u.id_usuario = la.id_usuario)))
  ORDER BY la.timestamp_accion DESC;


ALTER VIEW public.vw_logs OWNER TO hospital_admin;

--
-- Name: vw_ocupacion_areas; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_ocupacion_areas AS
 SELECT a.id_area,
    a.nombre_area,
    ta.nombre AS tipo,
    a.capacidad,
    COALESCE(aa.personas_actuales, (0)::bigint) AS ocupacion_actual,
    pi.nombre_piso
   FROM (((public.areas a
     JOIN public.tipos_area ta ON ((ta.id_tipo_area = a.id_tipo_area)))
     LEFT JOIN public.pisos pi ON ((pi.id_piso = a.id_piso)))
     LEFT JOIN ( SELECT asignaciones_area.id_area,
            count(*) AS personas_actuales
           FROM public.asignaciones_area
          WHERE (asignaciones_area.activo = true)
          GROUP BY asignaciones_area.id_area) aa ON (((aa.id_area)::text = (a.id_area)::text)))
  WHERE (a.activo = true)
  ORDER BY a.nombre_area;


ALTER VIEW public.vw_ocupacion_areas OWNER TO hospital_admin;

--
-- Name: vw_pacientes; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_pacientes AS
 SELECT p.id_paciente,
    p.curp,
    p.nombre,
    p.apellidop,
    p.apellidom,
    to_char((p.fecha_nac)::timestamp with time zone, 'YYYY-MM-DD'::text) AS fecha_nac,
    p.sexo,
    p.tipo_sangre,
    p.telefono,
    p.email,
    COALESCE(p.foto, ((((('https://ui-avatars.com/api/?name='::text || (p.nombre)::text) || '+'::text) || (p.apellidop)::text) || '&background=6366f1&color=fff&size=128'::text))::character varying) AS foto,
    e.num_expediente
   FROM (public.pacientes p
     LEFT JOIN public.expedientes e ON (((e.id_paciente = p.id_paciente) AND (e.activo = true))));


ALTER VIEW public.vw_pacientes OWNER TO hospital_admin;

--
-- Name: vw_sala_espera; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_sala_espera AS
 SELECT p.id_paciente,
    ((((p.nombre)::text || ' '::text) || (p.apellidop)::text) || COALESCE((' '::text || (p.apellidom)::text), ''::text)) AS nombre_completo,
    COALESCE(p.foto, ((((('https://ui-avatars.com/api/?name='::text || (p.nombre)::text) || '+'::text) || (p.apellidop)::text) || '&background=6366f1&color=fff&size=128'::text))::character varying) AS foto,
    e.num_expediente,
    i.id_ingreso,
    to_char(i.fecha_ingreso, 'HH24:MI'::text) AS hora_ingreso,
    round((EXTRACT(epoch FROM (now() - (i.fecha_ingreso)::timestamp with time zone)) / (60)::numeric)) AS min_espera
   FROM ((public.ingresos i
     JOIN public.expedientes e ON ((e.id_expediente = i.id_expediente)))
     JOIN public.pacientes p ON ((p.id_paciente = e.id_paciente)))
  WHERE ((i.estado)::text = 'EN_ESPERA'::text)
  ORDER BY i.fecha_ingreso;


ALTER VIEW public.vw_sala_espera OWNER TO hospital_admin;

--
-- Name: vw_tarjetas_nfc; Type: VIEW; Schema: public; Owner: hospital_admin
--

CREATE VIEW public.vw_tarjetas_nfc AS
 SELECT t.uid_hex,
    t.descripcion,
    to_char(t.fecha_registro, 'YYYY-MM-DD'::text) AS fecha_registro,
    p.id_paciente,
    ((((p.nombre)::text || ' '::text) || (p.apellidop)::text) || COALESCE((' '::text || (p.apellidom)::text), ''::text)) AS nombre_completo,
    COALESCE(p.foto, ((((('https://ui-avatars.com/api/?name='::text || (p.nombre)::text) || '+'::text) || (p.apellidop)::text) || '&background=6366f1&color=fff&size=128'::text))::character varying) AS foto,
    e.num_expediente
   FROM ((public.tarjetas_nfc t
     JOIN public.pacientes p ON ((p.id_paciente = t.id_paciente)))
     LEFT JOIN public.expedientes e ON (((e.id_paciente = p.id_paciente) AND (e.activo = true))))
  ORDER BY t.fecha_registro DESC;


ALTER VIEW public.vw_tarjetas_nfc OWNER TO hospital_admin;

--
-- Name: edificios id_edificio; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.edificios ALTER COLUMN id_edificio SET DEFAULT nextval('public.edificios_id_edificio_seq'::regclass);


--
-- Name: historial_estados_ingreso id_historial; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.historial_estados_ingreso ALTER COLUMN id_historial SET DEFAULT nextval('public.historial_estados_ingreso_id_historial_seq'::regclass);


--
-- Name: hospitales id_hospital; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.hospitales ALTER COLUMN id_hospital SET DEFAULT nextval('public.hospitales_id_hospital_seq'::regclass);


--
-- Name: mantenimientos_beacon id_mantenimiento; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.mantenimientos_beacon ALTER COLUMN id_mantenimiento SET DEFAULT nextval('public.mantenimientos_beacon_id_mantenimiento_seq'::regclass);


--
-- Name: modelos_beacon id_modelo; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.modelos_beacon ALTER COLUMN id_modelo SET DEFAULT nextval('public.modelos_beacon_id_modelo_seq'::regclass);


--
-- Name: pisos id_piso; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pisos ALTER COLUMN id_piso SET DEFAULT nextval('public.pisos_id_piso_seq'::regclass);


--
-- Name: servicios id_servicio; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.servicios ALTER COLUMN id_servicio SET DEFAULT nextval('public.servicios_id_servicio_seq'::regclass);


--
-- Name: tipos_area id_tipo_area; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tipos_area ALTER COLUMN id_tipo_area SET DEFAULT nextval('public.tipos_area_id_tipo_area_seq'::regclass);


--
-- Name: triajes id_triaje; Type: DEFAULT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.triajes ALTER COLUMN id_triaje SET DEFAULT nextval('public.triajes_id_triaje_seq'::regclass);


--
-- Data for Name: alergias_paciente; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.alergias_paciente (id_paciente, id_alergia, severidad, observaciones) FROM stdin;
1	1	SEVERA	Reacción anafiláctica documentada 2019
1	2	LEVE	Urticaria de contacto
4	3	MODERADA	Rash cutáneo generalizado
5	4	ANAFILACTICA	Shock anafiláctico previo — EpiPen disponible
6	6	MODERADA	Gastritis hemorrágica
8	7	SEVERA	Angioedema labial
\.


--
-- Data for Name: alertas_saturacion; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.alertas_saturacion (id_alerta, id_umbral, id_area, timestamp_alerta, valor_detectado, resuelta, timestamp_resolucion) FROM stdin;
1	1	A-001	2024-03-10 16:00:00	34.50	t	2024-03-10 17:30:00
2	2	A-001	2024-03-05 20:00:00	93.30	t	2024-03-05 21:00:00
3	1	A-001	2024-03-15 11:00:00	31.20	f	\N
\.


--
-- Data for Name: antecedentes; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.antecedentes (id_antecedente, id_expediente, tipo, descripcion, fecha_registro, activo) FROM stdin;
1	1	CRONICO	Hipertensión arterial sistémica desde 2018, controlada con Losartán 50mg	2024-01-10	t
2	1	CRONICO	Dislipidemia mixta, Atorvastatina 20mg noche	2024-01-10	t
3	4	CRONICO	Diabetes mellitus tipo 2 desde 2015, insulina NPH	2024-02-10	t
4	4	QUIRURGICO	Bypass coronario doble 2020, Hospital Christus	2024-02-10	t
5	6	CRONICO	Diabetes mellitus tipo 2 e hipertensión, triple terapia antihipertensiva	2024-03-01	t
6	5	TRAUMATICO	Esguince grado III rodilla derecha, ligamento cruzado anterior	2024-02-20	t
\.


--
-- Data for Name: area_servicio; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.area_servicio (id_area, id_servicio) FROM stdin;
A-001	1
A-001	8
A-002	1
A-003	1
A-003	7
A-004	2
A-005	3
A-006	4
A-007	1
A-008	6
\.


--
-- Data for Name: areas; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.areas (id_area, id_piso, id_tipo_area, nombre_area, capacidad, activo) FROM stdin;
A-001	1	1	Urgencias Adultos	30	t
A-002	1	2	Sala de Espera Urgencias	60	t
A-003	2	5	UCI General	12	t
A-004	5	3	Consultorio Cardiología	2	t
A-005	6	3	Consultorio Pediatría	2	t
A-006	7	4	Laboratorio Central	20	t
A-007	4	2	Recepción Principal	50	t
A-008	1	7	Farmacia Urgencias	10	t
\.


--
-- Data for Name: aseguradoras; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.aseguradoras (id_aseguradora, nombre, tipo, telefono, activo) FROM stdin;
1	IMSS	PUBLICA	800-623-2323	t
2	ISSSTE	PUBLICA	800-011-2036	t
3	GNP Seguros	PRIVADA	800-400-9000	t
4	MetLife México	PRIVADA	800-362-3900	t
5	AXA Salud	PRIVADA	800-900-1234	t
6	Seguro Popular	PUBLICA	800-900-2000	t
\.


--
-- Data for Name: asignaciones_area; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.asignaciones_area (id_asignacion, id_enfermero, id_area, id_turno, fecha_inicio, fecha_fin, activo) FROM stdin;
1	1	A-001	1	2024-01-01	\N	t
2	2	A-001	2	2024-01-01	\N	t
3	3	A-003	1	2024-01-01	\N	t
4	4	A-003	2	2024-01-01	\N	t
5	5	A-001	4	2024-01-01	\N	t
6	6	A-002	1	2024-01-01	\N	t
\.


--
-- Data for Name: beacons; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.beacons (id_beacon, id_area, id_modelo, uuid_beacon, nombre, estado, fecha_instalacion) FROM stdin;
BCN-02	A-001	2	550e8400-e29b-41d4-a716-446655440002	Beacon Urgencias Central	ACTIVO	2024-01-15
BCN-03	A-002	1	550e8400-e29b-41d4-a716-446655440003	Beacon Sala Espera	ACTIVO	2024-01-20
BCN-04	A-003	5	550e8400-e29b-41d4-a716-446655440004	UWB UCI Cama 1	ACTIVO	2024-02-01
BCN-05	A-004	3	550e8400-e29b-41d4-a716-446655440005	Beacon Cardiología	ACTIVO	2024-01-25
BCN-06	A-005	3	550e8400-e29b-41d4-a716-446655440006	Beacon Pediatría	ACTIVO	2024-01-25
BCN-07	A-006	4	550e8400-e29b-41d4-a716-446655440007	Beacon Laboratorio	ACTIVO	2024-02-10
BCN-08	A-008	1	550e8400-e29b-41d4-a716-446655440008	Beacon Farmacia	MANTENIMIENTO	2024-02-15
BCN-01	A-001	2	FDA50693A4E24FB1AFCFC6EB07647825	Beacon Cosultorio 1	ACTIVO	2024-01-15
\.


--
-- Data for Name: cat_alergias; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.cat_alergias (id_alergia, nombre, tipo) FROM stdin;
1	Penicilina	MEDICAMENTO
2	Látex	LATEX
3	Sulfonamidas	MEDICAMENTO
4	Mariscos	ALIMENTO
5	Polen	AMBIENTAL
6	Aspirina	MEDICAMENTO
7	Nueces	ALIMENTO
8	Metamizol	MEDICAMENTO
\.


--
-- Data for Name: cat_diagnosticos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.cat_diagnosticos (id_diagnostico, codigo_cie10, nombre, categoria) FROM stdin;
1	I20.0	Angina de pecho inestable	Enfermedades cardiacas
2	I21.0	Infarto agudo de miocardio pared anterior	Enfermedades cardiacas
3	J18.9	Neumonía no especificada	Enfermedades respiratorias
4	J06.9	Infección aguda vías respiratorias altas	Enfermedades respiratorias
5	R56.0	Convulsiones febriles	Síntomas y signos neurológicos
6	M23.2	Lesión de ligamento cruzado anterior	Enfermedades del aparato locomotor
7	E11.9	Diabetes mellitus tipo 2 sin complicaciones	Enfermedades endocrinas
8	I10	Hipertensión esencial primaria	Enfermedades del sistema circulatorio
9	E78.5	Hiperlipidemia no especificada	Enfermedades metabólicas
10	Z00.00	Examen médico general sin hallazgos anormales	Contactos con servicios de salud
\.


--
-- Data for Name: citas; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.citas (id_cita, id_horario, id_expediente, fecha_cita, hora_cita, id_estado, motivo, observaciones, fecha_registro) FROM stdin;
1	1	1	2024-03-15	08:00:00	2	Control hipertensión y perfil lipídico	\N	2026-04-11 18:17:35.091675
2	6	2	2024-03-15	09:00:00	2	Control pediátrico semestral	\N	2026-04-11 18:17:35.091675
3	1	4	2024-03-20	10:00:00	2	Seguimiento postoperatorio bypass coronario	\N	2026-04-11 18:17:35.091675
4	13	2	2024-03-22	11:00:00	1	Vacunación y talla-peso	\N	2026-04-11 18:17:35.091675
5	6	8	2024-03-25	09:30:00	1	Primera consulta pediatría	\N	2026-04-11 18:17:35.091675
6	2	6	2024-03-18	08:00:00	2	Control diabetes e HTA — ajuste de dosis	\N	2026-04-11 18:17:35.091675
7	1	1	2024-12-01	09:00:00	1	Control cardiológico trimestral	\N	2026-04-11 18:17:35.148386
\.


--
-- Data for Name: consultorios; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.consultorios (id_consultorio, id_area, cedula_medico, nombre, numero, activo) FROM stdin;
1	A-001	CED-004	Consultorio Urgencias 1	U-01	t
2	A-001	CED-004	Consultorio Urgencias 2	U-02	t
3	A-004	CED-001	Consultorio Cardiología 1	C-01	t
4	A-005	CED-002	Consultorio Pediatría 1	P-01	t
5	A-005	CED-002	Consultorio Pediatría 2	P-02	t
\.


--
-- Data for Name: contactos_emergencia; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.contactos_emergencia (id_contacto, id_paciente, nombre, parentesco, telefono, es_principal) FROM stdin;
1	1	José González Martínez	Esposo	81-2222-0001	t
2	1	Carmen López Ruiz	Madre	81-3333-0011	f
3	2	Pedro Torres Ramírez	Padre	81-4444-0002	t
4	3	Sofía Hernández Ruiz	Madre	81-5555-0003	t
5	4	Andrés Morales Vega	Hijo	81-6666-0004	t
6	5	Elena Pérez Castro	Madre	81-7777-0005	t
7	7	Daniela Flores Reyes	Madre	81-8888-0007	t
8	8	Carlos Juárez Ríos	Padre	81-9999-0008	t
\.


--
-- Data for Name: diagnosticos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.diagnosticos (id_reg_dx, id_ingreso, id_diagnostico, cedula_medico, tipo, timestamp_dx, notas) FROM stdin;
1	1	1	CED-001	PRESUNTIVO	2024-03-15 09:00:00	ECG con cambios ST, troponina pendiente. Iniciar AAS y heparina.
2	1	2	CED-001	DEFINITIVO	2024-03-15 11:00:00	Troponina I: 2.4 ng/mL. Confirmado IAM anterior. Traslado a hemodinamia.
3	2	10	CED-002	DEFINITIVO	2024-03-15 09:45:00	Niño en buen estado general, peso y talla en percentil 50.
4	3	5	CED-004	DEFINITIVO	2024-03-05 22:30:00	Convulsión febril simple. Diazepam rectal 5mg. Alta con observación domiciliaria.
5	4	1	CED-001	DEFINITIVO	2024-03-20 11:00:00	Fracción de eyección 55%. Sin nueva isquemia. Continuar doble antiagregación.
6	5	6	CED-005	DEFINITIVO	2024-03-12 19:00:00	RMN: ruptura parcial LCA. Plan quirúrgico en 4 semanas.
7	6	7	CED-001	DEFINITIVO	2024-03-18 09:00:00	HbA1c 9.2%, ajuste de insulina glargina a 30 UI nocturna.
8	6	8	CED-001	DEFINITIVO	2024-03-18 09:00:00	PA 158/96 en consultorio. Agregar amlodipino 5mg.
9	7	3	CED-003	DEFINITIVO	2024-03-10 16:00:00	Rx tórax: infiltrado basal derecho. Azitromicina 500mg x 5 días. Hospitalar si empeora.
\.


--
-- Data for Name: dias_semana; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.dias_semana (id_dia, nombre) FROM stdin;
1	Lunes
2	Martes
3	Miércoles
4	Jueves
5	Viernes
6	Sábado
7	Domingo
\.


--
-- Data for Name: edificios; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.edificios (id_edificio, id_hospital, nombre, descripcion) FROM stdin;
1	1	Torre de Urgencias	Atención de emergencias 24/7
2	1	Torre de Consultorios	Consultas externas y especialidades
3	1	Edificio de Laboratorio	Laboratorio clínico e imagen
4	2	Torre Principal	Servicios centrales UANL
5	3	Torre Muguerza Sur	Torre principal Christus
\.


--
-- Data for Name: especialidades; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.especialidades (id_especialidad, nombre, descripcion) FROM stdin;
1	Cardiología	Enfermedades del corazón y sistema cardiovascular
2	Pediatría	Atención médica de niños y adolescentes
3	Medicina Interna	Enfermedades sistémicas en adultos
4	Traumatología	Lesiones del aparato locomotor
5	Urgencias	Atención médica de emergencias
6	Neurología	Enfermedades del sistema nervioso
7	Neumología	Enfermedades del aparato respiratorio
8	Enfermería General	Personal de enfermería general
\.


--
-- Data for Name: estados_cita; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.estados_cita (id_estado, nombre, descripcion) FROM stdin;
1	PROGRAMADA	Cita creada, pendiente de confirmación
2	CONFIRMADA	Cita confirmada por el paciente
3	EN_PROCESO	Paciente en consulta
4	COMPLETADA	Consulta finalizada con éxito
5	CANCELADA	Cita cancelada por el paciente o médico
6	NO_ASISTIO	El paciente no se presentó
7	REPROGRAMADA	Cita movida a otra fecha u horario
\.


--
-- Data for Name: estancias; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.estancias (id_estancia, id_ingreso, id_area, timestamp_entrada, timestamp_salida, duracion_min, fuente_verdad) FROM stdin;
1	1	A-002	2024-03-15 08:00:00	2024-03-15 08:45:00	45.00	BEACON
2	1	A-001	2024-03-15 08:45:00	2024-03-15 12:25:00	220.00	BEACON
3	2	A-002	2024-03-15 09:05:00	2024-03-15 09:15:00	10.00	BEACON
4	2	A-005	2024-03-15 09:15:00	2024-03-15 09:55:00	40.00	BEACON
5	3	A-001	2024-03-05 22:15:00	2024-03-05 23:00:00	45.00	BEACON
6	3	A-003	2024-03-05 23:00:00	2024-03-06 05:55:00	415.00	BEACON
7	5	A-001	2024-03-12 17:30:00	2024-03-12 19:55:00	145.00	BEACON
8	7	A-001	2024-03-10 14:00:00	2024-03-10 14:10:00	10.00	BEACON
9	7	A-001	2024-03-10 14:10:00	2024-03-10 18:25:00	255.00	BEACON
10	10	A-001	2026-04-16 17:24:47.641173	2026-04-16 17:24:48.436234	0.01	BEACON
11	11	A-001	2026-04-16 17:25:11.41764	2026-04-16 17:25:12.031491	0.01	BEACON
12	12	A-001	2026-04-16 17:34:53.184768	2026-04-16 17:34:53.960145	0.01	BEACON
13	13	A-001	2026-04-16 17:35:35.518763	2026-04-16 17:35:36.116903	0.01	BEACON
14	14	A-001	2026-04-16 18:25:28.174703	2026-04-16 18:25:29.292631	0.02	BEACON
15	15	A-001	2026-04-16 18:33:57.647923	2026-04-16 18:34:03.56754	0.10	BEACON
16	16	A-001	2026-04-16 18:40:12.567634	2026-04-16 18:40:17.261295	0.08	BEACON
17	17	A-001	2026-04-16 18:40:33.073242	2026-04-16 18:40:33.878868	0.01	BEACON
18	18	A-001	2026-04-16 22:01:09.658393	2026-04-16 22:01:10.981601	0.02	BEACON
19	19	A-001	2026-04-16 22:01:42.669885	2026-04-16 22:01:47.20763	0.08	BEACON
20	20	A-001	2026-04-16 22:02:00.174872	2026-04-16 22:02:05.468368	0.09	BEACON
21	21	A-001	2026-04-16 22:04:09.016104	2026-04-16 22:04:12.413838	0.06	BEACON
22	22	A-001	2026-04-17 21:43:15.783482	2026-04-17 21:43:16.576429	0.01	BEACON
23	23	A-001	2026-04-17 21:43:33.893287	2026-04-17 21:43:34.704039	0.01	BEACON
24	24	A-001	2026-04-17 21:49:44.146396	2026-04-17 21:49:45.373794	0.02	BEACON
25	25	A-001	2026-04-17 21:51:48.396194	2026-04-17 21:51:52.557946	0.07	BEACON
26	26	A-001	2026-04-17 21:55:56.451861	2026-04-17 21:55:59.877511	0.06	BEACON
27	27	A-001	2026-04-17 21:58:17.084951	2026-04-17 21:58:20.802863	0.06	BEACON
28	28	A-001	2026-04-17 22:00:31.01603	2026-04-17 22:00:35.139278	0.07	BEACON
29	29	A-001	2026-04-17 22:01:26.033903	2026-04-17 22:01:26.511523	0.01	BEACON
30	30	A-001	2026-04-17 22:01:37.432874	2026-04-17 22:01:41.373405	0.07	BEACON
33	31	A-001	2026-04-17 22:18:05.119668	2026-04-17 22:18:12.179334	0.12	BEACON
32	31	A-001	2026-04-17 22:17:58.023824	2026-04-17 22:18:19.343928	0.36	BEACON
31	31	A-001	2026-04-17 22:17:52.002293	2026-04-17 22:18:26.493553	0.57	BEACON
34	32	A-001	2026-04-17 22:18:26.768712	2026-04-17 22:18:33.47361	0.11	BEACON
35	33	A-001	2026-04-17 22:19:15.99048	2026-04-17 22:19:16.182087	0.00	BEACON
36	34	A-001	2026-04-17 22:19:23.172344	\N	\N	BEACON
37	34	A-001	2026-04-17 22:19:29.999685	2026-04-17 22:19:30.500367	0.01	BEACON
38	35	A-001	2026-04-18 12:51:44.422503	2026-04-18 12:51:51.954054	0.13	BEACON
39	36	A-001	2026-04-19 12:42:37.951494	2026-04-19 12:42:57.734078	0.33	BEACON
40	37	A-001	2026-04-19 12:44:43.806402	2026-04-19 12:44:59.34388	0.26	BEACON
41	38	A-001	2026-04-19 12:48:36.368894	2026-04-19 12:48:41.413748	0.08	BEACON
42	39	A-001	2026-04-19 12:48:43.507327	2026-04-19 12:48:57.633363	0.24	BEACON
43	40	A-001	2026-04-19 12:49:02.926503	2026-04-19 12:49:08.211441	0.09	BEACON
44	41	A-001	2026-04-19 12:51:09.352523	2026-04-19 12:52:12.693481	1.06	BEACON
45	42	A-001	2026-04-19 12:51:32.227532	2026-04-19 12:52:15.918461	0.73	BEACON
47	44	A-001	2026-04-19 12:52:57.296088	2026-04-19 12:55:59.834813	3.04	BEACON
46	43	A-001	2026-04-19 12:52:47.313093	2026-04-19 12:56:03.700791	3.27	BEACON
48	45	A-001	2026-04-19 12:56:45.85026	\N	\N	BEACON
49	46	A-001	2026-04-19 13:00:31.74741	2026-04-19 13:01:27.962653	0.94	BEACON
50	47	A-001	2026-04-19 13:02:10.464084	2026-04-19 13:02:34.536841	0.40	BEACON
51	48	A-001	2026-04-19 13:02:34.438659	2026-04-19 13:02:34.649555	0.00	BEACON
52	49	A-001	2026-04-19 13:02:34.746094	2026-04-19 13:02:34.927926	0.00	BEACON
53	50	A-001	2026-04-19 13:02:34.833276	2026-04-19 13:02:35.037579	0.00	BEACON
54	51	A-001	2026-04-19 13:02:36.959807	2026-04-19 13:02:44.394351	0.12	BEACON
55	52	A-001	2026-04-19 13:02:48.537361	2026-04-19 13:03:15.109151	0.44	BEACON
56	53	A-001	2026-04-19 13:03:19.251284	2026-04-19 13:03:35.862102	0.28	BEACON
57	54	A-001	2026-04-19 13:04:22.189758	\N	\N	BEACON
58	55	A-001	2026-04-19 13:04:24.685552	\N	\N	BEACON
59	56	A-001	2026-04-19 13:10:32.521737	2026-04-19 13:10:40.904028	0.14	BEACON
60	57	A-001	2026-04-19 13:10:45.634556	2026-04-19 13:10:51.685096	0.10	BEACON
61	58	A-001	2026-04-19 13:12:56.121329	2026-04-19 13:15:28.367625	2.54	BEACON
62	59	A-001	2026-04-19 13:13:01.933263	2026-04-19 13:15:33.415966	2.52	BEACON
64	61	A-001	2026-04-19 13:16:08.606524	2026-04-19 13:19:58.111033	3.83	BEACON
63	60	A-001	2026-04-19 13:16:02.207834	2026-04-19 13:20:05.275579	4.05	BEACON
66	63	A-001	2026-04-19 13:21:48.781073	2026-04-19 13:21:54.522385	0.10	BEACON
65	62	A-001	2026-04-19 13:21:46.547447	2026-04-19 13:22:05.021809	0.31	BEACON
68	65	A-001	2026-04-19 13:26:01.070623	2026-04-19 13:26:07.955527	0.11	BEACON
67	64	A-001	2026-04-19 13:25:56.689858	2026-04-19 13:26:11.590708	0.25	BEACON
69	66	A-001	2026-04-20 08:42:12.525245	2026-04-20 08:42:32.356254	0.33	BEACON
70	67	A-001	2026-04-20 08:42:41.264641	2026-04-20 08:42:46.568931	0.09	BEACON
71	68	A-001	2026-04-20 08:54:52.859946	2026-04-20 08:55:03.493384	0.18	BEACON
73	70	A-001	2026-04-20 08:56:23.712815	2026-04-20 08:56:28.956404	0.09	BEACON
72	69	A-001	2026-04-20 08:56:16.74321	2026-04-20 08:56:32.190221	0.26	BEACON
74	71	A-001	2026-04-20 08:57:18.177775	2026-04-20 08:57:29.316426	0.19	BEACON
75	72	A-001	2026-04-20 08:58:29.010569	2026-04-20 08:58:34.251682	0.09	BEACON
76	73	A-001	2026-04-20 09:26:00.857777	2026-04-20 09:26:06.178929	0.09	BEACON
77	74	A-001	2026-04-20 09:26:11.215865	2026-04-20 09:26:16.265022	0.08	BEACON
78	75	A-001	2026-04-20 10:42:07.08956	2026-04-20 10:42:42.557127	0.59	BEACON
79	76	A-001	2026-04-20 10:47:23.091395	2026-04-20 10:48:55.111983	1.53	BEACON
80	77	A-001	2026-04-20 10:47:33.744923	2026-04-20 10:49:11.732261	1.63	BEACON
81	78	A-001	2026-04-20 10:53:18.668599	2026-04-20 10:53:28.285489	0.16	BEACON
82	79	A-001	2026-04-20 11:10:32.200599	2026-04-20 11:10:37.755808	0.09	BEACON
83	80	A-001	2026-04-20 11:54:24.834333	2026-04-20 11:54:36.6203	0.20	BEACON
84	81	A-001	2026-04-20 11:56:25.587868	2026-04-20 11:56:38.330433	0.21	BEACON
86	83	A-001	2026-04-20 12:59:01.731453	2026-04-20 12:59:21.198431	0.32	BEACON
85	82	A-001	2026-04-20 12:58:38.499667	2026-04-20 12:59:25.663619	0.79	BEACON
87	84	A-001	2026-04-20 13:10:49.421002	2026-04-20 13:10:59.053031	0.16	BEACON
89	86	A-001	2026-04-20 13:11:44.834242	2026-04-20 13:11:58.425581	0.23	BEACON
88	85	A-001	2026-04-20 13:11:18.093281	2026-04-20 13:12:03.463896	0.76	BEACON
90	87	A-001	2026-04-20 13:12:41.084238	2026-04-20 13:12:54.043435	0.22	BEACON
91	88	A-001	2026-04-20 13:12:58.895095	2026-04-20 13:13:03.753698	0.08	BEACON
92	89	A-001	2026-04-20 13:13:09.479421	2026-04-20 13:13:14.317022	0.08	BEACON
93	90	A-001	2026-04-20 13:13:19.287601	2026-04-20 13:13:25.013981	0.10	BEACON
94	91	A-001	2026-04-20 13:13:31.512443	2026-04-20 13:13:34.138743	0.04	BEACON
95	92	A-001	2026-04-20 13:13:40.508529	2026-04-20 13:13:45.107211	0.08	BEACON
97	94	A-001	2026-04-20 13:13:46.5161	2026-04-20 13:13:51.458603	0.08	BEACON
98	95	A-001	2026-04-20 13:13:56.346117	2026-04-20 13:14:01.287748	0.08	BEACON
96	93	A-001	2026-04-20 13:13:45.98076	2026-04-20 13:14:04.924941	0.32	BEACON
99	96	A-001	2026-04-20 13:15:44.878953	2026-04-20 13:15:49.70089	0.08	BEACON
100	97	A-001	2026-04-20 13:15:54.98875	2026-04-20 13:15:59.97971	0.08	BEACON
101	98	A-001	2026-04-20 13:16:08.308309	2026-04-20 13:16:10.064486	0.03	BEACON
102	99	A-001	2026-04-20 13:16:10.670368	2026-04-20 13:16:15.689199	0.08	BEACON
103	100	A-001	2026-04-20 13:16:22.34974	2026-04-20 13:16:51.964819	0.49	BEACON
104	101	A-001	2026-04-20 14:34:29.926332	2026-04-20 14:34:40.103404	0.17	BEACON
105	102	A-001	2026-04-20 14:35:41.94563	2026-04-20 14:35:50.764805	0.15	BEACON
106	103	A-001	2026-04-20 14:37:50.496757	2026-04-20 14:38:00.381042	0.16	BEACON
107	104	A-001	2026-04-20 14:38:35.046627	2026-04-20 14:38:42.604592	0.13	BEACON
108	105	A-001	2026-04-20 20:11:28.399295	2026-04-20 20:11:35.639662	0.12	BEACON
109	106	A-001	2026-04-20 20:12:16.399848	2026-04-20 20:12:28.999661	0.21	BEACON
110	107	A-001	2026-04-20 20:19:11.538034	2026-04-20 20:19:17.556089	0.10	BEACON
112	109	A-001	2026-04-20 20:33:32.475576	2026-04-20 20:34:01.811055	0.49	BEACON
111	108	A-001	2026-04-20 20:33:27.101348	2026-04-20 20:34:04.562763	0.62	BEACON
113	110	A-001	2026-04-21 08:48:46.969442	2026-04-21 08:48:52.395001	0.09	BEACON
114	111	A-001	2026-04-21 08:49:39.287974	2026-04-21 08:49:48.120582	0.15	BEACON
115	112	A-001	2026-04-21 10:32:35.257293	2026-04-21 10:33:12.237579	0.62	BEACON
116	113	A-001	2026-04-21 10:32:47.800739	2026-04-21 10:33:17.806884	0.50	BEACON
117	114	A-001	2026-04-21 11:04:53.95162	2026-04-21 11:05:08.692203	0.25	BEACON
118	115	A-001	2026-04-21 11:05:33.667369	2026-04-21 11:05:43.988154	0.17	BEACON
119	116	A-001	2026-04-21 11:18:25.547793	2026-04-21 11:18:30.593385	0.08	BEACON
120	117	A-001	2026-04-21 11:18:44.301005	2026-04-21 11:18:59.134467	0.25	BEACON
121	118	A-001	2026-04-21 11:18:50.563594	2026-04-21 11:19:05.232333	0.24	BEACON
123	120	A-001	2026-04-21 12:14:21.369617	2026-04-21 12:14:37.693104	0.27	BEACON
122	119	A-001	2026-04-21 12:14:05.357395	2026-04-21 12:14:54.537296	0.82	BEACON
124	121	A-001	2026-04-21 12:14:42.265282	2026-04-21 12:15:00.389168	0.30	BEACON
125	122	A-001	2026-04-21 12:17:45.183537	2026-04-21 12:18:00.596101	0.26	BEACON
126	123	A-001	2026-04-21 12:23:33.768466	2026-04-21 12:26:49.456809	3.26	BEACON
127	124	A-001	2026-04-21 12:38:20.72251	2026-04-21 12:38:33.499581	0.21	BEACON
129	126	A-001	2026-04-21 12:39:28.704556	2026-04-21 12:39:35.935583	0.12	BEACON
128	125	A-001	2026-04-21 12:39:22.023561	2026-04-21 12:39:41.805728	0.33	BEACON
131	128	A-001	2026-04-21 12:45:53.815077	2026-04-21 12:46:01.813679	0.13	BEACON
130	127	A-001	2026-04-21 12:45:48.047527	2026-04-21 12:47:04.407468	1.27	BEACON
133	130	A-001	2026-04-21 12:53:33.217648	2026-04-21 12:53:39.1014	0.10	BEACON
132	129	A-001	2026-04-21 12:47:14.014337	2026-04-21 12:53:43.853544	6.50	BEACON
134	131	A-001	2026-04-21 12:59:47.501377	2026-04-21 12:59:56.358204	0.15	BEACON
135	132	A-001	2026-04-21 13:03:11.913052	2026-04-21 13:03:18.912228	0.12	BEACON
136	133	A-001	2026-04-21 13:05:06.634788	2026-04-21 13:06:54.398968	1.80	BEACON
137	134	A-001	2026-04-21 13:05:15.20898	2026-04-21 13:07:14.146666	1.98	BEACON
138	135	A-001	2026-04-21 13:12:02.115525	2026-04-21 13:12:06.785311	0.08	BEACON
139	136	A-001	2026-04-21 13:12:12.009982	2026-04-21 13:13:06.393215	0.91	BEACON
140	137	A-001	2026-04-21 13:12:18.042933	2026-04-21 13:13:17.752008	1.00	BEACON
141	138	A-001	2026-04-21 13:13:11.509755	2026-04-21 13:13:37.552148	0.43	BEACON
142	139	A-001	2026-04-21 17:29:51.12456	2026-04-21 17:29:58.981752	0.13	BEACON
143	140	A-001	2026-04-24 14:07:39.59092	2026-04-24 14:08:14.614906	0.58	BEACON
144	141	A-001	2026-04-24 14:09:06.076158	2026-04-24 14:09:11.710212	0.09	BEACON
145	142	A-001	2026-04-24 20:33:16.049943	2026-04-24 20:33:55.337407	0.65	BEACON
146	143	A-001	2026-04-24 20:34:27.040012	2026-04-24 20:34:35.257571	0.14	BEACON
147	144	A-001	2026-04-25 20:05:12.794978	2026-04-25 20:05:33.381152	0.34	BEACON
148	145	A-001	2026-04-25 20:08:01.467436	2026-04-25 20:08:21.645336	0.34	BEACON
149	146	A-001	2026-04-27 19:57:36.897333	2026-04-27 19:58:08.520657	0.53	BEACON
150	147	A-001	2026-04-27 19:58:29.919326	2026-04-27 19:58:42.720802	0.21	BEACON
151	148	A-001	2026-04-27 19:59:20.510503	2026-04-27 20:01:01.581316	1.68	BEACON
153	150	A-001	2026-04-27 20:01:51.933982	2026-04-27 20:02:00.077891	0.14	BEACON
152	149	A-001	2026-04-27 20:01:04.691194	2026-04-27 20:02:04.352033	0.99	BEACON
154	151	A-001	2026-04-28 08:25:26.304864	2026-04-28 08:25:31.698129	0.09	BEACON
155	152	A-001	2026-04-28 08:26:14.309308	2026-04-28 08:26:30.422765	0.27	BEACON
156	153	A-001	2026-04-28 08:27:02.508066	2026-04-28 08:27:09.124568	0.11	BEACON
157	154	A-001	2026-04-28 09:54:46.538533	2026-04-28 09:54:55.348952	0.15	BEACON
159	156	A-001	2026-04-28 09:55:49.686079	2026-04-28 09:55:54.824149	0.09	BEACON
160	157	A-001	2026-04-28 09:56:04.815497	2026-04-28 09:56:35.177566	0.51	BEACON
161	158	A-001	2026-04-28 09:56:10.863477	2026-04-28 09:56:39.633824	0.48	BEACON
158	155	A-001	2026-04-28 09:55:00.639271	2026-04-28 09:56:50.909257	1.84	BEACON
\.


--
-- Data for Name: eventos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.eventos (id_evento, id_ingreso, id_beacon, id_tipo_evento, timestamp_evento, rssi_signal) FROM stdin;
1	1	BCN-03	1	2024-03-15 08:00:00	-65
2	1	BCN-01	1	2024-03-15 08:02:00	-52
3	1	BCN-02	1	2024-03-15 08:45:00	-48
4	1	BCN-02	2	2024-03-15 12:25:00	-50
5	2	BCN-03	1	2024-03-15 09:05:00	-70
6	2	BCN-06	1	2024-03-15 09:15:00	-55
7	2	BCN-06	2	2024-03-15 09:55:00	-58
8	3	BCN-01	1	2024-03-05 22:15:00	-45
9	3	BCN-02	1	2024-03-05 22:18:00	-42
10	3	BCN-04	1	2024-03-05 23:00:00	-38
11	3	BCN-04	2	2024-03-06 05:55:00	-40
12	5	BCN-01	1	2024-03-12 17:30:00	-68
13	5	BCN-01	2	2024-03-12 19:55:00	-65
14	7	BCN-01	1	2024-03-10 14:00:00	-60
15	7	BCN-02	1	2024-03-10 14:10:00	-55
16	7	BCN-02	2	2024-03-10 18:25:00	-57
18	10	BCN-01	1	2026-04-16 17:24:47.716136	\N
19	10	BCN-01	2	2026-04-16 17:24:48.430932	\N
20	10	BCN-01	2	2026-04-16 17:25:00.521965	\N
21	11	BCN-01	1	2026-04-16 17:25:11.428651	\N
22	11	BCN-01	2	2026-04-16 17:25:12.026386	\N
23	11	BCN-01	2	2026-04-16 17:25:37.512076	\N
24	12	BCN-01	1	2026-04-16 17:34:53.198197	\N
25	12	BCN-01	2	2026-04-16 17:34:53.953586	\N
26	12	BCN-01	2	2026-04-16 17:35:05.891526	\N
27	13	BCN-01	1	2026-04-16 17:35:35.528393	\N
28	13	BCN-01	2	2026-04-16 17:35:36.111112	\N
29	13	BCN-01	2	2026-04-16 17:35:42.880859	\N
30	14	BCN-01	1	2026-04-16 18:25:28.190091	\N
31	14	BCN-01	2	2026-04-16 18:25:29.286674	\N
32	14	BCN-01	2	2026-04-16 18:25:38.446378	\N
33	15	BCN-01	1	2026-04-16 18:33:57.66245	\N
34	15	BCN-01	2	2026-04-16 18:34:03.563451	\N
35	15	BCN-01	2	2026-04-16 18:34:07.387845	\N
36	16	BCN-01	1	2026-04-16 18:40:12.579768	\N
37	16	BCN-01	2	2026-04-16 18:40:17.252541	\N
38	16	BCN-01	2	2026-04-16 18:40:26.758145	\N
39	17	BCN-01	1	2026-04-16 18:40:33.080656	\N
40	17	BCN-01	2	2026-04-16 18:40:33.874165	\N
41	17	BCN-01	2	2026-04-16 18:40:37.369296	\N
42	18	BCN-01	1	2026-04-16 22:01:09.678267	\N
43	18	BCN-01	2	2026-04-16 22:01:10.975497	\N
44	18	BCN-01	2	2026-04-16 22:01:14.708498	\N
45	19	BCN-01	1	2026-04-16 22:01:42.682835	\N
46	19	BCN-01	2	2026-04-16 22:01:47.201521	\N
47	19	BCN-01	2	2026-04-16 22:01:53.630988	\N
48	20	BCN-01	1	2026-04-16 22:02:00.181602	\N
49	20	BCN-01	2	2026-04-16 22:02:05.462182	\N
50	20	BCN-01	2	2026-04-16 22:02:07.737441	\N
51	21	BCN-01	1	2026-04-16 22:04:09.039319	\N
52	21	BCN-01	2	2026-04-16 22:04:12.406909	\N
53	21	BCN-01	2	2026-04-16 22:04:14.042553	\N
54	22	BCN-01	1	2026-04-17 21:43:15.850166	\N
55	22	BCN-01	2	2026-04-17 21:43:16.569796	\N
56	22	BCN-01	2	2026-04-17 21:43:25.8029	\N
57	23	BCN-01	1	2026-04-17 21:43:33.90505	\N
58	23	BCN-01	2	2026-04-17 21:43:34.697138	\N
59	23	BCN-01	2	2026-04-17 21:43:44.867815	\N
60	24	BCN-01	1	2026-04-17 21:49:44.169363	\N
61	24	BCN-01	2	2026-04-17 21:49:45.369241	\N
62	24	BCN-01	2	2026-04-17 21:49:53.309254	\N
63	25	BCN-01	1	2026-04-17 21:51:48.407908	\N
64	25	BCN-01	2	2026-04-17 21:51:52.551669	\N
65	25	BCN-01	2	2026-04-17 21:51:53.40508	\N
66	26	BCN-01	1	2026-04-17 21:55:56.465316	\N
67	26	BCN-01	2	2026-04-17 21:55:59.8699	\N
68	26	BCN-01	2	2026-04-17 21:56:03.343867	\N
69	27	BCN-01	1	2026-04-17 21:58:17.098533	\N
70	27	BCN-01	2	2026-04-17 21:58:20.798393	\N
71	27	BCN-01	2	2026-04-17 21:58:23.925243	\N
72	28	BCN-01	1	2026-04-17 22:00:31.032067	\N
73	28	BCN-01	2	2026-04-17 22:00:35.133023	\N
74	28	BCN-01	2	2026-04-17 22:00:36.915154	\N
75	29	BCN-01	1	2026-04-17 22:01:26.048266	\N
76	29	BCN-01	2	2026-04-17 22:01:26.506865	\N
77	29	BCN-01	2	2026-04-17 22:01:33.997754	\N
78	30	BCN-01	1	2026-04-17 22:01:37.441348	\N
79	30	BCN-01	2	2026-04-17 22:01:41.365545	\N
80	30	BCN-01	2	2026-04-17 22:01:42.865883	\N
81	31	BCN-01	1	2026-04-17 22:17:52.014586	\N
82	31	BCN-01	1	2026-04-17 22:17:58.016425	-49
83	31	BCN-01	1	2026-04-17 22:18:05.114695	-43
84	31	BCN-01	2	2026-04-17 22:18:12.173274	\N
85	31	BCN-01	2	2026-04-17 22:18:19.336972	\N
86	31	BCN-01	2	2026-04-17 22:18:26.485634	\N
87	31	BCN-01	2	2026-04-17 22:18:26.613132	\N
88	32	BCN-01	1	2026-04-17 22:18:26.772119	\N
89	32	BCN-01	2	2026-04-17 22:18:33.466726	\N
90	32	BCN-01	2	2026-04-17 22:18:55.849683	\N
91	33	BCN-01	1	2026-04-17 22:19:16.001547	\N
92	33	BCN-01	2	2026-04-17 22:19:16.185729	\N
93	34	BCN-01	1	2026-04-17 22:19:23.180393	\N
94	34	BCN-01	1	2026-04-17 22:19:29.994151	-48
95	34	BCN-01	2	2026-04-17 22:19:30.504037	\N
96	35	BCN-01	1	2026-04-18 12:51:44.430572	\N
97	35	BCN-01	2	2026-04-18 12:51:51.957938	\N
98	36	BCN-01	1	2026-04-19 12:42:37.957159	\N
99	36	BCN-01	2	2026-04-19 12:42:57.741604	\N
100	37	BCN-01	1	2026-04-19 12:44:43.809769	\N
101	37	BCN-01	2	2026-04-19 12:44:59.346087	\N
102	38	BCN-01	1	2026-04-19 12:48:36.373072	\N
103	38	BCN-01	2	2026-04-19 12:48:41.417374	\N
104	39	BCN-01	1	2026-04-19 12:48:43.510765	\N
105	39	BCN-01	2	2026-04-19 12:48:57.63702	\N
106	40	BCN-01	1	2026-04-19 12:49:02.93147	\N
107	40	BCN-01	2	2026-04-19 12:49:08.215823	\N
108	41	BCN-01	1	2026-04-19 12:51:09.356683	\N
109	42	BCN-01	1	2026-04-19 12:51:32.230768	\N
110	41	BCN-01	2	2026-04-19 12:52:12.698225	\N
111	42	BCN-01	2	2026-04-19 12:52:15.921939	\N
112	43	BCN-01	1	2026-04-19 12:52:47.316973	\N
113	44	BCN-01	1	2026-04-19 12:52:57.299176	\N
114	44	BCN-01	2	2026-04-19 12:55:59.839052	\N
115	43	BCN-01	2	2026-04-19 12:56:03.703145	\N
116	45	BCN-01	1	2026-04-19 12:56:45.854539	\N
117	46	BCN-01	1	2026-04-19 13:00:31.772669	\N
118	46	BCN-01	2	2026-04-19 13:01:27.966724	\N
119	47	BCN-01	1	2026-04-19 13:02:10.467865	\N
120	48	BCN-01	1	2026-04-19 13:02:34.44243	\N
121	47	BCN-01	2	2026-04-19 13:02:34.543404	\N
122	48	BCN-01	2	2026-04-19 13:02:34.652742	\N
123	49	BCN-01	1	2026-04-19 13:02:34.749231	\N
124	50	BCN-01	1	2026-04-19 13:02:34.836025	\N
125	49	BCN-01	2	2026-04-19 13:02:34.93057	\N
126	50	BCN-01	2	2026-04-19 13:02:35.040174	\N
127	51	BCN-01	1	2026-04-19 13:02:36.963452	\N
128	51	BCN-01	2	2026-04-19 13:02:44.398491	\N
129	52	BCN-01	1	2026-04-19 13:02:48.541087	\N
130	52	BCN-01	2	2026-04-19 13:03:15.112969	\N
131	53	BCN-01	1	2026-04-19 13:03:19.254574	\N
132	53	BCN-01	2	2026-04-19 13:03:35.865737	\N
133	54	BCN-01	1	2026-04-19 13:04:22.193252	\N
134	55	BCN-01	1	2026-04-19 13:04:24.688651	\N
135	56	BCN-01	1	2026-04-19 13:10:32.525616	\N
136	56	BCN-01	2	2026-04-19 13:10:40.907083	\N
137	57	BCN-01	1	2026-04-19 13:10:45.637105	\N
138	57	BCN-01	2	2026-04-19 13:10:51.688009	\N
139	58	BCN-01	1	2026-04-19 13:12:56.124843	\N
140	59	BCN-01	1	2026-04-19 13:13:01.936743	\N
141	58	BCN-01	2	2026-04-19 13:15:28.372185	\N
142	59	BCN-01	2	2026-04-19 13:15:33.418469	\N
143	60	BCN-01	1	2026-04-19 13:16:02.212355	\N
144	61	BCN-01	1	2026-04-19 13:16:08.60864	\N
145	61	BCN-01	2	2026-04-19 13:19:58.114149	\N
146	60	BCN-01	2	2026-04-19 13:20:05.277839	\N
147	62	BCN-01	1	2026-04-19 13:21:46.551802	\N
148	63	BCN-01	1	2026-04-19 13:21:48.783904	\N
149	63	BCN-01	2	2026-04-19 13:21:54.524255	\N
150	62	BCN-01	2	2026-04-19 13:22:05.025446	\N
151	64	BCN-01	1	2026-04-19 13:25:56.695949	\N
152	65	BCN-01	1	2026-04-19 13:26:01.072879	\N
153	65	BCN-01	2	2026-04-19 13:26:07.968524	\N
154	64	BCN-01	2	2026-04-19 13:26:11.593538	\N
155	66	BCN-01	1	2026-04-20 08:42:12.529144	\N
156	66	BCN-01	2	2026-04-20 08:42:32.359579	\N
157	67	BCN-01	1	2026-04-20 08:42:41.266779	\N
158	67	BCN-01	2	2026-04-20 08:42:46.571363	\N
159	68	BCN-01	1	2026-04-20 08:54:52.863551	\N
160	68	BCN-01	2	2026-04-20 08:55:03.496422	\N
161	69	BCN-01	1	2026-04-20 08:56:16.745321	\N
162	70	BCN-01	1	2026-04-20 08:56:23.715325	\N
163	70	BCN-01	2	2026-04-20 08:56:28.958968	\N
164	69	BCN-01	2	2026-04-20 08:56:32.192597	\N
165	71	BCN-01	1	2026-04-20 08:57:18.180863	\N
166	71	BCN-01	2	2026-04-20 08:57:29.341662	\N
167	72	BCN-01	1	2026-04-20 08:58:29.013459	\N
168	72	BCN-01	2	2026-04-20 08:58:34.254479	\N
169	73	BCN-01	1	2026-04-20 09:26:00.863569	\N
170	73	BCN-01	2	2026-04-20 09:26:06.181793	\N
171	74	BCN-01	1	2026-04-20 09:26:11.218041	\N
172	74	BCN-01	2	2026-04-20 09:26:16.267806	\N
173	75	BCN-01	1	2026-04-20 10:42:07.098592	\N
174	75	BCN-01	2	2026-04-20 10:42:42.56975	\N
175	76	BCN-01	1	2026-04-20 10:47:23.095531	\N
176	77	BCN-01	1	2026-04-20 10:47:33.747278	\N
177	76	BCN-01	2	2026-04-20 10:48:55.115249	\N
178	77	BCN-01	2	2026-04-20 10:49:11.739352	\N
179	78	BCN-01	1	2026-04-20 10:53:18.674334	\N
180	78	BCN-01	2	2026-04-20 10:53:28.288903	\N
181	79	BCN-01	1	2026-04-20 11:10:32.379938	\N
182	79	BCN-01	2	2026-04-20 11:10:37.770106	\N
183	80	BCN-01	1	2026-04-20 11:54:24.838583	\N
184	80	BCN-01	2	2026-04-20 11:54:36.624497	\N
185	81	BCN-01	1	2026-04-20 11:56:25.590876	\N
186	81	BCN-01	2	2026-04-20 11:56:38.33334	\N
187	82	BCN-01	1	2026-04-20 12:58:38.50546	\N
188	83	BCN-01	1	2026-04-20 12:59:01.736942	\N
189	83	BCN-01	2	2026-04-20 12:59:21.224277	\N
190	82	BCN-01	2	2026-04-20 12:59:25.66693	\N
191	84	BCN-01	1	2026-04-20 13:10:49.427116	\N
192	84	BCN-01	2	2026-04-20 13:10:59.055945	\N
193	85	BCN-01	1	2026-04-20 13:11:18.09757	\N
194	86	BCN-01	1	2026-04-20 13:11:44.836212	\N
195	86	BCN-01	2	2026-04-20 13:11:58.429689	\N
196	85	BCN-01	2	2026-04-20 13:12:03.466556	\N
197	87	BCN-01	1	2026-04-20 13:12:41.087043	\N
198	87	BCN-01	2	2026-04-20 13:12:54.046711	\N
199	88	BCN-01	1	2026-04-20 13:12:58.897727	\N
200	88	BCN-01	2	2026-04-20 13:13:03.760139	\N
201	89	BCN-01	1	2026-04-20 13:13:09.493551	\N
202	89	BCN-01	2	2026-04-20 13:13:14.319386	\N
203	90	BCN-01	1	2026-04-20 13:13:19.290496	\N
204	90	BCN-01	2	2026-04-20 13:13:25.016541	\N
205	91	BCN-01	1	2026-04-20 13:13:31.51469	\N
206	91	BCN-01	2	2026-04-20 13:13:34.140703	\N
207	92	BCN-01	1	2026-04-20 13:13:40.52206	\N
208	92	BCN-01	2	2026-04-20 13:13:45.110461	\N
209	93	BCN-01	1	2026-04-20 13:13:45.985176	\N
210	94	BCN-01	1	2026-04-20 13:13:46.518625	\N
211	94	BCN-01	2	2026-04-20 13:13:51.461091	\N
212	95	BCN-01	1	2026-04-20 13:13:56.349765	\N
213	95	BCN-01	2	2026-04-20 13:14:01.290027	\N
214	93	BCN-01	2	2026-04-20 13:14:04.927352	\N
215	96	BCN-01	1	2026-04-20 13:15:44.882975	\N
216	96	BCN-01	2	2026-04-20 13:15:49.7055	\N
217	97	BCN-01	1	2026-04-20 13:15:54.991524	\N
218	97	BCN-01	2	2026-04-20 13:15:59.981915	\N
219	98	BCN-01	1	2026-04-20 13:16:08.311037	\N
220	98	BCN-01	2	2026-04-20 13:16:10.066334	\N
221	99	BCN-01	1	2026-04-20 13:16:10.673501	\N
222	99	BCN-01	2	2026-04-20 13:16:15.691495	\N
223	100	BCN-01	1	2026-04-20 13:16:22.352382	\N
224	100	BCN-01	2	2026-04-20 13:16:51.972734	\N
225	101	BCN-01	1	2026-04-20 14:34:29.933963	\N
226	101	BCN-01	2	2026-04-20 14:34:40.107174	\N
227	102	BCN-01	1	2026-04-20 14:35:41.949599	\N
228	102	BCN-01	2	2026-04-20 14:35:50.768583	\N
229	103	BCN-01	1	2026-04-20 14:37:50.501785	\N
230	103	BCN-01	2	2026-04-20 14:38:00.384177	\N
231	104	BCN-01	1	2026-04-20 14:38:35.049496	\N
232	104	BCN-01	2	2026-04-20 14:38:42.614569	\N
233	105	BCN-01	1	2026-04-20 20:11:28.404784	\N
234	105	BCN-01	2	2026-04-20 20:11:35.642618	\N
235	106	BCN-01	1	2026-04-20 20:12:16.402829	\N
236	106	BCN-01	2	2026-04-20 20:12:29.002536	\N
237	107	BCN-01	1	2026-04-20 20:19:11.542961	\N
238	107	BCN-01	2	2026-04-20 20:19:17.563889	\N
239	108	BCN-01	1	2026-04-20 20:33:27.136219	\N
240	109	BCN-01	1	2026-04-20 20:33:32.479031	\N
241	109	BCN-01	2	2026-04-20 20:34:01.842986	\N
242	108	BCN-01	2	2026-04-20 20:34:04.565121	\N
243	110	BCN-01	1	2026-04-21 08:48:46.973643	\N
244	110	BCN-01	2	2026-04-21 08:48:52.39881	\N
245	111	BCN-01	1	2026-04-21 08:49:39.292121	\N
246	111	BCN-01	2	2026-04-21 08:49:48.124243	\N
247	112	BCN-01	1	2026-04-21 10:32:35.261996	\N
248	113	BCN-01	1	2026-04-21 10:32:47.804851	\N
249	112	BCN-01	2	2026-04-21 10:33:12.243264	\N
250	113	BCN-01	2	2026-04-21 10:33:17.809777	\N
251	114	BCN-01	1	2026-04-21 11:04:53.969339	\N
252	114	BCN-01	2	2026-04-21 11:05:08.696596	\N
253	115	BCN-01	1	2026-04-21 11:05:33.676122	\N
254	115	BCN-01	2	2026-04-21 11:05:43.990278	\N
255	116	BCN-01	1	2026-04-21 11:18:25.553903	\N
256	116	BCN-01	2	2026-04-21 11:18:30.596888	\N
257	117	BCN-01	1	2026-04-21 11:18:44.303773	\N
258	118	BCN-01	1	2026-04-21 11:18:50.566138	\N
259	117	BCN-01	2	2026-04-21 11:18:59.136387	\N
260	118	BCN-01	2	2026-04-21 11:19:05.234884	\N
261	119	BCN-01	1	2026-04-21 12:14:05.361736	\N
262	120	BCN-01	1	2026-04-21 12:14:21.371468	\N
263	120	BCN-01	2	2026-04-21 12:14:37.697033	\N
264	121	BCN-01	1	2026-04-21 12:14:42.268278	\N
265	119	BCN-01	2	2026-04-21 12:14:54.540675	\N
266	121	BCN-01	2	2026-04-21 12:15:00.392761	\N
267	122	BCN-01	1	2026-04-21 12:17:45.188467	\N
268	122	BCN-01	2	2026-04-21 12:18:00.59891	\N
269	123	BCN-01	1	2026-04-21 12:23:33.77066	\N
270	123	BCN-01	2	2026-04-21 12:26:49.46292	\N
271	124	BCN-01	1	2026-04-21 12:38:20.727069	\N
272	124	BCN-01	2	2026-04-21 12:38:33.50292	\N
273	125	BCN-01	1	2026-04-21 12:39:22.027685	\N
274	126	BCN-01	1	2026-04-21 12:39:28.706338	\N
275	126	BCN-01	2	2026-04-21 12:39:35.937882	\N
276	125	BCN-01	2	2026-04-21 12:39:41.80817	\N
277	127	BCN-01	1	2026-04-21 12:45:48.051756	\N
278	128	BCN-01	1	2026-04-21 12:45:53.818611	\N
279	128	BCN-01	2	2026-04-21 12:46:01.816461	\N
280	127	BCN-01	2	2026-04-21 12:47:04.410403	\N
281	129	BCN-01	1	2026-04-21 12:47:14.019428	\N
282	130	BCN-01	1	2026-04-21 12:53:33.221671	\N
283	130	BCN-01	2	2026-04-21 12:53:39.104106	\N
284	129	BCN-01	2	2026-04-21 12:53:43.855773	\N
285	131	BCN-01	1	2026-04-21 12:59:47.504863	\N
286	131	BCN-01	2	2026-04-21 12:59:56.372896	\N
287	132	BCN-01	1	2026-04-21 13:03:11.918447	\N
288	132	BCN-01	2	2026-04-21 13:03:18.91623	\N
289	133	BCN-01	1	2026-04-21 13:05:06.63779	\N
290	134	BCN-01	1	2026-04-21 13:05:15.21165	\N
291	133	BCN-01	2	2026-04-21 13:06:54.411035	\N
292	134	BCN-01	2	2026-04-21 13:07:14.150383	\N
293	135	BCN-01	1	2026-04-21 13:12:02.124814	\N
294	135	BCN-01	2	2026-04-21 13:12:06.789024	\N
295	136	BCN-01	1	2026-04-21 13:12:12.02283	\N
296	137	BCN-01	1	2026-04-21 13:12:18.045648	\N
297	136	BCN-01	2	2026-04-21 13:13:06.396481	\N
298	138	BCN-01	1	2026-04-21 13:13:11.51405	\N
299	137	BCN-01	2	2026-04-21 13:13:17.754317	\N
300	138	BCN-01	2	2026-04-21 13:13:37.555502	\N
301	139	BCN-01	1	2026-04-21 17:29:51.132131	\N
302	139	BCN-01	2	2026-04-21 17:29:58.985441	\N
303	140	BCN-01	1	2026-04-24 14:07:39.603601	\N
304	140	BCN-01	2	2026-04-24 14:08:14.65519	\N
305	141	BCN-01	1	2026-04-24 14:09:06.079111	\N
306	141	BCN-01	2	2026-04-24 14:09:11.712624	\N
307	142	BCN-01	1	2026-04-24 20:33:16.060579	\N
308	142	BCN-01	2	2026-04-24 20:33:55.355509	\N
309	143	BCN-01	1	2026-04-24 20:34:27.043994	\N
310	143	BCN-01	2	2026-04-24 20:34:35.259875	\N
311	144	BCN-01	1	2026-04-25 20:05:12.804284	\N
312	144	BCN-01	2	2026-04-25 20:05:33.428392	\N
313	145	BCN-01	1	2026-04-25 20:08:01.471682	\N
314	145	BCN-01	2	2026-04-25 20:08:21.647741	\N
315	146	BCN-01	1	2026-04-27 19:57:36.90428	\N
316	146	BCN-01	2	2026-04-27 19:58:08.523523	\N
317	147	BCN-01	1	2026-04-27 19:58:29.922605	\N
318	147	BCN-01	2	2026-04-27 19:58:42.722668	\N
319	148	BCN-01	1	2026-04-27 19:59:20.515661	\N
320	148	BCN-01	2	2026-04-27 20:01:01.5866	\N
321	149	BCN-01	1	2026-04-27 20:01:04.694235	\N
322	150	BCN-01	1	2026-04-27 20:01:51.937173	\N
323	150	BCN-01	2	2026-04-27 20:02:00.102725	\N
324	149	BCN-01	2	2026-04-27 20:02:04.354125	\N
325	151	BCN-01	1	2026-04-28 08:25:26.311945	\N
326	151	BCN-01	2	2026-04-28 08:25:31.702962	\N
327	152	BCN-01	1	2026-04-28 08:26:14.313214	\N
328	152	BCN-01	2	2026-04-28 08:26:30.426157	\N
329	153	BCN-01	1	2026-04-28 08:27:02.510431	\N
330	153	BCN-01	2	2026-04-28 08:27:09.12723	\N
331	154	BCN-01	1	2026-04-28 09:54:46.600123	\N
332	154	BCN-01	2	2026-04-28 09:54:55.352074	\N
333	155	BCN-01	1	2026-04-28 09:55:00.640774	\N
334	156	BCN-01	1	2026-04-28 09:55:49.688792	\N
335	156	BCN-01	2	2026-04-28 09:55:54.82828	\N
336	157	BCN-01	1	2026-04-28 09:56:04.818506	\N
337	158	BCN-01	1	2026-04-28 09:56:10.865237	\N
338	157	BCN-01	2	2026-04-28 09:56:35.179524	\N
339	158	BCN-01	2	2026-04-28 09:56:39.635864	\N
340	155	BCN-01	2	2026-04-28 09:56:50.91224	\N
\.


--
-- Data for Name: expedientes; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.expedientes (id_expediente, num_expediente, id_paciente, id_hospital, medico_titular, fecha_apertura, activo, notas_iniciales) FROM stdin;
1	EXP-001	1	1	CED-001	2024-01-10	t	Paciente con antecedentes de hipertensión
2	EXP-002	2	1	CED-002	2024-01-15	t	Control pediátrico anual
3	EXP-003	3	1	CED-003	2024-02-01	t	Primera consulta medicina interna
4	EXP-004	4	1	CED-001	2024-02-10	t	Seguimiento cardiológico post-infarto
5	EXP-005	5	1	CED-005	2024-02-20	t	Lesión deportiva rodilla derecha
6	EXP-006	6	1	CED-001	2024-03-01	t	Paciente diabética tipo 2 con HTA
7	EXP-007	7	1	CED-004	2024-03-05	t	Ingreso por urgencias, fiebre alta
8	EXP-008	8	1	CED-002	2024-03-10	t	Pediatría — control vacunación
11	EXP-021	21	1	CED-001	2026-04-20	t	Expediente de prueba
12	EXP-022	16	2	CED-004	2026-04-20	t	\N
13	EXP-023	23	3	CED-003	2026-04-21	t	\N
\.


--
-- Data for Name: historial_estados_ingreso; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.historial_estados_ingreso (id_historial, id_ingreso, id_usuario, timestamp_cambio, estado_anterior, estado_nuevo, motivo, ip_origen) FROM stdin;
\.


--
-- Data for Name: horarios_medico; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.horarios_medico (id_horario, id_consultorio, id_turno, id_dia, max_pacientes, activo) FROM stdin;
1	3	1	1	8	t
2	3	1	2	8	t
3	3	1	3	8	t
4	3	1	4	8	t
5	3	1	5	8	t
6	4	1	1	6	t
7	4	1	2	6	t
8	4	1	3	6	t
9	4	1	4	6	t
10	4	1	5	6	t
11	4	2	1	5	t
12	4	2	2	5	t
13	5	1	3	6	t
14	5	1	4	6	t
15	5	1	5	6	t
16	1	4	1	15	t
17	1	4	2	15	t
18	1	4	3	15	t
19	1	4	4	15	t
20	1	4	5	15	t
21	1	4	6	12	t
22	1	4	7	12	t
\.


--
-- Data for Name: hospitales; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.hospitales (id_hospital, nombre, direccion, telefono, rfc, tipo_hospital, activo) FROM stdin;
1	Hospital General Regional No. 1	Av. Constitución 1200, Monterrey, NL	81-1234-5678	HGR010101XXX	PUBLICO	t
2	Hospital Universitario UANL	Av. Francisco I. Madero 1291, Mty, NL	81-8347-3400	HUN020202YYY	PUBLICO	t
3	Hospital Christus Muguerza Sur	Av. Morones Prieto 3000, Mty, NL	81-8399-3400	HCM030303ZZZ	PRIVADO	t
\.


--
-- Data for Name: ingresos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.ingresos (id_ingreso, id_expediente, cedula_medico, id_cita, tipo_ingreso, motivo_ingreso, fecha_ingreso, estado, fecha_egreso, tiempo_espera_min) FROM stdin;
1	1	CED-004	\N	URGENCIA	Dolor torácico opresivo con irradiación al brazo izquierdo	2024-03-15 08:00:00	COMPLETADO	2024-03-15 12:30:00	10.00
2	2	CED-002	2	PROGRAMADO	Control pediátrico semestral	2024-03-15 09:05:00	COMPLETADO	2024-03-15 10:00:00	5.00
3	7	CED-004	\N	URGENCIA	Fiebre 39.8°C, convulsión febril, 5 minutos de duración	2024-03-05 22:15:00	COMPLETADO	2024-03-06 06:00:00	3.00
4	4	CED-001	3	PROGRAMADO	Seguimiento cardio post-bypass — control ecocardiograma	2024-03-20 10:00:00	COMPLETADO	2024-03-20 11:45:00	8.00
5	5	CED-005	\N	URGENCIA	Traumatismo rodilla derecha — caída practicando fútbol	2024-03-12 17:30:00	COMPLETADO	2024-03-12 20:00:00	22.00
6	6	CED-001	6	PROGRAMADO	Control metabólico — DM2 e HTA descompensada	2024-03-18 08:00:00	COMPLETADO	2024-03-18 09:30:00	0.00
7	3	CED-003	\N	URGENCIA	Dificultad respiratoria, saturación 88%, fiebre 38.5°C	2024-03-10 14:00:00	COMPLETADO	2024-03-10 18:30:00	15.00
71	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:57:18.172359	ALTA	2026-04-20 08:57:29.309791	0.19
10	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 17:24:47.617817	ALTA	2026-04-16 17:25:00.501822	0.21
11	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 17:25:11.402705	ALTA	2026-04-16 17:25:37.473732	0.43
12	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 17:34:53.170765	ALTA	2026-04-16 17:35:05.881192	0.21
13	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 17:35:35.506575	ALTA	2026-04-16 17:35:42.867989	0.12
14	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 18:25:28.147947	ALTA	2026-04-16 18:25:38.427713	0.17
15	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 18:33:57.632189	ALTA	2026-04-16 18:34:07.374118	0.16
16	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 18:40:12.55067	ALTA	2026-04-16 18:40:26.747578	0.24
17	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 18:40:33.062402	ALTA	2026-04-16 18:40:37.355302	0.07
18	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 22:01:09.638702	ALTA	2026-04-16 22:01:14.69673	0.08
19	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 22:01:42.656157	ALTA	2026-04-16 22:01:53.618877	0.18
20	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 22:02:00.161693	ALTA	2026-04-16 22:02:07.725676	0.13
21	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-16 22:04:09.002147	ALTA	2026-04-16 22:04:14.028176	0.08
22	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:43:15.739639	ALTA	2026-04-17 21:43:25.79052	0.17
23	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:43:33.884362	ALTA	2026-04-17 21:43:44.842417	0.18
24	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:49:44.119884	ALTA	2026-04-17 21:49:53.2958	0.15
25	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:51:48.376363	ALTA	2026-04-17 21:51:53.39312	0.08
26	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:55:56.435774	ALTA	2026-04-17 21:56:03.333039	0.11
27	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 21:58:17.069753	ALTA	2026-04-17 21:58:23.915977	0.11
28	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:00:30.996944	ALTA	2026-04-17 22:00:36.901807	0.10
29	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:01:26.017131	ALTA	2026-04-17 22:01:33.984262	0.13
30	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:01:37.424087	ALTA	2026-04-17 22:01:42.850841	0.09
31	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:17:51.984826	ALTA	2026-04-17 22:18:26.600878	0.58
32	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:18:26.761079	ALTA	2026-04-17 22:18:55.832226	0.48
33	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:19:15.978944	ALTA	2026-04-17 22:19:16.172213	0.00
34	1	CED-001	\N	PROGRAMADO	Registro automático por lectura NFC — sala de espera	2026-04-17 22:19:23.163373	ALTA	2026-04-17 22:19:30.489527	0.12
35	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-18 12:51:44.389975	ALTA	2026-04-18 12:51:51.943841	0.13
36	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:42:37.936899	ALTA	2026-04-19 12:42:57.720699	0.33
37	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:44:43.797456	ALTA	2026-04-19 12:44:59.335646	0.26
38	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:48:36.358526	ALTA	2026-04-19 12:48:41.403897	0.08
39	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:48:43.500454	ALTA	2026-04-19 12:48:57.625472	0.24
40	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:49:02.917526	ALTA	2026-04-19 12:49:08.199856	0.09
8	8	CED-002	5	PROGRAMADO	Primera consulta pediátrica — evaluación general	2024-03-25 09:30:00	ALTA	2026-04-19 12:50:38.913147	\N
41	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:51:09.344996	ALTA	2026-04-19 12:52:12.685239	1.06
42	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:51:32.21995	ALTA	2026-04-19 12:52:15.910067	0.73
44	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:52:57.28967	ALTA	2026-04-19 12:55:59.822079	3.04
43	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:52:47.296748	ALTA	2026-04-19 12:56:03.694576	3.27
46	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:00:31.70195	ALTA	2026-04-19 13:01:27.952241	0.94
47	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:10.455024	ALTA	2026-04-19 13:02:34.529725	0.40
48	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:34.424215	ALTA	2026-04-19 13:02:34.643177	0.00
49	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:34.739151	ALTA	2026-04-19 13:02:34.921543	0.00
50	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:34.826101	ALTA	2026-04-19 13:02:35.030997	0.00
51	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:36.953056	ALTA	2026-04-19 13:02:44.384767	0.12
52	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:02:48.530861	ALTA	2026-04-19 13:03:15.098298	0.44
53	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:03:19.244023	ALTA	2026-04-19 13:03:35.854501	0.28
45	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 12:56:45.838093	ALTA	2026-04-19 13:03:42.839591	\N
56	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:10:32.502609	ALTA	2026-04-19 13:10:40.89273	0.14
54	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:04:22.178484	ALTA	2026-04-19 13:12:32.211698	\N
57	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:10:45.627751	ALTA	2026-04-19 13:10:51.676221	0.10
55	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:04:24.677853	ALTA	2026-04-19 13:12:32.211698	\N
72	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:58:29.002861	ALTA	2026-04-20 08:58:34.244812	0.09
58	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:12:56.108814	ALTA	2026-04-19 13:15:28.35674	2.54
59	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:13:01.924333	ALTA	2026-04-19 13:15:33.405522	2.52
73	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 09:26:00.847317	ALTA	2026-04-20 09:26:06.17144	0.09
74	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 09:26:11.211297	ALTA	2026-04-20 09:26:16.261158	0.08
61	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:16:08.601619	ALTA	2026-04-19 13:19:58.100318	3.82
60	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:16:02.200817	ALTA	2026-04-19 13:20:05.26933	4.05
75	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 10:42:07.062729	ALTA	2026-04-20 10:42:42.540435	0.59
63	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:21:48.775269	ALTA	2026-04-19 13:21:54.517279	0.10
62	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:21:46.537647	ALTA	2026-04-19 13:22:05.014723	0.31
76	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 10:47:23.079682	ALTA	2026-04-20 10:48:55.102162	1.53
77	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 10:47:33.740002	ALTA	2026-04-20 10:49:11.710793	1.63
65	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:26:01.0635	ALTA	2026-04-19 13:26:07.949552	0.11
64	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-19 13:25:56.68101	ALTA	2026-04-19 13:26:11.585124	0.25
66	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:42:12.507101	ALTA	2026-04-20 08:42:32.347366	0.33
78	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 10:53:18.650587	ALTA	2026-04-20 10:53:28.279344	0.16
67	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:42:41.257732	ALTA	2026-04-20 08:42:46.564246	0.09
68	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:54:52.844315	ALTA	2026-04-20 08:55:03.486762	0.18
79	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 11:10:32.079934	ALTA	2026-04-20 11:10:37.750499	0.09
70	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:56:23.704498	ALTA	2026-04-20 08:56:28.952074	0.09
69	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 08:56:16.735454	ALTA	2026-04-20 08:56:32.18414	0.26
80	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 11:54:24.817029	ALTA	2026-04-20 11:54:36.614689	0.20
81	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 11:56:25.571565	ALTA	2026-04-20 11:56:38.32218	0.21
83	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 12:59:01.714972	ALTA	2026-04-20 12:59:21.103152	0.32
82	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 12:58:38.474584	ALTA	2026-04-20 12:59:25.654513	0.79
84	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:10:49.405436	ALTA	2026-04-20 13:10:59.046932	0.16
86	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:11:44.828132	ALTA	2026-04-20 13:11:58.418048	0.23
85	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:11:18.079305	ALTA	2026-04-20 13:12:03.459295	0.76
87	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:12:41.074016	ALTA	2026-04-20 13:12:54.037355	0.22
88	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:12:58.890859	ALTA	2026-04-20 13:13:03.742766	0.08
89	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:09.473319	ALTA	2026-04-20 13:13:14.309636	0.08
90	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:19.277033	ALTA	2026-04-20 13:13:25.007482	0.10
91	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:31.50682	ALTA	2026-04-20 13:13:34.134267	0.04
92	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:40.329239	ALTA	2026-04-20 13:13:45.100664	0.08
94	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:46.509381	ALTA	2026-04-20 13:13:51.451785	0.08
95	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:56.339096	ALTA	2026-04-20 13:14:01.283018	0.08
93	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:13:45.971769	ALTA	2026-04-20 13:14:04.918531	0.32
96	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:15:44.855652	ALTA	2026-04-20 13:15:49.693145	0.08
97	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:15:54.98326	ALTA	2026-04-20 13:15:59.972927	0.08
98	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:16:08.299119	ALTA	2026-04-20 13:16:10.05852	0.03
99	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:16:10.664406	ALTA	2026-04-20 13:16:15.683723	0.08
100	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 13:16:22.343709	ALTA	2026-04-20 13:16:51.959386	0.49
101	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 14:34:29.905996	ALTA	2026-04-20 14:34:40.092619	0.17
102	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 14:35:41.93611	ALTA	2026-04-20 14:35:50.753772	0.15
103	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 14:37:50.485927	ALTA	2026-04-20 14:38:00.365934	0.16
104	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 14:38:35.025074	ALTA	2026-04-20 14:38:42.600067	0.13
105	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 20:11:28.380972	ALTA	2026-04-20 20:11:35.629484	0.12
106	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 20:12:16.389851	ALTA	2026-04-20 20:12:28.989137	0.21
107	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 20:19:11.523931	ALTA	2026-04-20 20:19:17.547627	0.10
109	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 20:33:32.467839	ALTA	2026-04-20 20:34:01.800607	0.49
108	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-20 20:33:26.891159	ALTA	2026-04-20 20:34:04.553926	0.63
110	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 08:48:46.945693	ALTA	2026-04-21 08:48:52.387856	0.09
111	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 08:49:39.279411	ALTA	2026-04-21 08:49:48.113146	0.15
112	12	CED-004	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 10:32:35.244126	ALTA	2026-04-21 10:33:12.230653	0.62
113	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 10:32:47.791054	ALTA	2026-04-21 10:33:17.791061	0.50
114	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 11:04:53.93303	ALTA	2026-04-21 11:05:08.682677	0.25
115	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 11:05:33.654227	ALTA	2026-04-21 11:05:43.983697	0.17
116	13	CED-003	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 11:18:25.531042	ALTA	2026-04-21 11:18:30.570211	0.08
117	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 11:18:44.292612	ALTA	2026-04-21 11:18:59.129596	0.25
118	13	CED-003	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 11:18:50.55668	ALTA	2026-04-21 11:19:05.221558	0.24
119	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:14:05.34551	ALTA	2026-04-21 12:14:54.53106	0.82
120	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:14:21.365032	ALTA	2026-04-21 12:14:37.68177	0.27
146	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-27 19:57:36.87206	ALTA	2026-04-27 19:58:08.516366	0.53
121	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:14:42.260388	ALTA	2026-04-21 12:15:00.382378	0.30
147	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-27 19:58:29.912507	ALTA	2026-04-27 19:58:42.715182	0.21
122	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:17:45.170723	ALTA	2026-04-21 12:18:00.589387	0.26
148	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-27 19:59:20.50049	ALTA	2026-04-27 20:01:01.569758	1.68
123	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:23:33.755957	ALTA	2026-04-21 12:26:49.444627	3.26
124	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:38:20.708639	ALTA	2026-04-21 12:38:33.492828	0.21
150	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-27 20:01:51.925301	ALTA	2026-04-27 20:02:00.049268	0.14
149	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-27 20:01:04.682076	ALTA	2026-04-27 20:02:04.347545	0.99
126	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:39:28.69681	ALTA	2026-04-21 12:39:35.931432	0.12
125	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:39:22.005683	ALTA	2026-04-21 12:39:41.799313	0.33
151	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 08:25:26.286721	ALTA	2026-04-28 08:25:31.689957	0.09
128	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:45:53.806191	ALTA	2026-04-21 12:46:01.808735	0.13
127	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:45:48.033651	ALTA	2026-04-21 12:47:04.369866	1.27
152	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 08:26:14.297135	ALTA	2026-04-28 08:26:30.414618	0.27
130	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:53:33.20599	ALTA	2026-04-21 12:53:39.095262	0.10
129	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:47:13.981426	ALTA	2026-04-21 12:53:43.841759	6.50
131	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 12:59:47.491338	ALTA	2026-04-21 12:59:56.353142	0.15
153	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 08:27:02.498617	ALTA	2026-04-28 08:27:09.119934	0.11
132	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:03:11.90381	ALTA	2026-04-21 13:03:18.904712	0.12
154	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 09:54:46.30698	ALTA	2026-04-28 09:54:55.343324	0.15
133	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:05:06.622464	ALTA	2026-04-21 13:06:54.391534	1.80
134	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:05:15.203084	ALTA	2026-04-21 13:07:14.138135	1.98
135	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:12:02.10309	ALTA	2026-04-21 13:12:06.776544	0.08
156	13	CED-003	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 09:55:49.678193	ALTA	2026-04-28 09:55:54.817506	0.09
136	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:12:12.003067	ALTA	2026-04-21 13:13:06.385343	0.91
137	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:12:18.03559	ALTA	2026-04-21 13:13:17.745061	1.00
138	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 13:13:11.501958	ALTA	2026-04-21 13:13:37.543471	0.43
139	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-21 17:29:51.104074	ALTA	2026-04-21 17:29:58.97298	0.13
157	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 09:56:04.807785	ALTA	2026-04-28 09:56:35.173147	0.51
140	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-24 14:07:39.297839	ALTA	2026-04-24 14:08:14.595605	0.59
158	12	CED-004	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 09:56:10.858287	ALTA	2026-04-28 09:56:39.628876	0.48
141	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-24 14:09:06.060923	ALTA	2026-04-24 14:09:11.704518	0.09
155	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-28 09:55:00.612831	ALTA	2026-04-28 09:56:50.902421	1.84
142	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-24 20:33:16.031729	ALTA	2026-04-24 20:33:55.3235	0.65
143	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-24 20:34:27.032018	ALTA	2026-04-24 20:34:35.253351	0.14
159	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-30 23:58:50.240451	ALTA	2026-04-30 23:59:07.031765	0.28
144	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-25 20:05:12.778085	ALTA	2026-04-25 20:05:33.375854	0.34
145	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-04-25 20:08:01.456289	ALTA	2026-04-25 20:08:21.641438	0.34
160	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-04-30 23:59:17.906909	ALTA	2026-04-30 23:59:23.085199	0.09
161	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-01 16:43:28.629702	ALTA	2026-05-01 16:43:45.001273	0.27
163	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-01 16:50:32.382485	ALTA	2026-05-01 16:50:38.457018	0.10
164	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-01 16:50:48.987879	ALTA	2026-05-01 16:51:26.578568	0.63
162	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-01 16:50:12.462205	ALTA	2026-05-01 16:51:30.008486	1.29
165	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-01 16:53:31.851806	ALTA	2026-05-01 16:53:45.18628	0.22
166	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-03 12:48:05.815903	ALTA	2026-05-03 12:48:13.892731	0.13
167	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-03 12:56:44.295151	ALTA	2026-05-03 12:56:52.65202	0.14
168	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-03 13:11:46.04614	ALTA	2026-05-05 08:30:47.632911	2599.03
169	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-05 10:38:48.9609	ALTA	2026-05-05 10:39:41.739712	0.88
170	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-05 10:40:40.022885	ALTA	2026-05-05 10:40:46.392688	0.11
171	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-05 21:14:13.530602	ALTA	2026-05-05 21:16:12.017929	1.97
172	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-05 21:17:39.303077	ALTA	2026-05-05 21:17:47.625384	0.14
173	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-05 21:18:04.661266	ALTA	2026-05-05 21:18:29.925125	0.42
174	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 19:52:00.648768	ALTA	2026-05-06 19:52:14.587407	0.23
175	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 20:12:00.877623	ALTA	2026-05-06 20:12:15.315591	0.24
176	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 20:20:04.596386	ALTA	2026-05-06 20:20:09.849643	0.09
177	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 20:27:59.781136	ALTA	2026-05-06 20:35:51.036533	7.85
178	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 20:28:12.510272	ALTA	2026-05-06 20:35:56.009216	7.72
179	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-06 20:38:15.13366	ALTA	2026-05-06 20:41:32.77782	3.29
180	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:26:06.053826	ALTA	\N	\N
181	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:43:39.093318	ALTA	\N	\N
182	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:52:09.904064	ALTA	\N	\N
184	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:54:35.194913	ALTA	\N	\N
183	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:54:26.100867	ALTA	\N	\N
185	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 17:56:43.86852	ALTA	2026-05-07 17:56:48.86989	0.08
186	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 20:21:23.286403	ALTA	2026-05-07 20:21:32.938609	0.16
187	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 20:23:07.960319	ALTA	\N	\N
188	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-07 20:24:11.554334	ALTA	\N	\N
189	8	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-08 08:29:15.660139	ALTA	\N	\N
190	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-08 09:25:30.276874	ALTA	2026-05-08 09:27:31.833102	2.03
191	8	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-08 09:28:44.6533	ALTA	\N	\N
192	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-08 13:58:48.515642	ALTA	2026-05-09 09:44:59.977828	1186.19
193	8	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-09 09:45:17.043075	ALTA	\N	\N
194	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-09 09:46:02.844696	ALTA	\N	\N
195	11	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-09 09:46:20.48046	ALTA	2026-05-09 09:50:02.63818	3.70
197	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 11:20:07.996404	ALTA	2026-05-11 11:20:17.264811	0.15
196	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 11:19:38.848561	ALTA	2026-05-11 11:20:25.924817	0.78
198	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 11:20:47.292042	ALTA	\N	\N
199	8	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:39:52.002049	ALTA	\N	\N
200	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:42:28.443175	ALTA	2026-05-11 16:42:35.827569	0.12
201	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:44:03.20141	ALTA	2026-05-11 16:44:19.863854	0.28
202	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:53:20.038144	ALTA	2026-05-11 16:53:26.457843	0.11
203	8	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:53:37.899819	ALTA	\N	\N
204	8	CED-002	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 16:55:11.326089	ALTA	2026-05-11 16:56:12.620966	1.02
205	1	CED-001	\N	PROGRAMADO	Registro automático por NFC	2026-05-11 22:30:06.208303	ALTA	2026-05-11 22:33:46.983159	3.68
\.


--
-- Data for Name: log_acceso; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.log_acceso (id_log, id_usuario, accion, tabla_afectada, id_registro, timestamp_accion, detalle) FROM stdin;
1	5	INSERT	ingresos	1	2024-03-15 08:01:00	Nuevo ingreso urgencia — EXP-001
2	5	INSERT	triajes	1	2024-03-15 08:06:00	Triaje nivel NARANJA — FC 110, PA 160/100
3	2	UPDATE	diagnosticos	2	2024-03-15 11:01:00	Diagnóstico definitivo IAM anterior confirmado
4	2	INSERT	diagnosticos	1	2024-03-15 09:01:00	Diagnóstico presuntivo angina inestable
5	1	INSERT	usuarios	9	2024-03-14 10:00:00	Alta de usuario auditor1
6	1	INSERT	pacientes	21	2026-04-20 20:06:18.392562	Nuevo paciente: Marcelo Avila
7	1	INSERT	pacientes	23	2026-04-21 11:16:28.82765	Nuevo paciente: David Jimenez
8	1	UPDATE	pacientes	21	2026-05-08 09:26:24.25895	Actualizacion paciente ID 21
9	1	UPDATE	pacientes	21	2026-05-08 09:27:14.182122	Actualizacion paciente ID 21
10	1	INSERT	pacientes	17	2026-05-11 22:31:55.24005	Nuevo paciente: Marceloo Tecmilenio
\.


--
-- Data for Name: mantenimientos_beacon; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.mantenimientos_beacon (id_mantenimiento, id_beacon, fecha_inicio, fecha_fin, tipo_mantenimiento, descripcion, responsable) FROM stdin;
\.


--
-- Data for Name: medicos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.medicos (cedula_medico, nombre, apellidop, apellidom, id_especialidad, telefono, email, activo, foto) FROM stdin;
CED-001	Roberto	Ramírez	Soto	1	81-0001-0001	rramirez@hgr.mx	t	\N
CED-002	Patricia	Torres	Vega	2	81-0001-0002	ptorres@hgr.mx	t	\N
CED-003	Carlos	Mendoza	Ríos	3	81-0001-0003	cmendoza@hgr.mx	t	\N
CED-004	Sofía	Guerrero	Leal	5	81-0001-0004	sguerrero@hgr.mx	t	\N
CED-005	Diego	Salinas	Mora	4	81-0001-0005	dsalinas@hgr.mx	t	\N
CED-006	Laura	Pérez	Castillo	6	81-0001-0006	lperez@hgr.mx	t	\N
\.


--
-- Data for Name: metricas_consultorio; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.metricas_consultorio (id_metrica_cons, id_consultorio, fecha, citas_programadas, citas_realizadas, citas_canceladas) FROM stdin;
1	3	2024-03-15	8	7	1
2	4	2024-03-15	6	6	0
3	3	2024-03-20	8	8	0
4	4	2024-03-22	6	5	1
5	5	2024-03-25	6	0	0
\.


--
-- Data for Name: metricas_diarias; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.metricas_diarias (id_metrica, id_area, fecha, total_ingresos, tiempo_espera_prom, tiempo_estancia_prom) FROM stdin;
1	A-001	2024-03-15	8	12.50	185.30
2	A-001	2024-03-05	14	8.20	210.00
3	A-001	2024-03-10	11	18.70	165.50
4	A-001	2024-03-12	9	22.10	145.00
5	A-005	2024-03-15	6	5.00	42.00
\.


--
-- Data for Name: metricas_medico; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.metricas_medico (id_metrica_med, cedula_medico, fecha, total_pacientes, tiempo_consulta_prom) FROM stdin;
1	CED-001	2024-03-15	5	48.00
2	CED-001	2024-03-18	4	52.50
3	CED-001	2024-03-20	3	55.00
4	CED-002	2024-03-15	6	38.50
5	CED-004	2024-03-15	12	22.00
6	CED-004	2024-03-05	18	19.50
7	CED-003	2024-03-10	7	42.00
\.


--
-- Data for Name: modelos_beacon; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.modelos_beacon (id_modelo, fabricante, modelo, protocolo, rango_metros) FROM stdin;
1	Estimote	Proximity Beacon S	BLE	10
2	Estimote	Location Beacon F	BLE	70
3	Zebra	MB1000 Healthcare Tag	BLE	30
4	Kontakt.io	S18-3 Patient Tag	BLE	15
5	Sewio	UWB Tag T200	UWB	100
\.


--
-- Data for Name: pacientes; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.pacientes (id_paciente, curp, nombre, apellidop, apellidom, fecha_nac, sexo, tipo_sangre, telefono, email, foto) FROM stdin;
1	GOLM900512MNLPZR09	María	González	López	1990-05-12	F	O+	81-1111-0001	mgonzalez@mail.com	\N
2	TOVA850320HNLRGS07	Ana	Torres	Vega	1985-03-20	F	A+	81-2222-0002	atorres@mail.com	\N
3	HEMA010615HNLRNS08	Alejandro	Hernández	Martínez	2001-06-15	M	B+	81-3333-0003	ahernandez@mail.com	\N
4	MORC780901MNLRSL04	Claudia	Morales	Castillo	1978-09-01	F	AB-	81-4444-0004	cmorales@mail.com	\N
5	PELD950725HNLRRD05	Luis	Pérez	Delgado	1995-07-25	M	O-	81-5555-0005	lperez@mail.com	\N
6	SARM680415MNLNDR06	Rosa	Sánchez	Ramírez	1968-04-15	F	A-	81-6666-0006	\N	\N
8	JUDP110820MNLRZL08	Valentina	Juárez	Pacheco	2011-08-20	F	O+	81-8888-0008	\N	\N
16	TEST900101HDFXXX02	Marce	Guerra	Cantu	2026-04-01	F	B+	81-0000-0001	david.jimenezsaldivar@udem.ede	\N
23	LOLM700423LNMPRR06	David	Jimenez	Saldivar	2006-07-07	M	B+	81938475646	david.jimenez@udem.edu	\N
7	FLOC030210HNLRLR07	Emilio	Flores	Cruz	2003-02-10	M	B+	81-7777-0007	eflores@mail.com	\N
21	GOMM699513MLNPRR08	Marcelo	Avila	Garza	2006-01-31	M	B+	8123647584	marcelo.avila@udem.edu	https://preview.free3d.com/img/2013/03/2400292568383358450/4mz0q0pu.jpg
\.


--
-- Data for Name: permisos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.permisos (id_permiso, nombre, descripcion, modulo) FROM stdin;
1	VER_METRICAS	Ver dashboards y reportes de métricas	Métricas
2	EDITAR_PACIENTES	Crear y modificar datos de pacientes	Pacientes
3	VER_EXPEDIENTES	Consultar expedientes clínicos	Clínico
4	EDITAR_DIAGNOSTICOS	Registrar y modificar diagnósticos	Clínico
5	GESTIONAR_CITAS	Crear, modificar y cancelar citas	Citas
6	VER_BEACONS	Consultar eventos y estancias beacon	IoT
7	GESTIONAR_USUARIOS	Alta, baja y modificación de usuarios	Seguridad
8	VER_LOGS	Consultar log de acceso del sistema	Seguridad
9	REGISTRAR_TRIAJE	Registrar signos vitales y nivel de triaje	Clínico
10	GESTIONAR_ALERTAS	Configurar umbrales y resolver alertas	Métricas
\.


--
-- Data for Name: personal_enfermeria; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.personal_enfermeria (id_enfermero, nombre, apellidop, apellidom, cedula, nivel, activo) FROM stdin;
1	Jorge	Salinas	Martínez	ENF-001	JEFE_PISO	t
2	Carmen	Vázquez	López	ENF-002	ESPECIALISTA	t
3	Miguel	Cruz	Herrera	ENF-003	GENERAL	t
4	Daniela	Rojas	Fuentes	ENF-004	GENERAL	t
5	Beatriz	Hernández	Gómez	ENF-005	SUPERVISOR	t
6	Ricardo	Mora	Sandoval	ENF-006	GENERAL	t
\.


--
-- Data for Name: pisos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.pisos (id_piso, id_edificio, numero_piso, nombre_piso) FROM stdin;
1	1	0	Planta Baja — Urgencias
2	1	1	Piso 1 — UCI
3	1	2	Piso 2 — Observación
4	2	0	Planta Baja — Recepción
5	2	1	Piso 1 — Cardiología
6	2	2	Piso 2 — Pediatría
7	3	0	Planta Baja — Laboratorio
\.


--
-- Data for Name: rol_permiso; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.rol_permiso (id_rol, id_permiso) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
1	7
1	8
1	9
1	10
2	1
2	3
2	4
2	5
2	6
3	3
3	6
3	9
4	3
4	5
4	2
5	1
5	8
5	6
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.roles (id_rol, nombre, descripcion) FROM stdin;
1	ADMIN	Administrador total del sistema
2	MEDICO	Acceso clínico — expedientes, citas, diagnósticos
3	ENFERMERO	Acceso a triajes, estancias y eventos beacon
4	RECEPCION	Gestión de citas y registro de pacientes
5	AUDITOR	Acceso de solo lectura a métricas y logs
\.


--
-- Data for Name: seguros_paciente; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.seguros_paciente (id_seguro, id_paciente, id_aseguradora, num_poliza, vigencia_desde, vigencia_hasta, activo) FROM stdin;
1	1	1	IMSS-123456789	2024-01-01	2024-12-31	t
2	2	1	IMSS-234567890	2024-01-01	2024-12-31	t
3	3	2	ISSSTE-345678901	2024-01-01	2024-12-31	t
4	4	3	GNP-456789012	2023-07-01	2024-06-30	t
5	5	4	MET-567890123	2024-03-01	2025-02-28	t
6	6	6	SP-678901234	2024-01-01	2024-12-31	t
7	7	1	IMSS-789012345	2024-01-01	2024-12-31	t
8	8	1	IMSS-890123456	2024-01-01	2024-12-31	t
\.


--
-- Data for Name: servicios; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.servicios (id_servicio, nombre, descripcion, activo) FROM stdin;
1	Urgencias Generales	Atención de urgencias 24 horas	t
2	Cardiología	Atención cardiológica especializada	t
3	Pediatría	Atención médica infantil	t
4	Laboratorio Clínico	Análisis de muestras biológicas	t
5	Imagenología	Rayos X, TAC, Resonancia	t
6	Farmacia	Dispensación y control de medicamentos	t
7	Medicina Interna	Atención de enfermedades sistémicas	t
8	Traumatología	Atención de lesiones del aparato locomotor	t
\.


--
-- Data for Name: sesiones; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.sesiones (id_sesion, id_usuario, token_hash, ip_origen, timestamp_inicio, timestamp_fin, activa) FROM stdin;
1	1	tok_admin_abc123def456	192.168.1.10	2024-03-15 07:50:00	2024-03-15 17:00:00	f
2	2	tok_ramirez_xyz789ghi	192.168.1.11	2024-03-15 07:55:00	2024-03-15 14:30:00	f
3	5	tok_guerrero_pqr012stu	192.168.1.15	2024-03-15 07:58:00	\N	t
\.


--
-- Data for Name: tarjetas_nfc; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.tarjetas_nfc (uid_hex, id_paciente, descripcion, fecha_registro) FROM stdin;
31B91507	1	Descripcion	2026-04-15 14:03:15.693107
AB251607	8	Tarjeta de Valentina	2026-04-19 12:48:15.370547
DF45E68B	21	Marcelo Avila Estudiante	2026-04-20 20:09:59.229494
FFAED88B	16	\N	2026-04-21 10:32:31.965163
7F4ADB8B	23	\N	2026-04-21 11:18:08.628635
\.


--
-- Data for Name: tipos_area; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.tipos_area (id_tipo_area, nombre, descripcion) FROM stdin;
1	Urgencias	Atención de emergencias médicas
2	Sala de Espera	Área de espera para pacientes y familiares
3	Consultorio	Consulta médica individual
4	Laboratorio	Toma y análisis de muestras
5	UCI	Unidad de Cuidados Intensivos
6	Radiología	Estudios de imagen
7	Farmacia	Dispensación de medicamentos
8	Administrativo	Áreas administrativas y de gestión
\.


--
-- Data for Name: tipos_evento; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.tipos_evento (id_tipo_evento, nombre, genera_estancia) FROM stdin;
1	ENTRADA	t
2	SALIDA	t
3	PASO	f
4	ALERTA	f
\.


--
-- Data for Name: triajes; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.triajes (id_triaje, id_ingreso, id_enfermero, nivel_triaje, frecuencia_cardiaca, presion_sistolica, presion_diastolica, temperatura, saturacion_o2, glasgow, timestamp_triaje, observaciones) FROM stdin;
1	179	3	ROJO	120	120	60	36.0	98	15	2026-05-06 20:38:46.916988	\N
\.


--
-- Data for Name: turnos; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.turnos (id_turno, nombre, hora_inicio, hora_fin) FROM stdin;
1	MATUTINO	07:00:00	14:00:00
2	VESPERTINO	14:00:00	21:00:00
3	NOCTURNO	21:00:00	07:00:00
4	GUARDIA_24H	07:00:00	07:00:00
\.


--
-- Data for Name: umbrales_alerta; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.umbrales_alerta (id_umbral, id_hospital, id_area, nombre_metrica, valor_umbral, activo) FROM stdin;
1	1	A-001	tiempo_espera_prom	30.00	t
2	1	A-001	ocupacion_porcentaje	90.00	t
3	1	A-003	tiempo_espera_prom	5.00	t
4	1	\N	citas_canceladas_dia	10.00	t
\.


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: hospital_admin
--

COPY public.usuarios (id_usuario, username, password_hash, id_rol, cedula_medico, id_enfermero, id_hospital, activo) FROM stdin;
1	admin	$2b$12$hash_admin_placeholder	1	\N	\N	1	t
2	dr_ramirez	medico123	2	CED-001	\N	1	t
3	dr_torres	medico123	2	CED-002	\N	1	t
4	dr_mendoza	medico123	2	CED-003	\N	1	t
5	dr_guerrero	medico123	2	CED-004	\N	1	t
6	enf_salinas	enfermero123	3	\N	1	1	t
7	enf_vazquez	enfermero123	3	\N	2	1	t
8	recepcion1	recepcion123	4	\N	\N	1	t
9	auditor1	auditor123	5	\N	\N	1	t
\.


--
-- Name: alertas_saturacion_id_alerta_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.alertas_saturacion_id_alerta_seq', 3, true);


--
-- Name: antecedentes_id_antecedente_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.antecedentes_id_antecedente_seq', 6, true);


--
-- Name: aseguradoras_id_aseguradora_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.aseguradoras_id_aseguradora_seq', 6, true);


--
-- Name: asignaciones_area_id_asignacion_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.asignaciones_area_id_asignacion_seq', 6, true);


--
-- Name: cat_alergias_id_alergia_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.cat_alergias_id_alergia_seq', 8, true);


--
-- Name: cat_diagnosticos_id_diagnostico_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.cat_diagnosticos_id_diagnostico_seq', 10, true);


--
-- Name: citas_id_cita_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.citas_id_cita_seq', 7, true);


--
-- Name: consultorios_id_consultorio_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.consultorios_id_consultorio_seq', 5, true);


--
-- Name: contactos_emergencia_id_contacto_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.contactos_emergencia_id_contacto_seq', 8, true);


--
-- Name: diagnosticos_id_reg_dx_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.diagnosticos_id_reg_dx_seq', 9, true);


--
-- Name: edificios_id_edificio_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.edificios_id_edificio_seq', 5, true);


--
-- Name: especialidades_id_especialidad_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.especialidades_id_especialidad_seq', 8, true);


--
-- Name: estados_cita_id_estado_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.estados_cita_id_estado_seq', 7, true);


--
-- Name: estancias_id_estancia_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.estancias_id_estancia_seq', 161, true);


--
-- Name: eventos_id_evento_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.eventos_id_evento_seq', 231, true);


--
-- Name: expedientes_id_expediente_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.expedientes_id_expediente_seq', 14, true);


--
-- Name: historial_estados_ingreso_id_historial_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.historial_estados_ingreso_id_historial_seq', 1, false);


--
-- Name: horarios_medico_id_horario_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.horarios_medico_id_horario_seq', 23, true);


--
-- Name: hospitales_id_hospital_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.hospitales_id_hospital_seq', 5, true);


--
-- Name: ingresos_id_ingreso_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.ingresos_id_ingreso_seq', 206, true);


--
-- Name: log_acceso_id_log_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.log_acceso_id_log_seq', 10, true);


--
-- Name: mantenimientos_beacon_id_mantenimiento_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.mantenimientos_beacon_id_mantenimiento_seq', 1, false);


--
-- Name: metricas_consultorio_id_metrica_cons_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.metricas_consultorio_id_metrica_cons_seq', 5, true);


--
-- Name: metricas_diarias_id_metrica_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.metricas_diarias_id_metrica_seq', 5, true);


--
-- Name: metricas_medico_id_metrica_med_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.metricas_medico_id_metrica_med_seq', 7, true);


--
-- Name: modelos_beacon_id_modelo_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.modelos_beacon_id_modelo_seq', 5, true);


--
-- Name: pacientes_id_paciente_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.pacientes_id_paciente_seq', 23, true);


--
-- Name: permisos_id_permiso_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.permisos_id_permiso_seq', 10, true);


--
-- Name: personal_enfermeria_id_enfermero_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.personal_enfermeria_id_enfermero_seq', 6, true);


--
-- Name: pisos_id_piso_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.pisos_id_piso_seq', 7, true);


--
-- Name: roles_id_rol_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.roles_id_rol_seq', 5, true);


--
-- Name: seguros_paciente_id_seguro_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.seguros_paciente_id_seguro_seq', 9, true);


--
-- Name: servicios_id_servicio_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.servicios_id_servicio_seq', 8, true);


--
-- Name: sesiones_id_sesion_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.sesiones_id_sesion_seq', 4, true);


--
-- Name: tipos_area_id_tipo_area_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.tipos_area_id_tipo_area_seq', 8, true);


--
-- Name: tipos_evento_id_tipo_evento_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.tipos_evento_id_tipo_evento_seq', 4, true);


--
-- Name: triajes_id_triaje_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.triajes_id_triaje_seq', 1, true);


--
-- Name: turnos_id_turno_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.turnos_id_turno_seq', 4, true);


--
-- Name: umbrales_alerta_id_umbral_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.umbrales_alerta_id_umbral_seq', 4, true);


--
-- Name: usuarios_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: hospital_admin
--

SELECT pg_catalog.setval('public.usuarios_id_usuario_seq', 9, true);


--
-- Name: alergias_paciente alergias_paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alergias_paciente
    ADD CONSTRAINT alergias_paciente_pkey PRIMARY KEY (id_paciente, id_alergia);


--
-- Name: alertas_saturacion alertas_saturacion_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alertas_saturacion
    ADD CONSTRAINT alertas_saturacion_pkey PRIMARY KEY (id_alerta);


--
-- Name: antecedentes antecedentes_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.antecedentes
    ADD CONSTRAINT antecedentes_pkey PRIMARY KEY (id_antecedente);


--
-- Name: area_servicio area_servicio_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.area_servicio
    ADD CONSTRAINT area_servicio_pkey PRIMARY KEY (id_area, id_servicio);


--
-- Name: areas areas_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_pkey PRIMARY KEY (id_area);


--
-- Name: aseguradoras aseguradoras_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.aseguradoras
    ADD CONSTRAINT aseguradoras_nombre_key UNIQUE (nombre);


--
-- Name: aseguradoras aseguradoras_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.aseguradoras
    ADD CONSTRAINT aseguradoras_pkey PRIMARY KEY (id_aseguradora);


--
-- Name: asignaciones_area asignaciones_area_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.asignaciones_area
    ADD CONSTRAINT asignaciones_area_pkey PRIMARY KEY (id_asignacion);


--
-- Name: beacons beacons_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.beacons
    ADD CONSTRAINT beacons_pkey PRIMARY KEY (id_beacon);


--
-- Name: beacons beacons_uuid_beacon_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.beacons
    ADD CONSTRAINT beacons_uuid_beacon_key UNIQUE (uuid_beacon);


--
-- Name: cat_alergias cat_alergias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.cat_alergias
    ADD CONSTRAINT cat_alergias_nombre_key UNIQUE (nombre);


--
-- Name: cat_alergias cat_alergias_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.cat_alergias
    ADD CONSTRAINT cat_alergias_pkey PRIMARY KEY (id_alergia);


--
-- Name: cat_diagnosticos cat_diagnosticos_codigo_cie10_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.cat_diagnosticos
    ADD CONSTRAINT cat_diagnosticos_codigo_cie10_key UNIQUE (codigo_cie10);


--
-- Name: cat_diagnosticos cat_diagnosticos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.cat_diagnosticos
    ADD CONSTRAINT cat_diagnosticos_pkey PRIMARY KEY (id_diagnostico);


--
-- Name: citas citas_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT citas_pkey PRIMARY KEY (id_cita);


--
-- Name: consultorios consultorios_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.consultorios
    ADD CONSTRAINT consultorios_pkey PRIMARY KEY (id_consultorio);


--
-- Name: contactos_emergencia contactos_emergencia_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.contactos_emergencia
    ADD CONSTRAINT contactos_emergencia_pkey PRIMARY KEY (id_contacto);


--
-- Name: diagnosticos diagnosticos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.diagnosticos
    ADD CONSTRAINT diagnosticos_pkey PRIMARY KEY (id_reg_dx);


--
-- Name: dias_semana dias_semana_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.dias_semana
    ADD CONSTRAINT dias_semana_nombre_key UNIQUE (nombre);


--
-- Name: dias_semana dias_semana_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.dias_semana
    ADD CONSTRAINT dias_semana_pkey PRIMARY KEY (id_dia);


--
-- Name: edificios edificios_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.edificios
    ADD CONSTRAINT edificios_pkey PRIMARY KEY (id_edificio);


--
-- Name: especialidades especialidades_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.especialidades
    ADD CONSTRAINT especialidades_nombre_key UNIQUE (nombre);


--
-- Name: especialidades especialidades_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.especialidades
    ADD CONSTRAINT especialidades_pkey PRIMARY KEY (id_especialidad);


--
-- Name: estados_cita estados_cita_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.estados_cita
    ADD CONSTRAINT estados_cita_nombre_key UNIQUE (nombre);


--
-- Name: estados_cita estados_cita_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.estados_cita
    ADD CONSTRAINT estados_cita_pkey PRIMARY KEY (id_estado);


--
-- Name: estancias estancias_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.estancias
    ADD CONSTRAINT estancias_pkey PRIMARY KEY (id_estancia);


--
-- Name: eventos eventos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_pkey PRIMARY KEY (id_evento);


--
-- Name: expedientes expedientes_num_expediente_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.expedientes
    ADD CONSTRAINT expedientes_num_expediente_key UNIQUE (num_expediente);


--
-- Name: expedientes expedientes_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.expedientes
    ADD CONSTRAINT expedientes_pkey PRIMARY KEY (id_expediente);


--
-- Name: historial_estados_ingreso historial_estados_ingreso_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.historial_estados_ingreso
    ADD CONSTRAINT historial_estados_ingreso_pkey PRIMARY KEY (id_historial);


--
-- Name: horarios_medico horarios_medico_id_consultorio_id_turno_id_dia_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.horarios_medico
    ADD CONSTRAINT horarios_medico_id_consultorio_id_turno_id_dia_key UNIQUE (id_consultorio, id_turno, id_dia);


--
-- Name: horarios_medico horarios_medico_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.horarios_medico
    ADD CONSTRAINT horarios_medico_pkey PRIMARY KEY (id_horario);


--
-- Name: hospitales hospitales_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.hospitales
    ADD CONSTRAINT hospitales_pkey PRIMARY KEY (id_hospital);


--
-- Name: hospitales hospitales_rfc_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.hospitales
    ADD CONSTRAINT hospitales_rfc_key UNIQUE (rfc);


--
-- Name: ingresos ingresos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_pkey PRIMARY KEY (id_ingreso);


--
-- Name: log_acceso log_acceso_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.log_acceso
    ADD CONSTRAINT log_acceso_pkey PRIMARY KEY (id_log);


--
-- Name: mantenimientos_beacon mantenimientos_beacon_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.mantenimientos_beacon
    ADD CONSTRAINT mantenimientos_beacon_pkey PRIMARY KEY (id_mantenimiento);


--
-- Name: medicos medicos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.medicos
    ADD CONSTRAINT medicos_pkey PRIMARY KEY (cedula_medico);


--
-- Name: metricas_consultorio metricas_consultorio_id_consultorio_fecha_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_consultorio
    ADD CONSTRAINT metricas_consultorio_id_consultorio_fecha_key UNIQUE (id_consultorio, fecha);


--
-- Name: metricas_consultorio metricas_consultorio_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_consultorio
    ADD CONSTRAINT metricas_consultorio_pkey PRIMARY KEY (id_metrica_cons);


--
-- Name: metricas_diarias metricas_diarias_id_area_fecha_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_diarias
    ADD CONSTRAINT metricas_diarias_id_area_fecha_key UNIQUE (id_area, fecha);


--
-- Name: metricas_diarias metricas_diarias_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_diarias
    ADD CONSTRAINT metricas_diarias_pkey PRIMARY KEY (id_metrica);


--
-- Name: metricas_medico metricas_medico_cedula_medico_fecha_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_medico
    ADD CONSTRAINT metricas_medico_cedula_medico_fecha_key UNIQUE (cedula_medico, fecha);


--
-- Name: metricas_medico metricas_medico_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_medico
    ADD CONSTRAINT metricas_medico_pkey PRIMARY KEY (id_metrica_med);


--
-- Name: modelos_beacon modelos_beacon_fabricante_modelo_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.modelos_beacon
    ADD CONSTRAINT modelos_beacon_fabricante_modelo_key UNIQUE (fabricante, modelo);


--
-- Name: modelos_beacon modelos_beacon_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.modelos_beacon
    ADD CONSTRAINT modelos_beacon_pkey PRIMARY KEY (id_modelo);


--
-- Name: pacientes pacientes_curp_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT pacientes_curp_key UNIQUE (curp);


--
-- Name: pacientes pacientes_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pacientes
    ADD CONSTRAINT pacientes_pkey PRIMARY KEY (id_paciente);


--
-- Name: permisos permisos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_nombre_key UNIQUE (nombre);


--
-- Name: permisos permisos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.permisos
    ADD CONSTRAINT permisos_pkey PRIMARY KEY (id_permiso);


--
-- Name: personal_enfermeria personal_enfermeria_cedula_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.personal_enfermeria
    ADD CONSTRAINT personal_enfermeria_cedula_key UNIQUE (cedula);


--
-- Name: personal_enfermeria personal_enfermeria_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.personal_enfermeria
    ADD CONSTRAINT personal_enfermeria_pkey PRIMARY KEY (id_enfermero);


--
-- Name: pisos pisos_id_edificio_numero_piso_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pisos
    ADD CONSTRAINT pisos_id_edificio_numero_piso_key UNIQUE (id_edificio, numero_piso);


--
-- Name: pisos pisos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pisos
    ADD CONSTRAINT pisos_pkey PRIMARY KEY (id_piso);


--
-- Name: rol_permiso rol_permiso_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_pkey PRIMARY KEY (id_rol, id_permiso);


--
-- Name: roles roles_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id_rol);


--
-- Name: seguros_paciente seguros_paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.seguros_paciente
    ADD CONSTRAINT seguros_paciente_pkey PRIMARY KEY (id_seguro);


--
-- Name: servicios servicios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.servicios
    ADD CONSTRAINT servicios_nombre_key UNIQUE (nombre);


--
-- Name: servicios servicios_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.servicios
    ADD CONSTRAINT servicios_pkey PRIMARY KEY (id_servicio);


--
-- Name: sesiones sesiones_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.sesiones
    ADD CONSTRAINT sesiones_pkey PRIMARY KEY (id_sesion);


--
-- Name: sesiones sesiones_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.sesiones
    ADD CONSTRAINT sesiones_token_hash_key UNIQUE (token_hash);


--
-- Name: tarjetas_nfc tarjetas_nfc_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tarjetas_nfc
    ADD CONSTRAINT tarjetas_nfc_pkey PRIMARY KEY (uid_hex);


--
-- Name: tipos_area tipos_area_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tipos_area
    ADD CONSTRAINT tipos_area_nombre_key UNIQUE (nombre);


--
-- Name: tipos_area tipos_area_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tipos_area
    ADD CONSTRAINT tipos_area_pkey PRIMARY KEY (id_tipo_area);


--
-- Name: tipos_evento tipos_evento_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tipos_evento
    ADD CONSTRAINT tipos_evento_nombre_key UNIQUE (nombre);


--
-- Name: tipos_evento tipos_evento_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tipos_evento
    ADD CONSTRAINT tipos_evento_pkey PRIMARY KEY (id_tipo_evento);


--
-- Name: triajes triajes_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.triajes
    ADD CONSTRAINT triajes_pkey PRIMARY KEY (id_triaje);


--
-- Name: turnos turnos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.turnos
    ADD CONSTRAINT turnos_nombre_key UNIQUE (nombre);


--
-- Name: turnos turnos_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.turnos
    ADD CONSTRAINT turnos_pkey PRIMARY KEY (id_turno);


--
-- Name: umbrales_alerta umbrales_alerta_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.umbrales_alerta
    ADD CONSTRAINT umbrales_alerta_pkey PRIMARY KEY (id_umbral);


--
-- Name: seguros_paciente uq_poliza_aseguradora; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.seguros_paciente
    ADD CONSTRAINT uq_poliza_aseguradora UNIQUE (id_aseguradora, num_poliza);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id_usuario);


--
-- Name: usuarios usuarios_username_key; Type: CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_username_key UNIQUE (username);


--
-- Name: idx_alertas_area; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_alertas_area ON public.alertas_saturacion USING btree (id_area);


--
-- Name: idx_alertas_resuelta; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_alertas_resuelta ON public.alertas_saturacion USING btree (resuelta) WHERE (resuelta = false);


--
-- Name: idx_beacons_area; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_beacons_area ON public.beacons USING btree (id_area);


--
-- Name: idx_citas_fecha; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_citas_fecha ON public.citas USING btree (fecha_cita);


--
-- Name: idx_citas_horario; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_citas_horario ON public.citas USING btree (id_horario);


--
-- Name: idx_diagnosticos_ingreso; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_diagnosticos_ingreso ON public.diagnosticos USING btree (id_ingreso);


--
-- Name: idx_estancias_area; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_estancias_area ON public.estancias USING btree (id_area);


--
-- Name: idx_estancias_ingreso; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_estancias_ingreso ON public.estancias USING btree (id_ingreso);


--
-- Name: idx_eventos_beacon; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_eventos_beacon ON public.eventos USING btree (id_beacon);


--
-- Name: idx_eventos_ingreso; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_eventos_ingreso ON public.eventos USING btree (id_ingreso);


--
-- Name: idx_eventos_timestamp; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_eventos_timestamp ON public.eventos USING btree (timestamp_evento DESC);


--
-- Name: idx_expedientes_paciente; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_expedientes_paciente ON public.expedientes USING btree (id_paciente);


--
-- Name: idx_historial_ingreso; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_historial_ingreso ON public.historial_estados_ingreso USING btree (id_ingreso);


--
-- Name: idx_ingresos_estado; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_ingresos_estado ON public.ingresos USING btree (estado);


--
-- Name: idx_ingresos_expediente; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_ingresos_expediente ON public.ingresos USING btree (id_expediente);


--
-- Name: idx_ingresos_fecha; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_ingresos_fecha ON public.ingresos USING btree (fecha_ingreso DESC);


--
-- Name: idx_log_timestamp; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_log_timestamp ON public.log_acceso USING btree (timestamp_accion DESC);


--
-- Name: idx_log_usuario; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_log_usuario ON public.log_acceso USING btree (id_usuario);


--
-- Name: idx_pacientes_curp; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_pacientes_curp ON public.pacientes USING btree (curp);


--
-- Name: idx_sesiones_activa; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_sesiones_activa ON public.sesiones USING btree (activa) WHERE (activa = true);


--
-- Name: idx_sesiones_usuario; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_sesiones_usuario ON public.sesiones USING btree (id_usuario);


--
-- Name: idx_tarjetas_nfc_paciente; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE INDEX idx_tarjetas_nfc_paciente ON public.tarjetas_nfc USING btree (id_paciente);


--
-- Name: uq_contacto_principal; Type: INDEX; Schema: public; Owner: hospital_admin
--

CREATE UNIQUE INDEX uq_contacto_principal ON public.contactos_emergencia USING btree (id_paciente) WHERE (es_principal = true);


--
-- Name: estancias trg_calcular_duracion_estancia; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_calcular_duracion_estancia BEFORE UPDATE ON public.estancias FOR EACH ROW EXECUTE FUNCTION public.fn_calcular_duracion_estancia();


--
-- Name: beacons trg_log_beacons; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_beacons AFTER INSERT OR UPDATE ON public.beacons FOR EACH ROW EXECUTE FUNCTION public.fn_log_beacons();


--
-- Name: ingresos trg_log_ingresos; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_ingresos AFTER INSERT OR UPDATE ON public.ingresos FOR EACH ROW EXECUTE FUNCTION public.fn_log_ingresos();


--
-- Name: medicos trg_log_medicos; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_medicos AFTER INSERT OR DELETE OR UPDATE ON public.medicos FOR EACH ROW EXECUTE FUNCTION public.fn_log_medicos();


--
-- Name: pacientes trg_log_pacientes; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_pacientes AFTER INSERT OR DELETE OR UPDATE ON public.pacientes FOR EACH ROW EXECUTE FUNCTION public.fn_log_pacientes();


--
-- Name: triajes trg_log_triajes; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_triajes AFTER INSERT OR UPDATE ON public.triajes FOR EACH ROW EXECUTE FUNCTION public.fn_log_triajes();


--
-- Name: usuarios trg_log_usuarios; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_log_usuarios AFTER INSERT OR DELETE OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_log_usuarios();


--
-- Name: estancias trg_validar_capacidad_area; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_validar_capacidad_area BEFORE INSERT ON public.estancias FOR EACH ROW EXECUTE FUNCTION public.fn_validar_capacidad_area();


--
-- Name: ingresos trg_validar_ingreso_unico; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_validar_ingreso_unico BEFORE INSERT OR UPDATE ON public.ingresos FOR EACH ROW EXECUTE FUNCTION public.fn_validar_ingreso_unico();


--
-- Name: usuarios trg_validar_rol_usuario; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_validar_rol_usuario BEFORE INSERT OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION public.fn_validar_rol_usuario();


--
-- Name: triajes trg_validar_triaje; Type: TRIGGER; Schema: public; Owner: hospital_admin
--

CREATE TRIGGER trg_validar_triaje BEFORE INSERT OR UPDATE ON public.triajes FOR EACH ROW EXECUTE FUNCTION public.fn_validar_triaje();


--
-- Name: alergias_paciente alergias_paciente_id_alergia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alergias_paciente
    ADD CONSTRAINT alergias_paciente_id_alergia_fkey FOREIGN KEY (id_alergia) REFERENCES public.cat_alergias(id_alergia);


--
-- Name: alergias_paciente alergias_paciente_id_paciente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alergias_paciente
    ADD CONSTRAINT alergias_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES public.pacientes(id_paciente);


--
-- Name: alertas_saturacion alertas_saturacion_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alertas_saturacion
    ADD CONSTRAINT alertas_saturacion_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: alertas_saturacion alertas_saturacion_id_umbral_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.alertas_saturacion
    ADD CONSTRAINT alertas_saturacion_id_umbral_fkey FOREIGN KEY (id_umbral) REFERENCES public.umbrales_alerta(id_umbral);


--
-- Name: antecedentes antecedentes_id_expediente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.antecedentes
    ADD CONSTRAINT antecedentes_id_expediente_fkey FOREIGN KEY (id_expediente) REFERENCES public.expedientes(id_expediente);


--
-- Name: area_servicio area_servicio_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.area_servicio
    ADD CONSTRAINT area_servicio_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: area_servicio area_servicio_id_servicio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.area_servicio
    ADD CONSTRAINT area_servicio_id_servicio_fkey FOREIGN KEY (id_servicio) REFERENCES public.servicios(id_servicio);


--
-- Name: areas areas_id_piso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_id_piso_fkey FOREIGN KEY (id_piso) REFERENCES public.pisos(id_piso);


--
-- Name: areas areas_id_tipo_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.areas
    ADD CONSTRAINT areas_id_tipo_area_fkey FOREIGN KEY (id_tipo_area) REFERENCES public.tipos_area(id_tipo_area);


--
-- Name: asignaciones_area asignaciones_area_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.asignaciones_area
    ADD CONSTRAINT asignaciones_area_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: asignaciones_area asignaciones_area_id_enfermero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.asignaciones_area
    ADD CONSTRAINT asignaciones_area_id_enfermero_fkey FOREIGN KEY (id_enfermero) REFERENCES public.personal_enfermeria(id_enfermero);


--
-- Name: asignaciones_area asignaciones_area_id_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.asignaciones_area
    ADD CONSTRAINT asignaciones_area_id_turno_fkey FOREIGN KEY (id_turno) REFERENCES public.turnos(id_turno);


--
-- Name: beacons beacons_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.beacons
    ADD CONSTRAINT beacons_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: beacons beacons_id_modelo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.beacons
    ADD CONSTRAINT beacons_id_modelo_fkey FOREIGN KEY (id_modelo) REFERENCES public.modelos_beacon(id_modelo);


--
-- Name: citas citas_id_estado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT citas_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.estados_cita(id_estado);


--
-- Name: citas citas_id_expediente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT citas_id_expediente_fkey FOREIGN KEY (id_expediente) REFERENCES public.expedientes(id_expediente);


--
-- Name: citas citas_id_horario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.citas
    ADD CONSTRAINT citas_id_horario_fkey FOREIGN KEY (id_horario) REFERENCES public.horarios_medico(id_horario);


--
-- Name: consultorios consultorios_cedula_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.consultorios
    ADD CONSTRAINT consultorios_cedula_medico_fkey FOREIGN KEY (cedula_medico) REFERENCES public.medicos(cedula_medico);


--
-- Name: consultorios consultorios_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.consultorios
    ADD CONSTRAINT consultorios_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: contactos_emergencia contactos_emergencia_id_paciente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.contactos_emergencia
    ADD CONSTRAINT contactos_emergencia_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES public.pacientes(id_paciente);


--
-- Name: diagnosticos diagnosticos_cedula_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.diagnosticos
    ADD CONSTRAINT diagnosticos_cedula_medico_fkey FOREIGN KEY (cedula_medico) REFERENCES public.medicos(cedula_medico);


--
-- Name: diagnosticos diagnosticos_id_diagnostico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.diagnosticos
    ADD CONSTRAINT diagnosticos_id_diagnostico_fkey FOREIGN KEY (id_diagnostico) REFERENCES public.cat_diagnosticos(id_diagnostico);


--
-- Name: diagnosticos diagnosticos_id_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.diagnosticos
    ADD CONSTRAINT diagnosticos_id_ingreso_fkey FOREIGN KEY (id_ingreso) REFERENCES public.ingresos(id_ingreso);


--
-- Name: edificios edificios_id_hospital_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.edificios
    ADD CONSTRAINT edificios_id_hospital_fkey FOREIGN KEY (id_hospital) REFERENCES public.hospitales(id_hospital);


--
-- Name: estancias estancias_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.estancias
    ADD CONSTRAINT estancias_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: estancias estancias_id_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.estancias
    ADD CONSTRAINT estancias_id_ingreso_fkey FOREIGN KEY (id_ingreso) REFERENCES public.ingresos(id_ingreso);


--
-- Name: eventos eventos_id_beacon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_id_beacon_fkey FOREIGN KEY (id_beacon) REFERENCES public.beacons(id_beacon);


--
-- Name: eventos eventos_id_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_id_ingreso_fkey FOREIGN KEY (id_ingreso) REFERENCES public.ingresos(id_ingreso);


--
-- Name: eventos eventos_id_tipo_evento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_id_tipo_evento_fkey FOREIGN KEY (id_tipo_evento) REFERENCES public.tipos_evento(id_tipo_evento);


--
-- Name: expedientes expedientes_id_hospital_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.expedientes
    ADD CONSTRAINT expedientes_id_hospital_fkey FOREIGN KEY (id_hospital) REFERENCES public.hospitales(id_hospital);


--
-- Name: expedientes expedientes_id_paciente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.expedientes
    ADD CONSTRAINT expedientes_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES public.pacientes(id_paciente);


--
-- Name: expedientes fk_exp_medico; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.expedientes
    ADD CONSTRAINT fk_exp_medico FOREIGN KEY (medico_titular) REFERENCES public.medicos(cedula_medico);


--
-- Name: historial_estados_ingreso historial_estados_ingreso_id_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.historial_estados_ingreso
    ADD CONSTRAINT historial_estados_ingreso_id_ingreso_fkey FOREIGN KEY (id_ingreso) REFERENCES public.ingresos(id_ingreso);


--
-- Name: historial_estados_ingreso historial_estados_ingreso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.historial_estados_ingreso
    ADD CONSTRAINT historial_estados_ingreso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: horarios_medico horarios_medico_id_consultorio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.horarios_medico
    ADD CONSTRAINT horarios_medico_id_consultorio_fkey FOREIGN KEY (id_consultorio) REFERENCES public.consultorios(id_consultorio);


--
-- Name: horarios_medico horarios_medico_id_dia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.horarios_medico
    ADD CONSTRAINT horarios_medico_id_dia_fkey FOREIGN KEY (id_dia) REFERENCES public.dias_semana(id_dia);


--
-- Name: horarios_medico horarios_medico_id_turno_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.horarios_medico
    ADD CONSTRAINT horarios_medico_id_turno_fkey FOREIGN KEY (id_turno) REFERENCES public.turnos(id_turno);


--
-- Name: ingresos ingresos_cedula_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_cedula_medico_fkey FOREIGN KEY (cedula_medico) REFERENCES public.medicos(cedula_medico);


--
-- Name: ingresos ingresos_id_cita_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_id_cita_fkey FOREIGN KEY (id_cita) REFERENCES public.citas(id_cita);


--
-- Name: ingresos ingresos_id_expediente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.ingresos
    ADD CONSTRAINT ingresos_id_expediente_fkey FOREIGN KEY (id_expediente) REFERENCES public.expedientes(id_expediente);


--
-- Name: log_acceso log_acceso_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.log_acceso
    ADD CONSTRAINT log_acceso_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: mantenimientos_beacon mantenimientos_beacon_id_beacon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.mantenimientos_beacon
    ADD CONSTRAINT mantenimientos_beacon_id_beacon_fkey FOREIGN KEY (id_beacon) REFERENCES public.beacons(id_beacon);


--
-- Name: medicos medicos_id_especialidad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.medicos
    ADD CONSTRAINT medicos_id_especialidad_fkey FOREIGN KEY (id_especialidad) REFERENCES public.especialidades(id_especialidad);


--
-- Name: metricas_consultorio metricas_consultorio_id_consultorio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_consultorio
    ADD CONSTRAINT metricas_consultorio_id_consultorio_fkey FOREIGN KEY (id_consultorio) REFERENCES public.consultorios(id_consultorio);


--
-- Name: metricas_diarias metricas_diarias_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_diarias
    ADD CONSTRAINT metricas_diarias_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: metricas_medico metricas_medico_cedula_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.metricas_medico
    ADD CONSTRAINT metricas_medico_cedula_medico_fkey FOREIGN KEY (cedula_medico) REFERENCES public.medicos(cedula_medico);


--
-- Name: pisos pisos_id_edificio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.pisos
    ADD CONSTRAINT pisos_id_edificio_fkey FOREIGN KEY (id_edificio) REFERENCES public.edificios(id_edificio);


--
-- Name: rol_permiso rol_permiso_id_permiso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_id_permiso_fkey FOREIGN KEY (id_permiso) REFERENCES public.permisos(id_permiso);


--
-- Name: rol_permiso rol_permiso_id_rol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.roles(id_rol);


--
-- Name: seguros_paciente seguros_paciente_id_aseguradora_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.seguros_paciente
    ADD CONSTRAINT seguros_paciente_id_aseguradora_fkey FOREIGN KEY (id_aseguradora) REFERENCES public.aseguradoras(id_aseguradora);


--
-- Name: seguros_paciente seguros_paciente_id_paciente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.seguros_paciente
    ADD CONSTRAINT seguros_paciente_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES public.pacientes(id_paciente);


--
-- Name: sesiones sesiones_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.sesiones
    ADD CONSTRAINT sesiones_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuarios(id_usuario);


--
-- Name: tarjetas_nfc tarjetas_nfc_id_paciente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.tarjetas_nfc
    ADD CONSTRAINT tarjetas_nfc_id_paciente_fkey FOREIGN KEY (id_paciente) REFERENCES public.pacientes(id_paciente);


--
-- Name: triajes triajes_id_enfermero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.triajes
    ADD CONSTRAINT triajes_id_enfermero_fkey FOREIGN KEY (id_enfermero) REFERENCES public.personal_enfermeria(id_enfermero);


--
-- Name: triajes triajes_id_ingreso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.triajes
    ADD CONSTRAINT triajes_id_ingreso_fkey FOREIGN KEY (id_ingreso) REFERENCES public.ingresos(id_ingreso) ON DELETE CASCADE;


--
-- Name: umbrales_alerta umbrales_alerta_id_area_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.umbrales_alerta
    ADD CONSTRAINT umbrales_alerta_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.areas(id_area);


--
-- Name: umbrales_alerta umbrales_alerta_id_hospital_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.umbrales_alerta
    ADD CONSTRAINT umbrales_alerta_id_hospital_fkey FOREIGN KEY (id_hospital) REFERENCES public.hospitales(id_hospital);


--
-- Name: usuarios usuarios_cedula_medico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_cedula_medico_fkey FOREIGN KEY (cedula_medico) REFERENCES public.medicos(cedula_medico);


--
-- Name: usuarios usuarios_id_enfermero_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_enfermero_fkey FOREIGN KEY (id_enfermero) REFERENCES public.personal_enfermeria(id_enfermero);


--
-- Name: usuarios usuarios_id_hospital_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_hospital_fkey FOREIGN KEY (id_hospital) REFERENCES public.hospitales(id_hospital);


--
-- Name: usuarios usuarios_id_rol_fkey; Type: FK CONSTRAINT; Schema: public; Owner: hospital_admin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_id_rol_fkey FOREIGN KEY (id_rol) REFERENCES public.roles(id_rol);


--
-- PostgreSQL database dump complete
--

\unrestrict ySzwEXCOrOEvSst9rhVd0X0pCe5QyRclkY4PRV8AO6V4xk73ca932gtw7D3Bvri

