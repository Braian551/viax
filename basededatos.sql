--
-- PostgreSQL database dump
--

\restrict Dq3oD9jINVut0lUKABlMd9ADHtI5cuvjIbq7nWdarCIibKXRE12hetzNNYge0ca

-- Dumped from database version 17.7
-- Dumped by pg_dump version 17.7

-- Started on 2026-01-20 20:50:48

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
-- TOC entry 349 (class 1255 OID 91304)
-- Name: actualizar_metricas_empresa(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_metricas_empresa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Cuando un conductor se vincula/desvincula de una empresa
    IF TG_TABLE_NAME = 'usuarios' THEN
        -- Actualizar empresa anterior (si había)
        IF OLD.empresa_id IS NOT NULL AND OLD.empresa_id != NEW.empresa_id THEN
            UPDATE empresas_metricas 
            SET total_conductores = (
                SELECT COUNT(*) FROM usuarios 
                WHERE empresa_id = OLD.empresa_id AND tipo_usuario = 'conductor'
            ),
            conductores_activos = (
                SELECT COUNT(*) FROM usuarios 
                WHERE empresa_id = OLD.empresa_id AND tipo_usuario = 'conductor' AND es_activo = 1
            ),
            ultima_actualizacion = CURRENT_TIMESTAMP
            WHERE empresa_id = OLD.empresa_id;
        END IF;
        
        -- Actualizar empresa nueva
        IF NEW.empresa_id IS NOT NULL THEN
            -- Insertar registro de métricas si no existe
            INSERT INTO empresas_metricas (empresa_id) 
            VALUES (NEW.empresa_id)
            ON CONFLICT (empresa_id) DO NOTHING;
            
            UPDATE empresas_metricas 
            SET total_conductores = (
                SELECT COUNT(*) FROM usuarios 
                WHERE empresa_id = NEW.empresa_id AND tipo_usuario = 'conductor'
            ),
            conductores_activos = (
                SELECT COUNT(*) FROM usuarios 
                WHERE empresa_id = NEW.empresa_id AND tipo_usuario = 'conductor' AND es_activo = 1
            ),
            ultima_actualizacion = CURRENT_TIMESTAMP
            WHERE empresa_id = NEW.empresa_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.actualizar_metricas_empresa() OWNER TO postgres;

--
-- TOC entry 351 (class 1255 OID 123830)
-- Name: actualizar_resumen_tracking(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.actualizar_resumen_tracking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_puntos INTEGER;
    v_velocidad_max DECIMAL(6,2);
    v_inicio TIMESTAMP;
BEGIN
    -- Obtener estadísticas del viaje
    SELECT 
        COUNT(*),
        MAX(velocidad),
        MIN(timestamp_gps)
    INTO v_total_puntos, v_velocidad_max, v_inicio
    FROM viaje_tracking_realtime
    WHERE solicitud_id = NEW.solicitud_id;
    
    -- Insertar o actualizar resumen
    INSERT INTO viaje_resumen_tracking (
        solicitud_id,
        distancia_real_km,
        tiempo_real_minutos,
        total_puntos_gps,
        velocidad_maxima_kmh,
        velocidad_promedio_kmh,
        inicio_viaje_real,
        actualizado_en
    ) VALUES (
        NEW.solicitud_id,
        NEW.distancia_acumulada_km,
        CEIL(NEW.tiempo_transcurrido_seg / 60.0),
        v_total_puntos,
        v_velocidad_max,
        CASE WHEN NEW.tiempo_transcurrido_seg > 0 
             THEN (NEW.distancia_acumulada_km * 3600 / NEW.tiempo_transcurrido_seg) 
             ELSE 0 END,
        v_inicio,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (solicitud_id) DO UPDATE SET
        distancia_real_km = EXCLUDED.distancia_real_km,
        tiempo_real_minutos = EXCLUDED.tiempo_real_minutos,
        total_puntos_gps = EXCLUDED.total_puntos_gps,
        velocidad_maxima_kmh = GREATEST(viaje_resumen_tracking.velocidad_maxima_kmh, EXCLUDED.velocidad_maxima_kmh),
        velocidad_promedio_kmh = EXCLUDED.velocidad_promedio_kmh,
        actualizado_en = CURRENT_TIMESTAMP;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.actualizar_resumen_tracking() OWNER TO postgres;

--
-- TOC entry 348 (class 1255 OID 91195)
-- Name: aprobar_vinculacion_conductor(bigint, bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.aprobar_vinculacion_conductor(p_solicitud_id bigint, p_aprobado_por bigint) RETURNS json
    LANGUAGE plpgsql
    AS $$
    DECLARE
        v_conductor_id BIGINT;
        v_empresa_id BIGINT;
        v_resultado JSON;
    BEGIN
        -- Obtener datos de la solicitud
        SELECT conductor_id, empresa_id INTO v_conductor_id, v_empresa_id
        FROM solicitudes_vinculacion_conductor
        WHERE id = p_solicitud_id AND estado = 'pendiente';
        
        IF v_conductor_id IS NULL THEN
            RETURN json_build_object('success', false, 'message', 'Solicitud no encontrada o ya procesada');
        END IF;
        
        -- Actualizar solicitud
        UPDATE solicitudes_vinculacion_conductor
        SET estado = 'aprobada', procesado_por = p_aprobado_por, procesado_en = CURRENT_TIMESTAMP
        WHERE id = p_solicitud_id;
        
        -- Vincular conductor a empresa y reactivar
        UPDATE usuarios
        SET empresa_id = v_empresa_id, 
            estado_vinculacion = 'vinculado',
            es_activo = 1, 
            fecha_actualizacion = CURRENT_TIMESTAMP -- Fixed column name
        WHERE id = v_conductor_id;
        
        -- Actualizar contador de conductores en empresa
        UPDATE empresas_transporte
        SET total_conductores = total_conductores + 1, actualizado_en = CURRENT_TIMESTAMP
        WHERE id = v_empresa_id;
        
        -- Rechazar otras solicitudes pendientes del mismo conductor
        UPDATE solicitudes_vinculacion_conductor
        SET estado = 'rechazada', 
            respuesta_empresa = 'Conductor vinculado a otra empresa',
            procesado_en = CURRENT_TIMESTAMP
        WHERE conductor_id = v_conductor_id AND estado = 'pendiente' AND id != p_solicitud_id;
        
        RETURN json_build_object(
            'success', true, 
            'message', 'Conductor vinculado exitosamente',
            'conductor_id', v_conductor_id,
            'empresa_id', v_empresa_id
        );
    END;
    $$;


ALTER FUNCTION public.aprobar_vinculacion_conductor(p_solicitud_id bigint, p_aprobado_por bigint) OWNER TO postgres;

--
-- TOC entry 350 (class 1255 OID 123829)
-- Name: calcular_precio_por_tracking(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calcular_precio_por_tracking(p_solicitud_id bigint) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_resumen RECORD;
    v_config RECORD;
    v_tipo_vehiculo VARCHAR(50);
    v_precio_base DECIMAL(12,2);
    v_precio_distancia DECIMAL(12,2);
    v_precio_tiempo DECIMAL(12,2);
    v_recargos DECIMAL(12,2) := 0;
    v_precio_total DECIMAL(12,2);
    v_tarifa_minima DECIMAL(12,2);
    v_resultado JSONB;
BEGIN
    -- Obtener resumen del tracking
    SELECT * INTO v_resumen
    FROM viaje_resumen_tracking
    WHERE solicitud_id = p_solicitud_id;
    
    IF v_resumen IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No hay datos de tracking para este viaje'
        );
    END IF;
    
    -- Obtener tipo de vehículo del viaje
    SELECT tipo_servicio INTO v_tipo_vehiculo
    FROM solicitudes_servicio
    WHERE id = p_solicitud_id;
    
    -- Obtener configuración de precios
    SELECT * INTO v_config
    FROM configuracion_precios
    WHERE tipo_vehiculo = v_tipo_vehiculo AND activo = 1
    LIMIT 1;
    
    IF v_config IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No hay configuración de precios para este tipo de vehículo'
        );
    END IF;
    
    -- Calcular componentes del precio
    v_precio_base := COALESCE(v_config.tarifa_base, 0);
    v_precio_distancia := v_resumen.distancia_real_km * COALESCE(v_config.costo_por_km, 0);
    v_precio_tiempo := (v_resumen.tiempo_real_minutos) * COALESCE(v_config.costo_por_minuto, 0);
    
    -- Calcular total
    v_precio_total := v_precio_base + v_precio_distancia + v_precio_tiempo + v_recargos;
    
    -- Aplicar tarifa mínima
    v_tarifa_minima := COALESCE(v_config.tarifa_minima, 0);
    IF v_precio_total < v_tarifa_minima THEN
        v_precio_total := v_tarifa_minima;
    END IF;
    
    -- Aplicar tarifa máxima si existe
    IF v_config.tarifa_maxima IS NOT NULL AND v_precio_total > v_config.tarifa_maxima THEN
        v_precio_total := v_config.tarifa_maxima;
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'precio_calculado', v_precio_total,
        'desglose', jsonb_build_object(
            'tarifa_base', v_precio_base,
            'precio_distancia', v_precio_distancia,
            'precio_tiempo', v_precio_tiempo,
            'recargos', v_recargos,
            'distancia_km', v_resumen.distancia_real_km,
            'tiempo_min', v_resumen.tiempo_real_minutos
        ),
        'diferencia_estimado', v_precio_total - v_resumen.precio_estimado
    );
END;
$$;


ALTER FUNCTION public.calcular_precio_por_tracking(p_solicitud_id bigint) OWNER TO postgres;

--
-- TOC entry 6164 (class 0 OID 0)
-- Dependencies: 350
-- Name: FUNCTION calcular_precio_por_tracking(p_solicitud_id bigint); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.calcular_precio_por_tracking(p_solicitud_id bigint) IS 'Calcula el precio final de un viaje basado en los datos REALES del tracking GPS';


--
-- TOC entry 344 (class 1255 OID 91051)
-- Name: contar_notificaciones_no_leidas(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.contar_notificaciones_no_leidas(p_usuario_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER 
        FROM notificaciones_usuario 
        WHERE usuario_id = p_usuario_id 
          AND leida = FALSE 
          AND eliminada = FALSE
    );
END;
$$;


ALTER FUNCTION public.contar_notificaciones_no_leidas(p_usuario_id integer) OWNER TO postgres;

--
-- TOC entry 6165 (class 0 OID 0)
-- Dependencies: 344
-- Name: FUNCTION contar_notificaciones_no_leidas(p_usuario_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.contar_notificaciones_no_leidas(p_usuario_id integer) IS 'Cuenta notificaciones no leídas de un usuario';


--
-- TOC entry 343 (class 1255 OID 91050)
-- Name: crear_notificacion(integer, character varying, character varying, text, character varying, integer, jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.crear_notificacion(p_usuario_id integer, p_tipo_codigo character varying, p_titulo character varying, p_mensaje text, p_referencia_tipo character varying DEFAULT NULL::character varying, p_referencia_id integer DEFAULT NULL::integer, p_data jsonb DEFAULT '{}'::jsonb) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tipo_id INTEGER;
    v_notif_id INTEGER;
BEGIN
    -- Obtener el ID del tipo
    SELECT id INTO v_tipo_id 
    FROM tipos_notificacion 
    WHERE codigo = p_tipo_codigo AND activo = TRUE;
    
    IF v_tipo_id IS NULL THEN
        -- Usar tipo 'system' como fallback
        SELECT id INTO v_tipo_id 
        FROM tipos_notificacion 
        WHERE codigo = 'system';
    END IF;
    
    -- Insertar la notificación
    INSERT INTO notificaciones_usuario (
        usuario_id, tipo_id, titulo, mensaje, 
        referencia_tipo, referencia_id, data
    ) VALUES (
        p_usuario_id, v_tipo_id, p_titulo, p_mensaje,
        p_referencia_tipo, p_referencia_id, p_data
    ) RETURNING id INTO v_notif_id;
    
    RETURN v_notif_id;
END;
$$;


ALTER FUNCTION public.crear_notificacion(p_usuario_id integer, p_tipo_codigo character varying, p_titulo character varying, p_mensaje text, p_referencia_tipo character varying, p_referencia_id integer, p_data jsonb) OWNER TO postgres;

--
-- TOC entry 6166 (class 0 OID 0)
-- Dependencies: 343
-- Name: FUNCTION crear_notificacion(p_usuario_id integer, p_tipo_codigo character varying, p_titulo character varying, p_mensaje text, p_referencia_tipo character varying, p_referencia_id integer, p_data jsonb); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.crear_notificacion(p_usuario_id integer, p_tipo_codigo character varying, p_titulo character varying, p_mensaje text, p_referencia_tipo character varying, p_referencia_id integer, p_data jsonb) IS 'Función helper para crear notificaciones de forma sencilla';


--
-- TOC entry 330 (class 1255 OID 115710)
-- Name: generar_numero_ticket(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generar_numero_ticket() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.numero_ticket := 'TKT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(NEW.id::TEXT, 5, '0');
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.generar_numero_ticket() OWNER TO postgres;

--
-- TOC entry 329 (class 1255 OID 91306)
-- Name: get_empresa_stats(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_empresa_stats(p_empresa_id bigint) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_stats JSON;
BEGIN
    SELECT json_build_object(
        'total_conductores', COALESCE(em.total_conductores, 0),
        'conductores_activos', COALESCE(em.conductores_activos, 0),
        'conductores_pendientes', (
            SELECT COUNT(*) FROM solicitudes_vinculacion_conductor 
            WHERE empresa_id = p_empresa_id AND estado = 'pendiente'
        ),
        'total_viajes', COALESCE(em.total_viajes_completados, 0),
        'calificacion', COALESCE(em.calificacion_promedio, 0),
        'ingresos_mes', COALESCE(em.ingresos_mes, 0)
    ) INTO v_stats
    FROM empresas_metricas em
    WHERE em.empresa_id = p_empresa_id;
    
    IF v_stats IS NULL THEN
        v_stats := json_build_object(
            'total_conductores', 0,
            'conductores_activos', 0,
            'conductores_pendientes', 0,
            'total_viajes', 0,
            'calificacion', 0,
            'ingresos_mes', 0
        );
    END IF;
    
    RETURN v_stats;
END;
$$;


ALTER FUNCTION public.get_empresa_stats(p_empresa_id bigint) OWNER TO postgres;

--
-- TOC entry 327 (class 1255 OID 115658)
-- Name: log_empresa_tipo_vehiculo_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_empresa_tipo_vehiculo_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.activo IS DISTINCT FROM NEW.activo THEN
        INSERT INTO empresa_tipos_vehiculo_historial (
            empresa_tipo_vehiculo_id,
            empresa_id,
            tipo_vehiculo_codigo,
            accion,
            estado_anterior,
            estado_nuevo,
            realizado_por,
            motivo
        ) VALUES (
            NEW.id,
            NEW.empresa_id,
            NEW.tipo_vehiculo_codigo,
            CASE WHEN NEW.activo THEN 'activado' ELSE 'desactivado' END,
            OLD.activo,
            NEW.activo,
            COALESCE(NEW.desactivado_por, NEW.activado_por),
            NEW.motivo_desactivacion
        );
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_empresa_tipo_vehiculo_change() OWNER TO postgres;

--
-- TOC entry 346 (class 1255 OID 91196)
-- Name: rechazar_vinculacion_conductor(bigint, bigint, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rechazar_vinculacion_conductor(p_solicitud_id bigint, p_rechazado_por bigint, p_razon text DEFAULT 'Solicitud rechazada por la empresa'::text) RETURNS json
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE solicitudes_vinculacion_conductor
    SET estado = 'rechazada', 
        procesado_por = p_rechazado_por, 
        procesado_en = CURRENT_TIMESTAMP,
        respuesta_empresa = p_razon
    WHERE id = p_solicitud_id AND estado = 'pendiente';
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Solicitud no encontrada o ya procesada');
    END IF;
    
    RETURN json_build_object('success', true, 'message', 'Solicitud rechazada');
END;
$$;


ALTER FUNCTION public.rechazar_vinculacion_conductor(p_solicitud_id bigint, p_rechazado_por bigint, p_razon text) OWNER TO postgres;

--
-- TOC entry 323 (class 1255 OID 17237)
-- Name: set_actualizado_en(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_actualizado_en() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_actualizado_en() OWNER TO postgres;

--
-- TOC entry 345 (class 1255 OID 91052)
-- Name: update_config_notif_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_config_notif_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_config_notif_timestamp() OWNER TO postgres;

--
-- TOC entry 328 (class 1255 OID 115660)
-- Name: update_empresa_tipo_vehiculo_conductores(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_empresa_tipo_vehiculo_conductores() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE empresa_tipos_vehiculo etv
    SET conductores_activos = (
        SELECT COUNT(*)
        FROM usuarios u
        INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id
        WHERE u.empresa_id = etv.empresa_id
        AND dc.tipo_vehiculo = etv.tipo_vehiculo_codigo
        AND dc.estado_verificacion = 'aprobado'
        AND u.es_activo = true
    )
    WHERE etv.empresa_id = COALESCE(NEW.empresa_id, OLD.empresa_id);
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_empresa_tipo_vehiculo_conductores() OWNER TO postgres;

--
-- TOC entry 326 (class 1255 OID 115656)
-- Name: update_empresa_tipos_vehiculo_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_empresa_tipos_vehiculo_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.actualizado_en = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_empresa_tipos_vehiculo_timestamp() OWNER TO postgres;

--
-- TOC entry 325 (class 1255 OID 25479)
-- Name: update_empresas_transporte_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_empresas_transporte_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.actualizado_en = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_empresas_transporte_timestamp() OWNER TO postgres;

--
-- TOC entry 324 (class 1255 OID 17279)
-- Name: update_mensajes_chat_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_mensajes_chat_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_mensajes_chat_timestamp() OWNER TO postgres;

--
-- TOC entry 331 (class 1255 OID 115751)
-- Name: update_support_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_support_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_support_timestamp() OWNER TO postgres;

--
-- TOC entry 347 (class 1255 OID 91197)
-- Name: validar_conductor_nueva_empresa(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validar_conductor_nueva_empresa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si se está registrando como conductor sin empresa
    IF NEW.tipo_usuario = 'conductor' AND NEW.empresa_id IS NULL THEN
        -- Permitir pero forzar estado pendiente_empresa
        NEW.estado_vinculacion := 'pendiente_empresa';
        NEW.es_activo := 0;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validar_conductor_nueva_empresa() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 217 (class 1259 OID 16508)
-- Name: asignaciones_conductor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asignaciones_conductor (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    asignado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    llegado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    estado character varying(30) DEFAULT 'asignado'::character varying,
    CONSTRAINT asignaciones_conductor_conductor_id_check CHECK ((conductor_id > 0)),
    CONSTRAINT asignaciones_conductor_estado_check CHECK (((estado)::text = ANY ((ARRAY['asignado'::character varying, 'llegado'::character varying, 'en_curso'::character varying, 'completado'::character varying, 'cancelado'::character varying])::text[]))),
    CONSTRAINT asignaciones_conductor_id_check CHECK ((id > 0)),
    CONSTRAINT asignaciones_conductor_solicitud_id_check CHECK ((solicitud_id > 0))
);


ALTER TABLE public.asignaciones_conductor OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 17143)
-- Name: asignaciones_conductor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.asignaciones_conductor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asignaciones_conductor_id_seq OWNER TO postgres;

--
-- TOC entry 6167 (class 0 OID 0)
-- Dependencies: 245
-- Name: asignaciones_conductor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.asignaciones_conductor_id_seq OWNED BY public.asignaciones_conductor.id;


--
-- TOC entry 218 (class 1259 OID 16518)
-- Name: cache_direcciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cache_direcciones (
    id bigint NOT NULL,
    latitud_origen numeric(10,8) NOT NULL,
    longitud_origen numeric(11,8) NOT NULL,
    latitud_destino numeric(10,8) NOT NULL,
    longitud_destino numeric(11,8) NOT NULL,
    distancia numeric(8,2) NOT NULL,
    duracion integer NOT NULL,
    polilinea text NOT NULL,
    datos_respuesta json NOT NULL,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    expira_en timestamp(0) without time zone NOT NULL,
    CONSTRAINT cache_direcciones_id_check CHECK ((id > 0))
);


ALTER TABLE public.cache_direcciones OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 17161)
-- Name: cache_direcciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cache_direcciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cache_direcciones_id_seq OWNER TO postgres;

--
-- TOC entry 6168 (class 0 OID 0)
-- Dependencies: 254
-- Name: cache_direcciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cache_direcciones_id_seq OWNED BY public.cache_direcciones.id;


--
-- TOC entry 219 (class 1259 OID 16525)
-- Name: cache_geocodificacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cache_geocodificacion (
    id bigint NOT NULL,
    latitud numeric(10,8) NOT NULL,
    longitud numeric(11,8) NOT NULL,
    direccion_formateada character varying(500) NOT NULL,
    id_lugar character varying(255) DEFAULT NULL::character varying,
    datos_respuesta json NOT NULL,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    expira_en timestamp(0) without time zone NOT NULL,
    CONSTRAINT cache_geocodificacion_id_check CHECK ((id > 0))
);


ALTER TABLE public.cache_geocodificacion OWNER TO postgres;

--
-- TOC entry 255 (class 1259 OID 17163)
-- Name: cache_geocodificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cache_geocodificacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cache_geocodificacion_id_seq OWNER TO postgres;

--
-- TOC entry 6169 (class 0 OID 0)
-- Dependencies: 255
-- Name: cache_geocodificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cache_geocodificacion_id_seq OWNED BY public.cache_geocodificacion.id;


--
-- TOC entry 220 (class 1259 OID 16533)
-- Name: calificaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.calificaciones (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    usuario_calificador_id bigint NOT NULL,
    usuario_calificado_id bigint NOT NULL,
    calificacion smallint NOT NULL,
    comentarios text,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT calificaciones_id_check CHECK ((id > 0)),
    CONSTRAINT calificaciones_solicitud_id_check CHECK ((solicitud_id > 0)),
    CONSTRAINT calificaciones_usuario_calificado_id_check CHECK ((usuario_calificado_id > 0)),
    CONSTRAINT calificaciones_usuario_calificador_id_check CHECK ((usuario_calificador_id > 0))
);


ALTER TABLE public.calificaciones OWNER TO postgres;

--
-- TOC entry 6170 (class 0 OID 0)
-- Dependencies: 220
-- Name: TABLE calificaciones; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.calificaciones IS 'Calificaciones de viajes entre conductores y clientes';


--
-- TOC entry 246 (class 1259 OID 17145)
-- Name: calificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.calificaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calificaciones_id_seq OWNER TO postgres;

--
-- TOC entry 6171 (class 0 OID 0)
-- Dependencies: 246
-- Name: calificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.calificaciones_id_seq OWNED BY public.calificaciones.id;


--
-- TOC entry 300 (class 1259 OID 115555)
-- Name: catalogo_tipos_vehiculo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.catalogo_tipos_vehiculo (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    icono character varying(100),
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.catalogo_tipos_vehiculo OWNER TO postgres;

--
-- TOC entry 6172 (class 0 OID 0)
-- Dependencies: 300
-- Name: TABLE catalogo_tipos_vehiculo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.catalogo_tipos_vehiculo IS 'Catálogo maestro de tipos de vehículo disponibles';


--
-- TOC entry 299 (class 1259 OID 115554)
-- Name: catalogo_tipos_vehiculo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.catalogo_tipos_vehiculo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.catalogo_tipos_vehiculo_id_seq OWNER TO postgres;

--
-- TOC entry 6173 (class 0 OID 0)
-- Dependencies: 299
-- Name: catalogo_tipos_vehiculo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.catalogo_tipos_vehiculo_id_seq OWNED BY public.catalogo_tipos_vehiculo.id;


--
-- TOC entry 310 (class 1259 OID 115673)
-- Name: categorias_soporte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categorias_soporte (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    icono character varying(50) DEFAULT 'support'::character varying,
    color character varying(20) DEFAULT '#2196F3'::character varying,
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.categorias_soporte OWNER TO postgres;

--
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 310
-- Name: TABLE categorias_soporte; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.categorias_soporte IS 'Catálogo de categorías de soporte';


--
-- TOC entry 309 (class 1259 OID 115672)
-- Name: categorias_soporte_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categorias_soporte_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categorias_soporte_id_seq OWNER TO postgres;

--
-- TOC entry 6175 (class 0 OID 0)
-- Dependencies: 309
-- Name: categorias_soporte_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categorias_soporte_id_seq OWNED BY public.categorias_soporte.id;


--
-- TOC entry 273 (class 1259 OID 33658)
-- Name: colores_vehiculo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.colores_vehiculo (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    hex_code character varying(7) NOT NULL,
    activo boolean DEFAULT true
);


ALTER TABLE public.colores_vehiculo OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 33657)
-- Name: colores_vehiculo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.colores_vehiculo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.colores_vehiculo_id_seq OWNER TO postgres;

--
-- TOC entry 6176 (class 0 OID 0)
-- Dependencies: 272
-- Name: colores_vehiculo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.colores_vehiculo_id_seq OWNED BY public.colores_vehiculo.id;


--
-- TOC entry 257 (class 1259 OID 17166)
-- Name: conductores_favoritos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.conductores_favoritos (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    es_favorito boolean DEFAULT true,
    fecha_marcado timestamp with time zone DEFAULT now(),
    fecha_desmarcado timestamp with time zone
);


ALTER TABLE public.conductores_favoritos OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16588)
-- Name: detalles_conductor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalles_conductor (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    licencia_conduccion character varying(50) NOT NULL,
    licencia_vencimiento date NOT NULL,
    licencia_expedicion date,
    licencia_categoria character varying(10) DEFAULT 'C1'::character varying,
    licencia_foto_url character varying(500) DEFAULT NULL::character varying,
    vehiculo_tipo character varying(30) NOT NULL,
    vehiculo_marca character varying(50) DEFAULT NULL::character varying,
    vehiculo_modelo character varying(50) DEFAULT NULL::character varying,
    vehiculo_anio integer,
    vehiculo_color character varying(30) DEFAULT NULL::character varying,
    vehiculo_placa character varying(20) NOT NULL,
    aseguradora character varying(100) DEFAULT NULL::character varying,
    numero_poliza_seguro character varying(100) DEFAULT NULL::character varying,
    vencimiento_seguro date,
    seguro_foto_url character varying(500) DEFAULT NULL::character varying,
    soat_numero character varying(50) DEFAULT NULL::character varying,
    soat_vencimiento date,
    soat_foto_url character varying(500) DEFAULT NULL::character varying,
    tecnomecanica_numero character varying(50) DEFAULT NULL::character varying,
    tecnomecanica_vencimiento date,
    tecnomecanica_foto_url character varying(500) DEFAULT NULL::character varying,
    tarjeta_propiedad_numero character varying(50) DEFAULT NULL::character varying,
    tarjeta_propiedad_foto_url character varying(500) DEFAULT NULL::character varying,
    aprobado smallint DEFAULT 0,
    estado_aprobacion character varying(30) DEFAULT 'pendiente'::character varying,
    calificacion_promedio numeric(3,2) DEFAULT 0.00,
    total_calificaciones integer DEFAULT 0,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    disponible smallint DEFAULT 0,
    latitud_actual numeric(10,8) DEFAULT NULL::numeric,
    longitud_actual numeric(11,8) DEFAULT NULL::numeric,
    ultima_actualizacion timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    total_viajes integer DEFAULT 0,
    estado_verificacion character varying(30) DEFAULT 'pendiente'::character varying,
    fecha_ultima_verificacion timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    ganancias_totales numeric(12,2) DEFAULT 0,
    estado_biometrico character varying(20) DEFAULT 'pendiente'::character varying,
    foto_vehiculo character varying(255),
    licencia_tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    soat_tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    tecnomecanica_tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    tarjeta_propiedad_tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    seguro_tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    plantilla_biometrica text,
    fecha_verificacion_biometrica timestamp without time zone,
    razon_rechazo text
);


ALTER TABLE public.detalles_conductor OWNER TO postgres;

--
-- TOC entry 6177 (class 0 OID 0)
-- Dependencies: 223
-- Name: COLUMN detalles_conductor.foto_vehiculo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.detalles_conductor.foto_vehiculo IS 'URL relative path to the vehicle photo';


--
-- TOC entry 259 (class 1259 OID 17187)
-- Name: historial_confianza; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historial_confianza (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    total_viajes integer DEFAULT 0,
    viajes_completados integer DEFAULT 0,
    viajes_cancelados integer DEFAULT 0,
    suma_calificaciones_conductor numeric(10,2) DEFAULT 0,
    suma_calificaciones_usuario numeric(10,2) DEFAULT 0,
    total_calificaciones integer DEFAULT 0,
    ultimo_viaje_fecha timestamp with time zone,
    score_confianza numeric(5,2) DEFAULT 0.00,
    zona_frecuente_lat numeric(10,8),
    zona_frecuente_lng numeric(11,8),
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


ALTER TABLE public.historial_confianza OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 16835)
-- Name: usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    telefono character varying(20),
    hash_contrasena character varying(255) NOT NULL,
    tipo_usuario character varying(30) DEFAULT 'cliente'::character varying,
    foto_perfil character varying(500) DEFAULT NULL::character varying,
    fecha_nacimiento date,
    es_verificado smallint DEFAULT 0,
    es_activo smallint DEFAULT 1,
    fecha_registro timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    ultimo_acceso_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    tiene_disputa_activa boolean DEFAULT false,
    disputa_activa_id bigint,
    empresa_id bigint,
    empresa_preferida_id bigint,
    calificacion_promedio numeric(3,2) DEFAULT 5.0,
    estado_vinculacion character varying(50) DEFAULT 'activo'::character varying,
    google_id character varying(255),
    apple_id character varying(255),
    auth_provider character varying(20) DEFAULT 'email'::character varying,
    CONSTRAINT chk_conductor_empresa_required CHECK ((((tipo_usuario)::text <> 'conductor'::text) OR (empresa_id IS NOT NULL) OR ((estado_vinculacion)::text = 'pendiente_empresa'::text))),
    CONSTRAINT usuarios_id_check CHECK ((id > 0)),
    CONSTRAINT usuarios_tipo_usuario_check CHECK (((tipo_usuario)::text = ANY ((ARRAY['cliente'::character varying, 'conductor'::character varying, 'administrador'::character varying, 'empresa'::character varying])::text[])))
);


ALTER TABLE public.usuarios OWNER TO postgres;

--
-- TOC entry 6178 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN usuarios.google_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.usuarios.google_id IS 'ID único del usuario en Google para OAuth';


--
-- TOC entry 6179 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN usuarios.apple_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.usuarios.apple_id IS 'ID único del usuario en Apple para Sign-In with Apple';


--
-- TOC entry 6180 (class 0 OID 0)
-- Dependencies: 240
-- Name: COLUMN usuarios.auth_provider; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.usuarios.auth_provider IS 'Método de autenticación original: email, google, apple';


--
-- TOC entry 6181 (class 0 OID 0)
-- Dependencies: 240
-- Name: CONSTRAINT chk_conductor_empresa_required ON usuarios; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON CONSTRAINT chk_conductor_empresa_required ON public.usuarios IS 'Conductores deben tener empresa_id o estar en estado_vinculacion pendiente_empresa';


--
-- TOC entry 260 (class 1259 OID 17214)
-- Name: conductores_confianza_ranking; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.conductores_confianza_ranking AS
 SELECT hc.usuario_id,
    hc.conductor_id,
    u.nombre AS conductor_nombre,
    u.apellido AS conductor_apellido,
    dc.calificacion_promedio,
    dc.total_viajes AS total_viajes_conductor,
    hc.total_viajes AS viajes_con_usuario,
    hc.viajes_completados,
    hc.score_confianza,
    cf.es_favorito,
        CASE
            WHEN cf.es_favorito THEN 100
            ELSE 0
        END AS bonus_favorito,
    (hc.score_confianza + (
        CASE
            WHEN cf.es_favorito THEN 100
            ELSE 0
        END)::numeric) AS score_total
   FROM (((public.historial_confianza hc
     JOIN public.usuarios u ON ((hc.conductor_id = u.id)))
     JOIN public.detalles_conductor dc ON ((u.id = dc.usuario_id)))
     LEFT JOIN public.conductores_favoritos cf ON (((hc.usuario_id = cf.usuario_id) AND (hc.conductor_id = cf.conductor_id) AND (cf.es_favorito = true))))
  WHERE ((dc.estado_verificacion)::text = 'aprobado'::text)
  ORDER BY (hc.score_confianza + (
        CASE
            WHEN cf.es_favorito THEN 100
            ELSE 0
        END)::numeric) DESC;


ALTER VIEW public.conductores_confianza_ranking OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 17165)
-- Name: conductores_favoritos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.conductores_favoritos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.conductores_favoritos_id_seq OWNER TO postgres;

--
-- TOC entry 6182 (class 0 OID 0)
-- Dependencies: 256
-- Name: conductores_favoritos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.conductores_favoritos_id_seq OWNED BY public.conductores_favoritos.id;


--
-- TOC entry 269 (class 1259 OID 25436)
-- Name: empresas_transporte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas_transporte (
    id bigint NOT NULL,
    nombre character varying(255) NOT NULL,
    nit character varying(50),
    razon_social character varying(255),
    email character varying(255),
    telefono character varying(50),
    telefono_secundario character varying(50),
    direccion text,
    municipio character varying(100),
    departamento character varying(100),
    representante_nombre character varying(255),
    representante_telefono character varying(50),
    representante_email character varying(255),
    tipos_vehiculo text[],
    logo_url character varying(500),
    descripcion text,
    estado character varying(50) DEFAULT 'activo'::character varying,
    verificada boolean DEFAULT false,
    fecha_verificacion timestamp without time zone,
    verificado_por bigint,
    total_conductores integer DEFAULT 0,
    total_viajes_completados integer DEFAULT 0,
    calificacion_promedio numeric(3,2) DEFAULT 0.00,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    creado_por bigint,
    notas_admin text,
    comision_admin_porcentaje numeric(5,2) DEFAULT 0,
    saldo_pendiente numeric(15,2) DEFAULT 0
);


ALTER TABLE public.empresas_transporte OWNER TO postgres;

--
-- TOC entry 6183 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE empresas_transporte; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresas_transporte IS 'Tabla para almacenar empresas de transporte registradas';


--
-- TOC entry 6184 (class 0 OID 0)
-- Dependencies: 269
-- Name: COLUMN empresas_transporte.tipos_vehiculo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresas_transporte.tipos_vehiculo IS 'Array de tipos de vehículos que maneja la empresa';


--
-- TOC entry 6185 (class 0 OID 0)
-- Dependencies: 269
-- Name: COLUMN empresas_transporte.estado; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresas_transporte.estado IS 'Estado de la empresa: activo, inactivo, suspendido, pendiente';


--
-- TOC entry 6186 (class 0 OID 0)
-- Dependencies: 269
-- Name: COLUMN empresas_transporte.comision_admin_porcentaje; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresas_transporte.comision_admin_porcentaje IS 'Porcentaje de la comision de la empresa que va para admin (0-100)';


--
-- TOC entry 6187 (class 0 OID 0)
-- Dependencies: 269
-- Name: COLUMN empresas_transporte.saldo_pendiente; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresas_transporte.saldo_pendiente IS 'Saldo que la empresa debe pagar a la plataforma (COP)';


--
-- TOC entry 289 (class 1259 OID 91158)
-- Name: solicitudes_vinculacion_conductor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitudes_vinculacion_conductor (
    id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    estado character varying(50) DEFAULT 'pendiente'::character varying,
    mensaje_conductor text,
    respuesta_empresa text,
    procesado_por bigint,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    procesado_en timestamp without time zone
);


ALTER TABLE public.solicitudes_vinculacion_conductor OWNER TO postgres;

--
-- TOC entry 6188 (class 0 OID 0)
-- Dependencies: 289
-- Name: TABLE solicitudes_vinculacion_conductor; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.solicitudes_vinculacion_conductor IS 'Solicitudes de conductores para vincularse a empresas de transporte';


--
-- TOC entry 290 (class 1259 OID 91200)
-- Name: conductores_pendientes_vinculacion; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.conductores_pendientes_vinculacion AS
 SELECT u.id,
    u.nombre,
    u.apellido,
    u.email,
    u.telefono,
    u.fecha_registro AS creado_en,
    u.estado_vinculacion,
    dc.vehiculo_tipo,
    dc.vehiculo_marca,
    dc.vehiculo_modelo,
    dc.vehiculo_placa,
    sv.empresa_id AS empresa_solicitada_id,
    et.nombre AS empresa_solicitada_nombre,
    sv.estado AS estado_solicitud,
    sv.creado_en AS fecha_solicitud
   FROM (((public.usuarios u
     LEFT JOIN public.detalles_conductor dc ON ((u.id = dc.usuario_id)))
     LEFT JOIN public.solicitudes_vinculacion_conductor sv ON (((u.id = sv.conductor_id) AND ((sv.estado)::text = 'pendiente'::text))))
     LEFT JOIN public.empresas_transporte et ON ((sv.empresa_id = et.id)))
  WHERE (((u.tipo_usuario)::text = 'conductor'::text) AND (u.empresa_id IS NULL));


ALTER VIEW public.conductores_pendientes_vinculacion OWNER TO postgres;

--
-- TOC entry 6189 (class 0 OID 0)
-- Dependencies: 290
-- Name: VIEW conductores_pendientes_vinculacion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.conductores_pendientes_vinculacion IS 'Vista de conductores que necesitan vincularse a una empresa';


--
-- TOC entry 284 (class 1259 OID 91011)
-- Name: configuracion_notificaciones_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.configuracion_notificaciones_usuario (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    push_enabled boolean DEFAULT true,
    email_enabled boolean DEFAULT true,
    sms_enabled boolean DEFAULT false,
    notif_viajes boolean DEFAULT true,
    notif_pagos boolean DEFAULT true,
    notif_promociones boolean DEFAULT true,
    notif_sistema boolean DEFAULT true,
    notif_chat boolean DEFAULT true,
    horario_silencioso_inicio time without time zone,
    horario_silencioso_fin time without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.configuracion_notificaciones_usuario OWNER TO postgres;

--
-- TOC entry 6190 (class 0 OID 0)
-- Dependencies: 284
-- Name: TABLE configuracion_notificaciones_usuario; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.configuracion_notificaciones_usuario IS 'Preferencias de notificación por usuario';


--
-- TOC entry 283 (class 1259 OID 91010)
-- Name: configuracion_notificaciones_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configuracion_notificaciones_usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuracion_notificaciones_usuario_id_seq OWNER TO postgres;

--
-- TOC entry 6191 (class 0 OID 0)
-- Dependencies: 283
-- Name: configuracion_notificaciones_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configuracion_notificaciones_usuario_id_seq OWNED BY public.configuracion_notificaciones_usuario.id;


--
-- TOC entry 222 (class 1259 OID 16555)
-- Name: configuracion_precios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.configuracion_precios (
    id bigint NOT NULL,
    tipo_vehiculo character varying(30) DEFAULT 'moto'::character varying NOT NULL,
    tarifa_base numeric(10,2) DEFAULT 5000.00 NOT NULL,
    costo_por_km numeric(10,2) DEFAULT 2500.00 NOT NULL,
    costo_por_minuto numeric(10,2) DEFAULT 300.00 NOT NULL,
    tarifa_minima numeric(10,2) DEFAULT 8000.00 NOT NULL,
    tarifa_maxima numeric(10,2) DEFAULT NULL::numeric,
    recargo_hora_pico numeric(5,2) DEFAULT 20.00 NOT NULL,
    recargo_nocturno numeric(5,2) DEFAULT 25.00 NOT NULL,
    recargo_festivo numeric(5,2) DEFAULT 30.00 NOT NULL,
    descuento_distancia_larga numeric(5,2) DEFAULT 10.00 NOT NULL,
    umbral_km_descuento numeric(10,2) DEFAULT 15.00 NOT NULL,
    hora_pico_inicio_manana time(0) without time zone DEFAULT '07:00:00'::time without time zone,
    hora_pico_fin_manana time(0) without time zone DEFAULT '09:00:00'::time without time zone,
    hora_pico_inicio_tarde time(0) without time zone DEFAULT '17:00:00'::time without time zone,
    hora_pico_fin_tarde time(0) without time zone DEFAULT '19:00:00'::time without time zone,
    hora_nocturna_inicio time(0) without time zone DEFAULT '22:00:00'::time without time zone,
    hora_nocturna_fin time(0) without time zone DEFAULT '06:00:00'::time without time zone,
    comision_plataforma numeric(5,2) DEFAULT 15.00 NOT NULL,
    comision_metodo_pago numeric(5,2) DEFAULT 2.50 NOT NULL,
    distancia_minima numeric(10,2) DEFAULT 1.00 NOT NULL,
    distancia_maxima numeric(10,2) DEFAULT 50.00 NOT NULL,
    tiempo_espera_gratis integer DEFAULT 3 NOT NULL,
    costo_tiempo_espera numeric(10,2) DEFAULT 500.00 NOT NULL,
    activo smallint DEFAULT 1 NOT NULL,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    notas text,
    empresa_id bigint
);


ALTER TABLE public.configuracion_precios OWNER TO postgres;

--
-- TOC entry 247 (class 1259 OID 17147)
-- Name: configuracion_precios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configuracion_precios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuracion_precios_id_seq OWNER TO postgres;

--
-- TOC entry 6192 (class 0 OID 0)
-- Dependencies: 247
-- Name: configuracion_precios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configuracion_precios_id_seq OWNED BY public.configuracion_precios.id;


--
-- TOC entry 221 (class 1259 OID 16543)
-- Name: configuraciones_app; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.configuraciones_app (
    id bigint NOT NULL,
    clave character varying(100) NOT NULL,
    valor text,
    tipo character varying(30) DEFAULT 'string'::character varying,
    categoria character varying(50) DEFAULT NULL::character varying,
    descripcion text,
    es_publica smallint DEFAULT 0,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT configuraciones_app_id_check CHECK ((id > 0)),
    CONSTRAINT configuraciones_app_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['string'::character varying, 'number'::character varying, 'boolean'::character varying, 'json'::character varying])::text[])))
);


ALTER TABLE public.configuraciones_app OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 17149)
-- Name: configuraciones_app_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.configuraciones_app_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuraciones_app_id_seq OWNER TO postgres;

--
-- TOC entry 6193 (class 0 OID 0)
-- Dependencies: 248
-- Name: configuraciones_app_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.configuraciones_app_id_seq OWNED BY public.configuraciones_app.id;


--
-- TOC entry 249 (class 1259 OID 17151)
-- Name: detalles_conductor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detalles_conductor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detalles_conductor_id_seq OWNER TO postgres;

--
-- TOC entry 6194 (class 0 OID 0)
-- Dependencies: 249
-- Name: detalles_conductor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalles_conductor_id_seq OWNED BY public.detalles_conductor.id;


--
-- TOC entry 224 (class 1259 OID 16627)
-- Name: detalles_paquete; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalles_paquete (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    tipo_paquete character varying(30) NOT NULL,
    descripcion_paquete character varying(500) DEFAULT NULL::character varying,
    valor_estimado numeric(10,2) DEFAULT NULL::numeric,
    peso numeric(5,2) NOT NULL,
    largo numeric(5,2) DEFAULT NULL::numeric,
    ancho numeric(5,2) DEFAULT NULL::numeric,
    alto numeric(5,2) DEFAULT NULL::numeric,
    requiere_firma smallint DEFAULT 0,
    seguro_solicitado smallint DEFAULT 0,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT detalles_paquete_id_check CHECK ((id > 0)),
    CONSTRAINT detalles_paquete_solicitud_id_check CHECK ((solicitud_id > 0)),
    CONSTRAINT detalles_paquete_tipo_paquete_check CHECK (((tipo_paquete)::text = ANY ((ARRAY['documento'::character varying, 'pequeno'::character varying, 'mediano'::character varying, 'grande'::character varying, 'fragil'::character varying, 'perecedero'::character varying])::text[])))
);


ALTER TABLE public.detalles_paquete OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16643)
-- Name: detalles_viaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalles_viaje (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    numero_pasajeros integer DEFAULT 1,
    opciones_viaje json,
    tarifa_estimada numeric(8,2) DEFAULT NULL::numeric,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT detalles_viaje_id_check CHECK ((id > 0)),
    CONSTRAINT detalles_viaje_solicitud_id_check CHECK ((solicitud_id > 0))
);


ALTER TABLE public.detalles_viaje OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 17282)
-- Name: disputas_pago; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.disputas_pago (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    cliente_confirma_pago boolean DEFAULT false,
    conductor_confirma_recibo boolean DEFAULT false,
    estado character varying(50) DEFAULT 'pendiente'::character varying,
    resuelto_por bigint,
    resolucion_notas text,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    resuelto_en timestamp without time zone
);


ALTER TABLE public.disputas_pago OWNER TO postgres;

--
-- TOC entry 6195 (class 0 OID 0)
-- Dependencies: 264
-- Name: TABLE disputas_pago; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.disputas_pago IS 'Registro de disputas de pago entre cliente y conductor';


--
-- TOC entry 6196 (class 0 OID 0)
-- Dependencies: 264
-- Name: COLUMN disputas_pago.estado; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.disputas_pago.estado IS 'pendiente=esperando confirmaciones, activa=hay desacuerdo, resuelta_*=ya resuelto';


--
-- TOC entry 263 (class 1259 OID 17281)
-- Name: disputas_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.disputas_pago_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.disputas_pago_id_seq OWNER TO postgres;

--
-- TOC entry 6197 (class 0 OID 0)
-- Dependencies: 263
-- Name: disputas_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.disputas_pago_id_seq OWNED BY public.disputas_pago.id;


--
-- TOC entry 226 (class 1259 OID 16653)
-- Name: documentos_conductor_historial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documentos_conductor_historial (
    id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    tipo_documento character varying(30) NOT NULL,
    url_documento character varying(500) NOT NULL,
    fecha_carga timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    activo smallint DEFAULT 1,
    reemplazado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    asignado_empresa_id bigint,
    verificado_por_admin boolean DEFAULT false,
    tipo_archivo character varying(10) DEFAULT 'imagen'::character varying,
    nombre_archivo_original character varying(255),
    tamanio_archivo integer,
    CONSTRAINT documentos_conductor_historial_conductor_id_check CHECK ((conductor_id > 0)),
    CONSTRAINT documentos_conductor_historial_id_check CHECK ((id > 0)),
    CONSTRAINT documentos_conductor_historial_tipo_documento_check CHECK (((tipo_documento)::text = ANY ((ARRAY['licencia'::character varying, 'soat'::character varying, 'tecnomecanica'::character varying, 'tarjeta_propiedad'::character varying, 'seguro'::character varying])::text[])))
);


ALTER TABLE public.documentos_conductor_historial OWNER TO postgres;

--
-- TOC entry 6198 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN documentos_conductor_historial.asignado_empresa_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.documentos_conductor_historial.asignado_empresa_id IS 'ID de la empresa que debe verificar este documento';


--
-- TOC entry 6199 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN documentos_conductor_historial.verificado_por_admin; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.documentos_conductor_historial.verificado_por_admin IS 'True si debe ser verificado por el admin de la plataforma';


--
-- TOC entry 271 (class 1259 OID 33640)
-- Name: documentos_verificacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documentos_verificacion (
    id integer NOT NULL,
    conductor_id integer NOT NULL,
    tipo_documento character varying(50) NOT NULL,
    ruta_archivo character varying(255) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    comentario_rechazo text,
    fecha_subida timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_verificacion timestamp without time zone
);


ALTER TABLE public.documentos_verificacion OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 33639)
-- Name: documentos_verificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.documentos_verificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.documentos_verificacion_id_seq OWNER TO postgres;

--
-- TOC entry 6200 (class 0 OID 0)
-- Dependencies: 270
-- Name: documentos_verificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.documentos_verificacion_id_seq OWNED BY public.documentos_verificacion.id;


--
-- TOC entry 302 (class 1259 OID 115569)
-- Name: empresa_tipos_vehiculo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresa_tipos_vehiculo (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    tipo_vehiculo_codigo character varying(50) NOT NULL,
    activo boolean DEFAULT true,
    fecha_activacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_desactivacion timestamp without time zone,
    activado_por bigint,
    desactivado_por bigint,
    motivo_desactivacion text,
    conductores_activos integer DEFAULT 0,
    viajes_completados integer DEFAULT 0,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresa_tipos_vehiculo OWNER TO postgres;

--
-- TOC entry 6201 (class 0 OID 0)
-- Dependencies: 302
-- Name: TABLE empresa_tipos_vehiculo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresa_tipos_vehiculo IS 'Tipos de vehículo habilitados por empresa con estado activo/inactivo';


--
-- TOC entry 6202 (class 0 OID 0)
-- Dependencies: 302
-- Name: COLUMN empresa_tipos_vehiculo.activo; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresa_tipos_vehiculo.activo IS 'TRUE si el tipo de vehículo está habilitado para la empresa';


--
-- TOC entry 6203 (class 0 OID 0)
-- Dependencies: 302
-- Name: COLUMN empresa_tipos_vehiculo.motivo_desactivacion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.empresa_tipos_vehiculo.motivo_desactivacion IS 'Razón opcional por la cual se desactivó el tipo';


--
-- TOC entry 304 (class 1259 OID 115610)
-- Name: empresa_tipos_vehiculo_historial; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresa_tipos_vehiculo_historial (
    id bigint NOT NULL,
    empresa_tipo_vehiculo_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    tipo_vehiculo_codigo character varying(50) NOT NULL,
    accion character varying(20) NOT NULL,
    estado_anterior boolean,
    estado_nuevo boolean,
    realizado_por bigint,
    motivo text,
    fecha_cambio timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ip_address character varying(45),
    user_agent text,
    conductores_afectados integer DEFAULT 0
);


ALTER TABLE public.empresa_tipos_vehiculo_historial OWNER TO postgres;

--
-- TOC entry 6204 (class 0 OID 0)
-- Dependencies: 304
-- Name: TABLE empresa_tipos_vehiculo_historial; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresa_tipos_vehiculo_historial IS 'Historial de cambios de estado de tipos de vehículo';


--
-- TOC entry 303 (class 1259 OID 115609)
-- Name: empresa_tipos_vehiculo_historial_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresa_tipos_vehiculo_historial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresa_tipos_vehiculo_historial_id_seq OWNER TO postgres;

--
-- TOC entry 6205 (class 0 OID 0)
-- Dependencies: 303
-- Name: empresa_tipos_vehiculo_historial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresa_tipos_vehiculo_historial_id_seq OWNED BY public.empresa_tipos_vehiculo_historial.id;


--
-- TOC entry 301 (class 1259 OID 115568)
-- Name: empresa_tipos_vehiculo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresa_tipos_vehiculo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresa_tipos_vehiculo_id_seq OWNER TO postgres;

--
-- TOC entry 6206 (class 0 OID 0)
-- Dependencies: 301
-- Name: empresa_tipos_vehiculo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresa_tipos_vehiculo_id_seq OWNED BY public.empresa_tipos_vehiculo.id;


--
-- TOC entry 306 (class 1259 OID 115633)
-- Name: empresa_vehiculo_notificaciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresa_vehiculo_notificaciones (
    id bigint NOT NULL,
    historial_id bigint,
    conductor_id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    tipo_vehiculo_codigo character varying(50) NOT NULL,
    tipo_notificacion character varying(50) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    asunto character varying(255),
    mensaje text,
    enviado_en timestamp without time zone,
    error_mensaje text,
    intentos integer DEFAULT 0,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresa_vehiculo_notificaciones OWNER TO postgres;

--
-- TOC entry 6207 (class 0 OID 0)
-- Dependencies: 306
-- Name: TABLE empresa_vehiculo_notificaciones; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresa_vehiculo_notificaciones IS 'Registro de notificaciones enviadas a conductores';


--
-- TOC entry 305 (class 1259 OID 115632)
-- Name: empresa_vehiculo_notificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresa_vehiculo_notificaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresa_vehiculo_notificaciones_id_seq OWNER TO postgres;

--
-- TOC entry 6208 (class 0 OID 0)
-- Dependencies: 305
-- Name: empresa_vehiculo_notificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresa_vehiculo_notificaciones_id_seq OWNED BY public.empresa_vehiculo_notificaciones.id;


--
-- TOC entry 298 (class 1259 OID 91274)
-- Name: empresas_configuracion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas_configuracion (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    tipos_vehiculo text[],
    zona_operacion text[],
    horario_operacion jsonb,
    acepta_efectivo boolean DEFAULT true,
    acepta_tarjeta boolean DEFAULT false,
    acepta_transferencia boolean DEFAULT false,
    radio_maximo_km integer DEFAULT 50,
    tiempo_espera_max_min integer DEFAULT 15,
    notificaciones_email boolean DEFAULT true,
    notificaciones_push boolean DEFAULT true,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresas_configuracion OWNER TO postgres;

--
-- TOC entry 6209 (class 0 OID 0)
-- Dependencies: 298
-- Name: TABLE empresas_configuracion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresas_configuracion IS 'Configuración operativa de la empresa';


--
-- TOC entry 297 (class 1259 OID 91273)
-- Name: empresas_configuracion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_configuracion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_configuracion_id_seq OWNER TO postgres;

--
-- TOC entry 6210 (class 0 OID 0)
-- Dependencies: 297
-- Name: empresas_configuracion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_configuracion_id_seq OWNED BY public.empresas_configuracion.id;


--
-- TOC entry 292 (class 1259 OID 91208)
-- Name: empresas_contacto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas_contacto (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    email character varying(255),
    telefono character varying(50),
    telefono_secundario character varying(50),
    direccion text,
    municipio character varying(100),
    departamento character varying(100),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresas_contacto OWNER TO postgres;

--
-- TOC entry 6211 (class 0 OID 0)
-- Dependencies: 292
-- Name: TABLE empresas_contacto; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresas_contacto IS 'Información de contacto de empresas de transporte';


--
-- TOC entry 291 (class 1259 OID 91207)
-- Name: empresas_contacto_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_contacto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_contacto_id_seq OWNER TO postgres;

--
-- TOC entry 6212 (class 0 OID 0)
-- Dependencies: 291
-- Name: empresas_contacto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_contacto_id_seq OWNED BY public.empresas_contacto.id;


--
-- TOC entry 296 (class 1259 OID 91248)
-- Name: empresas_metricas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas_metricas (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    total_conductores integer DEFAULT 0,
    conductores_activos integer DEFAULT 0,
    conductores_pendientes integer DEFAULT 0,
    total_viajes_completados integer DEFAULT 0,
    total_viajes_cancelados integer DEFAULT 0,
    calificacion_promedio numeric(3,2) DEFAULT 0.00,
    total_calificaciones integer DEFAULT 0,
    ingresos_totales numeric(15,2) DEFAULT 0.00,
    viajes_mes integer DEFAULT 0,
    ingresos_mes numeric(15,2) DEFAULT 0.00,
    ultima_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresas_metricas OWNER TO postgres;

--
-- TOC entry 6213 (class 0 OID 0)
-- Dependencies: 296
-- Name: TABLE empresas_metricas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresas_metricas IS 'Métricas y estadísticas calculadas de la empresa';


--
-- TOC entry 295 (class 1259 OID 91247)
-- Name: empresas_metricas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_metricas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_metricas_id_seq OWNER TO postgres;

--
-- TOC entry 6214 (class 0 OID 0)
-- Dependencies: 295
-- Name: empresas_metricas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_metricas_id_seq OWNED BY public.empresas_metricas.id;


--
-- TOC entry 294 (class 1259 OID 91228)
-- Name: empresas_representante; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empresas_representante (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    nombre character varying(255),
    telefono character varying(50),
    email character varying(255),
    documento_identidad character varying(50),
    cargo character varying(100) DEFAULT 'Representante Legal'::character varying,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.empresas_representante OWNER TO postgres;

--
-- TOC entry 6215 (class 0 OID 0)
-- Dependencies: 294
-- Name: TABLE empresas_representante; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.empresas_representante IS 'Información del representante legal de la empresa';


--
-- TOC entry 293 (class 1259 OID 91227)
-- Name: empresas_representante_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_representante_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_representante_id_seq OWNER TO postgres;

--
-- TOC entry 6216 (class 0 OID 0)
-- Dependencies: 293
-- Name: empresas_representante_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_representante_id_seq OWNED BY public.empresas_representante.id;


--
-- TOC entry 268 (class 1259 OID 25435)
-- Name: empresas_transporte_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empresas_transporte_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empresas_transporte_id_seq OWNER TO postgres;

--
-- TOC entry 6217 (class 0 OID 0)
-- Dependencies: 268
-- Name: empresas_transporte_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empresas_transporte_id_seq OWNED BY public.empresas_transporte.id;


--
-- TOC entry 227 (class 1259 OID 16664)
-- Name: estadisticas_sistema; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estadisticas_sistema (
    id bigint NOT NULL,
    fecha date NOT NULL,
    total_usuarios integer DEFAULT 0,
    total_clientes integer DEFAULT 0,
    total_conductores integer DEFAULT 0,
    total_administradores integer DEFAULT 0,
    usuarios_activos_dia integer DEFAULT 0,
    nuevos_registros_dia integer DEFAULT 0,
    total_solicitudes integer DEFAULT 0,
    solicitudes_completadas integer DEFAULT 0,
    solicitudes_canceladas integer DEFAULT 0,
    ingresos_totales numeric(10,2) DEFAULT 0.00,
    ingresos_dia numeric(10,2) DEFAULT 0.00,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT estadisticas_sistema_id_check CHECK ((id > 0)),
    CONSTRAINT estadisticas_sistema_nuevos_registros_dia_check CHECK ((nuevos_registros_dia >= 0)),
    CONSTRAINT estadisticas_sistema_solicitudes_canceladas_check CHECK ((solicitudes_canceladas >= 0)),
    CONSTRAINT estadisticas_sistema_solicitudes_completadas_check CHECK ((solicitudes_completadas >= 0)),
    CONSTRAINT estadisticas_sistema_total_administradores_check CHECK ((total_administradores >= 0)),
    CONSTRAINT estadisticas_sistema_total_clientes_check CHECK ((total_clientes >= 0)),
    CONSTRAINT estadisticas_sistema_total_conductores_check CHECK ((total_conductores >= 0)),
    CONSTRAINT estadisticas_sistema_total_solicitudes_check CHECK ((total_solicitudes >= 0)),
    CONSTRAINT estadisticas_sistema_total_usuarios_check CHECK ((total_usuarios >= 0)),
    CONSTRAINT estadisticas_sistema_usuarios_activos_dia_check CHECK ((usuarios_activos_dia >= 0))
);


ALTER TABLE public.estadisticas_sistema OWNER TO postgres;

--
-- TOC entry 258 (class 1259 OID 17186)
-- Name: historial_confianza_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historial_confianza_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.historial_confianza_id_seq OWNER TO postgres;

--
-- TOC entry 6218 (class 0 OID 0)
-- Dependencies: 258
-- Name: historial_confianza_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historial_confianza_id_seq OWNED BY public.historial_confianza.id;


--
-- TOC entry 228 (class 1259 OID 16690)
-- Name: historial_precios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historial_precios (
    id bigint NOT NULL,
    configuracion_id bigint NOT NULL,
    campo_modificado character varying(100) NOT NULL,
    valor_anterior text,
    valor_nuevo text,
    usuario_id bigint,
    fecha_cambio timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    motivo text,
    CONSTRAINT historial_precios_configuracion_id_check CHECK ((configuracion_id > 0)),
    CONSTRAINT historial_precios_id_check CHECK ((id > 0)),
    CONSTRAINT historial_precios_usuario_id_check CHECK ((usuario_id > 0))
);


ALTER TABLE public.historial_precios OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16699)
-- Name: historial_seguimiento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historial_seguimiento (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    latitud numeric(10,8) NOT NULL,
    longitud numeric(11,8) NOT NULL,
    precision_gps numeric(5,2) DEFAULT NULL::numeric,
    velocidad numeric(5,2) DEFAULT NULL::numeric,
    direccion smallint,
    timestamp_seguimiento timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT historial_seguimiento_conductor_id_check CHECK ((conductor_id > 0)),
    CONSTRAINT historial_seguimiento_id_check CHECK ((id > 0)),
    CONSTRAINT historial_seguimiento_solicitud_id_check CHECK ((solicitud_id > 0))
);


ALTER TABLE public.historial_seguimiento OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 16708)
-- Name: logs_auditoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.logs_auditoria (
    id bigint NOT NULL,
    usuario_id bigint,
    accion character varying(100) NOT NULL,
    entidad character varying(100) DEFAULT NULL::character varying,
    entidad_id bigint,
    descripcion text,
    ip_address character varying(45) DEFAULT NULL::character varying,
    user_agent character varying(255) DEFAULT NULL::character varying,
    datos_anteriores json,
    datos_nuevos json,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT logs_auditoria_entidad_id_check CHECK ((entidad_id > 0)),
    CONSTRAINT logs_auditoria_id_check CHECK ((id > 0)),
    CONSTRAINT logs_auditoria_usuario_id_check CHECK ((usuario_id > 0))
);


ALTER TABLE public.logs_auditoria OWNER TO postgres;

--
-- TOC entry 274 (class 1259 OID 50012)
-- Name: logs_auditoria_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.logs_auditoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.logs_auditoria_id_seq OWNER TO postgres;

--
-- TOC entry 6219 (class 0 OID 0)
-- Dependencies: 274
-- Name: logs_auditoria_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.logs_auditoria_id_seq OWNED BY public.logs_auditoria.id;


--
-- TOC entry 262 (class 1259 OID 17244)
-- Name: mensajes_chat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mensajes_chat (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    remitente_id integer NOT NULL,
    destinatario_id integer NOT NULL,
    tipo_remitente character varying(20) NOT NULL,
    mensaje text NOT NULL,
    tipo_mensaje character varying(20) DEFAULT 'texto'::character varying,
    leido boolean DEFAULT false,
    leido_en timestamp without time zone,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    activo boolean DEFAULT true,
    CONSTRAINT mensajes_chat_tipo_mensaje_check CHECK (((tipo_mensaje)::text = ANY ((ARRAY['texto'::character varying, 'imagen'::character varying, 'ubicacion'::character varying, 'audio'::character varying, 'sistema'::character varying])::text[]))),
    CONSTRAINT mensajes_chat_tipo_remitente_check CHECK (((tipo_remitente)::text = ANY ((ARRAY['cliente'::character varying, 'conductor'::character varying])::text[])))
);


ALTER TABLE public.mensajes_chat OWNER TO postgres;

--
-- TOC entry 6220 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE mensajes_chat; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.mensajes_chat IS 'Mensajes de chat entre conductores y clientes durante viajes';


--
-- TOC entry 6221 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN mensajes_chat.solicitud_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.mensajes_chat.solicitud_id IS 'ID de la solicitud/viaje asociada';


--
-- TOC entry 6222 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN mensajes_chat.tipo_remitente; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.mensajes_chat.tipo_remitente IS 'Tipo de usuario que envía: cliente o conductor';


--
-- TOC entry 6223 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN mensajes_chat.tipo_mensaje; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.mensajes_chat.tipo_mensaje IS 'Tipo de contenido: texto, imagen, ubicacion, audio, sistema';


--
-- TOC entry 6224 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN mensajes_chat.leido; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.mensajes_chat.leido IS 'Si el mensaje ha sido leído por el destinatario';


--
-- TOC entry 261 (class 1259 OID 17243)
-- Name: mensajes_chat_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mensajes_chat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mensajes_chat_id_seq OWNER TO postgres;

--
-- TOC entry 6225 (class 0 OID 0)
-- Dependencies: 261
-- Name: mensajes_chat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mensajes_chat_id_seq OWNED BY public.mensajes_chat.id;


--
-- TOC entry 314 (class 1259 OID 115717)
-- Name: mensajes_ticket; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mensajes_ticket (
    id integer NOT NULL,
    ticket_id integer NOT NULL,
    remitente_id integer NOT NULL,
    es_agente boolean DEFAULT false,
    mensaje text NOT NULL,
    adjuntos jsonb DEFAULT '[]'::jsonb,
    leido boolean DEFAULT false,
    leido_en timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.mensajes_ticket OWNER TO postgres;

--
-- TOC entry 6226 (class 0 OID 0)
-- Dependencies: 314
-- Name: TABLE mensajes_ticket; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.mensajes_ticket IS 'Mensajes dentro de un ticket de soporte';


--
-- TOC entry 313 (class 1259 OID 115716)
-- Name: mensajes_ticket_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mensajes_ticket_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mensajes_ticket_id_seq OWNER TO postgres;

--
-- TOC entry 6227 (class 0 OID 0)
-- Dependencies: 313
-- Name: mensajes_ticket_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mensajes_ticket_id_seq OWNED BY public.mensajes_ticket.id;


--
-- TOC entry 231 (class 1259 OID 16720)
-- Name: metodos_pago_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.metodos_pago_usuario (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    tipo_pago character varying(30) NOT NULL,
    ultimos_cuatro_digitos character varying(4) DEFAULT NULL::character varying,
    marca_tarjeta character varying(50) DEFAULT NULL::character varying,
    tipo_billetera character varying(50) DEFAULT NULL::character varying,
    es_principal smallint DEFAULT 0,
    activo smallint DEFAULT 1,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    CONSTRAINT metodos_pago_usuario_id_check CHECK ((id > 0)),
    CONSTRAINT metodos_pago_usuario_tipo_pago_check CHECK (((tipo_pago)::text = ANY ((ARRAY['tarjeta_credito'::character varying, 'tarjeta_debito'::character varying, 'billetera_digital'::character varying])::text[]))),
    CONSTRAINT metodos_pago_usuario_usuario_id_check CHECK ((usuario_id > 0))
);


ALTER TABLE public.metodos_pago_usuario OWNER TO postgres;

--
-- TOC entry 282 (class 1259 OID 90987)
-- Name: notificaciones_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notificaciones_usuario (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    tipo_id integer NOT NULL,
    titulo character varying(255) NOT NULL,
    mensaje text NOT NULL,
    referencia_tipo character varying(50),
    referencia_id integer,
    data jsonb DEFAULT '{}'::jsonb,
    leida boolean DEFAULT false,
    leida_en timestamp without time zone,
    push_enviada boolean DEFAULT false,
    push_enviada_en timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    eliminada boolean DEFAULT false,
    eliminada_en timestamp without time zone
);


ALTER TABLE public.notificaciones_usuario OWNER TO postgres;

--
-- TOC entry 6228 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE notificaciones_usuario; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.notificaciones_usuario IS 'Notificaciones enviadas a usuarios';


--
-- TOC entry 280 (class 1259 OID 90972)
-- Name: tipos_notificacion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipos_notificacion (
    id integer NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    icono character varying(50) DEFAULT 'notifications'::character varying,
    color character varying(20) DEFAULT '#2196F3'::character varying,
    activo boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tipos_notificacion OWNER TO postgres;

--
-- TOC entry 6229 (class 0 OID 0)
-- Dependencies: 280
-- Name: TABLE tipos_notificacion; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.tipos_notificacion IS 'Catálogo de tipos de notificación para normalización';


--
-- TOC entry 287 (class 1259 OID 91045)
-- Name: notificaciones_completas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.notificaciones_completas AS
 SELECT n.id,
    n.usuario_id,
    n.titulo,
    n.mensaje,
    n.leida,
    n.leida_en,
    n.referencia_tipo,
    n.referencia_id,
    n.data,
    n.created_at,
    t.codigo AS tipo_codigo,
    t.nombre AS tipo_nombre,
    t.icono AS tipo_icono,
    t.color AS tipo_color
   FROM (public.notificaciones_usuario n
     JOIN public.tipos_notificacion t ON ((n.tipo_id = t.id)))
  WHERE (n.eliminada = false);


ALTER VIEW public.notificaciones_completas OWNER TO postgres;

--
-- TOC entry 6230 (class 0 OID 0)
-- Dependencies: 287
-- Name: VIEW notificaciones_completas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.notificaciones_completas IS 'Vista optimizada de notificaciones con información de tipo';


--
-- TOC entry 281 (class 1259 OID 90986)
-- Name: notificaciones_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notificaciones_usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notificaciones_usuario_id_seq OWNER TO postgres;

--
-- TOC entry 6231 (class 0 OID 0)
-- Dependencies: 281
-- Name: notificaciones_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notificaciones_usuario_id_seq OWNED BY public.notificaciones_usuario.id;


--
-- TOC entry 276 (class 1259 OID 58206)
-- Name: pagos_empresas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos_empresas (
    id bigint NOT NULL,
    empresa_id bigint NOT NULL,
    monto numeric(15,2) NOT NULL,
    tipo character varying(50) NOT NULL,
    descripcion text,
    viaje_id bigint,
    saldo_anterior numeric(15,2),
    saldo_nuevo numeric(15,2),
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.pagos_empresas OWNER TO postgres;

--
-- TOC entry 6232 (class 0 OID 0)
-- Dependencies: 276
-- Name: TABLE pagos_empresas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.pagos_empresas IS 'Historial de cargos y pagos de empresas a la plataforma';


--
-- TOC entry 275 (class 1259 OID 58205)
-- Name: pagos_empresas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pagos_empresas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pagos_empresas_id_seq OWNER TO postgres;

--
-- TOC entry 6233 (class 0 OID 0)
-- Dependencies: 275
-- Name: pagos_empresas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pagos_empresas_id_seq OWNED BY public.pagos_empresas.id;


--
-- TOC entry 266 (class 1259 OID 17348)
-- Name: pagos_viaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pagos_viaje (
    id integer NOT NULL,
    solicitud_id integer NOT NULL,
    conductor_id integer NOT NULL,
    cliente_id integer,
    monto numeric(10,2) NOT NULL,
    metodo_pago character varying(50) DEFAULT 'efectivo'::character varying,
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    confirmado_en timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.pagos_viaje OWNER TO postgres;

--
-- TOC entry 6234 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE pagos_viaje; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.pagos_viaje IS 'Historial de pagos de viajes';


--
-- TOC entry 265 (class 1259 OID 17347)
-- Name: pagos_viaje_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pagos_viaje_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pagos_viaje_id_seq OWNER TO postgres;

--
-- TOC entry 6235 (class 0 OID 0)
-- Dependencies: 265
-- Name: pagos_viaje_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pagos_viaje_id_seq OWNED BY public.pagos_viaje.id;


--
-- TOC entry 232 (class 1259 OID 16733)
-- Name: paradas_solicitud; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paradas_solicitud (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    latitud numeric(10,8) NOT NULL,
    longitud numeric(11,8) NOT NULL,
    direccion character varying(500) NOT NULL,
    orden integer NOT NULL,
    estado character varying(30) DEFAULT 'pendiente'::character varying,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT paradas_solicitud_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'completada'::character varying, 'omitida'::character varying])::text[]))),
    CONSTRAINT paradas_solicitud_id_check CHECK ((id > 0)),
    CONSTRAINT paradas_solicitud_solicitud_id_check CHECK ((solicitud_id > 0))
);


ALTER TABLE public.paradas_solicitud OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 17159)
-- Name: paradas_solicitud_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.paradas_solicitud_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.paradas_solicitud_id_seq OWNER TO postgres;

--
-- TOC entry 6236 (class 0 OID 0)
-- Dependencies: 253
-- Name: paradas_solicitud_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.paradas_solicitud_id_seq OWNED BY public.paradas_solicitud.id;


--
-- TOC entry 278 (class 1259 OID 82780)
-- Name: plantillas_bloqueadas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plantillas_bloqueadas (
    id integer NOT NULL,
    plantilla_hash character varying(64) NOT NULL,
    plantilla text NOT NULL,
    usuario_origen_id integer,
    razon character varying(100) DEFAULT 'bloqueado'::character varying,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    activo boolean DEFAULT true
);


ALTER TABLE public.plantillas_bloqueadas OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 82779)
-- Name: plantillas_bloqueadas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.plantillas_bloqueadas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plantillas_bloqueadas_id_seq OWNER TO postgres;

--
-- TOC entry 6237 (class 0 OID 0)
-- Dependencies: 277
-- Name: plantillas_bloqueadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.plantillas_bloqueadas_id_seq OWNED BY public.plantillas_bloqueadas.id;


--
-- TOC entry 233 (class 1259 OID 16743)
-- Name: proveedores_mapa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proveedores_mapa (
    id bigint NOT NULL,
    nombre character varying(100) NOT NULL,
    api_key character varying(255) NOT NULL,
    activo smallint DEFAULT 1,
    contador_solicitudes integer DEFAULT 0,
    ultimo_uso timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT proveedores_mapa_id_check CHECK ((id > 0))
);


ALTER TABLE public.proveedores_mapa OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16751)
-- Name: reglas_precios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reglas_precios (
    id bigint NOT NULL,
    tipo_servicio character varying(30) NOT NULL,
    tipo_vehiculo character varying(30) NOT NULL,
    tarifa_base numeric(8,2) NOT NULL,
    costo_por_km numeric(8,2) NOT NULL,
    costo_por_minuto numeric(8,2) NOT NULL,
    tarifa_minima numeric(8,2) NOT NULL,
    tarifa_cancelacion numeric(8,2) DEFAULT 0.00,
    multiplicador_demanda numeric(3,2) DEFAULT 1.00,
    activo smallint DEFAULT 1,
    valido_desde timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    valido_hasta timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reglas_precios_id_check CHECK ((id > 0)),
    CONSTRAINT reglas_precios_tipo_servicio_check CHECK (((tipo_servicio)::text = ANY ((ARRAY['transporte'::character varying, 'envio_paquete'::character varying])::text[]))),
    CONSTRAINT reglas_precios_tipo_vehiculo_check CHECK (((tipo_vehiculo)::text = ANY ((ARRAY['motocicleta'::character varying, 'carro'::character varying, 'furgoneta'::character varying, 'camion'::character varying])::text[])))
);


ALTER TABLE public.reglas_precios OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16763)
-- Name: reportes_usuarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reportes_usuarios (
    id bigint NOT NULL,
    usuario_reportante_id bigint NOT NULL,
    usuario_reportado_id bigint NOT NULL,
    solicitud_id bigint,
    tipo_reporte character varying(30) NOT NULL,
    descripcion text NOT NULL,
    estado character varying(30) DEFAULT 'pendiente'::character varying,
    notas_admin text,
    admin_revisor_id bigint,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_resolucion timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    CONSTRAINT reportes_usuarios_admin_revisor_id_check CHECK ((admin_revisor_id > 0)),
    CONSTRAINT reportes_usuarios_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'en_revision'::character varying, 'resuelto'::character varying, 'rechazado'::character varying])::text[]))),
    CONSTRAINT reportes_usuarios_id_check CHECK ((id > 0)),
    CONSTRAINT reportes_usuarios_solicitud_id_check CHECK ((solicitud_id > 0)),
    CONSTRAINT reportes_usuarios_tipo_reporte_check CHECK (((tipo_reporte)::text = ANY ((ARRAY['conducta_inapropiada'::character varying, 'fraude'::character varying, 'seguridad'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT reportes_usuarios_usuario_reportado_id_check CHECK ((usuario_reportado_id > 0)),
    CONSTRAINT reportes_usuarios_usuario_reportante_id_check CHECK ((usuario_reportante_id > 0))
);


ALTER TABLE public.reportes_usuarios OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 115737)
-- Name: solicitudes_callback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitudes_callback (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    telefono character varying(20) NOT NULL,
    motivo character varying(255),
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    notas text,
    programado_para timestamp without time zone,
    realizado_en timestamp without time zone,
    agente_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT solicitudes_callback_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'programado'::character varying, 'realizado'::character varying, 'fallido'::character varying, 'cancelado'::character varying])::text[])))
);


ALTER TABLE public.solicitudes_callback OWNER TO postgres;

--
-- TOC entry 6238 (class 0 OID 0)
-- Dependencies: 316
-- Name: TABLE solicitudes_callback; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.solicitudes_callback IS 'Solicitudes de llamada de vuelta';


--
-- TOC entry 315 (class 1259 OID 115736)
-- Name: solicitudes_callback_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitudes_callback_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solicitudes_callback_id_seq OWNER TO postgres;

--
-- TOC entry 6239 (class 0 OID 0)
-- Dependencies: 315
-- Name: solicitudes_callback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitudes_callback_id_seq OWNED BY public.solicitudes_callback.id;


--
-- TOC entry 236 (class 1259 OID 16778)
-- Name: solicitudes_servicio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.solicitudes_servicio (
    id bigint NOT NULL,
    uuid_solicitud character varying(255) NOT NULL,
    cliente_id bigint NOT NULL,
    tipo_servicio character varying(30) NOT NULL,
    ubicacion_recogida_id bigint,
    ubicacion_destino_id bigint,
    latitud_recogida numeric(10,8) NOT NULL,
    longitud_recogida numeric(11,8) NOT NULL,
    direccion_recogida character varying(500) NOT NULL,
    latitud_destino numeric(10,8) NOT NULL,
    longitud_destino numeric(11,8) NOT NULL,
    direccion_destino character varying(500) NOT NULL,
    distancia_estimada numeric(8,2) NOT NULL,
    tiempo_estimado integer NOT NULL,
    estado character varying(30) DEFAULT 'pendiente'::character varying,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    solicitado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    aceptado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    recogido_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    entregado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    completado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    cancelado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    motivo_cancelacion character varying(500) DEFAULT NULL::character varying,
    cliente_confirma_pago boolean DEFAULT false,
    conductor_confirma_recibo boolean DEFAULT false,
    tiene_disputa boolean DEFAULT false,
    disputa_id bigint,
    precio_final numeric(10,2) DEFAULT 0,
    metodo_pago character varying(50) DEFAULT 'efectivo'::character varying,
    pago_confirmado boolean DEFAULT false,
    pago_confirmado_en timestamp without time zone,
    precio_estimado numeric(10,2) DEFAULT 0,
    conductor_llego_en timestamp without time zone,
    metodo_pago_usado character varying(50),
    distancia_recorrida numeric(10,2) DEFAULT 0,
    tiempo_transcurrido integer DEFAULT 0,
    precio_ajustado_por_tracking boolean DEFAULT false,
    tuvo_desvio_ruta boolean DEFAULT false,
    tipo_vehiculo character varying(30) DEFAULT 'moto'::character varying,
    empresa_id bigint,
    conductor_id bigint,
    precio_en_tracking numeric(10,2) DEFAULT NULL::numeric,
    CONSTRAINT check_tipo_vehiculo_solicitud CHECK (((tipo_vehiculo IS NULL) OR ((tipo_vehiculo)::text = ANY ((ARRAY['moto'::character varying, 'auto'::character varying, 'motocarro'::character varying, 'taxi'::character varying])::text[]))))
);


ALTER TABLE public.solicitudes_servicio OWNER TO postgres;

--
-- TOC entry 6240 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN solicitudes_servicio.precio_final; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes_servicio.precio_final IS 'Precio final del viaje (puede variar por ruta real)';


--
-- TOC entry 6241 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN solicitudes_servicio.precio_estimado; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes_servicio.precio_estimado IS 'Precio calculado antes de iniciar el viaje';


--
-- TOC entry 6242 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN solicitudes_servicio.precio_ajustado_por_tracking; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes_servicio.precio_ajustado_por_tracking IS 'Indica si el precio final fue recalculado basado en tracking GPS real';


--
-- TOC entry 6243 (class 0 OID 0)
-- Dependencies: 236
-- Name: COLUMN solicitudes_servicio.tuvo_desvio_ruta; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.solicitudes_servicio.tuvo_desvio_ruta IS 'Indica si el viaje tuvo un desvío significativo de la ruta original';


--
-- TOC entry 244 (class 1259 OID 17141)
-- Name: solicitudes_servicio_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitudes_servicio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solicitudes_servicio_id_seq OWNER TO postgres;

--
-- TOC entry 6244 (class 0 OID 0)
-- Dependencies: 244
-- Name: solicitudes_servicio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitudes_servicio_id_seq OWNED BY public.solicitudes_servicio.id;


--
-- TOC entry 288 (class 1259 OID 91157)
-- Name: solicitudes_vinculacion_conductor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.solicitudes_vinculacion_conductor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solicitudes_vinculacion_conductor_id_seq OWNER TO postgres;

--
-- TOC entry 6245 (class 0 OID 0)
-- Dependencies: 288
-- Name: solicitudes_vinculacion_conductor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.solicitudes_vinculacion_conductor_id_seq OWNED BY public.solicitudes_vinculacion_conductor.id;


--
-- TOC entry 312 (class 1259 OID 115689)
-- Name: tickets_soporte; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tickets_soporte (
    id integer NOT NULL,
    numero_ticket character varying(20) NOT NULL,
    usuario_id integer NOT NULL,
    categoria_id integer NOT NULL,
    asunto character varying(255) NOT NULL,
    descripcion text,
    estado character varying(30) DEFAULT 'abierto'::character varying,
    prioridad character varying(20) DEFAULT 'normal'::character varying,
    viaje_id integer,
    agente_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    resuelto_en timestamp without time zone,
    cerrado_en timestamp without time zone,
    CONSTRAINT tickets_soporte_estado_check CHECK (((estado)::text = ANY ((ARRAY['abierto'::character varying, 'en_progreso'::character varying, 'esperando_usuario'::character varying, 'resuelto'::character varying, 'cerrado'::character varying])::text[]))),
    CONSTRAINT tickets_soporte_prioridad_check CHECK (((prioridad)::text = ANY ((ARRAY['baja'::character varying, 'normal'::character varying, 'alta'::character varying, 'urgente'::character varying])::text[])))
);


ALTER TABLE public.tickets_soporte OWNER TO postgres;

--
-- TOC entry 6246 (class 0 OID 0)
-- Dependencies: 312
-- Name: TABLE tickets_soporte; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.tickets_soporte IS 'Tickets de soporte de usuarios';


--
-- TOC entry 317 (class 1259 OID 115754)
-- Name: tickets_completos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.tickets_completos AS
 SELECT t.id,
    t.numero_ticket,
    t.usuario_id,
    t.asunto,
    t.descripcion,
    t.estado,
    t.prioridad,
    t.viaje_id,
    t.created_at,
    t.updated_at,
    t.resuelto_en,
    c.codigo AS categoria_codigo,
    c.nombre AS categoria_nombre,
    c.icono AS categoria_icono,
    c.color AS categoria_color,
    u.nombre AS usuario_nombre,
    u.email AS usuario_email,
    ( SELECT count(*) AS count
           FROM public.mensajes_ticket m
          WHERE (m.ticket_id = t.id)) AS total_mensajes,
    ( SELECT count(*) AS count
           FROM public.mensajes_ticket m
          WHERE ((m.ticket_id = t.id) AND (m.es_agente = true) AND (m.leido = false))) AS mensajes_no_leidos
   FROM ((public.tickets_soporte t
     JOIN public.categorias_soporte c ON ((t.categoria_id = c.id)))
     JOIN public.usuarios u ON ((t.usuario_id = u.id)));


ALTER VIEW public.tickets_completos OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 115688)
-- Name: tickets_soporte_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tickets_soporte_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tickets_soporte_id_seq OWNER TO postgres;

--
-- TOC entry 6247 (class 0 OID 0)
-- Dependencies: 311
-- Name: tickets_soporte_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tickets_soporte_id_seq OWNED BY public.tickets_soporte.id;


--
-- TOC entry 279 (class 1259 OID 90971)
-- Name: tipos_notificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipos_notificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tipos_notificacion_id_seq OWNER TO postgres;

--
-- TOC entry 6248 (class 0 OID 0)
-- Dependencies: 279
-- Name: tipos_notificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipos_notificacion_id_seq OWNED BY public.tipos_notificacion.id;


--
-- TOC entry 286 (class 1259 OID 91031)
-- Name: tokens_push_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tokens_push_usuario (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token text NOT NULL,
    plataforma character varying(20) NOT NULL,
    device_id character varying(255),
    device_name character varying(255),
    activo boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.tokens_push_usuario OWNER TO postgres;

--
-- TOC entry 6249 (class 0 OID 0)
-- Dependencies: 286
-- Name: TABLE tokens_push_usuario; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.tokens_push_usuario IS 'Tokens FCM/APNs para notificaciones push';


--
-- TOC entry 285 (class 1259 OID 91030)
-- Name: tokens_push_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tokens_push_usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tokens_push_usuario_id_seq OWNER TO postgres;

--
-- TOC entry 6250 (class 0 OID 0)
-- Dependencies: 285
-- Name: tokens_push_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tokens_push_usuario_id_seq OWNED BY public.tokens_push_usuario.id;


--
-- TOC entry 237 (class 1259 OID 16798)
-- Name: transacciones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transacciones (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    cliente_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    monto_tarifa numeric(10,2) DEFAULT 0,
    tarifa_distancia numeric(10,2) DEFAULT 0,
    tarifa_tiempo numeric(10,2) DEFAULT 0,
    multiplicador_demanda numeric(3,2) DEFAULT 1.0,
    tarifa_servicio numeric(10,2) DEFAULT 0,
    monto_total numeric(10,2) NOT NULL,
    metodo_pago character varying(30) NOT NULL,
    estado_pago character varying(30) DEFAULT 'pendiente'::character varying,
    fecha_creacion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    fecha_transaccion timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    completado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    estado character varying(50) DEFAULT 'pendiente'::character varying,
    comision_plataforma numeric(10,2) DEFAULT 0,
    monto_conductor numeric(10,2) DEFAULT 0,
    CONSTRAINT transacciones_cliente_id_check CHECK ((cliente_id > 0)),
    CONSTRAINT transacciones_conductor_id_check CHECK ((conductor_id > 0)),
    CONSTRAINT transacciones_estado_pago_check CHECK (((estado_pago)::text = ANY ((ARRAY['pendiente'::character varying, 'procesando'::character varying, 'completado'::character varying, 'fallido'::character varying, 'reembolsado'::character varying])::text[]))),
    CONSTRAINT transacciones_id_check CHECK ((id > 0)),
    CONSTRAINT transacciones_metodo_pago_check CHECK (((metodo_pago)::text = ANY ((ARRAY['efectivo'::character varying, 'tarjeta_credito'::character varying, 'tarjeta_debito'::character varying, 'billetera_digital'::character varying])::text[]))),
    CONSTRAINT transacciones_solicitud_id_check CHECK ((solicitud_id > 0))
);


ALTER TABLE public.transacciones OWNER TO postgres;

--
-- TOC entry 6251 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN transacciones.estado; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.transacciones.estado IS 'Estado de la transacción: pendiente, completada, cancelada';


--
-- TOC entry 6252 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN transacciones.monto_conductor; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.transacciones.monto_conductor IS 'Monto que recibe el conductor (total menos comisión)';


--
-- TOC entry 250 (class 1259 OID 17153)
-- Name: transacciones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transacciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transacciones_id_seq OWNER TO postgres;

--
-- TOC entry 6253 (class 0 OID 0)
-- Dependencies: 250
-- Name: transacciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transacciones_id_seq OWNED BY public.transacciones.id;


--
-- TOC entry 238 (class 1259 OID 16812)
-- Name: ubicaciones_usuario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ubicaciones_usuario (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    latitud numeric(10,8) NOT NULL,
    longitud numeric(11,8) NOT NULL,
    direccion character varying(500) NOT NULL,
    ciudad character varying(100) NOT NULL,
    departamento character varying(100) DEFAULT NULL::character varying,
    pais character varying(100) DEFAULT 'Colombia'::character varying,
    codigo_postal character varying(20) DEFAULT NULL::character varying,
    es_principal smallint DEFAULT 0,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    CONSTRAINT ubicaciones_usuario_id_check CHECK ((id > 0)),
    CONSTRAINT ubicaciones_usuario_usuario_id_check CHECK ((usuario_id > 0))
);


ALTER TABLE public.ubicaciones_usuario OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 17155)
-- Name: ubicaciones_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ubicaciones_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ubicaciones_usuario_id_seq OWNER TO postgres;

--
-- TOC entry 6254 (class 0 OID 0)
-- Dependencies: 251
-- Name: ubicaciones_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ubicaciones_usuario_id_seq OWNED BY public.ubicaciones_usuario.id;


--
-- TOC entry 239 (class 1259 OID 16825)
-- Name: user_devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_devices (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    device_uuid character varying(100) NOT NULL,
    first_seen timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    last_seen timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    trusted smallint DEFAULT 0 NOT NULL,
    fail_attempts integer DEFAULT 0 NOT NULL,
    locked_until timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    CONSTRAINT user_devices_id_check CHECK ((id > 0)),
    CONSTRAINT user_devices_user_id_check CHECK ((user_id > 0))
);


ALTER TABLE public.user_devices OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 17366)
-- Name: user_devices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_devices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_devices_id_seq OWNER TO postgres;

--
-- TOC entry 6255 (class 0 OID 0)
-- Dependencies: 267
-- Name: user_devices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_devices_id_seq OWNED BY public.user_devices.id;


--
-- TOC entry 241 (class 1259 OID 16849)
-- Name: usuarios_backup_20251023; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuarios_backup_20251023 (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    telefono character varying(20) NOT NULL,
    hash_contrasena character varying(255) NOT NULL,
    tipo_usuario character varying(30) DEFAULT 'cliente'::character varying,
    url_imagen_perfil character varying(500) DEFAULT NULL::character varying,
    fecha_nacimiento date,
    verificado smallint DEFAULT 0,
    activo smallint DEFAULT 1,
    creado_en timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    ultimo_acceso_en timestamp(0) without time zone DEFAULT NULL::timestamp without time zone,
    CONSTRAINT usuarios_backup_20251023_id_check CHECK ((id > 0)),
    CONSTRAINT usuarios_backup_20251023_tipo_usuario_check CHECK (((tipo_usuario)::text = ANY ((ARRAY['cliente'::character varying, 'conductor'::character varying, 'administrador'::character varying])::text[])))
);


ALTER TABLE public.usuarios_backup_20251023 OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 17157)
-- Name: usuarios_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuarios_id_seq OWNER TO postgres;

--
-- TOC entry 6256 (class 0 OID 0)
-- Dependencies: 252
-- Name: usuarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuarios_id_seq OWNED BY public.usuarios.id;


--
-- TOC entry 307 (class 1259 OID 115661)
-- Name: v_empresa_tipos_vehiculo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_empresa_tipos_vehiculo AS
 SELECT etv.id,
    etv.empresa_id,
    e.nombre AS empresa_nombre,
    etv.tipo_vehiculo_codigo,
    ctv.nombre AS tipo_vehiculo_nombre,
    ctv.descripcion AS tipo_vehiculo_descripcion,
    ctv.icono,
    etv.activo,
    etv.fecha_activacion,
    etv.fecha_desactivacion,
    etv.motivo_desactivacion,
    etv.conductores_activos,
    etv.viajes_completados,
    etv.creado_en,
    etv.actualizado_en,
    ctv.orden
   FROM ((public.empresa_tipos_vehiculo etv
     JOIN public.empresas_transporte e ON ((etv.empresa_id = e.id)))
     JOIN public.catalogo_tipos_vehiculo ctv ON (((etv.tipo_vehiculo_codigo)::text = (ctv.codigo)::text)))
  ORDER BY e.nombre, ctv.orden;


ALTER VIEW public.v_empresa_tipos_vehiculo OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 115666)
-- Name: v_empresas_completas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_empresas_completas AS
 SELECT e.id,
    e.nombre,
    e.nit,
    e.razon_social,
    e.logo_url,
    e.descripcion,
    e.estado,
    e.verificada,
    e.fecha_verificacion,
    e.verificado_por,
    e.creado_en,
    e.actualizado_en,
    e.creado_por,
    e.notas_admin,
    ec.email,
    ec.telefono,
    ec.telefono_secundario,
    ec.direccion,
    ec.municipio,
    ec.departamento,
    er.nombre AS representante_nombre,
    er.telefono AS representante_telefono,
    er.email AS representante_email,
    er.documento_identidad AS representante_documento,
    em.total_conductores,
    em.conductores_activos,
    em.conductores_pendientes,
    em.total_viajes_completados,
    em.calificacion_promedio,
    em.total_calificaciones,
    em.ingresos_totales,
    em.viajes_mes,
    em.ingresos_mes,
    ecf.tipos_vehiculo,
    ecf.zona_operacion,
    ecf.acepta_efectivo,
    ecf.acepta_tarjeta,
    ecf.acepta_transferencia
   FROM ((((public.empresas_transporte e
     LEFT JOIN public.empresas_contacto ec ON ((e.id = ec.empresa_id)))
     LEFT JOIN public.empresas_representante er ON ((e.id = er.empresa_id)))
     LEFT JOIN public.empresas_metricas em ON ((e.id = em.empresa_id)))
     LEFT JOIN public.empresas_configuracion ecf ON ((e.id = ecf.empresa_id)));


ALTER VIEW public.v_empresas_completas OWNER TO postgres;

--
-- TOC entry 6257 (class 0 OID 0)
-- Dependencies: 308
-- Name: VIEW v_empresas_completas; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_empresas_completas IS 'Vista consolidada de todos los datos de empresa para compatibilidad';


--
-- TOC entry 242 (class 1259 OID 16863)
-- Name: verification_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.verification_codes (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    code character varying(6) NOT NULL,
    created_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp(0) without time zone NOT NULL,
    used smallint DEFAULT 0
);


ALTER TABLE public.verification_codes OWNER TO postgres;

--
-- TOC entry 321 (class 1259 OID 123797)
-- Name: viaje_resumen_tracking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.viaje_resumen_tracking (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    distancia_real_km numeric(10,3) DEFAULT 0,
    tiempo_real_minutos integer DEFAULT 0,
    distancia_estimada_km numeric(10,3) DEFAULT 0,
    tiempo_estimado_minutos integer DEFAULT 0,
    diferencia_distancia_km numeric(10,3) DEFAULT 0,
    diferencia_tiempo_min integer DEFAULT 0,
    porcentaje_desvio_distancia numeric(6,2) DEFAULT 0,
    precio_estimado numeric(12,2) DEFAULT 0,
    precio_final_calculado numeric(12,2) DEFAULT 0,
    precio_final_aplicado numeric(12,2) DEFAULT 0,
    velocidad_promedio_kmh numeric(6,2) DEFAULT 0,
    velocidad_maxima_kmh numeric(6,2) DEFAULT 0,
    total_puntos_gps integer DEFAULT 0,
    tiene_desvio_ruta boolean DEFAULT false,
    km_desvio_detectado numeric(8,3) DEFAULT 0,
    inicio_viaje_real timestamp without time zone,
    fin_viaje_real timestamp without time zone,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.viaje_resumen_tracking OWNER TO postgres;

--
-- TOC entry 6258 (class 0 OID 0)
-- Dependencies: 321
-- Name: TABLE viaje_resumen_tracking; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.viaje_resumen_tracking IS 'Resumen consolidado del tracking de cada viaje para consultas rápidas y cálculo de tarifas';


--
-- TOC entry 320 (class 1259 OID 123796)
-- Name: viaje_resumen_tracking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.viaje_resumen_tracking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.viaje_resumen_tracking_id_seq OWNER TO postgres;

--
-- TOC entry 6259 (class 0 OID 0)
-- Dependencies: 320
-- Name: viaje_resumen_tracking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.viaje_resumen_tracking_id_seq OWNED BY public.viaje_resumen_tracking.id;


--
-- TOC entry 319 (class 1259 OID 123764)
-- Name: viaje_tracking_realtime; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.viaje_tracking_realtime (
    id bigint NOT NULL,
    solicitud_id bigint NOT NULL,
    conductor_id bigint NOT NULL,
    latitud numeric(10,8) NOT NULL,
    longitud numeric(11,8) NOT NULL,
    precision_gps numeric(6,2) DEFAULT NULL::numeric,
    altitud numeric(8,2) DEFAULT NULL::numeric,
    velocidad numeric(6,2) DEFAULT 0,
    bearing numeric(6,2) DEFAULT 0,
    distancia_acumulada_km numeric(10,3) DEFAULT 0,
    tiempo_transcurrido_seg integer DEFAULT 0,
    distancia_desde_anterior_m numeric(10,2) DEFAULT 0,
    precio_parcial numeric(12,2) DEFAULT 0,
    timestamp_gps timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    timestamp_servidor timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    fase_viaje character varying(30) DEFAULT 'hacia_destino'::character varying,
    evento character varying(50) DEFAULT NULL::character varying,
    sincronizado boolean DEFAULT true
);


ALTER TABLE public.viaje_tracking_realtime OWNER TO postgres;

--
-- TOC entry 6260 (class 0 OID 0)
-- Dependencies: 319
-- Name: TABLE viaje_tracking_realtime; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.viaje_tracking_realtime IS 'Tracking GPS en tiempo real durante viajes activos. Cada fila es un punto GPS con acumulados.';


--
-- TOC entry 6261 (class 0 OID 0)
-- Dependencies: 319
-- Name: COLUMN viaje_tracking_realtime.distancia_acumulada_km; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.viaje_tracking_realtime.distancia_acumulada_km IS 'Distancia TOTAL recorrida desde inicio del viaje hasta este punto (km)';


--
-- TOC entry 6262 (class 0 OID 0)
-- Dependencies: 319
-- Name: COLUMN viaje_tracking_realtime.tiempo_transcurrido_seg; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.viaje_tracking_realtime.tiempo_transcurrido_seg IS 'Tiempo TOTAL desde que inició el viaje hasta este punto (segundos)';


--
-- TOC entry 6263 (class 0 OID 0)
-- Dependencies: 319
-- Name: COLUMN viaje_tracking_realtime.precio_parcial; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.viaje_tracking_realtime.precio_parcial IS 'Precio calculado acumulado hasta este punto (para mostrar en UI cliente/conductor)';


--
-- TOC entry 318 (class 1259 OID 123763)
-- Name: viaje_tracking_realtime_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.viaje_tracking_realtime_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.viaje_tracking_realtime_id_seq OWNER TO postgres;

--
-- TOC entry 6264 (class 0 OID 0)
-- Dependencies: 318
-- Name: viaje_tracking_realtime_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.viaje_tracking_realtime_id_seq OWNED BY public.viaje_tracking_realtime.id;


--
-- TOC entry 322 (class 1259 OID 123832)
-- Name: viajes_con_tracking; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.viajes_con_tracking AS
 SELECT s.id,
    s.uuid_solicitud,
    s.cliente_id,
    s.tipo_servicio,
    s.estado,
    s.direccion_recogida,
    s.direccion_destino,
    s.distancia_estimada,
    s.tiempo_estimado,
    s.precio_estimado,
    s.precio_final,
    s.distancia_recorrida,
    s.tiempo_transcurrido,
    s.precio_ajustado_por_tracking,
    r.distancia_real_km AS tracking_distancia_km,
    r.tiempo_real_minutos AS tracking_tiempo_min,
    r.velocidad_promedio_kmh,
    r.total_puntos_gps,
    r.tiene_desvio_ruta,
    (COALESCE(r.distancia_real_km, (0)::numeric) - COALESCE(s.distancia_estimada, (0)::numeric)) AS diferencia_distancia_km,
    (COALESCE(r.tiempo_real_minutos, 0) - COALESCE(s.tiempo_estimado, 0)) AS diferencia_tiempo_min,
        CASE
            WHEN (s.distancia_estimada > (0)::numeric) THEN round((((COALESCE(r.distancia_real_km, (0)::numeric) - s.distancia_estimada) / s.distancia_estimada) * (100)::numeric), 2)
            ELSE (0)::numeric
        END AS porcentaje_desvio,
    ac.conductor_id
   FROM ((public.solicitudes_servicio s
     LEFT JOIN public.viaje_resumen_tracking r ON ((s.id = r.solicitud_id)))
     LEFT JOIN public.asignaciones_conductor ac ON (((s.id = ac.solicitud_id) AND ((ac.estado)::text <> 'cancelado'::text))));


ALTER VIEW public.viajes_con_tracking OWNER TO postgres;

--
-- TOC entry 6265 (class 0 OID 0)
-- Dependencies: 322
-- Name: VIEW viajes_con_tracking; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.viajes_con_tracking IS 'Vista que une solicitudes con su tracking para análisis de viajes';


--
-- TOC entry 243 (class 1259 OID 16875)
-- Name: vista_precios_activos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_precios_activos AS
 SELECT id,
    tipo_vehiculo,
    tarifa_base,
    costo_por_km,
    costo_por_minuto,
    tarifa_minima,
    tarifa_maxima,
    recargo_hora_pico,
    recargo_nocturno,
    recargo_festivo,
    descuento_distancia_larga,
    umbral_km_descuento,
    hora_pico_inicio_manana,
    hora_pico_fin_manana,
    hora_pico_inicio_tarde,
    hora_pico_fin_tarde,
    hora_nocturna_inicio,
    hora_nocturna_fin,
    comision_plataforma,
    comision_metodo_pago,
    distancia_minima,
    distancia_maxima,
    tiempo_espera_gratis,
    costo_tiempo_espera,
    activo,
    fecha_creacion,
    fecha_actualizacion,
    notas,
        CASE
            WHEN ((CURRENT_TIME >= (hora_pico_inicio_manana)::time with time zone) AND (CURRENT_TIME <= (hora_pico_fin_manana)::time with time zone)) THEN 'hora_pico_manana'::text
            WHEN ((CURRENT_TIME >= (hora_pico_inicio_tarde)::time with time zone) AND (CURRENT_TIME <= (hora_pico_fin_tarde)::time with time zone)) THEN 'hora_pico_tarde'::text
            WHEN ((CURRENT_TIME >= (hora_nocturna_inicio)::time with time zone) OR (CURRENT_TIME <= (hora_nocturna_fin)::time with time zone)) THEN 'nocturno'::text
            ELSE 'normal'::text
        END AS periodo_actual,
        CASE
            WHEN ((CURRENT_TIME >= (hora_pico_inicio_manana)::time with time zone) AND (CURRENT_TIME <= (hora_pico_fin_manana)::time with time zone)) THEN recargo_hora_pico
            WHEN ((CURRENT_TIME >= (hora_pico_inicio_tarde)::time with time zone) AND (CURRENT_TIME <= (hora_pico_fin_tarde)::time with time zone)) THEN recargo_hora_pico
            WHEN ((CURRENT_TIME >= (hora_nocturna_inicio)::time with time zone) OR (CURRENT_TIME <= (hora_nocturna_fin)::time with time zone)) THEN recargo_nocturno
            ELSE 0.00
        END AS recargo_actual
   FROM public.configuracion_precios cp
  WHERE (activo = 1);


ALTER VIEW public.vista_precios_activos OWNER TO postgres;

--
-- TOC entry 5050 (class 2604 OID 41821)
-- Name: asignaciones_conductor id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignaciones_conductor ALTER COLUMN id SET DEFAULT nextval('public.asignaciones_conductor_id_seq'::regclass);


--
-- TOC entry 5054 (class 2604 OID 41830)
-- Name: cache_direcciones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache_direcciones ALTER COLUMN id SET DEFAULT nextval('public.cache_direcciones_id_seq'::regclass);


--
-- TOC entry 5056 (class 2604 OID 41831)
-- Name: cache_geocodificacion id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache_geocodificacion ALTER COLUMN id SET DEFAULT nextval('public.cache_geocodificacion_id_seq'::regclass);


--
-- TOC entry 5059 (class 2604 OID 41822)
-- Name: calificaciones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones ALTER COLUMN id SET DEFAULT nextval('public.calificaciones_id_seq'::regclass);


--
-- TOC entry 5369 (class 2604 OID 115558)
-- Name: catalogo_tipos_vehiculo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catalogo_tipos_vehiculo ALTER COLUMN id SET DEFAULT nextval('public.catalogo_tipos_vehiculo_id_seq'::regclass);


--
-- TOC entry 5387 (class 2604 OID 115676)
-- Name: categorias_soporte id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias_soporte ALTER COLUMN id SET DEFAULT nextval('public.categorias_soporte_id_seq'::regclass);


--
-- TOC entry 5303 (class 2604 OID 33661)
-- Name: colores_vehiculo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colores_vehiculo ALTER COLUMN id SET DEFAULT nextval('public.colores_vehiculo_id_seq'::regclass);


--
-- TOC entry 5261 (class 2604 OID 17169)
-- Name: conductores_favoritos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conductores_favoritos ALTER COLUMN id SET DEFAULT nextval('public.conductores_favoritos_id_seq'::regclass);


--
-- TOC entry 5322 (class 2604 OID 91014)
-- Name: configuracion_notificaciones_usuario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_notificaciones_usuario ALTER COLUMN id SET DEFAULT nextval('public.configuracion_notificaciones_usuario_id_seq'::regclass);


--
-- TOC entry 5067 (class 2604 OID 41823)
-- Name: configuracion_precios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_precios ALTER COLUMN id SET DEFAULT nextval('public.configuracion_precios_id_seq'::regclass);


--
-- TOC entry 5061 (class 2604 OID 41824)
-- Name: configuraciones_app id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuraciones_app ALTER COLUMN id SET DEFAULT nextval('public.configuraciones_app_id_seq'::regclass);


--
-- TOC entry 5094 (class 2604 OID 41825)
-- Name: detalles_conductor id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_conductor ALTER COLUMN id SET DEFAULT nextval('public.detalles_conductor_id_seq'::regclass);


--
-- TOC entry 5280 (class 2604 OID 17285)
-- Name: disputas_pago id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago ALTER COLUMN id SET DEFAULT nextval('public.disputas_pago_id_seq'::regclass);


--
-- TOC entry 5300 (class 2604 OID 33643)
-- Name: documentos_verificacion id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_verificacion ALTER COLUMN id SET DEFAULT nextval('public.documentos_verificacion_id_seq'::regclass);


--
-- TOC entry 5373 (class 2604 OID 115572)
-- Name: empresa_tipos_vehiculo id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo ALTER COLUMN id SET DEFAULT nextval('public.empresa_tipos_vehiculo_id_seq'::regclass);


--
-- TOC entry 5380 (class 2604 OID 115613)
-- Name: empresa_tipos_vehiculo_historial id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo_historial ALTER COLUMN id SET DEFAULT nextval('public.empresa_tipos_vehiculo_historial_id_seq'::regclass);


--
-- TOC entry 5383 (class 2604 OID 115636)
-- Name: empresa_vehiculo_notificaciones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_vehiculo_notificaciones ALTER COLUMN id SET DEFAULT nextval('public.empresa_vehiculo_notificaciones_id_seq'::regclass);


--
-- TOC entry 5359 (class 2604 OID 91277)
-- Name: empresas_configuracion id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_configuracion ALTER COLUMN id SET DEFAULT nextval('public.empresas_configuracion_id_seq'::regclass);


--
-- TOC entry 5340 (class 2604 OID 91211)
-- Name: empresas_contacto id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_contacto ALTER COLUMN id SET DEFAULT nextval('public.empresas_contacto_id_seq'::regclass);


--
-- TOC entry 5347 (class 2604 OID 91251)
-- Name: empresas_metricas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_metricas ALTER COLUMN id SET DEFAULT nextval('public.empresas_metricas_id_seq'::regclass);


--
-- TOC entry 5343 (class 2604 OID 91231)
-- Name: empresas_representante id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_representante ALTER COLUMN id SET DEFAULT nextval('public.empresas_representante_id_seq'::regclass);


--
-- TOC entry 5290 (class 2604 OID 25439)
-- Name: empresas_transporte id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_transporte ALTER COLUMN id SET DEFAULT nextval('public.empresas_transporte_id_seq'::regclass);


--
-- TOC entry 5264 (class 2604 OID 17190)
-- Name: historial_confianza id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_confianza ALTER COLUMN id SET DEFAULT nextval('public.historial_confianza_id_seq'::regclass);


--
-- TOC entry 5163 (class 2604 OID 50013)
-- Name: logs_auditoria id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs_auditoria ALTER COLUMN id SET DEFAULT nextval('public.logs_auditoria_id_seq'::regclass);


--
-- TOC entry 5274 (class 2604 OID 17247)
-- Name: mensajes_chat id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_chat ALTER COLUMN id SET DEFAULT nextval('public.mensajes_chat_id_seq'::regclass);


--
-- TOC entry 5398 (class 2604 OID 115720)
-- Name: mensajes_ticket id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_ticket ALTER COLUMN id SET DEFAULT nextval('public.mensajes_ticket_id_seq'::regclass);


--
-- TOC entry 5316 (class 2604 OID 90990)
-- Name: notificaciones_usuario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones_usuario ALTER COLUMN id SET DEFAULT nextval('public.notificaciones_usuario_id_seq'::regclass);


--
-- TOC entry 5305 (class 2604 OID 58209)
-- Name: pagos_empresas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_empresas ALTER COLUMN id SET DEFAULT nextval('public.pagos_empresas_id_seq'::regclass);


--
-- TOC entry 5286 (class 2604 OID 17351)
-- Name: pagos_viaje id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_viaje ALTER COLUMN id SET DEFAULT nextval('public.pagos_viaje_id_seq'::regclass);


--
-- TOC entry 5175 (class 2604 OID 41829)
-- Name: paradas_solicitud id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paradas_solicitud ALTER COLUMN id SET DEFAULT nextval('public.paradas_solicitud_id_seq'::regclass);


--
-- TOC entry 5307 (class 2604 OID 82783)
-- Name: plantillas_bloqueadas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_bloqueadas ALTER COLUMN id SET DEFAULT nextval('public.plantillas_bloqueadas_id_seq'::regclass);


--
-- TOC entry 5403 (class 2604 OID 115740)
-- Name: solicitudes_callback id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_callback ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_callback_id_seq'::regclass);


--
-- TOC entry 5191 (class 2604 OID 41820)
-- Name: solicitudes_servicio id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_servicio_id_seq'::regclass);


--
-- TOC entry 5337 (class 2604 OID 91161)
-- Name: solicitudes_vinculacion_conductor id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor ALTER COLUMN id SET DEFAULT nextval('public.solicitudes_vinculacion_conductor_id_seq'::regclass);


--
-- TOC entry 5393 (class 2604 OID 115692)
-- Name: tickets_soporte id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets_soporte ALTER COLUMN id SET DEFAULT nextval('public.tickets_soporte_id_seq'::regclass);


--
-- TOC entry 5311 (class 2604 OID 90975)
-- Name: tipos_notificacion id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_notificacion ALTER COLUMN id SET DEFAULT nextval('public.tipos_notificacion_id_seq'::regclass);


--
-- TOC entry 5333 (class 2604 OID 91034)
-- Name: tokens_push_usuario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens_push_usuario ALTER COLUMN id SET DEFAULT nextval('public.tokens_push_usuario_id_seq'::regclass);


--
-- TOC entry 5214 (class 2604 OID 41826)
-- Name: transacciones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones ALTER COLUMN id SET DEFAULT nextval('public.transacciones_id_seq'::regclass);


--
-- TOC entry 5227 (class 2604 OID 41827)
-- Name: ubicaciones_usuario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicaciones_usuario ALTER COLUMN id SET DEFAULT nextval('public.ubicaciones_usuario_id_seq'::regclass);


--
-- TOC entry 5234 (class 2604 OID 17367)
-- Name: user_devices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_devices ALTER COLUMN id SET DEFAULT nextval('public.user_devices_id_seq'::regclass);


--
-- TOC entry 5240 (class 2604 OID 41828)
-- Name: usuarios id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios ALTER COLUMN id SET DEFAULT nextval('public.usuarios_id_seq'::regclass);


--
-- TOC entry 5421 (class 2604 OID 123800)
-- Name: viaje_resumen_tracking id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_resumen_tracking ALTER COLUMN id SET DEFAULT nextval('public.viaje_resumen_tracking_id_seq'::regclass);


--
-- TOC entry 5407 (class 2604 OID 123767)
-- Name: viaje_tracking_realtime id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_tracking_realtime ALTER COLUMN id SET DEFAULT nextval('public.viaje_tracking_realtime_id_seq'::regclass);


--
-- TOC entry 6061 (class 0 OID 16508)
-- Dependencies: 217
-- Data for Name: asignaciones_conductor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asignaciones_conductor (id, solicitud_id, conductor_id, asignado_en, llegado_en, estado) FROM stdin;
65	629	7	2025-12-21 20:30:07	\N	asignado
66	630	7	2025-12-21 20:54:36	\N	asignado
67	631	7	2025-12-21 20:57:53	\N	asignado
68	632	7	2025-12-21 21:02:48	\N	asignado
69	633	7	2025-12-21 21:16:52	\N	asignado
70	634	7	2025-12-21 21:23:25	\N	asignado
71	635	7	2025-12-21 21:35:26	\N	asignado
72	636	7	2025-12-21 21:46:05	\N	asignado
75	639	7	2025-12-21 22:17:58	\N	asignado
76	640	7	2025-12-21 22:27:23	\N	llegado
74	638	7	2025-12-21 22:15:05	\N	llegado
73	637	7	2025-12-21 21:51:43	\N	llegado
77	641	7	2025-12-21 22:38:25	\N	llegado
78	642	7	2025-12-21 22:44:54	\N	llegado
79	643	7	2025-12-21 22:54:05	\N	llegado
80	644	7	2025-12-21 22:56:48	\N	asignado
81	645	7	2025-12-21 23:06:34	\N	llegado
82	646	7	2025-12-21 23:29:26	\N	llegado
83	647	7	2025-12-21 23:32:02	\N	llegado
84	648	7	2025-12-22 00:10:01	\N	llegado
85	649	7	2025-12-22 00:16:00	\N	llegado
86	650	7	2025-12-22 00:37:59	\N	llegado
87	651	7	2025-12-22 00:53:55	\N	llegado
88	652	7	2025-12-22 01:17:33	\N	llegado
89	653	7	2025-12-22 01:28:56	\N	llegado
90	654	7	2025-12-22 22:53:10	\N	llegado
91	655	7	2025-12-22 23:01:07	\N	llegado
92	657	7	2025-12-23 00:22:08	\N	asignado
93	658	7	2025-12-23 02:54:55	\N	cancelado
94	659	7	2025-12-23 03:01:11	\N	llegado
95	660	7	2025-12-23 03:03:59	\N	cancelado
96	661	7	2025-12-23 03:08:09	\N	llegado
97	662	7	2025-12-23 03:16:49	\N	llegado
98	663	7	2025-12-23 03:19:14	\N	asignado
99	672	7	2025-12-29 20:48:49	\N	asignado
100	673	7	2025-12-29 20:55:33	\N	asignado
101	674	7	2025-12-29 20:59:46	\N	asignado
102	675	7	2025-12-29 21:17:57	\N	asignado
103	676	7	2025-12-29 21:24:37	\N	asignado
104	677	7	2025-12-29 21:26:15	\N	asignado
105	678	7	2025-12-29 21:30:00	\N	asignado
106	679	7	2025-12-29 21:31:19	\N	llegado
107	680	7	2025-12-29 21:41:03	\N	asignado
108	681	7	2025-12-29 21:45:38	\N	llegado
109	682	7	2025-12-29 21:47:44	\N	llegado
110	683	7	2025-12-29 23:23:40	\N	llegado
112	687	293	2026-01-14 02:35:30	\N	asignado
113	688	293	2026-01-14 02:36:26	\N	asignado
114	689	293	2026-01-14 02:37:17	\N	asignado
115	690	293	2026-01-14 02:37:17	\N	asignado
116	691	293	2026-01-14 02:37:17	\N	asignado
117	692	293	2026-01-14 02:37:17	\N	asignado
118	693	293	2026-01-14 02:37:17	\N	asignado
119	694	293	2026-01-14 02:37:17	\N	asignado
120	695	293	2026-01-14 02:37:17	\N	asignado
121	696	294	2026-01-14 02:37:17	\N	asignado
122	697	294	2026-01-14 02:37:17	\N	asignado
123	698	294	2026-01-14 02:37:17	\N	asignado
124	699	294	2026-01-14 02:37:17	\N	asignado
125	700	294	2026-01-14 02:37:17	\N	asignado
126	701	294	2026-01-14 02:37:17	\N	asignado
127	702	294	2026-01-14 02:37:17	\N	asignado
128	703	294	2026-01-14 02:37:17	\N	asignado
129	704	295	2026-01-14 02:37:17	\N	asignado
130	705	295	2026-01-14 02:37:17	\N	asignado
131	706	295	2026-01-14 02:37:17	\N	asignado
132	707	295	2026-01-14 02:37:17	\N	asignado
133	708	295	2026-01-14 02:37:17	\N	asignado
134	709	295	2026-01-14 02:37:17	\N	asignado
135	710	295	2026-01-14 02:37:17	\N	asignado
136	711	295	2026-01-14 02:37:17	\N	asignado
137	712	296	2026-01-14 02:37:17	\N	asignado
138	713	296	2026-01-14 02:37:17	\N	asignado
139	714	296	2026-01-14 02:37:17	\N	asignado
140	715	296	2026-01-14 02:37:17	\N	asignado
141	716	296	2026-01-14 02:37:17	\N	asignado
142	717	296	2026-01-14 02:37:17	\N	asignado
143	718	296	2026-01-14 02:37:17	\N	asignado
144	719	297	2026-01-14 02:37:17	\N	asignado
145	720	297	2026-01-14 02:37:17	\N	asignado
146	721	297	2026-01-14 02:37:17	\N	asignado
147	722	297	2026-01-14 02:37:17	\N	asignado
148	723	297	2026-01-14 02:37:17	\N	asignado
149	724	297	2026-01-14 02:37:17	\N	asignado
150	727	277	2026-01-16 19:23:30	\N	cancelado
151	728	277	2026-01-16 19:58:39	\N	cancelado
152	729	277	2026-01-16 20:37:03	\N	asignado
153	730	277	2026-01-16 21:33:49	\N	asignado
154	731	277	2026-01-16 22:11:07	\N	asignado
155	732	277	2026-01-16 22:21:48	\N	asignado
156	733	277	2026-01-17 22:06:54	\N	llegado
157	734	277	2026-01-17 23:00:39	\N	llegado
158	735	277	2026-01-17 23:18:39	\N	llegado
159	736	277	2026-01-17 23:32:07	\N	llegado
160	737	277	2026-01-17 23:56:45	\N	llegado
161	738	277	2026-01-18 00:26:12	\N	llegado
162	739	277	2026-01-18 01:26:56	\N	llegado
163	740	277	2026-01-18 02:08:25	\N	llegado
164	741	277	2026-01-18 02:22:51	\N	llegado
165	742	277	2026-01-18 02:58:20	\N	llegado
166	743	277	2026-01-18 03:19:45	\N	llegado
167	744	277	2026-01-18 13:10:47	\N	llegado
168	745	277	2026-01-18 13:56:41	\N	llegado
169	746	277	2026-01-18 14:20:22	\N	llegado
170	747	277	2026-01-18 14:24:00	\N	completado
171	748	277	2026-01-18 15:04:56	\N	completado
172	749	277	2026-01-18 20:25:30	\N	cancelado
173	750	277	2026-01-18 21:01:52	\N	cancelado
174	751	277	2026-01-18 21:07:44	\N	cancelado
175	752	277	2026-01-18 21:17:37	\N	cancelado
176	753	277	2026-01-18 21:25:18	\N	cancelado
177	754	277	2026-01-18 21:28:06	\N	cancelado
178	755	277	2026-01-18 22:05:06	\N	cancelado
179	756	277	2026-01-18 22:13:15	\N	cancelado
180	758	277	2026-01-18 22:34:21	\N	cancelado
181	759	277	2026-01-18 22:37:18	\N	cancelado
182	760	277	2026-01-18 23:02:58	\N	cancelado
183	761	277	2026-01-18 23:19:16	\N	cancelado
184	763	277	2026-01-18 23:22:41	\N	cancelado
185	764	277	2026-01-18 23:47:18	\N	cancelado
186	765	277	2026-01-18 23:53:21	\N	cancelado
187	766	277	2026-01-19 00:01:02	\N	completado
188	767	277	2026-01-19 03:24:14	\N	completado
189	768	277	2026-01-19 03:39:26	\N	completado
190	769	277	2026-01-19 22:21:23	\N	completado
191	772	277	2026-01-19 22:49:59	\N	completado
192	775	277	2026-01-19 22:59:39	\N	completado
193	776	277	2026-01-19 23:18:39	\N	completado
194	777	277	2026-01-19 23:21:45	\N	cancelado
195	778	277	2026-01-19 23:22:32	\N	completado
196	779	277	2026-01-20 00:02:32	\N	completado
197	780	277	2026-01-20 00:32:52	\N	completado
198	781	277	2026-01-20 00:46:55	\N	cancelado
199	782	277	2026-01-20 00:51:39	\N	completado
200	783	277	2026-01-20 01:03:50	\N	completado
201	784	277	2026-01-20 01:19:07	\N	completado
202	785	277	2026-01-20 01:33:53	\N	completado
203	786	277	2026-01-20 01:53:11	\N	completado
204	787	277	2026-01-21 01:37:24	\N	completado
\.


--
-- TOC entry 6062 (class 0 OID 16518)
-- Dependencies: 218
-- Data for Name: cache_direcciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cache_direcciones (id, latitud_origen, longitud_origen, latitud_destino, longitud_destino, distancia, duracion, polilinea, datos_respuesta, creado_en, expira_en) FROM stdin;
\.


--
-- TOC entry 6063 (class 0 OID 16525)
-- Dependencies: 219
-- Data for Name: cache_geocodificacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cache_geocodificacion (id, latitud, longitud, direccion_formateada, id_lugar, datos_respuesta, creado_en, expira_en) FROM stdin;
\.


--
-- TOC entry 6064 (class 0 OID 16533)
-- Dependencies: 220
-- Data for Name: calificaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.calificaciones (id, solicitud_id, usuario_calificador_id, usuario_calificado_id, calificacion, comentarios, creado_en) FROM stdin;
1	645	2	7	5	Excelente servicio!	2025-12-21 23:24:07
2	645	7	2	4	Buen pasajero	2025-12-21 23:24:07
3	650	7	3	5	ddd	2025-12-22 00:45:48
4	652	7	6	5	\N	2025-12-22 01:18:53
5	653	7	8	5	\N	2025-12-22 01:32:06
6	654	7	9	5	\N	2025-12-22 22:54:29
7	655	7	9	5	\N	2025-12-22 23:01:31
8	661	7	9	5	\N	2025-12-23 03:10:23
9	662	7	9	5	\N	2025-12-23 03:17:17
10	689	1	293	4	Excelente servicio	2026-01-14 02:37:17
11	690	1	293	4	Excelente servicio	2026-01-14 02:37:17
12	691	1	293	5	Excelente servicio	2026-01-14 02:37:17
13	692	1	293	5	Excelente servicio	2026-01-14 02:37:17
14	693	1	293	5	Excelente servicio	2026-01-14 02:37:17
15	694	1	293	4	Excelente servicio	2026-01-14 02:37:17
16	695	1	293	4	Excelente servicio	2026-01-14 02:37:17
17	696	1	294	4	Excelente servicio	2026-01-14 02:37:17
18	697	1	294	5	Excelente servicio	2026-01-14 02:37:17
19	698	1	294	4	Excelente servicio	2026-01-14 02:37:17
20	699	1	294	4	Excelente servicio	2026-01-14 02:37:17
21	700	1	294	5	Excelente servicio	2026-01-14 02:37:17
22	701	1	294	5	Excelente servicio	2026-01-14 02:37:17
23	702	1	294	4	Excelente servicio	2026-01-14 02:37:17
24	703	1	294	5	Excelente servicio	2026-01-14 02:37:17
25	704	1	295	4	Excelente servicio	2026-01-14 02:37:17
26	705	1	295	4	Excelente servicio	2026-01-14 02:37:17
27	706	1	295	4	Excelente servicio	2026-01-14 02:37:17
28	707	1	295	4	Excelente servicio	2026-01-14 02:37:17
29	708	1	295	5	Excelente servicio	2026-01-14 02:37:17
30	709	1	295	5	Excelente servicio	2026-01-14 02:37:17
31	710	1	295	4	Excelente servicio	2026-01-14 02:37:17
32	711	1	295	5	Excelente servicio	2026-01-14 02:37:17
33	712	1	296	5	Excelente servicio	2026-01-14 02:37:17
34	713	1	296	5	Excelente servicio	2026-01-14 02:37:17
35	714	1	296	5	Excelente servicio	2026-01-14 02:37:17
36	715	1	296	5	Excelente servicio	2026-01-14 02:37:17
37	716	1	296	5	Excelente servicio	2026-01-14 02:37:17
38	717	1	296	4	Excelente servicio	2026-01-14 02:37:17
39	718	1	296	5	Excelente servicio	2026-01-14 02:37:17
40	719	1	297	5	Excelente servicio	2026-01-14 02:37:17
41	720	1	297	5	Excelente servicio	2026-01-14 02:37:17
42	721	1	297	4	Excelente servicio	2026-01-14 02:37:17
43	722	1	297	5	Excelente servicio	2026-01-14 02:37:17
44	723	1	297	5	Excelente servicio	2026-01-14 02:37:17
45	724	1	297	5	Excelente servicio	2026-01-14 02:37:17
46	733	276	277	5	\N	2026-01-17 22:48:36
47	733	277	276	5	\N	2026-01-17 22:48:43
48	734	277	276	3	\N	2026-01-17 23:10:35
49	734	276	277	3	\N	2026-01-17 23:10:38
50	735	276	277	5	\N	2026-01-17 23:24:37
51	735	277	276	4	\N	2026-01-17 23:24:44
52	737	276	277	5	\N	2026-01-18 00:01:13
53	737	277	276	5	\N	2026-01-18 00:03:15
54	748	276	277	5	\N	2026-01-18 15:22:46
55	748	277	276	5	\N	2026-01-18 15:22:52
56	767	277	276	5	gran conductor \n	2026-01-19 03:27:19
57	767	276	277	5	\N	2026-01-19 03:27:25
58	768	277	276	5	\N	2026-01-19 03:40:57
59	768	276	277	5	\N	2026-01-19 03:41:07
60	769	276	277	5	buen conductor	2026-01-19 22:23:45
61	769	277	276	5	\N	2026-01-19 22:23:50
62	772	276	277	5	excelente	2026-01-19 22:52:00
63	772	277	276	5	\N	2026-01-19 22:52:07
64	775	277	276	5	\N	2026-01-19 23:01:35
65	776	277	276	5	I\nh	2026-01-19 23:20:11
66	776	276	277	5	grande	2026-01-19 23:20:19
67	778	277	276	5	\N	2026-01-19 23:23:17
68	780	277	276	5	\N	2026-01-20 00:33:59
69	780	276	277	5	ssas	2026-01-20 00:34:04
70	782	276	277	5	\N	2026-01-20 00:53:49
71	782	277	276	5	\N	2026-01-20 00:53:51
72	783	277	276	5	\N	2026-01-20 01:05:06
73	784	277	276	5	\N	2026-01-20 01:21:04
74	784	276	277	5	\N	2026-01-20 01:21:08
75	786	277	276	5	\N	2026-01-20 01:54:31
76	786	276	277	5	garnde	2026-01-20 01:54:38
77	787	277	276	5	\N	2026-01-21 01:39:14
78	787	276	277	5	\N	2026-01-21 01:39:18
\.


--
-- TOC entry 6140 (class 0 OID 115555)
-- Dependencies: 300
-- Data for Name: catalogo_tipos_vehiculo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.catalogo_tipos_vehiculo (id, codigo, nombre, descripcion, icono, orden, activo, creado_en) FROM stdin;
1	moto	Moto	Motocicletas para transporte rápido	two_wheeler	1	t	2026-01-11 01:02:14.525081
2	auto	Auto	Automóviles sedan y similares	directions_car	2	t	2026-01-11 01:02:14.525081
3	motocarro	Motocarro	Motocarros de carga y pasajeros	electric_rickshaw	3	t	2026-01-11 01:02:14.525081
4	taxi	Taxi	Taxis tradicionales amarillos	local_taxi	4	t	2026-01-12 01:44:51.005649
\.


--
-- TOC entry 6148 (class 0 OID 115673)
-- Dependencies: 310
-- Data for Name: categorias_soporte; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categorias_soporte (id, codigo, nombre, descripcion, icono, color, orden, activo, created_at) FROM stdin;
1	viaje	Problemas con viajes	Incidentes durante el viaje, rutas incorrectas, etc.	directions_car	#4CAF50	1	t	2026-01-12 00:48:53.322846
2	pago	Pagos y facturación	Problemas con cobros, reembolsos, facturas	payment	#FF9800	2	t	2026-01-12 00:48:53.322846
3	cuenta	Mi cuenta	Problemas de acceso, actualización de datos	person	#2196F3	3	t	2026-01-12 00:48:53.322846
4	conductor	Conductor	Reportar comportamiento, quejas o felicitaciones	badge	#9C27B0	4	t	2026-01-12 00:48:53.322846
5	app	Problemas técnicos	Errores en la aplicación, fallas técnicas	bug_report	#F44336	5	t	2026-01-12 00:48:53.322846
6	seguridad	Seguridad	Reportar situaciones de seguridad	security	#E91E63	6	t	2026-01-12 00:48:53.322846
7	sugerencia	Sugerencias	Ideas para mejorar el servicio	lightbulb	#00BCD4	7	t	2026-01-12 00:48:53.322846
8	otro	Otro	Otras consultas generales	help_outline	#607D8B	8	t	2026-01-12 00:48:53.322846
\.


--
-- TOC entry 6115 (class 0 OID 33658)
-- Dependencies: 273
-- Data for Name: colores_vehiculo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.colores_vehiculo (id, nombre, hex_code, activo) FROM stdin;
1	Negro	#000000	t
2	Blanco	#FFFFFF	t
3	Gris	#808080	t
4	Plateado	#C0C0C0	t
5	Azul	#0000FF	t
6	Rojo	#FF0000	t
7	Verde	#008000	t
8	Amarillo	#FFFF00	t
9	Naranja	#FFA500	t
10	Marrón	#A52A2A	t
11	Beige	#F5F5DC	t
12	Dorado	#FFD700	t
13	Otro	#CCCCCC	t
14	Negro	#000000	t
15	Blanco	#FFFFFF	t
16	Gris	#808080	t
17	Plateado	#C0C0C0	t
18	Azul	#0000FF	t
19	Rojo	#FF0000	t
20	Verde	#008000	t
21	Amarillo	#FFFF00	t
22	Naranja	#FFA500	t
23	Marrón	#A52A2A	t
24	Beige	#F5F5DC	t
25	Dorado	#FFD700	t
26	Otro	#CCCCCC	t
\.


--
-- TOC entry 6100 (class 0 OID 17166)
-- Dependencies: 257
-- Data for Name: conductores_favoritos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.conductores_favoritos (id, usuario_id, conductor_id, es_favorito, fecha_marcado, fecha_desmarcado) FROM stdin;
\.


--
-- TOC entry 6126 (class 0 OID 91011)
-- Dependencies: 284
-- Data for Name: configuracion_notificaciones_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.configuracion_notificaciones_usuario (id, usuario_id, push_enabled, email_enabled, sms_enabled, notif_viajes, notif_pagos, notif_promociones, notif_sistema, notif_chat, horario_silencioso_inicio, horario_silencioso_fin, created_at, updated_at) FROM stdin;
1	1	t	t	f	t	t	t	t	t	\N	\N	2026-01-07 22:56:45.852026	2026-01-07 22:56:45.852026
2	276	t	t	f	t	t	t	t	t	\N	\N	2026-01-11 23:36:58.247339	2026-01-11 23:36:58.247339
3	278	t	t	f	t	t	t	t	t	\N	\N	2026-01-13 21:57:43.271725	2026-01-13 21:57:43.271725
\.


--
-- TOC entry 6066 (class 0 OID 16555)
-- Dependencies: 222
-- Data for Name: configuracion_precios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.configuracion_precios (id, tipo_vehiculo, tarifa_base, costo_por_km, costo_por_minuto, tarifa_minima, tarifa_maxima, recargo_hora_pico, recargo_nocturno, recargo_festivo, descuento_distancia_larga, umbral_km_descuento, hora_pico_inicio_manana, hora_pico_fin_manana, hora_pico_inicio_tarde, hora_pico_fin_tarde, hora_nocturna_inicio, hora_nocturna_fin, comision_plataforma, comision_metodo_pago, distancia_minima, distancia_maxima, tiempo_espera_gratis, costo_tiempo_espera, activo, fecha_creacion, fecha_actualizacion, notas, empresa_id) FROM stdin;
5	moto	4000.00	2000.00	250.00	6000.00	\N	15.00	20.00	25.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	0.00	1.00	50.00	3	500.00	1	2025-10-26 18:40:23	2025-12-29 16:30:09	Configuraci├│n inicial para servicio de moto - Octubre 2025 | Comisiones establecidas a 0 - Dic 2025	\N
7	auto	6000.00	3000.00	400.00	9000.00	\N	20.00	25.00	30.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	0.00	1.00	50.00	3	500.00	1	2025-12-04 17:39:01	2025-12-29 16:30:09	Configuracion para servicio de auto - Diciembre 2025 | Comisiones establecidas a 0 - Dic 2025	\N
8	motocarro	5500.00	2500.00	350.00	8000.00	\N	18.00	22.00	28.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	0.00	1.00	50.00	3	500.00	1	2025-12-04 17:39:01	2025-12-29 16:30:09	Configuracion para servicio de motocarro - Diciembre 2025 | Comisiones establecidas a 0 - Dic 2025	\N
11	motocarro	5500.00	2500.00	350.00	8000.00	\N	18.00	22.00	28.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	0.00	1.00	50.00	3	500.00	1	2026-01-11 01:04:24	2026-01-11 01:04:24	\N	1
13	taxi	7000.00	3200.00	450.00	10000.00	\N	22.00	28.00	35.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	2.50	0.50	100.00	3	500.00	1	2026-01-12 01:46:28	2026-01-12 01:46:28	Configuración global para taxi - Enero 2026	\N
10	auto	7000.00	3000.00	400.00	9000.00	\N	20.00	25.00	30.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	0.00	0.00	1.00	50.00	3	500.00	1	2026-01-11 01:04:23	2026-01-13 15:58:26	\N	1
9	moto	4000.00	2000.00	250.00	6000.00	\N	15.00	20.00	25.00	10.00	15.00	07:00:00	09:00:00	17:00:00	19:00:00	22:00:00	06:00:00	10.00	0.00	1.00	50.00	3	500.00	1	2026-01-11 01:04:22	2026-01-21 00:15:40	\N	1
\.


--
-- TOC entry 6065 (class 0 OID 16543)
-- Dependencies: 221
-- Data for Name: configuraciones_app; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.configuraciones_app (id, clave, valor, tipo, categoria, descripcion, es_publica, fecha_creacion, fecha_actualizacion) FROM stdin;
1	app_nombre	Viax	string	sistema	Nombre de la aplicacion	1	2025-10-22 14:35:57	2025-11-08 22:25:24
2	app_version	1.0.0	string	sistema	Version actual de la aplicacion	1	2025-10-22 14:35:57	2025-11-08 22:25:24
3	mantenimiento_activo	false	boolean	sistema	Indica si la app esta en mantenimiento	1	2025-10-22 14:35:57	2025-11-08 22:25:24
4	precio_base_km	2500	number	precios	Precio base por kilometro en COP	0	2025-10-22 14:35:57	2025-11-08 22:25:24
5	precio_minimo_viaje	5000	number	precios	Precio minimo de un viaje en COP	0	2025-10-22 14:35:57	2025-11-08 22:25:24
6	comision_plataforma	15	number	precios	Porcentaje de comision de la plataforma	0	2025-10-22 14:35:57	2025-11-08 22:25:24
7	radio_busqueda_conductores	5000	number	sistema	Radio en metros para buscar conductores	0	2025-10-22 14:35:57	2025-11-08 22:25:24
8	tiempo_expiracion_solicitud	300	number	sistema	Tiempo en segundos antes de expirar solicitud	0	2025-10-22 14:35:57	2025-11-08 22:25:24
\.


--
-- TOC entry 6067 (class 0 OID 16588)
-- Dependencies: 223
-- Data for Name: detalles_conductor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalles_conductor (id, usuario_id, licencia_conduccion, licencia_vencimiento, licencia_expedicion, licencia_categoria, licencia_foto_url, vehiculo_tipo, vehiculo_marca, vehiculo_modelo, vehiculo_anio, vehiculo_color, vehiculo_placa, aseguradora, numero_poliza_seguro, vencimiento_seguro, seguro_foto_url, soat_numero, soat_vencimiento, soat_foto_url, tecnomecanica_numero, tecnomecanica_vencimiento, tecnomecanica_foto_url, tarjeta_propiedad_numero, tarjeta_propiedad_foto_url, aprobado, estado_aprobacion, calificacion_promedio, total_calificaciones, creado_en, actualizado_en, disponible, latitud_actual, longitud_actual, ultima_actualizacion, total_viajes, estado_verificacion, fecha_ultima_verificacion, fecha_creacion, ganancias_totales, estado_biometrico, foto_vehiculo, licencia_tipo_archivo, soat_tipo_archivo, tecnomecanica_tipo_archivo, tarjeta_propiedad_tipo_archivo, seguro_tipo_archivo, plantilla_biometrica, fecha_verificacion_biometrica, razon_rechazo) FROM stdin;
26	13	LIC10001	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC101	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:31:53	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:31:53	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
25	12	LIC10000	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC100	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:31:53	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:31:53	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
27	14	LIC10002	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC102	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:31:53	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:31:53	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
28	15	LIC10003	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC103	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:31:53	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:31:53	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
29	16	LIC10004	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC104	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:31:53	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:31:53	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
1	7	42424224242	2036-10-25	2020-10-08	C1	uploads/documentos/conductor_7/licencia_1761492375_1a4c4887f68f6988.jpg	motocicleta	toyota	corolla	2020	Blanco	3232323	\N	\N	\N	\N	3232323	2027-10-26	uploads/documentos/conductor_7/soat_1761492819_87a1e30ab2e6b43c.jpg	323232332	2027-10-26	uploads/documentos/conductor_7/tecnomecanica_1761492819_a331dc0207ae3a9d.jpg	32323	uploads/documentos/conductor_7/tarjeta_propiedad_1761492820_ad1097b64c039a5d.jpg	1	aprobado	5.00	1	2025-10-24 11:53:16	2025-11-24 00:38:27	0	6.25461830	-75.53955670	2025-12-29 23:23:40	16	aprobado	2025-10-26 16:22:01	2025-10-24 11:53:16	595169.58	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
11	231	32626	2028-01-01	2023-01-01	A2	documents/231/licencia_conduccion_1767322829.jpg	moto	IEIEIE	URURUE	32313	Blanco	UEUEU	\N	\N	\N	\N	iririi	2026-04-30	documents/231/soat_1767322830.jpg	6262662	2026-04-30	documents/231/tecnomecanica_1767322831.pdf	323232	documents/231/tarjeta_propiedad_1767322832.jpg	0	pendiente	0.00	0	2026-01-02 03:00:28	2026-01-02 03:00:29	0	\N	\N	\N	0	en_revision	\N	2026-01-02 03:00:28	0.00	verificado	\N	imagen	imagen	imagen	imagen	imagen	[0.07896222189602438,0.04918231838191605,0.08594102506286685,-0.006839148535249234,0.007383270290646202,-0.10811813466374397,-0.04653549790141691,-0.02214909798549509,0.0004155970379731051,0.08129976119109895,-0.07184170814111933,0.19697942687439218,0.09291042343148664,-0.12222917088063004,-0.06555125329088278,0.06509369255766355,-0.05719895506387122,-0.11798297228988726,-0.18975801776190415,0.028692998329574084,-0.015698487006357547,-0.02490692964817507,-0.05563386500897871,0.08870622809344098,0.13321544058814824,-0.026566338049777344,0.05515799785672848,-0.08608265086558411,-0.13071412947400293,-0.08441630221167867,0.03864780592601746,-0.2079776877382626,-0.07713354773054433,0.09910926573448801,0.05136114177729798,0.2826860861931601,-0.021022321340457475,-0.030798384750121838,-0.04700612426413813,0.04992351652791857,0.11992513682961206,0.05580023970716848,-0.12443238450304779,0.05171954643546709,0.02671623822825845,0.04110994655826477,0.13605708161533944,-0.13073011225978087,0.21013248262097095,-0.10488410982453936,0.047136105586772545,-0.004269445317967397,0.10989414151741904,0.01483690095480331,-0.005887265963620086,0.03578663169721535,-0.0056874272220999505,-0.09669710153429709,-0.13266802779392758,0.0751091361465821,-0.017801637696399256,0.012496897293496331,0.034622453744613785,-0.07724811811287202,0.140662110723981,-0.06504142014782617,-0.0489528038912079,-0.008744740351151711,0.06932304715503997,-0.052634544291798924,-0.011280297214476535,0.03784456391265048,0.1288169835694093,-0.02871997142100284,0.016661532929055624,0.01573775540288355,0.12216260299407627,0.17364006706036597,-0.1169672260586474,-0.024758757959976896,-0.01878639808481639,-0.14516137188990702,-0.03533988479570271,-0.09642680829250562,0.034580332608552415,-0.20765715573852928,-0.1199201674450555,-0.08327637763085281,0.09545302096883286,0.012006938133066306,0.049754311210185254,0.02181534691404435,-0.04425370723583469,-0.03587411114994352,0.11964628197816776,-0.01468539024111455,0.1346057748932762,0.010055470593472456,-0.05538903029427983,0.00640654106445651,0.11784855765427585,-0.05495661876781937,0.02595733804445849,-0.030773215286703043,0.07886906963334946,0.005327938018561264,0.1019045492306508,0.05866923319692627,0.09544079579228962,-0.0462218856839633,0.12962232180137578,-0.11397137520604697,0.14364637543374983,-0.1056254251708249,0.003905572355433517,-0.0012778277768761494,0.05979235834446737,0.05719312836381484,0.002174934513235817,0.11150077734436342,0.09338412676989125,-0.009134404537882368,-0.07583842518997053,-0.10567478040460705,0.021104370348971172,-0.0016540483305383096,0.044216642612358685,-0.036784217021361906]	2026-01-02 03:00:34.471478	\N
30	293	LIC10000	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC100	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:33:10	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:33:10	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
31	294	LIC10001	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC101	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:33:10	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:33:10	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
10	230	326535	2028-01-01	2023-01-01	A2	documents/230/licencia_conduccion_1767317391.pdf	moto	RJFJFJ	URUEUE	32323	Dorado	DUJDJD	\N	\N	\N	\N	krnrnej	2026-04-30	documents/230/soat_1767317393.pdf	6262616	2026-04-30	documents/230/tecnomecanica_1767317394.jpg	926262	documents/230/tarjeta_propiedad_1767317396.jpg	0	pendiente	0.00	0	2026-01-02 01:29:51	2026-01-02 01:29:51	0	\N	\N	\N	0	en_revision	\N	2026-01-02 01:29:51	0.00	verificado	\N	pdf	pdf	imagen	imagen	imagen	[-0.0928838002336624,0.09725358669798277,0.0662549346071044,0.02983599691208251,-0.11184121797914413,0.20477839332519504,0.044400860132273734,0.21321741062593827,-0.14246749002095538,-0.11021483472946259,0.08283064364473659,-0.08481888373765989,0.10916967240182747,0.145188210993632,-0.008297861426567733,0.06365793937217444,0.12373257190329107,0.07182309809621025,-0.04738983988003161,-0.0015285360926713988,0.2313879712201425,-0.0619230939659845,0.010289285189911793,-0.0823997785185079,-0.05360766361058588,0.010110125307062531,-0.09242620229734308,0.02698558954253534,0.07017443746727396,0.007873346461819036,-0.13133394838946028,-0.01204832326424106,-0.07429871780783803,-0.0027288912653058058,0.23938853593971904,-0.025258362457503805,-0.17144865964585188,0.09762984059129198,0.0949053612787432,0.09176687636731999,-0.1204061722855526,0.16201520273206446,0.005226418715702687,-0.01838406689336551,0.004719860331139475,-0.0002039438789013073,-0.141144637736885,0.048317519319884566,0.04881893106708266,-0.04094684975594579,0.14106697499676674,0.006822548798763043,0.015453052664827585,-0.08437446424390971,-0.016318719632191503,0.16326784829267882,0.049504911859000494,-0.16530009371605459,-0.007799125420459491,-0.039218807766941234,0.12194466294272044,0.10769133559861299,-0.18641440761180572,-0.008304264244524786,0.06937401967947647,-0.23063826348645017,-0.06699397025169963,-0.13683418058655053,0.0994231315251363,-0.029590173870288602,0.06345722659681334,0.0782231345296774,-0.09243543133774235,-0.24898006534662045,-0.042278661355677864,-0.02375269733988848,0.08861211249708623,-0.002519789776161477,0.2601837092311147,-0.12161124489507835,0.004890137798268815,0.0802280136835325,0.09929493668843509,0.01349095808554281,-0.2061713271787045,-0.07832625225028544,-0.14462170028400756,-0.031013461920703318,-0.16127589008634363,0.02495807441506027,-0.12263617803963063,0.02944361470450961,-0.004196530221404918,0.09545500704175558,-0.018370513532294422,0.0945658053755346,0.007393659949130035,-0.03637361406582008,0.06796556448757449,0.04434333846166111,0.08789686087879285,-0.05257349823835662,0.19040075893149574,-0.016358424149070166,-0.10551099552856394,-0.09543287194223034,0.044328400845124086,0.02104884787467456,0.1599626816829922,-0.0458422353761391,-0.12072091499869775,0.019066366837446995,0.08511477092935345,0.02277017363549567,-0.03593044535959785,-0.19237455498041411,-0.2634341048928009,-0.12019412266521806,0.03987771639839418,-0.21225394009659465,0.08212599768374407,0.0415139312699678,0.02311175490306882,0.0981189763727,-0.07815041203723516,-0.03681482943968546,0.048367193946189733,-0.10785978486030373]	2026-01-02 01:29:58.713056	\N
8	226	53566265	2028-01-01	2023-01-01	A2	documents/226/licencia_conduccion_1767315114.pdf	moto	KRJRJJR	NRNEBEN	53626	Blanco	JDJDJJDJ	\N	\N	\N	\N	nfnfnen	2026-04-30	documents/226/soat_1767315115.pdf	3562626	2026-04-30	documents/226/tecnomecanica_1767315117.jpg	62626	documents/226/tarjeta_propiedad_1767315118.jpg	0	pendiente	0.00	0	2026-01-02 00:51:53	2026-01-02 00:51:54	0	\N	\N	\N	0	en_revision	\N	2026-01-02 00:51:53	0.00	verificado	\N	pdf	pdf	imagen	imagen	imagen	\N	\N	\N
9	229	232323	2028-01-01	2023-01-01	A2	documents/229/licencia_conduccion_1767317141.pdf	moto	JDNDJDJ	JEJEJ	32616	Blanco	EYHEJ	\N	\N	\N	\N	rkejje	2026-04-30	documents/229/soat_1767317142.pdf	61313313	2026-04-30	documents/229/tecnomecanica_1767317143.jpg	616166	documents/229/tarjeta_propiedad_1767317144.jpg	0	pendiente	0.00	0	2026-01-02 01:23:41	2026-01-02 01:25:41	0	\N	\N	\N	0	en_revision	\N	2026-01-02 01:23:41	0.00	verificado	\N	pdf	pdf	imagen	imagen	imagen	[-0.014154002112392908,0.13878557807251007,0.12114906065178616,-1.146990277783971e-5,-0.054372059889417734,-0.013036560998471112,-0.11013189809041396,-0.1014506580735102,0.07814676290138686,-0.002921558368388029,0.04397632357149718,0.1202801459940315,-0.023838811498149082,-0.004304123267855671,0.0538689684431653,0.11115673082325653,-0.11753100568113661,-0.1620427367571341,0.02234129779282041,-0.066358406774732,0.14228772674049273,-0.12454962943787325,-0.0226294126159212,-0.0507257865558256,-0.0911665647386725,-0.0807119262039186,0.07945817691991651,-0.06016276405632172,0.07010724266658351,0.04096924720038901,-0.025922368194851116,0.14024559601537,0.03432638518065596,-0.12111177655471067,-0.08585651856874754,-0.05634162909596229,0.06927655848862112,-0.06355789969097984,-0.030394639481324783,-0.003883191658608394,-0.09004121140799613,-0.05224167577908491,0.02684574305852709,-0.11290631458427863,0.12234198113303144,0.0852292604285185,0.022974942213156477,0.14979784693354828,0.06506674034130248,0.051627472939707576,0.019029196289090368,-0.017944179190202973,0.028176926479320342,-0.03448965553003597,0.04444089911253181,0.19956713592882172,0.11826681009228297,-0.050305523508501274,0.06761396821122669,0.009258874904252066,0.029500763888709522,0.12281578294278153,0.16727562009763963,-0.05960962898719803,-0.02498015283364656,0.058762606348458035,0.015439811134451146,0.04639800841122785,-0.037591575211750605,0.18532031855766185,0.1344080793555887,0.11172573095942416,-0.1355311370340216,0.07535012438960854,0.19921570150497608,-0.07757804047940987,-0.014861887095180274,-0.09368833708245838,0.0667365103786024,0.057313224450412474,0.04929075959501025,0.13855167393121337,0.047939285905550306,-0.0952215247881514,-0.07957156387404823,0.012390171601571775,-0.09964943839628171,-0.010635870550328856,0.09633694681793989,-0.17390790455206337,-0.07722386202991238,-0.026738346839337547,-0.10493305044415124,-0.11638189870592391,-0.08178835599876377,-0.03976030988442432,0.033122981717242185,-0.06676403027227515,-0.029236296913857058,-0.11362446748779187,0.0023708727220440456,-0.11387948176984813,0.03252542976399429,0.019093520339560785,-0.09579135838829962,-0.012589325071290661,0.004548893415308443,-0.08372866912045895,-0.038374750095038726,0.08324006369510117,0.03623051497641402,-0.02774878472840918,-0.1276136849197387,-0.1418081652297384,-0.23125737598261834,-0.04503818924431019,-0.05452415713961614,-0.07455634778050231,0.12324856761701292,0.1363750403623348,-0.1119920826543786,-0.23438195738689524,0.06467523027016267,-0.11974010671481908,0.1956615149342431,0.09687336589529508,-0.052035024780524755,0.16280484545114518]	2026-01-02 01:25:47.515255	\N
7	6	6532626	2028-01-01	2023-01-01	A2	documents/6/licencia_conduccion_1767300416.jpg	moto	FLLRLRL	KRKRKKR	236262	Beige	KGKRKRK	\N	\N	\N	\N	kriirir	2026-04-30	documents/6/soat_1767300418.jpg	656262662	2026-04-30	documents/6/tecnomecanica_1767300419.jpg	6262323233	documents/6/tarjeta_propiedad_1767300421.jpg	0	pendiente	0.00	0	2026-01-01 20:46:56	2026-01-01 20:46:56	0	\N	\N	\N	0	en_revision	\N	2026-01-01 20:46:56	0.00	verificado	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
14	234	65662	2028-01-01	2023-01-01	A2	documents/234/licencia_conduccion_1767488583.pdf	moto	JJDJ	FUURUR	2020	Blanco	FKFKJF	\N	\N	\N	\N	kfkfjrj	2026-04-30	documents/234/soat_1767488584.jpg	6562626	2026-04-30	documents/234/tecnomecanica_1767488585.pdf	9592962	documents/234/tarjeta_propiedad_1767488587.jpg	0	pendiente	0.00	0	2026-01-04 01:03:02	2026-01-04 01:03:03	0	\N	\N	\N	0	en_revision	\N	2026-01-04 01:03:02	0.00	verificado	vehicle/234_1767488582.jpg	imagen	imagen	imagen	imagen	imagen	[-0.010752628735122394,0.15488318885208852,0.12000132646194646,-0.1541489917068979,0.012290385649119445,0.06581765036081777,0.06734024045391067,0.11187677238341186,-0.023095687405169534,0.021458730628447286,0.014518646640446676,-0.0689775510270663,0.039816248855482926,-0.1382205949103448,0.08320348542747635,0.20616374353169215,0.19024795233527977,-0.12454548632447093,0.05753429284301325,-0.022261071835100104,0.09002614269001424,0.08591056214375754,0.1132650660233544,-0.23939162477171794,-0.17902758026035295,-0.13675851297945843,-0.16002647636740053,-0.0009019594182845044,-0.011236596741708056,-0.10004266603938905,0.07706936494764652,0.050480393341653496,-0.24407750660459746,0.14587236085857266,0.05390410703615988,-0.0008463250557250599,0.07567586592133771,0.015799670048255263,-0.006871713039388813,-0.02132325175166923,0.09256697893930971,0.10336525431726012,0.24703204764394648,-0.08441260170989803,0.08803500151966902,-0.2293186216161991,-0.08521324956454211,0.01913540766864935,0.11163259083407423,-0.17417540937631049,0.09861592715052854,0.0012624237785443598,-0.05494552366767241,-0.047289521210046224,-0.2140169384238942,0.044565860217745557,0.09144577888325096,0.014843763764854905,0.09643905191551376,-0.06971387916527595,-0.09236423860689691,-0.08881819171211947,0.09072951076077476,-0.05750539996258139,-0.07569212627007842,-0.06440841476177707,-0.04077628397736643,0.1338243476231618,0.1618111871117266,0.11376200258178636,-0.07193379189002942,0.08048776477939903,0.11229504007746471,0.09450725330421866,0.08162173380815409,-0.049245246690005795,-0.06873240857631294,-0.11637715196586339,0.017222843142399306,0.12846111050895623,-0.06072316778098862,0.2118842465524906,0.0048911776922060625,0.03023800462676264,-0.1603147726880508,0.08825272643090648,0.08935204806579672,-0.02424256437147777,-0.04336588618327283,-0.06345377164567802,0.1220206071937414,0.15954404984362516,-0.12950224819141756,-0.15651577810084016,-0.03860828488534778,-0.05068644420960984,0.18530336740945644,-0.029496889148479963,-0.10600129906781047,0.0934906660849974,-0.06768721797304966,-0.08365398070554139,0.04024409336375002,-0.024651212041868223,0.04441516436859095,-0.06776592257113451,-0.02657164832436994,0.06339209501293518,0.05923278759438079,0.03549253574821185,-0.2203772707421522,0.16992678794023636,0.17277463898025786,-0.15008898800766932,-0.0076040483928646666,0.11762976321542934,-0.10905352462691387,-0.016676136197457232,0.08317988539213392,-0.09382503832609215,0.07715025052297264,0.11820463016828736,0.1488858603516749,-0.021124320120935496,0.21910865773687005,0.005991704334232829,0.22772134604063457,0.05900803721726691]	2026-01-04 01:03:09.649303	\N
13	233	65659	2028-01-01	2023-01-01	A2	documents/233/licencia_conduccion_1767323815.jpg	moto	JEJNFND	FJJDJE	65656	Blanco	JRNNFJF	\N	\N	\N	\N	irkfkf	2026-04-30	documents/233/soat_1767323816.pdf	6565626	2026-04-30	documents/233/tecnomecanica_1767323817.jpg	266262	documents/233/tarjeta_propiedad_1767323818.jpg	0	pendiente	0.00	0	2026-01-02 03:16:54	2026-01-02 03:16:55	0	\N	\N	\N	0	en_revision	\N	2026-01-02 03:16:54	0.00	verificado	vehicle/233_1767323814.jpg	imagen	imagen	imagen	imagen	imagen	[-0.016588675080919168,0.09923995161211742,0.006923094478129281,-0.024923124336983973,-0.02865273047264208,0.05942041385706173,0.04018104807054203,-0.12279943814767952,0.08126736576989552,-0.1237890774737831,-0.04234394464357635,-0.12166788703317231,-0.2058046347560615,-0.06375418920070157,0.07366458175537548,0.043642478435247135,-0.13718626658526373,0.08963245986562955,-0.18595888261977467,-0.08034406375369174,-0.08318878356382962,0.029595944654660308,0.02345417316370224,0.023584036252565495,-0.013961658976299036,-0.015344483976620808,-0.08084464659085736,0.037811465040469026,-0.10746763372863632,0.021339489314782495,0.006658469391720313,-0.21441786170809507,-0.023148448700789807,-0.018293756024907765,0.05141554689172401,0.07965796871860295,0.05661881349317743,0.14771496441204837,0.18364583635406365,0.08355597435998617,0.18110055125843638,-0.03434896881513844,0.1060073753080268,0.040827513496615446,-0.10387279744793232,0.08154996341141227,0.09933284321444219,-0.06565783906835351,0.19064664158258723,-0.03382026697765294,-0.047826319050463494,-0.09157188440935532,0.14368191562598406,0.01260588113761804,0.13888148207021192,0.01097230030032956,0.011552515619975116,0.01866943399166373,0.18563349382038588,-0.12220910230771609,0.09880038772065666,-0.09514976172467585,0.16816028603520713,0.0715255922434442,0.05819647046783588,0.13060486122894155,0.08848916116029815,0.1617945995776548,-0.06562780938981548,0.0023590439002961223,0.023276775963036202,-0.016068896774387782,0.11697483175987347,-0.10616954816805634,-0.0445647030070867,0.13485820769912427,0.0008394709131292126,-0.011223664412005015,-0.15491639886933095,-0.009013633651131501,0.00541838784572613,-0.10205932492093105,0.09046345620460894,-0.0028727623690147346,0.0789018784825456,-0.07537138979795154,0.03863346404000415,-0.13101330626223057,0.1197373926993302,-0.02830062791123887,0.028309616656422773,0.12727520256808897,-0.05029156118827051,0.007549923333345267,0.044378520298070316,-0.12690059470848347,-0.15193923016321786,-0.06714268122952279,0.005541955698090688,0.018092957292315484,-0.06837539202196831,-0.02635420433017953,0.18457176218102603,0.010363208220432768,0.10093053137579958,0.01897967131981071,0.04751187993296957,0.0073877149798510485,0.06528550048379238,0.04003684775645072,-0.03857386436946783,-0.09101918954348162,-0.09661958111195686,-0.08627776630548971,0.06797119472539286,0.0531448113505849,0.10999899579889849,0.06945624046101936,0.05345324144443064,0.019885060841251318,0.004135301488281082,0.0711052793564994,0.033212499946152836,0.04881556614135138,0.05204736546713571,0.15132805672205582,-0.13202258077700899,0.031028638263126018]	2026-01-02 03:17:01.298993	\N
12	232	265656	2028-01-01	2023-01-01	A2	documents/232/licencia_conduccion_1767323347.jpg	moto	RNFNDN	RKFIKD	65653	Blanco	UBDJD	\N	\N	\N	\N	ridkd	2026-04-30	documents/232/soat_1767323349.jpg	326656	2026-04-30	documents/232/tecnomecanica_1767323350.pdf	326262	documents/232/tarjeta_propiedad_1767323352.jpg	0	rechazado	0.00	0	2026-01-02 03:09:07	2026-01-02 23:17:35	0	\N	\N	\N	0	rechazado	2026-01-02 23:17:35	2026-01-02 03:09:07	0.00	verificado	\N	imagen	imagen	imagen	imagen	imagen	[0.11805780160971013,-0.11389751637974244,-0.1044039933593143,0.28917767459859545,0.1740117541591018,0.07487427447443243,0.09034230440225577,0.019367138162584487,0.022349326004863213,-0.14355770939353543,-0.07124092671557922,0.1298399750742221,0.15327411164080737,0.044523055263113835,-0.08451649224656814,0.055699307199017105,0.04693858916751194,0.14866937069758454,-0.05883511968587584,-0.0007197192044541553,0.05419567364916024,-0.09766679532074396,0.040293565404195604,0.10424029222553935,0.09385161418008041,-0.12216269143337782,0.002480915507053486,0.1465426405362474,-0.10347640131430419,-0.18838323306414495,-0.17772685194259227,0.0486252388778347,0.027270297204250244,0.13061262276318805,0.005670535057284979,0.05109929113028742,0.0369328417303429,-0.02597028922927877,-0.05544025536347938,-0.055878272584521084,-0.13322546109554154,0.06773462699130947,0.028541407407487025,0.08034668442171557,-0.16173404762589763,0.05585554999926581,-0.023672737795324764,-0.035687567462664764,-0.05966846555622138,0.20949875528571052,0.11313141770718052,0.06750878256307695,-0.10414899593793042,0.05122986751648239,0.04231323118302919,0.026664598942706265,0.02032272954534209,-0.08725699022244643,0.02633888739270489,0.02274595942783325,0.04035714805717886,0.16288361873788396,0.007825190266329059,-0.028134642194193156,-0.025106884020261955,0.07786785321648783,0.038090994536746886,0.11962747760218631,-0.08728441737730891,0.014742570456485433,0.00412469775069923,-0.17159359226105803,-0.01839990036214424,0.027208728055063903,0.12678638013779103,-0.06451763403726712,0.018767090270462642,0.09836804795477722,0.04970246587489202,-0.06256230331139406,-0.01118226819162722,-0.05895691704893361,-0.06809661412590139,-0.0016570710570436567,0.10269086176237552,0.2523106952828272,-0.0591826379206045,0.03667821225674368,-0.1800917934626397,0.05822425940795406,0.07134996108582899,-0.08964698109472252,0.050001316154393384,0.0822911469790118,-0.015059063053316746,0.13885156436181126,0.13543871424515277,0.02849644603955445,0.003909004721517207,0.1084640459945919,-0.051037495167388716,-0.2579686593909661,0.04232053168947633,-0.0016818412171365777,0.04242884151529865,-0.1648895653250417,0.014208121330235588,-0.1620920331055747,-0.044972658108470884,-0.061757852203220165,-0.11901379812876896,-0.06451511271887804,0.1808006420627034,-0.04658579311771391,0.08937246760953035,0.0787701395617885,-0.05433227043901952,0.005554848459876812,-0.08952445506772458,-0.09432149014354096,-0.07221122922712474,0.11834152823860129,-0.09140184339298843,-0.1560457291462889,0.006237804158945968,-0.1962086456725296,0.04317948054184414,-0.04583888469392261]	2026-01-02 03:09:14.561879	\N
20	277	65564646	2028-01-01	2023-01-01	A2	documents/277/licencia_conduccion_1768322945.jpg	moto	FERRARI	VOLCAN11	2020	Negro	HDDHDU	\N	\N	\N	\N	jddjdjjjdd	2026-02-28	documents/277/soat_1768322946.jpg	34343	2026-04-30	documents/277/tecnomecanica_1768322947.jpg	65656645	documents/277/tarjeta_propiedad_1768322948.jpg	1	aprobado	4.87	15	2026-01-13 16:49:03	2026-01-14 22:43:48	1	6.25373000	-75.53883670	2026-01-21 01:38:49	35	aprobado	2026-01-13 20:48:12	2026-01-13 16:49:03	262296.76	verificado	vehicle/277_1768322944.jpg	imagen	imagen	imagen	imagen	imagen	[-0.02198266636817153,0.08118854439106869,-0.15134703669439734,0.09400863493486929,0.1430922866040471,-0.10769984928838956,0.2532615964559309,0.006454133603568187,-0.05963281054568396,0.13033529184109824,-0.17059385697477214,0.06258115683244449,0.08843000849485341,-0.11286166062853885,-0.036042190552170214,0.0680902380865547,0.1418954508464828,-0.2848853932835627,0.02634503142717344,0.005799642140664835,-0.21373742784493227,0.08952500597659185,-0.11642419018415336,0.12341300721318425,-0.09209776228555473,-0.03765305889052175,0.05925028409029159,-0.06778579451920462,0.048158269483613896,0.21234609527139595,0.07432419112437506,-0.2039775785132934,-0.07930836186899588,0.020992036370863484,-0.189597679522125,0.0012616195733990622,-0.023259334000801213,0.11694855907245466,-0.0259067181524517,0.13862078691093224,-0.031996498059407165,-0.06669367722882429,-0.0016231349902908476,0.07802691621336023,-0.01372937506200167,0.07614873907582027,0.13698042507703842,-0.04385676549284473,-0.053166980385005475,-0.005149956177844757,0.09581979880441256,0.006075493966404885,0.0037821960084418733,-0.011259255508114328,0.10520638600354398,-0.002433192710948574,0.16282834554971806,0.1037574027680318,0.03657130801175542,-0.09557571140238613,0.05273103206439499,-0.057142851557288155,0.014307818102591595,-0.08320638014218074,-0.11029828080862612,-0.03715329376239424,-0.015733164308572297,-0.08368091203928407,-0.21390279469749685,-0.06417938504525808,0.15593142553135128,0.007901315127039888,-0.03800845692093727,-0.07230604943459125,-0.08796046913574523,-0.1395405476348696,-0.042387122202096,0.25308718355428084,0.04975147712622939,-0.049625096157900055,0.1148979410668221,-0.1912101297237323,0.0680880957953568,-0.11344283242605735,-0.09798674684274307,0.087694557148006,0.03295511715289056,0.10691257025978183,-0.03023187205037363,-0.10937847257553378,0.08657365466263062,-0.022097298178281065,-0.1074216279247453,-0.03381857096788278,-0.16069527092085048,-0.10107678517480197,0.050611557571712186,-0.16542083931461846,-0.0619488319589121,-0.1106126829452438,0.08064075848079333,-0.12055090824880972,0.07026001902275412,-0.016932005187664655,0.041943836740266,0.10456002613193556,-0.14573089007921075,0.05419790901820698,0.09838042421943566,-0.035019862654241,-0.04860770383498092,0.02063709826372452,-0.03039991268754351,-0.15674899905998005,0.12498571759874642,-0.16184763432026728,-0.022354009029222337,0.0640674753787169,0.08229415538281465,-0.17525525283276536,0.05721913680611791,-0.021397909529529607,0.015339747494722708,-0.02704050795590391,0.14542137270446553,-0.024735401880913235,0.03998275079670499,0.023739270407349033]	2026-01-13 16:49:11.177031	\N
18	5	PENDIENTE	2030-01-01	\N	C1	\N	auto	\N	\N	\N	\N	PENDIENTE	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	0.00	0	2026-01-04 17:45:27	2026-01-04 17:45:27	0	\N	\N	\N	0	rechazado	2026-01-04 17:45:27	2026-01-04 17:45:27	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	w
19	11	PENDIENTE	2030-01-01	\N	C1	\N	auto	\N	\N	\N	\N	PENDIENTE	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	0.00	0	2026-01-04 17:56:32	2026-01-04 17:56:32	0	\N	\N	\N	0	aprobado	2026-01-04 17:56:32	2026-01-04 17:56:32	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
15	235	265665	2028-01-01	2023-01-01	A2	documents/235/licencia_conduccion_1767495096.pdf	moto	JDJDJ	EHEJ	2020	Blanco	GDHHDH	\N	\N	\N	\N	rufjjf	2026-04-30	documents/235/soat_1767495097.jpg	6562632	2026-04-30	documents/235/tecnomecanica_1767495099.jpg	65656	documents/235/tarjeta_propiedad_1767495100.jpg	0	pendiente	0.00	0	2026-01-04 02:51:35	2026-01-04 17:58:56	0	\N	\N	\N	0	aprobado	2026-01-04 17:58:56	2026-01-04 02:51:35	0.00	verificado	vehicle/235_1767495094.jpg	imagen	imagen	imagen	imagen	imagen	[0.10712268379144835,-0.12813128744547242,-0.1515694798710023,0.0560848253925513,-0.20460121647040852,-0.05154047135669626,-0.10681627429275908,-0.15839945694042837,-0.058944630261466874,-0.21564334582921224,-0.03693879524274278,-0.04891054600053267,0.06076358100077905,0.04163567861208249,0.21697704287013253,0.12848009426358237,-0.055685114392792945,-0.04315841591409123,0.12025309392345612,0.08677381497925689,0.011072914643354836,-0.06817737434900413,0.12411886710280495,-0.043760914147058114,-0.04549563624148264,0.06457622728080133,-0.10393121791309326,-0.014582509106188642,0.08579349028413367,-0.06335843255941782,0.17769395137244448,-0.05906646945875141,-0.08695530941226746,-0.18515236549084568,-0.039873317369713196,0.0723447011486767,-0.0012275221352925803,-0.0980514942927531,0.07067345192956287,0.036808951648656385,-0.14134235798967806,-0.15859591490126682,0.03551941868534899,0.13635107710988567,-0.07681660491229816,-0.0013386531152784242,-0.0073200586661886745,0.009771078186152533,0.045701364263334626,0.1261268566910709,-0.02060283343781147,0.010382517693263517,0.2349803740938218,-0.09033730051473338,-0.08027273003836186,0.16497791076995824,0.05899405941156724,-0.0082357924576219,0.0021705907951377374,0.10653040504048286,-0.04460227021504559,0.005993277353304076,0.17303090749452163,0.0008412234787578745,0.11985685664263279,0.06258320641719227,-0.09519732792427764,-0.06505177159863616,0.009620695192118889,0.10616518268397963,-0.13203818830635966,0.14929188350760822,-0.0478686185130802,0.05214075383002127,-0.11592631308076085,-0.05877511896381715,0.1013777530881975,0.05680464627936635,0.061367719602792886,0.13858586209919588,0.051004907562212966,0.034555634215054254,0.07693931418301657,0.030668355192639954,0.04007018406531962,0.1179461446027841,-0.06786603680805497,-0.035370134871729894,-0.13661223958866084,0.06111465918747821,-0.321291802586909,0.09061192748143608,-0.16496344741950203,0.04032612701563909,0.13180152194034886,-0.001472068482878503,0.03907458658164641,0.1301175359410745,0.08703214268945472,-0.09771973024535131,-0.12405765572408048,0.07476951133643983,-0.044019540463488604,-0.015126171610006964,-0.032862258296019124,0.12992175482653504,0.0972521911061727,-0.18897128273725775,-0.13058459040201595,0.11304442583581585,0.010691078283745478,0.017695127025521586,-0.05690824169126096,-0.06537582745498416,0.08608468137750808,0.0032174662659955645,-0.04541626095712019,0.0372435717796494,-0.0061304010952890065,-0.13603309334173047,0.09221728509815805,0.09662355395814401,-0.07613932141181701,0.22132366263771389,0.055613727671965096,0.12885183560480906,0.003762468044567579,-0.1791516646250979]	2026-01-04 02:51:42.974727	\N
32	295	LIC10002	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC102	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:33:10	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:33:10	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
33	296	LIC10003	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC103	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:33:10	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:33:10	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
34	297	LIC10004	2030-01-01	\N	C1	\N	moto	Honda	CBR	2022	Negro	ABC104	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	pendiente	4.50	0	2026-01-14 02:33:10	\N	1	6.25180000	-75.56360000	\N	0	aprobado	\N	2026-01-14 02:33:10	0.00	pendiente	\N	imagen	imagen	imagen	imagen	imagen	\N	\N	\N
21	278	656565	2028-01-01	2023-01-01	A2	documents/278/licencia_conduccion_1768341439.jpg	carro	TOYOTA	ARC	2020	Gris	YSG62	\N	\N	\N	\N	idudud	2026-04-30	documents/278/soat_1768341441.jpg	322332	2026-04-30	documents/278/tecnomecanica_1768341443.jpg	65626	documents/278/tarjeta_propiedad_1768341444.jpg	1	aprobado	0.00	0	2026-01-13 21:57:18	2026-01-14 13:20:11	0	\N	\N	\N	0	aprobado	2026-01-14 13:20:11	2026-01-13 21:57:18	0.00	verificado	vehicle/278_1768341438.jpg	imagen	imagen	imagen	imagen	imagen	[0.013496991220026459,0.0003691826954359571,0.12723640626547167,-0.06646423216825295,0.17162936046545374,-0.11583092801141813,-0.0313201724182808,0.029371941711836505,0.012702743478872406,0.13666815125618906,0.02854130182460948,-0.02348420155306132,-0.07410541548775011,-0.1074070292967619,0.03159993963061094,0.14235511593625935,0.09263169922546616,0.01611697043694708,0.08376802337170298,0.05399919742507586,-0.1344897099512454,0.027113601652897307,-0.07189866375628222,-0.001230738512182774,0.046480994858089875,-0.09116895204360112,0.08692467039767063,0.15323017215590717,0.018925053377091876,-0.11193909640756697,-0.20220606638917826,0.0927836849664262,0.07864523065657851,0.07437217387969514,-0.08988215281108602,0.02757650903975416,-0.011930719024862712,-0.15043069352921454,-0.022886596088447998,-0.023413393127788316,-0.008810106194883148,-0.02965860361287479,-0.06646980151997016,0.11325465418850891,0.006409988142575725,-0.08738080629600972,0.004060409676210863,0.10271362248706967,-0.16734842255066507,0.1513827616739158,-0.019215040711795424,0.12918329910383058,-0.058205746558930765,0.028043610679380306,0.01531320959960521,0.07503136754731987,0.1301188743524904,0.03893824449019445,0.11112298529688797,-0.05026287591555333,-0.016929279902278837,-0.025720820509507122,0.03510710919838819,-0.0760768015828374,-0.037491051300873796,0.1854203417268378,-0.17639820864160463,0.18983866419590723,-0.018112458242750356,0.04683218356397921,-0.008386544371861154,0.09760948826362402,0.039531509939876475,-0.09597762783817224,0.009689636928565006,0.12002967033367562,0.010836211058402063,-0.027668841507048198,0.0986186940512075,0.0524424963078639,0.12946877206620958,-0.13800723890238475,-0.07452555642365644,0.09660169779318034,-0.06761738066481823,0.09946092089411304,0.060131776771436864,0.12084325197212907,-0.11347231068415531,0.042203097317351196,-0.04427922389567878,-0.04612225777353454,0.005356420843796671,-0.0183295413331605,-0.19581646343864204,-0.08622716254830545,-0.07074599606293205,0.17330217667584866,0.09301486894774091,-0.12399839529519766,-0.14571062628387615,0.06352042110437943,-0.07018538474581201,-0.06082881227800994,0.2092193572557192,0.07711687958654184,-0.030327971180480896,-0.2712844322518748,0.1922670085105339,-0.11432272742595678,-0.2075386766909055,-0.009037691516832733,0.14560135547866623,-0.08985061644376346,0.09587003548928512,0.015379183886086181,0.002127472182048483,0.010996086203567255,0.16214357190218837,-0.12905014867770284,0.20058030132314292,0.08096565978120243,-0.12000614871361404,-0.044090352185796794,-1.3158848941428233e-5,-0.13307247902883015,-0.06574194657821804,-0.14883816611440853]	2026-01-14 00:47:32.793369	\N
35	298	62662	2028-01-01	2023-01-01	A2	documents/298/licencia_conduccion_1768879665.jpg	motocarro	BIRD	UDUD	53343	Dorado	YHDJD	\N	\N	\N	\N	uwuu	2026-04-30	documents/298/soat_1768879666.jpg	65646	2026-04-30	documents/298/tecnomecanica_1768879667.jpg	3533131	documents/298/tarjeta_propiedad_1768879669.jpg	1	aprobado	0.00	0	2026-01-20 03:27:43	2026-01-20 03:29:49	0	\N	\N	\N	0	aprobado	2026-01-20 03:29:49	2026-01-20 03:27:43	0.00	verificado	vehicle/298_1768879663.jpg	imagen	imagen	imagen	imagen	imagen	[0.0402664842969667,-0.007697903896773913,0.10296417073298476,0.10142600340521685,-0.1746710532837769,-0.11103746726431546,-0.044700280158779415,0.11206853181786998,-0.01267606640363345,0.13541611935446926,-0.012380148221099736,0.055333743723015395,0.08779321315562842,0.05490900546967249,0.06124352527707227,-0.05817224675739339,-0.09831211137174094,0.12822823250921292,-0.03940988824166658,0.02592245120965607,-0.02436708982299868,-0.030347394017548962,0.19219022809835815,-0.06177419466162394,0.017695505331672842,-0.012840438831521837,-0.014602759146575987,0.04475399173098901,0.05437380272685016,-0.14132243784607815,0.05227106125049256,-0.018047484690424827,-0.017829145625584564,0.11170604197516748,0.16810692580578315,0.08018848326161343,-0.04012976823153135,-0.0416420731054175,0.04534212190733766,-0.036090029143631956,-0.23435107068462158,-0.07488803592502045,0.11135763438615083,-0.12277128986634733,0.17354626009173804,0.03340518757395229,-0.09654408221859859,-0.030400145782848033,-0.2241147363369661,-0.009124354719341839,0.14380159685632143,0.16224046884859433,0.02777659070023943,-0.01109059410194933,0.08384536079986274,-0.03878572200542277,-0.11378981816223624,-0.08745156700929917,0.06145402830363344,0.11030621012875674,0.14376370045047185,-0.029626509448280783,-0.04375682531059833,0.05438616163414426,-0.1011981748183962,-0.16652562158684608,-0.00995593689745506,0.16714693880977172,-0.12053038190929324,0.14532862963136328,0.04906241958525215,-0.0038886437646200654,-0.0009976335177603723,-0.08146625885139297,-0.0347611382434687,0.07781332921688587,0.0771787642872929,0.18743036194067697,0.13336917724806788,-0.08193967456721175,-0.09822055937916148,0.12683215385038377,0.005705546917198029,-0.016445253375068632,0.08188506763834813,-0.06757647001704249,0.22354395679570552,0.02462058649408541,-0.21421061240413963,-0.11709131528857045,0.14269372992189955,-0.00370665609938238,0.05995897140772232,-0.023862374435628532,-0.09853715439990218,-0.030463444857448087,0.13682013143045155,-0.006797560617915037,0.06819725461607304,-0.17099239580807407,-0.015610961204025997,0.06297846560513512,-0.11296227926273317,0.04371000294816348,0.031478054132626825,0.10055868352645336,0.006854310751447809,0.15624080033502744,0.01735930001832333,-0.044194246829370884,0.10330080302180662,0.05090297024374274,0.04814795764846733,-0.09728512976728076,-0.0388388886510088,0.19695346707375277,0.12630256039139728,-0.03848103774855457,0.03226263009043714,0.08117620141838362,0.2474934781643416,-0.02620925096238759,0.0412825528886327,0.0357974598859358,0.17283008952384105,0.03631758130122484,0.04327170658185946,-0.18277557324641328]	2026-01-20 03:27:51.825371	\N
\.


--
-- TOC entry 6068 (class 0 OID 16627)
-- Dependencies: 224
-- Data for Name: detalles_paquete; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalles_paquete (id, solicitud_id, tipo_paquete, descripcion_paquete, valor_estimado, peso, largo, ancho, alto, requiere_firma, seguro_solicitado, creado_en) FROM stdin;
\.


--
-- TOC entry 6069 (class 0 OID 16643)
-- Dependencies: 225
-- Data for Name: detalles_viaje; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalles_viaje (id, solicitud_id, numero_pasajeros, opciones_viaje, tarifa_estimada, creado_en) FROM stdin;
\.


--
-- TOC entry 6106 (class 0 OID 17282)
-- Dependencies: 264
-- Data for Name: disputas_pago; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.disputas_pago (id, solicitud_id, cliente_id, conductor_id, cliente_confirma_pago, conductor_confirma_recibo, estado, resuelto_por, resolucion_notas, creado_en, actualizado_en, resuelto_en) FROM stdin;
1	649	2	7	t	f	pendiente	\N	\N	2025-12-22 00:31:00.248662	2025-12-22 00:31:00.248662	\N
2	650	3	7	t	f	pendiente	\N	\N	2025-12-22 00:45:30.280047	2025-12-22 00:45:30.280047	\N
5	653	8	7	t	t	resuelta_conductor	\N	\N	2025-12-22 01:31:02.577894	2025-12-22 01:31:02.577894	2025-12-22 22:53:45.819024
\.


--
-- TOC entry 6070 (class 0 OID 16653)
-- Dependencies: 226
-- Data for Name: documentos_conductor_historial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.documentos_conductor_historial (id, conductor_id, tipo_documento, url_documento, fecha_carga, activo, reemplazado_en, asignado_empresa_id, verificado_por_admin, tipo_archivo, nombre_archivo_original, tamanio_archivo) FROM stdin;
1	7	licencia	uploads/documentos/conductor_7/licencia_1761492375_1a4c4887f68f6988.jpg	2025-10-26 15:26:15	1	\N	\N	f	imagen	\N	\N
2	7	soat	uploads/documentos/conductor_7/soat_1761492819_87a1e30ab2e6b43c.jpg	2025-10-26 15:33:39	1	\N	\N	f	imagen	\N	\N
3	7	tecnomecanica	uploads/documentos/conductor_7/tecnomecanica_1761492819_a331dc0207ae3a9d.jpg	2025-10-26 15:33:39	1	\N	\N	f	imagen	\N	\N
4	7	tarjeta_propiedad	uploads/documentos/conductor_7/tarjeta_propiedad_1761492820_ad1097b64c039a5d.jpg	2025-10-26 15:33:40	1	\N	\N	f	imagen	\N	\N
\.


--
-- TOC entry 6113 (class 0 OID 33640)
-- Dependencies: 271
-- Data for Name: documentos_verificacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.documentos_verificacion (id, conductor_id, tipo_documento, ruta_archivo, estado, comentario_rechazo, fecha_subida, fecha_verificacion) FROM stdin;
1	226	soat	uploads/conductores/226/soat/1766700884_5168.jpg	pendiente	\N	2025-12-25 22:14:44.875663	\N
2	226	tecnomecanica	uploads/conductores/226/tecnomecanica/1766700885_4697.jpg	pendiente	\N	2025-12-25 22:14:45.142297	\N
3	226	tarjeta_propiedad	uploads/conductores/226/tarjeta_propiedad/1766700885_2472.jpg	pendiente	\N	2025-12-25 22:14:45.464825	\N
60	6	licencia_conduccion	documents/6/licencia_conduccion_1767300416.jpg	pendiente	\N	2026-01-01 20:46:57.95942	\N
61	6	soat	documents/6/soat_1767300418.jpg	pendiente	\N	2026-01-01 20:46:59.51924	\N
62	6	tecnomecanica	documents/6/tecnomecanica_1767300419.jpg	pendiente	\N	2026-01-01 20:47:00.885286	\N
63	6	tarjeta_propiedad	documents/6/tarjeta_propiedad_1767300421.jpg	pendiente	\N	2026-01-01 20:47:02.382324	\N
64	226	licencia_conduccion	documents/226/licencia_conduccion_1767315114.pdf	pendiente	\N	2026-01-02 00:51:55.714749	\N
65	226	soat	documents/226/soat_1767315115.pdf	pendiente	\N	2026-01-02 00:51:56.943295	\N
66	226	tecnomecanica	documents/226/tecnomecanica_1767315117.jpg	pendiente	\N	2026-01-02 00:51:58.262048	\N
67	226	tarjeta_propiedad	documents/226/tarjeta_propiedad_1767315118.jpg	pendiente	\N	2026-01-02 00:51:59.493193	\N
68	229	licencia_conduccion	documents/229/licencia_conduccion_1767317021.pdf	pendiente	\N	2026-01-02 01:23:43.27468	\N
69	229	soat	documents/229/soat_1767317023.pdf	pendiente	\N	2026-01-02 01:23:44.894039	\N
70	229	tecnomecanica	documents/229/tecnomecanica_1767317025.jpg	pendiente	\N	2026-01-02 01:23:46.154204	\N
71	229	tarjeta_propiedad	documents/229/tarjeta_propiedad_1767317026.jpg	pendiente	\N	2026-01-02 01:23:47.29	\N
72	229	licencia_conduccion	documents/229/licencia_conduccion_1767317076.pdf	pendiente	\N	2026-01-02 01:24:37.298408	\N
73	229	soat	documents/229/soat_1767317077.pdf	pendiente	\N	2026-01-02 01:24:38.844149	\N
74	229	tecnomecanica	documents/229/tecnomecanica_1767317078.jpg	pendiente	\N	2026-01-02 01:24:39.697051	\N
75	229	tarjeta_propiedad	documents/229/tarjeta_propiedad_1767317079.jpg	pendiente	\N	2026-01-02 01:24:40.949314	\N
76	229	licencia_conduccion	documents/229/licencia_conduccion_1767317141.pdf	pendiente	\N	2026-01-02 01:25:42.684297	\N
77	229	soat	documents/229/soat_1767317142.pdf	pendiente	\N	2026-01-02 01:25:43.709621	\N
78	229	tecnomecanica	documents/229/tecnomecanica_1767317143.jpg	pendiente	\N	2026-01-02 01:25:44.586363	\N
79	229	tarjeta_propiedad	documents/229/tarjeta_propiedad_1767317144.jpg	pendiente	\N	2026-01-02 01:25:45.875782	\N
80	230	licencia_conduccion	documents/230/licencia_conduccion_1767317391.pdf	pendiente	\N	2026-01-02 01:29:53.251108	\N
81	230	soat	documents/230/soat_1767317393.pdf	pendiente	\N	2026-01-02 01:29:54.515734	\N
82	230	tecnomecanica	documents/230/tecnomecanica_1767317394.jpg	pendiente	\N	2026-01-02 01:29:55.876835	\N
83	230	tarjeta_propiedad	documents/230/tarjeta_propiedad_1767317396.jpg	pendiente	\N	2026-01-02 01:29:57.190253	\N
84	231	licencia_conduccion	documents/231/licencia_conduccion_1767322829.jpg	pendiente	\N	2026-01-02 03:00:30.429427	\N
85	231	soat	documents/231/soat_1767322830.jpg	pendiente	\N	2026-01-02 03:00:31.318813	\N
86	231	tecnomecanica	documents/231/tecnomecanica_1767322831.pdf	pendiente	\N	2026-01-02 03:00:32.167665	\N
87	231	tarjeta_propiedad	documents/231/tarjeta_propiedad_1767322832.jpg	pendiente	\N	2026-01-02 03:00:33.040069	\N
88	232	licencia_conduccion	documents/232/licencia_conduccion_1767323347.jpg	pendiente	\N	2026-01-02 03:09:09.039171	\N
89	232	soat	documents/232/soat_1767323349.jpg	pendiente	\N	2026-01-02 03:09:10.575542	\N
90	232	tecnomecanica	documents/232/tecnomecanica_1767323350.pdf	pendiente	\N	2026-01-02 03:09:12.103993	\N
91	232	tarjeta_propiedad	documents/232/tarjeta_propiedad_1767323352.jpg	pendiente	\N	2026-01-02 03:09:13.134592	\N
92	233	licencia_conduccion	documents/233/licencia_conduccion_1767323815.jpg	pendiente	\N	2026-01-02 03:16:56.736071	\N
93	233	soat	documents/233/soat_1767323816.pdf	pendiente	\N	2026-01-02 03:16:57.716224	\N
94	233	tecnomecanica	documents/233/tecnomecanica_1767323817.jpg	pendiente	\N	2026-01-02 03:16:58.511526	\N
95	233	tarjeta_propiedad	documents/233/tarjeta_propiedad_1767323818.jpg	pendiente	\N	2026-01-02 03:16:59.877572	\N
96	234	licencia_conduccion	documents/234/licencia_conduccion_1767488583.pdf	pendiente	\N	2026-01-04 01:03:04.40882	\N
97	234	soat	documents/234/soat_1767488584.jpg	pendiente	\N	2026-01-04 01:03:05.656984	\N
98	234	tecnomecanica	documents/234/tecnomecanica_1767488585.pdf	pendiente	\N	2026-01-04 01:03:07.071161	\N
99	234	tarjeta_propiedad	documents/234/tarjeta_propiedad_1767488587.jpg	pendiente	\N	2026-01-04 01:03:08.285126	\N
100	235	licencia_conduccion	documents/235/licencia_conduccion_1767495096.pdf	pendiente	\N	2026-01-04 02:51:37.555602	\N
101	235	soat	documents/235/soat_1767495097.jpg	pendiente	\N	2026-01-04 02:51:38.819806	\N
102	235	tecnomecanica	documents/235/tecnomecanica_1767495099.jpg	pendiente	\N	2026-01-04 02:51:40.180416	\N
103	235	tarjeta_propiedad	documents/235/tarjeta_propiedad_1767495100.jpg	pendiente	\N	2026-01-04 02:51:41.510436	\N
108	277	licencia_conduccion	documents/277/licencia_conduccion_1768322945.jpg	pendiente	\N	2026-01-13 16:49:06.271802	\N
109	277	soat	documents/277/soat_1768322946.jpg	pendiente	\N	2026-01-13 16:49:07.338564	\N
110	277	tecnomecanica	documents/277/tecnomecanica_1768322947.jpg	pendiente	\N	2026-01-13 16:49:08.362848	\N
111	277	tarjeta_propiedad	documents/277/tarjeta_propiedad_1768322948.jpg	pendiente	\N	2026-01-13 16:49:09.366417	\N
112	278	licencia_conduccion	documents/278/licencia_conduccion_1768341439.jpg	pendiente	\N	2026-01-13 21:57:21.495943	\N
113	278	soat	documents/278/soat_1768341441.jpg	pendiente	\N	2026-01-13 21:57:22.943425	\N
114	278	tecnomecanica	documents/278/tecnomecanica_1768341443.jpg	pendiente	\N	2026-01-13 21:57:24.375999	\N
115	278	tarjeta_propiedad	documents/278/tarjeta_propiedad_1768341444.jpg	pendiente	\N	2026-01-13 21:57:25.772095	\N
116	298	licencia_conduccion	documents/298/licencia_conduccion_1768879665.jpg	pendiente	\N	2026-01-20 03:27:46.364011	\N
117	298	soat	documents/298/soat_1768879666.jpg	pendiente	\N	2026-01-20 03:27:47.641332	\N
118	298	tecnomecanica	documents/298/tecnomecanica_1768879667.jpg	pendiente	\N	2026-01-20 03:27:49.057165	\N
119	298	tarjeta_propiedad	documents/298/tarjeta_propiedad_1768879669.jpg	pendiente	\N	2026-01-20 03:27:50.365324	\N
\.


--
-- TOC entry 6142 (class 0 OID 115569)
-- Dependencies: 302
-- Data for Name: empresa_tipos_vehiculo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresa_tipos_vehiculo (id, empresa_id, tipo_vehiculo_codigo, activo, fecha_activacion, fecha_desactivacion, activado_por, desactivado_por, motivo_desactivacion, conductores_activos, viajes_completados, creado_en, actualizado_en) FROM stdin;
4	11	moto	t	2026-01-11 01:07:31.381959	\N	\N	\N	\N	0	0	2026-01-11 01:07:31.381959	2026-01-11 01:07:31.381959
5	11	auto	t	2026-01-11 01:07:31.390262	\N	\N	\N	\N	0	0	2026-01-11 01:07:31.390262	2026-01-11 01:07:31.390262
6	11	motocarro	t	2026-01-11 01:07:31.391075	\N	\N	\N	\N	0	0	2026-01-11 01:07:31.391075	2026-01-11 01:07:31.391075
1	1	moto	t	2026-01-11 01:04:21.845836	\N	\N	\N	\N	0	0	2026-01-11 01:04:21.845836	2026-01-11 01:08:16.535609
2	1	auto	t	2026-01-11 01:04:22.746251	\N	\N	\N	\N	0	0	2026-01-11 01:04:22.746251	2026-01-11 01:08:16.535609
3	1	motocarro	t	2026-01-11 01:04:23.538481	\N	\N	\N	\N	0	0	2026-01-11 01:04:23.538481	2026-01-11 01:08:16.535609
13	12	moto	t	2026-01-14 01:37:23.478268	\N	1	\N	\N	0	0	2026-01-14 00:40:54.855458	2026-01-14 01:37:23.478268
14	12	auto	t	2026-01-14 01:37:23.479803	\N	1	\N	\N	0	0	2026-01-14 00:40:54.855458	2026-01-14 01:37:23.479803
15	12	motocarro	t	2026-01-14 01:37:23.480502	\N	1	\N	\N	0	0	2026-01-14 00:40:54.855458	2026-01-14 01:37:23.480502
16	12	taxi	t	2026-01-14 01:37:23.481157	\N	1	\N	\N	0	0	2026-01-14 00:40:54.855458	2026-01-14 01:37:23.481157
17	13	moto	t	2026-01-14 01:37:26.030991	\N	1	\N	\N	0	0	2026-01-14 00:45:55.299546	2026-01-14 01:37:26.030991
18	13	auto	t	2026-01-14 01:37:26.031921	\N	1	\N	\N	0	0	2026-01-14 00:45:55.299546	2026-01-14 01:37:26.031921
19	13	motocarro	t	2026-01-14 01:37:26.032385	\N	1	\N	\N	0	0	2026-01-14 00:45:55.299546	2026-01-14 01:37:26.032385
20	13	taxi	t	2026-01-14 01:37:26.032859	\N	1	\N	\N	0	0	2026-01-14 00:45:55.299546	2026-01-14 01:37:26.032859
21	14	moto	t	2026-01-14 01:37:29.85869	\N	1	\N	\N	0	0	2026-01-14 01:22:46.418438	2026-01-14 01:37:29.85869
22	14	auto	t	2026-01-14 01:37:29.859797	\N	1	\N	\N	0	0	2026-01-14 01:22:46.418438	2026-01-14 01:37:29.859797
23	14	motocarro	t	2026-01-14 01:37:29.860357	\N	1	\N	\N	0	0	2026-01-14 01:22:46.418438	2026-01-14 01:37:29.860357
24	14	taxi	t	2026-01-14 01:37:29.860907	\N	1	\N	\N	0	0	2026-01-14 01:22:46.418438	2026-01-14 01:37:29.860907
25	15	moto	t	2026-01-14 01:37:32.526826	\N	1	\N	\N	0	0	2026-01-14 01:27:46.039417	2026-01-14 01:37:32.526826
26	15	auto	t	2026-01-14 01:37:32.527702	\N	1	\N	\N	0	0	2026-01-14 01:27:46.039417	2026-01-14 01:37:32.527702
27	15	motocarro	t	2026-01-14 01:37:32.528186	\N	1	\N	\N	0	0	2026-01-14 01:27:46.039417	2026-01-14 01:37:32.528186
28	15	taxi	t	2026-01-14 01:37:32.528489	\N	1	\N	\N	0	0	2026-01-14 01:27:46.039417	2026-01-14 01:37:32.528489
29	16	moto	t	2026-01-14 01:37:43.566415	\N	1	\N	\N	0	0	2026-01-14 01:32:03.278549	2026-01-14 01:37:43.566415
30	16	auto	t	2026-01-14 01:37:43.567168	\N	1	\N	\N	0	0	2026-01-14 01:32:03.278549	2026-01-14 01:37:43.567168
31	16	motocarro	t	2026-01-14 01:37:43.567701	\N	1	\N	\N	0	0	2026-01-14 01:32:03.278549	2026-01-14 01:37:43.567701
32	16	taxi	t	2026-01-14 01:37:43.568132	\N	1	\N	\N	0	0	2026-01-14 01:32:03.278549	2026-01-14 01:37:43.568132
\.


--
-- TOC entry 6144 (class 0 OID 115610)
-- Dependencies: 304
-- Data for Name: empresa_tipos_vehiculo_historial; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresa_tipos_vehiculo_historial (id, empresa_tipo_vehiculo_id, empresa_id, tipo_vehiculo_codigo, accion, estado_anterior, estado_nuevo, realizado_por, motivo, fecha_cambio, ip_address, user_agent, conductores_afectados) FROM stdin;
\.


--
-- TOC entry 6146 (class 0 OID 115633)
-- Dependencies: 306
-- Data for Name: empresa_vehiculo_notificaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresa_vehiculo_notificaciones (id, historial_id, conductor_id, empresa_id, tipo_vehiculo_codigo, tipo_notificacion, estado, asunto, mensaje, enviado_en, error_mensaje, intentos, creado_en) FROM stdin;
\.


--
-- TOC entry 6138 (class 0 OID 91274)
-- Dependencies: 298
-- Data for Name: empresas_configuracion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas_configuracion (id, empresa_id, tipos_vehiculo, zona_operacion, horario_operacion, acepta_efectivo, acepta_tarjeta, acepta_transferencia, radio_maximo_km, tiempo_espera_max_min, notificaciones_email, notificaciones_push, creado_en, actualizado_en) FROM stdin;
2	11	{moto,motocarro,carro}	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-11 19:44:20.809792	2026-01-14 01:56:44.221618
3	1	{moto,motocarro,carro}	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-11 19:44:20.809792	2026-01-14 01:56:44.229626
4	14	\N	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-14 01:58:41.20189	2026-01-14 01:58:41.20189
5	13	\N	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-14 01:58:41.219147	2026-01-14 01:58:41.219147
6	16	\N	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-14 01:58:41.220079	2026-01-14 01:58:41.220079
7	15	\N	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-14 01:58:41.220826	2026-01-14 01:58:41.220826
8	12	\N	{Cañasgordas,Antioquia}	\N	t	f	f	50	15	t	t	2026-01-14 01:58:41.221842	2026-01-14 01:58:41.221842
\.


--
-- TOC entry 6132 (class 0 OID 91208)
-- Dependencies: 292
-- Data for Name: empresas_contacto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas_contacto (id, empresa_id, email, telefono, telefono_secundario, direccion, municipio, departamento, creado_en, actualizado_en) FROM stdin;
2	11	aguila@gmail.com4	32424	4234342	Cra 16d 	Cañasgordas	Antioquia	2026-01-11 19:44:20.809792	2026-01-11 19:44:20.809792
3	1	bird@gmail.com	2434234	432434	Cra 16d	Cañasgordas	Antioquia	2026-01-11 19:44:20.809792	2026-01-11 19:44:20.809792
4	14	\N	\N	\N	\N	Cañasgordas	Antioquia	2026-01-14 01:58:41.214761	2026-01-14 01:58:41.214761
5	13	\N	\N	\N	\N	Cañasgordas	Antioquia	2026-01-14 01:58:41.219659	2026-01-14 01:58:41.219659
6	16	\N	\N	\N	\N	Cañasgordas	Antioquia	2026-01-14 01:58:41.220456	2026-01-14 01:58:41.220456
7	15	\N	\N	\N	\N	Cañasgordas	Antioquia	2026-01-14 01:58:41.221172	2026-01-14 01:58:41.221172
8	12	\N	\N	\N	\N	Cañasgordas	Antioquia	2026-01-14 01:58:41.222681	2026-01-14 01:58:41.222681
\.


--
-- TOC entry 6136 (class 0 OID 91248)
-- Dependencies: 296
-- Data for Name: empresas_metricas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas_metricas (id, empresa_id, total_conductores, conductores_activos, conductores_pendientes, total_viajes_completados, total_viajes_cancelados, calificacion_promedio, total_calificaciones, ingresos_totales, viajes_mes, ingresos_mes, ultima_actualizacion) FROM stdin;
6	11	0	0	0	0	0	0.00	0	0.00	0	0.00	2026-01-20 02:16:59.428012
26	12	0	0	0	0	0	0.00	0	0.00	0	0.00	2026-01-20 02:16:59.440043
8	13	9	5	0	38	0	4.58	36	570000.00	38	570000.00	2026-01-20 02:16:59.451306
28	14	0	0	0	0	0	0.00	0	0.00	0	0.00	2026-01-20 02:16:59.456851
29	15	0	0	0	0	0	0.00	0	0.00	0	0.00	2026-01-20 02:16:59.463702
30	16	0	0	0	0	0	0.00	0	0.00	0	0.00	2026-01-20 02:16:59.472594
7	1	2	1	0	35	19	4.87	15	483109.84	30	483109.84	2026-01-21 01:39:18.203446
\.


--
-- TOC entry 6134 (class 0 OID 91228)
-- Dependencies: 294
-- Data for Name: empresas_representante; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas_representante (id, empresa_id, nombre, telefono, email, documento_identidad, cargo, creado_en, actualizado_en) FROM stdin;
2	11	Juan Oquendo	43434553	angelow2025sen@gmail.com	\N	Representante Legal	2026-01-11 19:44:20.809792	2026-01-11 19:44:20.809792
3	1	Braian Andres Oquendo Durango	233232	traconmaster@gmail.com	\N	Representante Legal	2026-01-11 19:44:20.809792	2026-01-11 19:44:20.809792
\.


--
-- TOC entry 6111 (class 0 OID 25436)
-- Dependencies: 269
-- Data for Name: empresas_transporte; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empresas_transporte (id, nombre, nit, razon_social, email, telefono, telefono_secundario, direccion, municipio, departamento, representante_nombre, representante_telefono, representante_email, tipos_vehiculo, logo_url, descripcion, estado, verificada, fecha_verificacion, verificado_por, total_conductores, total_viajes_completados, calificacion_promedio, creado_en, actualizado_en, creado_por, notas_admin, comision_admin_porcentaje, saldo_pendiente) FROM stdin;
11	Aguila 	323243342	Aguila sas3	aguila@gmail.com4	32424	4234342	Cra 16d 	Cañasgordas	Antioquia	Juan Oquendo	43434553	angelow2025sen@gmail.com	{moto,motocarro,carro}	http://192.168.18.68/viax/backend/r2_proxy.php?key=empresas%2Flogos%2Flogo_6962e6306db9c.jpg	sas	activo	t	2026-01-10 23:52:45.356995	1	0	0	0.00	2026-01-10 23:52:17.473911	2026-01-11 00:20:14.198995	274	sas	15.00	0.00
12	Humany	34435543	Humany SAS	humany@gmail.com	45535435	4555646	cra 16d	Cañasgordas	Antioquia	Braian Andres Gonzales	5435365	humanypersonal@gmail.com	{moto,motocarro,carro,taxi}	empresas/logos/logo_6966e61576e23.jpg	Empresa dedicada al transporte	activo	t	2026-01-14 01:37:23.471688	1	0	0	0.00	2026-01-14 00:40:54.855458	2026-01-14 01:37:23.471688	279	\N	0.00	0.00
13	Elite	34545	Elite SAS	elite@gmail.com	5646465	435353455	cra 16d	Cañasgordas	Antioquia	Cristian Zapata	4554665	elitepersonal@gmail.com	{moto,motocarro,taxi,carro}	empresas/logos/logo_6966e7421d2bf.jpg	Empresa elite	activo	t	2026-01-14 01:37:26.026664	1	0	0	0.00	2026-01-14 00:45:55.299546	2026-01-14 01:37:26.026664	281	\N	0.00	0.00
14	Acard	4342423423	Acard SAS	acard@gmail.com	43424	453545	Cra 16d	Cañasgordas	Antioquia	Pablo Arrumedo	4553453	arcardpersonal@gmail.com	{moto,motocarro,carro,taxi}	empresas/logos/logo_6966efe51e46c.jpg	Empresa	activo	t	2026-01-14 01:37:29.85157	1	0	0	0.00	2026-01-14 01:22:46.418438	2026-01-14 01:37:29.85157	283	\N	0.00	0.00
15	Halal	3454353	Halal SAS	halal@gmail.com	4342423356	424342	Cra 16d	Cañasgordas	Antioquia	Victor Proto	42345345	Halalpersonal@gmail.com	{moto,motocarro,carro,taxi}	empresas/logos/logo_6966f110ae306.jpg	HALAL EMPRESA	activo	t	2026-01-14 01:37:32.515851	1	0	0	0.00	2026-01-14 01:27:46.039417	2026-01-14 01:37:32.515851	285	\N	0.00	0.00
16	Friends	543535342	Friends SAS	friends@gmail.com	3243453	53456543	Cra 16d	Cañasgordas	Antioquia	Hector Gustavo	5423	friendspersonal@gmail.com	{moto,taxi,motocarro,carro}	empresas/logos/logo_6966f2121704e.jpg	Friends SAS empresa	activo	t	2026-01-14 01:37:43.558331	1	0	0	0.00	2026-01-14 01:32:03.278549	2026-01-14 01:37:43.558331	287	\N	0.00	0.00
1	Bird	342234234234	Bird SAS	bird@gmail.com	2434234	432434	Cra 16d	Cañasgordas	Antioquia	Braian Andres Oquendo Durango	233232	traconmaster@gmail.com	{moto,motocarro,carro}	http://192.168.18.68/viax/backend/r2_proxy.php?key=empresas%2Fregistros%2F2026%2F01%2Flogo_1768012079_fed5ce304cb2c4b4.webp	addsad	activo	t	2026-01-10 20:51:42.678888	1	6	0	0.00	2026-01-10 02:28:00.353123	2026-01-20 03:29:49.121648	254	Registro desde app móvil - pendiente de verificación	10.00	0.00
\.


--
-- TOC entry 6071 (class 0 OID 16664)
-- Dependencies: 227
-- Data for Name: estadisticas_sistema; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.estadisticas_sistema (id, fecha, total_usuarios, total_clientes, total_conductores, total_administradores, usuarios_activos_dia, nuevos_registros_dia, total_solicitudes, solicitudes_completadas, solicitudes_canceladas, ingresos_totales, ingresos_dia, fecha_creacion, fecha_actualizacion) FROM stdin;
\.


--
-- TOC entry 6102 (class 0 OID 17187)
-- Dependencies: 259
-- Data for Name: historial_confianza; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historial_confianza (id, usuario_id, conductor_id, total_viajes, viajes_completados, viajes_cancelados, suma_calificaciones_conductor, suma_calificaciones_usuario, total_calificaciones, ultimo_viaje_fecha, score_confianza, zona_frecuente_lat, zona_frecuente_lng, creado_en, actualizado_en) FROM stdin;
\.


--
-- TOC entry 6072 (class 0 OID 16690)
-- Dependencies: 228
-- Data for Name: historial_precios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historial_precios (id, configuracion_id, campo_modificado, valor_anterior, valor_nuevo, usuario_id, fecha_cambio, motivo) FROM stdin;
\.


--
-- TOC entry 6073 (class 0 OID 16699)
-- Dependencies: 229
-- Data for Name: historial_seguimiento; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historial_seguimiento (id, solicitud_id, conductor_id, latitud, longitud, precision_gps, velocidad, direccion, timestamp_seguimiento) FROM stdin;
\.


--
-- TOC entry 6074 (class 0 OID 16708)
-- Dependencies: 230
-- Data for Name: logs_auditoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.logs_auditoria (id, usuario_id, accion, entidad, entidad_id, descripcion, ip_address, user_agent, datos_anteriores, datos_nuevos, fecha_creacion) FROM stdin;
1	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-22 14:37:21
2	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-24 11:11:27
3	7	submit_verification	detalles_conductor	7	Conductor envió perfil para verificación	\N	\N	\N	\N	2025-10-25 15:41:26
4	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-25 16:08:02
5	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-25 18:47:52
6	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 15:05:06
7	7	submit_verification	detalles_conductor	7	Conductor envió perfil para verificación	\N	\N	\N	\N	2025-10-26 15:45:50
8	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 15:48:18
9	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 16:23:40
10	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 17:07:32
11	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 17:53:51
12	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 19:31:37
13	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 20:33:37
14	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 21:41:51
15	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 23:07:04
16	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 23:30:41
17	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-26 23:52:53
18	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 01:00:48
19	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 01:10:23
20	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 01:16:41
21	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 01:19:23
22	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 01:27:04
23	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 02:01:29
24	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 04:01:54
25	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 04:15:05
26	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 04:17:24
27	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 04:18:33
28	1	actualizar_usuario	usuarios	5	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-10-27 04:26:37
29	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 22:09:32
30	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 22:11:36
31	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-27 22:13:55
32	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-10-29 17:47:58
33	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-03 15:40:24
34	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-03 17:33:35
35	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 01:36:52
36	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 12:48:54
37	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 13:41:12
38	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 18:33:39
39	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 18:36:01
40	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-04 18:40:57
41	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-08 22:42:54
42	1	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-08 22:46:13
43	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-09 02:52:39
44	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-09 22:29:11
45	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-09 22:31:28
46	7	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-11 12:12:08
47	6	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2025-11-29 00:41:12
48	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-27 23:17:42
49	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-27 23:17:46
50	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-27 23:17:49
53	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 00:17:36
54	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:36:58
55	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:41:42
56	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:44:20
57	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:47:50
58	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:48:07
59	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:48:16
60	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:48:27
61	1	actualizar_usuario	usuarios	227	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:49:56
62	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:56:32
63	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:59:28
64	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:59:34
65	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:59:38
66	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 00:59:44
67	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 01:03:12
68	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 01:03:16
69	1	actualizar_usuario	usuarios	228	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 01:03:21
70	1	actualizar_usuario	usuarios	227	Administrador actualizó datos del usuario	\N	\N	\N	\N	2025-12-28 01:03:31
76	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-29 16:05:21
78	7	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-29 20:47:30
79	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2025-12-29 21:59:22
80	226	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-30 22:38:10
81	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.37	Dart/3.9 (dart:io)	\N	\N	2026-01-01 01:52:29
82	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.37	Dart/3.9 (dart:io)	\N	\N	2026-01-01 02:49:02
83	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.37	Dart/3.9 (dart:io)	\N	\N	2026-01-01 02:54:11
84	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-01 13:13:40
85	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-01 13:15:10
86	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-01 13:16:00
87	1	actualizar_usuario	usuarios	11	Administrador actualizó datos del usuario	\N	\N	\N	\N	2026-01-01 13:20:41
88	1	actualizar_usuario	usuarios	11	Administrador actualizó datos del usuario	\N	\N	\N	\N	2026-01-01 13:20:46
89	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-01 13:36:21
90	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 14:00:55
91	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 17:23:17
92	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 17:45:04
93	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 17:56:02
94	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-01 19:57:12
95	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 20:32:05
96	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 20:47:31
97	226	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-01 23:03:08
98	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-02 01:26:08
99	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-02 01:30:25
100	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-02 01:42:57
101	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-02 03:20:13
134	1	rechazar_conductor	detalles_conductor	232	Conductor ID 232 rechazado por administrador ID 1 - Motivo: documento fraudelento	\N	\N	\N	\N	2026-01-02 23:17:35
135	6	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-02 23:56:01
136	1	migracion	sistema	\N	Migración 028: Conductores obligatoriamente vinculados a empresa. Eliminada opción independiente.	\N	\N	\N	\N	2026-01-03 22:34:10
137	1	migracion	sistema	\N	Migración 028: Conductores obligatoriamente vinculados a empresa. Eliminada opción independiente.	\N	\N	\N	\N	2026-01-03 22:34:22
138	234	login	\N	\N	Usuario inició sesión exitosamente	127.0.0.1	Dart/3.9 (dart:io)	\N	\N	2026-01-04 00:44:31
139	234	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-04 01:01:10
141	1	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 01:29:10
142	1	migracion	sistema	\N	Migración 029: Normalización de tabla empresas_transporte en 4 tablas relacionadas	\N	\N	\N	\N	2026-01-04 01:51:26
144	235	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-04 02:49:59
146	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-04 03:14:25
51	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-27 23:18:49
52	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-27 23:22:14
71	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 01:04:29
72	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 01:21:53
73	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 01:22:48
74	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 01:31:25
75	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-28 01:53:17
77	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2025-12-29 17:02:14
140	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 01:14:33
143	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 02:16:08
145	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-04 02:52:18
147	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.41	Dart/3.9 (dart:io)	\N	\N	2026-01-04 03:14:47
148	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 15:56:10
150	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 15:58:58
151	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-08 00:16:40
149	\N	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-04 15:56:54
152	\N	update_commission	empresas_transporte	11	Comisión admin actualizada de 0.00% a 17% para empresa: Aguila 	\N	\N	\N	\N	2026-01-11 00:07:22
153	\N	update_commission	empresas_transporte	11	Comisión admin actualizada de 17.00% a 20% para empresa: Aguila 	\N	\N	\N	\N	2026-01-11 00:13:45
154	\N	update_commission	empresas_transporte	11	Comisión admin actualizada de 20.00% a 15% para empresa: Aguila 	\N	\N	\N	\N	2026-01-11 00:20:14
155	1	migracion	sistema	\N	Migración 029: Normalización de tabla empresas_transporte en 4 tablas relacionadas	\N	\N	\N	\N	2026-01-11 19:44:21
156	276	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-13 16:03:01
157	\N	update_commission	empresas_transporte	1	Comisión admin actualizada de 0.00% a 10% para empresa: Bird	\N	\N	\N	\N	2026-01-13 21:29:07
158	280	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.68	Dart/3.9 (dart:io)	\N	\N	2026-01-14 01:42:23
159	298	login	\N	\N	Usuario inició sesión exitosamente	192.168.18.37	Dart/3.10 (dart:io)	\N	\N	2026-01-20 03:07:03
\.


--
-- TOC entry 6104 (class 0 OID 17244)
-- Dependencies: 262
-- Data for Name: mensajes_chat; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mensajes_chat (id, solicitud_id, remitente_id, destinatario_id, tipo_remitente, mensaje, tipo_mensaje, leido, leido_en, fecha_creacion, fecha_actualizacion, activo) FROM stdin;
1	635	7	2	conductor	HOLA	texto	f	\N	2025-12-21 21:36:01.199602	2025-12-21 21:36:01.199602	t
2	635	7	2	conductor	COMO ESTAS	texto	f	\N	2025-12-21 21:36:14.648077	2025-12-21 21:36:14.648077	t
3	636	7	2	conductor	Ya llegué al punto de recogida	texto	f	\N	2025-12-21 21:47:08.323032	2025-12-21 21:47:08.323032	t
4	637	7	2	conductor	Estoy afuera esperando	texto	f	\N	2025-12-21 21:54:03.99706	2025-12-21 21:54:03.99706	t
5	637	7	2	conductor	Ya llegué al punto de recogida	texto	f	\N	2025-12-21 21:57:09.594569	2025-12-21 21:57:09.594569	t
6	658	6	7	cliente	Hola	texto	f	\N	2025-12-23 02:55:25.040216	2025-12-23 02:55:25.040216	t
7	658	6	7	cliente	Estoy afuera esperando	texto	f	\N	2025-12-23 02:55:28.32459	2025-12-23 02:55:28.32459	t
8	659	6	7	cliente	Hola	texto	t	2025-12-23 03:01:42.431718	2025-12-23 03:01:38.708766	2025-12-23 03:01:42.431718	t
9	659	7	6	conductor	Hola	texto	t	2025-12-23 03:01:55.125078	2025-12-23 03:01:53.831518	2025-12-23 03:01:55.125078	t
10	659	7	6	conductor	Estoy en camino	texto	t	2025-12-23 03:01:58.173474	2025-12-23 03:01:55.539647	2025-12-23 03:01:58.173474	t
11	659	6	7	cliente	Estoy afuera esperando	texto	t	2025-12-23 03:02:06.31156	2025-12-23 03:02:04.205944	2025-12-23 03:02:06.31156	t
12	661	7	9	conductor	Hola	texto	f	\N	2025-12-23 03:10:04.608508	2025-12-23 03:10:04.608508	t
13	661	7	9	conductor	Ya llegué al punto de recogida	texto	f	\N	2025-12-23 03:10:06.21716	2025-12-23 03:10:06.21716	t
14	728	276	277	cliente	hola	texto	t	2026-01-16 19:59:37.184348	2026-01-16 19:59:30.14724	2026-01-16 19:59:37.184348	t
15	729	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 20:37:42.974858	2026-01-16 20:37:28.287422	2026-01-16 20:37:42.974858	t
16	729	276	277	cliente	Ya bajo	texto	t	2026-01-16 20:37:49.672598	2026-01-16 20:37:46.832519	2026-01-16 20:37:49.672598	t
17	729	276	277	cliente	Ya bajo	texto	t	2026-01-16 20:39:21.56346	2026-01-16 20:39:07.13862	2026-01-16 20:39:21.56346	t
18	729	276	277	cliente	sas	texto	t	2026-01-16 20:40:23.70212	2026-01-16 20:39:49.894236	2026-01-16 20:40:23.70212	t
19	729	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 20:40:41.892168	2026-01-16 20:40:39.234144	2026-01-16 20:40:41.892168	t
20	729	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 20:41:32.110084	2026-01-16 20:40:59.081044	2026-01-16 20:41:32.110084	t
21	729	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 20:41:32.110084	2026-01-16 20:41:27.534385	2026-01-16 20:41:32.110084	t
22	730	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 21:34:06.858762	2026-01-16 21:34:04.149736	2026-01-16 21:34:06.858762	t
23	730	276	277	cliente	Ya bajo	texto	t	2026-01-16 21:34:21.855436	2026-01-16 21:34:20.184028	2026-01-16 21:34:21.855436	t
24	730	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 21:35:16.252712	2026-01-16 21:35:00.217099	2026-01-16 21:35:16.252712	t
25	730	277	276	conductor	Estoy en camino	texto	f	\N	2026-01-16 21:35:23.502919	2026-01-16 21:35:23.502919	t
26	731	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:12:17.082579	2026-01-16 22:12:16.329511	2026-01-16 22:12:17.082579	t
27	731	276	277	cliente	Ya bajo	texto	f	\N	2026-01-16 22:12:34.441383	2026-01-16 22:12:34.441383	t
28	732	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 22:22:26.055326	2026-01-16 22:22:09.488472	2026-01-16 22:22:26.055326	t
29	732	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:22:43.94194	2026-01-16 22:22:32.283468	2026-01-16 22:22:43.94194	t
30	732	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 22:24:37.746989	2026-01-16 22:24:33.91961	2026-01-16 22:24:37.746989	t
31	732	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:24:41.422826	2026-01-16 22:24:39.399132	2026-01-16 22:24:41.422826	t
32	732	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:25:01.623397	2026-01-16 22:24:44.137026	2026-01-16 22:25:01.623397	t
33	732	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 22:25:02.68204	2026-01-16 22:25:02.531355	2026-01-16 22:25:02.68204	t
34	732	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-16 22:25:25.54583	2026-01-16 22:25:08.289875	2026-01-16 22:25:25.54583	t
35	732	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:26:53.44266	2026-01-16 22:25:27.058808	2026-01-16 22:26:53.44266	t
36	732	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-16 22:26:53.44266	2026-01-16 22:25:32.985342	2026-01-16 22:26:53.44266	t
37	733	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-17 22:07:18.716305	2026-01-17 22:07:12.909292	2026-01-17 22:07:18.716305	t
38	733	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-17 22:11:43.898256	2026-01-17 22:11:33.872894	2026-01-17 22:11:43.898256	t
39	733	277	276	conductor	Estoy en camino	texto	t	2026-01-17 22:11:43.898256	2026-01-17 22:11:40.45052	2026-01-17 22:11:43.898256	t
40	754	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-18 21:29:03.286296	2026-01-18 21:28:54.173491	2026-01-18 21:29:03.286296	t
41	754	276	277	cliente	Ya bajo	texto	t	2026-01-18 21:29:09.820672	2026-01-18 21:29:08.698645	2026-01-18 21:29:09.820672	t
42	754	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-18 21:29:24.704971	2026-01-18 21:29:22.22881	2026-01-18 21:29:24.704971	t
43	755	277	276	conductor	Ya llegué al punto de recogida	texto	f	\N	2026-01-18 22:05:36.860979	2026-01-18 22:05:36.860979	t
44	755	277	276	conductor	Estoy en camino	texto	f	\N	2026-01-18 22:05:53.415427	2026-01-18 22:05:53.415427	t
45	756	277	276	conductor	Ya llegué al punto de recogida	texto	f	\N	2026-01-18 22:13:23.948574	2026-01-18 22:13:23.948574	t
46	758	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-18 22:34:46.549802	2026-01-18 22:34:44.39271	2026-01-18 22:34:46.549802	t
47	758	276	277	cliente	Estoy afuera esperando	texto	t	2026-01-18 22:35:12.41031	2026-01-18 22:35:11.210974	2026-01-18 22:35:12.41031	t
48	758	277	276	conductor	Ya llegué al punto de recogida	texto	t	2026-01-18 22:35:40.493763	2026-01-18 22:35:38.764535	2026-01-18 22:35:40.493763	t
\.


--
-- TOC entry 6152 (class 0 OID 115717)
-- Dependencies: 314
-- Data for Name: mensajes_ticket; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mensajes_ticket (id, ticket_id, remitente_id, es_agente, mensaje, adjuntos, leido, leido_en, created_at) FROM stdin;
\.


--
-- TOC entry 6075 (class 0 OID 16720)
-- Dependencies: 231
-- Data for Name: metodos_pago_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.metodos_pago_usuario (id, usuario_id, tipo_pago, ultimos_cuatro_digitos, marca_tarjeta, tipo_billetera, es_principal, activo, creado_en, actualizado_en) FROM stdin;
\.


--
-- TOC entry 6124 (class 0 OID 90987)
-- Dependencies: 282
-- Data for Name: notificaciones_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notificaciones_usuario (id, usuario_id, tipo_id, titulo, mensaje, referencia_tipo, referencia_id, data, leida, leida_en, push_enviada, push_enviada_en, created_at, eliminada, eliminada_en) FROM stdin;
6	1	9	Actualización disponible	Una nueva versión de Viax está disponible. Actualiza para obtener las últimas funciones.	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:13.010091	f	\N
5	1	10	Nueva calificación	Has recibido una calificación de 5 estrellas. ¡Excelente!	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:13.009025	f	\N
4	1	8	🎉 ¡Oferta especial!	Obtén 20% de descuento en tu próximo viaje. Código: VIAX20	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:13.007725	f	\N
3	1	6	Pago confirmado	El pago de $25.000 ha sido procesado correctamente.	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:13.00605	f	\N
2	1	3	Viaje completado	Tu viaje ha finalizado exitosamente. ¡Gracias por usar Viax!	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:13.004003	f	\N
1	1	1	¡Conductor en camino!	Juan Carlos ha aceptado tu solicitud de viaje. Llegará en aproximadamente 5 minutos.	\N	\N	{}	t	2026-01-07 23:42:19.301262	f	\N	2026-01-03 03:11:12.996353	f	\N
\.


--
-- TOC entry 6118 (class 0 OID 58206)
-- Dependencies: 276
-- Data for Name: pagos_empresas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pagos_empresas (id, empresa_id, monto, tipo, descripcion, viaje_id, saldo_anterior, saldo_nuevo, creado_en) FROM stdin;
\.


--
-- TOC entry 6108 (class 0 OID 17348)
-- Dependencies: 266
-- Data for Name: pagos_viaje; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pagos_viaje (id, solicitud_id, conductor_id, cliente_id, monto, metodo_pago, estado, confirmado_en, created_at) FROM stdin;
1	647	7	2	50000.00	efectivo	confirmado	2025-12-21 23:33:21	2025-12-23 00:19:29.435709
2	655	7	9	50000.00	efectivo	confirmado	2025-12-22 23:01:25	2025-12-23 00:19:29.440581
3	651	7	4	50000.00	efectivo	confirmado	2025-12-22 00:55:08	2025-12-23 00:19:29.443732
4	653	7	8	50000.00	efectivo	confirmado	2025-12-22 01:30:35	2025-12-23 00:19:29.447285
5	654	7	9	50000.00	efectivo	confirmado	2025-12-22 22:53:34	2025-12-23 00:19:29.450816
6	652	7	6	50000.00	efectivo	confirmado	2025-12-22 01:18:28	2025-12-23 00:19:29.453397
7	646	7	2	50000.00	efectivo	confirmado	2025-12-21 23:30:30	2025-12-23 00:19:29.454938
8	648	7	2	50000.00	efectivo	confirmado	2025-12-22 00:10:53	2025-12-23 00:19:29.45641
9	650	7	3	50000.00	efectivo	confirmado	2025-12-22 00:40:25	2025-12-23 00:19:29.458845
10	645	7	2	50000.00	efectivo	confirmado	2025-12-21 23:23:54	2025-12-23 00:19:29.461562
11	657	7	2	38000.00	efectivo	confirmado	2025-12-23 00:22:07.523925	2025-12-23 00:22:07.523925
12	661	7	9	62062.94	efectivo	confirmado	2025-12-23 03:10:19.792495	2025-12-23 03:10:19.792495
13	662	7	9	61236.60	efectivo	confirmado	2025-12-23 03:17:12.532288	2025-12-23 03:17:12.532288
14	733	277	276	291440.84	efectivo	confirmado	2026-01-17 22:48:28.132858	2026-01-17 22:48:28.132858
\.


--
-- TOC entry 6076 (class 0 OID 16733)
-- Dependencies: 232
-- Data for Name: paradas_solicitud; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.paradas_solicitud (id, solicitud_id, latitud, longitud, direccion, orden, estado, creado_en) FROM stdin;
\.


--
-- TOC entry 6120 (class 0 OID 82780)
-- Dependencies: 278
-- Data for Name: plantillas_bloqueadas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.plantillas_bloqueadas (id, plantilla_hash, plantilla, usuario_origen_id, razon, creado_en, activo) FROM stdin;
\.


--
-- TOC entry 6077 (class 0 OID 16743)
-- Dependencies: 233
-- Data for Name: proveedores_mapa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proveedores_mapa (id, nombre, api_key, activo, contador_solicitudes, ultimo_uso, creado_en) FROM stdin;
\.


--
-- TOC entry 6078 (class 0 OID 16751)
-- Dependencies: 234
-- Data for Name: reglas_precios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reglas_precios (id, tipo_servicio, tipo_vehiculo, tarifa_base, costo_por_km, costo_por_minuto, tarifa_minima, tarifa_cancelacion, multiplicador_demanda, activo, valido_desde, valido_hasta, creado_en) FROM stdin;
\.


--
-- TOC entry 6079 (class 0 OID 16763)
-- Dependencies: 235
-- Data for Name: reportes_usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reportes_usuarios (id, usuario_reportante_id, usuario_reportado_id, solicitud_id, tipo_reporte, descripcion, estado, notas_admin, admin_revisor_id, fecha_creacion, fecha_resolucion) FROM stdin;
\.


--
-- TOC entry 6154 (class 0 OID 115737)
-- Dependencies: 316
-- Data for Name: solicitudes_callback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.solicitudes_callback (id, usuario_id, telefono, motivo, estado, notas, programado_para, realizado_en, agente_id, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 6080 (class 0 OID 16778)
-- Dependencies: 236
-- Data for Name: solicitudes_servicio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.solicitudes_servicio (id, uuid_solicitud, cliente_id, tipo_servicio, ubicacion_recogida_id, ubicacion_destino_id, latitud_recogida, longitud_recogida, direccion_recogida, latitud_destino, longitud_destino, direccion_destino, distancia_estimada, tiempo_estimado, estado, fecha_creacion, solicitado_en, aceptado_en, recogido_en, entregado_en, completado_en, cancelado_en, motivo_cancelacion, cliente_confirma_pago, conductor_confirma_recibo, tiene_disputa, disputa_id, precio_final, metodo_pago, pago_confirmado, pago_confirmado_en, precio_estimado, conductor_llego_en, metodo_pago_usado, distancia_recorrida, tiempo_transcurrido, precio_ajustado_por_tracking, tuvo_desvio_ruta, tipo_vehiculo, empresa_id, conductor_id, precio_en_tracking) FROM stdin;
629	699a839e-587e-4ffc-86c4-2e380521a503	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 20:30:00	2025-12-21 20:30:00	2025-12-21 20:30:07	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
630	8a544e12-5a76-4ed8-a61d-51f75d7ab9b6	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 20:54:34	2025-12-21 20:54:34	2025-12-21 20:54:36	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
631	50cac957-abfa-4af0-8ca8-057b78448a14	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 20:57:49	2025-12-21 20:57:49	2025-12-21 20:57:53	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
632	be3e2557-af78-490e-96bd-8567512d429b	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 21:02:42	2025-12-21 21:02:42	2025-12-21 21:02:48	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
633	ff13dcd9-3540-44e1-924f-f4a8019e210b	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 21:16:43	2025-12-21 21:16:43	2025-12-21 21:16:52	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
634	1e06e459-2ac9-4b9a-b42e-978094f0f12d	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 21:23:21	2025-12-21 21:23:21	2025-12-21 21:23:25	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
635	004f5f2a-a249-4a7c-9abd-ed0860efb744	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 21:35:19	2025-12-21 21:35:19	2025-12-21 21:35:26	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
636	c0c54227-8aea-4cab-8e9a-4f7ac6f5a0c6	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 21:45:56	2025-12-21 21:45:56	2025-12-21 21:46:05	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
653	addd37b6-f9c5-4588-81db-af483a760507	8	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 01:28:49	2025-12-22 01:28:49	2025-12-22 01:28:56	2025-12-22 01:29:58	\N	2025-12-22 01:30:35	\N	\N	t	t	f	5	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
646	6ffeb18a-8621-4964-8582-2c4ee6362f8d	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-21 23:29:20	2025-12-21 23:29:20	2025-12-21 23:29:26	2025-12-21 23:29:39	\N	2025-12-21 23:30:30	\N	\N	f	f	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
639	c47b0fd9-73c6-41ea-9228-a874f7f925e8	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	conductor_llego	2025-12-21 22:17:43	2025-12-21 22:17:43	2025-12-21 22:17:58	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
640	af4eccae-e352-4af9-89ac-f4349b2ab83a	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	conductor_llego	2025-12-21 22:27:21	2025-12-21 22:27:21	2025-12-21 22:27:23	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
638	914735ed-1eb5-4c6e-b459-975db47c8fab	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	en_curso	2025-12-21 22:14:54	2025-12-21 22:14:54	2025-12-21 22:15:05	2025-12-21 22:29:12	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
637	0ce2cf12-7002-403b-9d6a-a3c0151be528	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	conductor_llego	2025-12-21 21:51:35	2025-12-21 21:51:35	2025-12-21 21:51:43	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
652	7bfde53f-13cd-43e2-88f2-d4d2bcbe3fd5	6	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 01:17:20	2025-12-22 01:17:20	2025-12-22 01:17:33	2025-12-22 01:18:19	\N	2025-12-22 01:18:28	\N	\N	\N	\N	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
641	8e0e30c9-c858-4fe5-9473-65ef5a9191cc	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	en_curso	2025-12-21 22:37:57	2025-12-21 22:37:57	2025-12-21 22:38:25	2025-12-21 22:39:03	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
642	37439b27-d3fe-4867-84c7-7d79ba534199	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	en_curso	2025-12-21 22:44:32	2025-12-21 22:44:32	2025-12-21 22:44:54	2025-12-21 22:45:30	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
654	645e6e9d-8e01-4466-bd73-af35426b5237	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 22:52:30	2025-12-22 22:52:30	2025-12-22 22:53:10	2025-12-22 22:53:22	\N	2025-12-22 22:53:34	\N	\N	f	t	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
643	595351a7-2044-4906-a9ab-dfa492f4fb81	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	en_curso	2025-12-21 22:53:42	2025-12-21 22:53:42	2025-12-21 22:54:05	2025-12-21 22:54:30	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
644	c4ae3c1f-e029-4558-8663-81149a640596	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-21 22:56:42	2025-12-21 22:56:42	2025-12-21 22:56:48	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
647	1a169b13-fc5e-4588-ae54-be1e96683d17	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-21 23:31:55	2025-12-21 23:31:55	2025-12-21 23:32:02	2025-12-21 23:32:48	\N	2025-12-21 23:33:21	\N	\N	f	f	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
651	24fe169d-80f5-4eec-a39a-4594b5b1c5dc	4	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 00:53:50	2025-12-22 00:53:50	2025-12-22 00:53:55	2025-12-22 00:55:00	\N	2025-12-22 00:55:08	\N	\N	\N	\N	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
648	fb3b7680-4556-45aa-8638-1db160bbbc1c	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 00:09:52	2025-12-22 00:09:52	2025-12-22 00:10:01	2025-12-22 00:10:44	\N	2025-12-22 00:10:53	\N	\N	f	f	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
650	5602b582-b0ea-4efe-b086-efe017c921fa	3	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 00:37:53	2025-12-22 00:37:53	2025-12-22 00:37:59	2025-12-22 00:39:40	\N	2025-12-22 00:40:25	\N	\N	t	f	t	2	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
645	e2969ddb-a482-4cc3-81ff-f3465a7a747f	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-21 23:06:23	2025-12-21 23:06:23	2025-12-21 23:06:34	2025-12-21 23:07:06	\N	2025-12-21 23:23:54	\N	\N	f	f	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
649	ac0759a6-661f-4fc8-bcb5-f6b2230c7cad	2	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completado	2025-12-22 00:15:56	2025-12-22 00:15:56	2025-12-22 00:16:00	2025-12-22 00:16:16	\N	2025-12-22 00:27:21	\N	\N	t	f	t	1	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
749	befd9b86-754b-44f3-9b4c-c62321357d4e	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 20:25:18	2026-01-18 20:25:18	2026-01-18 20:25:30	\N	\N	\N	2026-01-18 20:26:15	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
655	60be1f85-e210-4d8a-9e92-ec018866dfc3	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	completada	2025-12-22 23:01:01	2025-12-22 23:01:01	2025-12-22 23:01:07	2025-12-22 23:01:18	\N	2025-12-22 23:01:25	\N	\N	f	t	f	\N	50000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
751	047c46e2-1204-49ac-b32a-e285fe813ce5	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 21:07:37	2026-01-18 21:07:37	2026-01-18 21:07:44	\N	\N	\N	2026-01-18 21:10:38	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
733	3e9af0c4-dd9c-4273-93fb-eb7438b4d516	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.74532600	-76.02248900	Carrera 30 25 195, 057060 Cañasgordas, Antioquia, Colombia	1.11	4	completada	2026-01-17 22:06:35	2026-01-17 22:06:35	2026-01-17 22:06:54	2026-01-17 22:13:05	\N	2026-01-17 22:14:28	\N	\N	t	t	f	\N	291440.84	efectivo	t	2026-01-17 22:48:28.132858	8662.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
753	429370c2-df25-4076-b591-211beb6df6df	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 21:24:59	2026-01-18 21:24:59	2026-01-18 21:25:18	\N	\N	\N	2026-01-18 21:26:37	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
755	845fce96-23b0-4154-83e8-b660197dbd07	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 22:04:44	2026-01-18 22:04:44	2026-01-18 22:05:06	\N	\N	\N	2026-01-18 22:06:26	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
735	1f05b219-a52b-4c23-9fbe-ed783abc3663	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75786900	-76.03001000	Carrera 28 37 290, 057060 Cañasgordas, Antioquia, Colombia	1.61	6	completada	2026-01-17 23:18:28	2026-01-17 23:18:28	2026-01-17 23:18:39	2026-01-17 23:18:54	\N	2026-01-17 23:19:01	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	10470.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
757	32d113c8-923c-402a-8622-52c535737bcf	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 22:33:05	2026-01-18 22:33:05	\N	\N	\N	\N	2026-01-18 22:33:40	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
758	42e1292c-379d-4c7e-9bea-f367eef5fa84	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 22:33:50	2026-01-18 22:33:50	2026-01-18 22:34:21	\N	\N	\N	2026-01-18 22:36:01	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
737	864adfc1-ba86-4c2f-87a5-269ca7cab0e2	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75510200	-76.02918600	Carrera 28 34a 242, 057060 Cañasgordas, Antioquia, Colombia	0.61	4	completada	2026-01-17 23:56:34	2026-01-17 23:56:34	2026-01-17 23:56:45	2026-01-17 23:57:05	\N	2026-01-17 23:58:11	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	7458.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
759	dfb607a3-a2f4-4d0b-b5d0-ca7ee2643f1d	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 22:36:40	2026-01-18 22:36:40	2026-01-18 22:37:18	\N	\N	\N	2026-01-18 22:37:53	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-18 22:37:39.469945	\N	0.00	0	f	f	moto	1	\N	\N
739	5c86e127-e643-4fe2-84ae-9ba6ccb446e3	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75755300	-76.02989600	Carrera 28 37 212, 057060 Cañasgordas, Antioquia, Colombia	1.57	5	completada	2026-01-18 01:26:52	2026-01-18 01:26:52	2026-01-18 01:26:56	2026-01-18 01:27:22	2026-01-18 01:28:31	2026-01-18 01:28:31	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	10080.00	2026-01-18 01:27:13.063096	\N	118.20	1	f	f	moto	\N	\N	\N
760	b9393862-7a23-4009-8b39-db0b0e957a2b	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 23:02:38	2026-01-18 23:02:38	2026-01-18 23:02:58	\N	\N	\N	2026-01-18 23:03:06	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
741	6d3e0634-1729-4061-9bc2-f314f8cd40e4	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 02:22:37	2026-01-18 02:22:37	2026-01-18 02:22:51	2026-01-18 02:23:08	2026-01-18 02:24:15	2026-01-18 02:24:15	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-18 02:22:58.457902	\N	92.96	1	f	f	moto	\N	\N	\N
761	0f32f657-a3ca-4491-addf-b17020b2993a	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 23:06:10	2026-01-18 23:06:10	2026-01-18 23:19:16	\N	\N	\N	2026-01-18 23:19:55	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-18 23:19:38.702909	\N	0.00	0	f	f	moto	1	\N	\N
763	5416013c-b10b-4ded-9891-f4b9d58f9db0	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 23:22:36	2026-01-18 23:22:36	2026-01-18 23:22:41	\N	\N	\N	2026-01-18 23:38:37	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
743	11c13dcd-1f68-454a-8978-efb84c435422	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 03:19:35	2026-01-18 03:19:35	2026-01-18 03:19:45	2026-01-18 03:20:04	2026-01-18 03:21:08	2026-01-18 03:21:08	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-18 03:20:02.081526	\N	0.00	1	f	f	moto	1	\N	\N
765	0f349ad5-14d1-4bd2-8117-a26fd3430c3b	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.13996280	-75.62149500	Cañaveralejo, Sabaneta, Antioquia, Colombia	126.63	180	cancelada	2026-01-18 23:53:10	2026-01-18 23:53:10	2026-01-18 23:53:21	\N	\N	\N	2026-01-19 00:00:00	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	362702.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
745	98c075f9-40ae-47cf-8157-1bfc551b1d0e	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 13:56:35	2026-01-18 13:56:35	2026-01-18 13:56:41	2026-01-18 13:56:55	2026-01-18 14:15:38	2026-01-18 14:15:38	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	63225.00	2026-01-18 13:56:45.03322	\N	0.00	60	t	t	moto	1	\N	\N
747	5c2b7846-1fb1-4288-b5e1-1ea44cc19d62	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 14:23:54	2026-01-18 14:23:54	2026-01-18 14:24:00	2026-01-18 14:29:02	2026-01-18 14:30:41	2026-01-18 14:30:41	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	63225.00	2026-01-18 14:24:03.427655	\N	0.00	95	t	t	moto	1	\N	6000.00
657	c18f733f-c5bc-4482-a689-9338bad63684	2	transporte	\N	\N	4.60970000	-74.08170000	Test Origen	4.64970000	-74.07170000	Test Destino	5.20	15	completada	2025-12-23 00:22:08	2025-12-23 00:22:08	2025-12-23 00:22:08	\N	\N	2025-12-23 00:22:08	\N	\N	f	t	f	\N	38000.00	efectivo	t	2025-12-23 00:22:07.524355	35000.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
658	cbd2b3f9-faec-44c3-b2d9-84513d6251fe	6	transporte	\N	\N	6.25346200	-75.53843500	Calle 63 16d 111, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.71	47	cancelada	2025-12-23 02:54:32	2025-12-23 02:54:32	2025-12-23 02:54:55	\N	\N	\N	2025-12-23 02:55:36	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	61172.82	\N	\N	0.00	0	f	f	moto	\N	\N	\N
659	9f802101-f158-4577-8625-d75207b866ad	6	transporte	\N	\N	6.25265000	-75.53794100	Cr 17bb 57e-38, 050017 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.71	47	completada	2025-12-23 03:00:39	2025-12-23 03:00:39	2025-12-23 03:01:11	2025-12-23 03:02:43	\N	2025-12-23 03:03:05	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	73407.35	\N	\N	0.00	0	f	f	moto	\N	\N	\N
660	fa31d95f-29d9-4a84-a66a-fb5203fbe270	6	transporte	\N	\N	6.25263800	-75.53793700	Cr 17bb 57e-38, 050017 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.71	48	cancelada	2025-12-23 03:03:52	2025-12-23 03:03:52	2025-12-23 03:03:59	\N	\N	\N	2025-12-23 03:04:33	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	73707.81	\N	\N	0.00	0	f	f	moto	\N	\N	\N
661	77a23816-c6a1-42ad-9623-a4e838dbeb1c	9	transporte	\N	\N	6.27755470	-75.51824010	Punto de Recogida - Prueba (dentro de 5km)	6.31255470	-75.48824010	Punto de Destino - Prueba	7.00	20	completada	2025-12-23 03:07:47	2025-12-23 03:07:47	2025-12-23 03:08:09	2025-12-23 03:09:53	\N	2025-12-23 03:10:10	\N	\N	f	t	f	\N	62062.94	efectivo	t	2025-12-23 03:10:19.792495	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
673	81e5f8c2-e062-4d91-a750-892d54bf2208	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 20:55:26	2025-12-29 20:55:26	2025-12-29 20:55:33	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
662	9e88486b-4731-4ae1-9fcb-87332f80e31a	9	transporte	\N	\N	6.27755470	-75.51824010	Punto de Recogida - Prueba (dentro de 5km)	6.31255470	-75.48824010	Punto de Destino - Prueba	7.00	20	completada	2025-12-23 03:16:39	2025-12-23 03:16:39	2025-12-23 03:16:49	2025-12-23 03:17:00	\N	2025-12-23 03:17:09	\N	\N	f	t	f	\N	61236.60	efectivo	t	2025-12-23 03:17:12.532288	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
663	bd8285e8-a67c-4104-a353-3f7ed8bb6d98	6	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.15767810	-75.64338780	La Estrella, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 055460, Colombia	22.38	46	aceptada	2025-12-23 03:19:08	2025-12-23 03:19:08	2025-12-23 03:19:14	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	72314.36	\N	\N	0.00	0	f	f	moto	\N	\N	\N
664	faaf5585-de64-48b6-a9ac-bb123bf0a13f	6	transporte	\N	\N	6.25366300	-75.53828500	Calle 63 16d 111, 050017 Medellín, Antioquia, Colombia	2.80027410	-76.47050390	CENTRO EDUCATIVO CENTRO DE FORMACION INTEGRAL COMUNITARIO IKH TUKH KIWE LA ESTRE, Caldono - Pioya, Caldonó, Norte, Cauca, RAP Pacífico, Colombia	529.82	587	cancelada	2025-12-23 23:52:21	2025-12-23 23:52:21	\N	\N	\N	\N	2025-12-23 23:52:26	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	1391944.19	\N	\N	0.00	0	f	f	moto	\N	\N	\N
667	74f5fb58-9671-4ab9-b06c-9e69bff1311a	1	transporte	\N	\N	4.71098900	-74.07209200	Calle 10 #20-30, Centro	4.72541300	-74.08356400	Av. Principal #45-67, Norte	8.50	25	completada	2025-12-24 00:48:26	2025-12-24 00:48:26	\N	\N	\N	\N	\N	\N	f	f	f	\N	45000.00	efectivo	f	\N	45000.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
668	0aa118d3-a59d-463e-a6c1-5eabd38760af	1	transporte	\N	\N	4.69854700	-74.08914500	Carrera 15 #10-22	4.71234500	-74.07623400	Parque Central	5.20	15	completada	2025-12-24 00:48:26	2025-12-24 00:48:26	\N	\N	\N	\N	\N	\N	f	f	f	\N	28000.00	efectivo	f	\N	28000.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
670	90a317fb-dc89-4229-936d-0c2509bc6c64	1	mudanza	\N	\N	4.67823400	-74.05467800	Edificio Plaza, Apt 501	4.73215600	-74.02845600	Casa 23, Urb Los Pinos	15.00	45	completada	2025-12-24 00:48:26	2025-12-24 00:48:26	\N	\N	\N	\N	\N	\N	f	f	f	\N	125000.00	efectivo	f	\N	120000.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
671	774cadc2-0977-4a1e-9247-22711895a444	1	mandado	\N	\N	4.71567800	-74.06823400	Supermercado Extra	4.71245600	-74.07123400	Mi Casa	3.00	10	cancelada	2025-12-24 00:48:26	2025-12-24 00:48:26	\N	\N	\N	\N	\N	\N	f	f	f	\N	\N	efectivo	f	\N	15000.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
672	aa73d5f8-b99f-4061-9bc8-e940874e3147	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 20:48:22	2025-12-29 20:48:22	2025-12-29 20:48:49	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
674	0360e4ba-7b5a-4725-9875-495840dc00b6	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 20:59:38	2025-12-29 20:59:38	2025-12-29 20:59:46	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
675	751a3219-ea6e-458a-b4bd-fd91d5a9506b	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 21:17:42	2025-12-29 21:17:42	2025-12-29 21:17:57	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
676	322675b3-b4c9-4a0d-8462-c67fbb6c1d0b	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 21:24:32	2025-12-29 21:24:32	2025-12-29 21:24:37	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
677	bf7b578e-80f9-4f2c-8cf3-eea7ff3ece90	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 21:26:07	2025-12-29 21:26:07	2025-12-29 21:26:15	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
678	247ae73f-5a8a-4d45-82e3-c666a6b266ad	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 21:29:43	2025-12-29 21:29:43	2025-12-29 21:30:00	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
679	a1d4a547-8177-46d9-b717-5f675b8e904d	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	en_curso	2025-12-29 21:31:09	2025-12-29 21:31:09	2025-12-29 21:31:19	2025-12-29 21:31:44	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
680	869f4fab-dd7e-4c33-85e9-c7c3e41cf35a	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	aceptada	2025-12-29 21:40:56	2025-12-29 21:40:56	2025-12-29 21:41:03	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
681	21757b6d-1f10-4233-a0bc-6ab349d74559	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	en_curso	2025-12-29 21:45:29	2025-12-29 21:45:29	2025-12-29 21:45:38	2025-12-29 21:46:10	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
682	99ec91d1-280d-493d-917e-517bb776f038	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	conductor_llego	2025-12-29 21:47:31	2025-12-29 21:47:31	2025-12-29 21:47:44	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
683	af661b59-b089-4097-b4d7-8a53192ab827	9	transporte	\N	\N	6.27961830	-75.51955670	Punto de Recogida - Prueba (dentro de 5km)	6.31461830	-75.48955670	Punto de Destino - Prueba	7.00	20	en_curso	2025-12-29 23:23:31	2025-12-29 23:23:31	2025-12-29 23:23:40	2025-12-29 23:23:51	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
685	trip_69670065dcf519.66346969	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:33:10	2026-01-14 02:33:10	\N	\N	\N	2026-01-14 02:33:10	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
686	trip_696700b47d11c4.78561026	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:34:29	2026-01-14 02:34:29	\N	\N	\N	2026-01-14 02:34:29	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
687	trip_696700f1b26531.01615415	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:35:30	2026-01-14 02:35:30	\N	\N	\N	2026-01-14 02:35:30	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
688	trip_6967012a034af8.81870831	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:36:26	2026-01-14 02:36:26	\N	\N	\N	2026-01-14 02:36:26	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
689	trip_6967015cbed817.34557656	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
690	trip_6967015cc2f726.28636600	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
691	trip_6967015cc3dd01.51522905	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
692	trip_6967015cc4b9d9.29342693	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
693	trip_6967015cc5af51.21118155	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
694	trip_6967015cc67fa4.05328095	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
695	trip_6967015cc78b48.10294080	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
696	trip_6967015cc823c2.90764615	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
697	trip_6967015cc8c4f5.42674348	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
698	trip_6967015cc94403.73145604	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
699	trip_6967015cca0e27.81196448	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
700	trip_6967015ccafc40.73145627	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
701	trip_6967015ccbe973.51041687	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
702	trip_6967015cccbc67.57255690	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
703	trip_6967015ccd5029.12234334	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
704	trip_6967015cce3030.10136522	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
705	trip_6967015ccee7c2.17001484	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
706	trip_6967015ccf5e38.83927736	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
707	trip_6967015cd02369.15308568	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
708	trip_6967015cd0be01.04771192	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
709	trip_6967015cd18a54.04738514	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
710	trip_6967015cd234c4.67751676	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
711	trip_6967015cd314c3.17330257	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
712	trip_6967015cd40a74.86161000	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
713	trip_6967015cd4cc68.72840568	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
714	trip_6967015cd55615.09782641	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
715	trip_6967015cd60934.63585006	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
716	trip_6967015cd6d862.28844971	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
717	trip_6967015cd77bd2.85454591	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
718	trip_6967015cd81cc5.98796601	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
719	trip_6967015cd8d218.06636252	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
720	trip_6967015cd972b9.59565868	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
721	trip_6967015cda4f03.91476709	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
722	trip_6967015cdb0e30.62668180	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
723	trip_6967015cdbf9e5.30365560	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
724	trip_6967015cdc83f9.36535523	1	transporte	\N	\N	6.25180000	-75.56360000	Calle 10	6.25300000	-75.56400000	Carrera 43	2.50	15	completada	2026-01-14 02:37:17	2026-01-14 02:37:17	\N	\N	\N	2026-01-14 02:37:17	\N	\N	f	f	f	\N	15000.00	efectivo	f	\N	0.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
725	69657841-ce9a-4494-b5df-e74001088356	276	transporte	\N	\N	6.25346300	-75.53849300	Cl 64cr 16 127, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	81	pendiente	2026-01-16 02:40:26	2026-01-16 02:40:26	\N	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	161140.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
726	3bb70e8e-e6fa-4a45-9797-b38fa09ebce2	276	transporte	\N	\N	6.25264000	-75.53793800	Cr 17bb 57e-38, 050017 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	81	pendiente	2026-01-16 03:06:06	2026-01-16 03:06:06	\N	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	161140.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
748	5137f71c-a510-4d74-9e9a-2d8666bf7c0d	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 15:04:46	2026-01-18 15:04:46	2026-01-18 15:04:56	2026-01-18 15:05:14	2026-01-18 15:05:52	2026-01-18 15:05:52	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	63225.00	2026-01-18 15:05:08.189171	\N	0.00	36	t	t	moto	1	\N	6000.00
727	af24a0c2-0f09-43f6-b38a-a654e9e1d521	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	cancelada	2026-01-16 19:23:05	2026-01-16 19:23:05	2026-01-16 19:23:30	\N	\N	\N	2026-01-16 19:24:39	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	134534.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
750	23bf8717-6bd1-4ff3-a54d-75fbbd1d5bd6	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 21:01:44	2026-01-18 21:01:44	2026-01-18 21:01:52	\N	\N	\N	2026-01-18 21:02:37	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
728	89e01d90-704b-4dbc-8f9a-32511b94ee41	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	cancelada	2026-01-16 19:58:31	2026-01-16 19:58:31	2026-01-16 19:58:39	\N	\N	\N	2026-01-16 20:04:25	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	134534.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
734	8303b37c-9316-412e-b587-325c5543a6fb	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75589500	-76.02884500	Cañasgordas - Uramita, 057068 Cañasgordas, Antioquia, Colombia	1.33	4	completada	2026-01-17 23:00:27	2026-01-17 23:00:27	2026-01-17 23:00:39	2026-01-17 23:00:54	\N	2026-01-17 23:00:57	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	9185.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
752	5b529dc7-903a-4d36-bfc9-68c7ab998b2b	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 21:17:31	2026-01-18 21:17:31	2026-01-18 21:17:37	\N	\N	\N	2026-01-18 21:19:05	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
754	eb40b09c-2385-4281-a24c-f6a41cda6628	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 21:26:53	2026-01-18 21:26:53	2026-01-18 21:28:06	\N	\N	\N	2026-01-18 21:30:34	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	63225.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
736	57dc6309-c5e3-4f28-9484-f5f67e203d7c	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75385500	-76.02824800	Carrera 28 34a 67, 057060 Cañasgordas, Antioquia, Colombia	0.43	3	completada	2026-01-17 23:32:01	2026-01-17 23:32:01	2026-01-17 23:32:07	2026-01-17 23:32:25	\N	2026-01-17 23:32:28	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	6739.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
756	711d242d-9777-4527-a973-0da37b0e61df	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 22:13:00	2026-01-18 22:13:00	2026-01-18 22:13:15	\N	\N	\N	2026-01-18 22:13:36	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
729	788b114e-b95a-417f-846a-552ac3126736	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	completada	2026-01-16 20:36:47	2026-01-16 20:36:47	2026-01-16 20:37:03	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	134534.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
730	bbaf09a8-e7eb-4b42-91d4-bcd97dc03c80	276	transporte	\N	\N	6.25465300	-75.53949100	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	completada	2026-01-16 21:33:41	2026-01-16 21:33:41	2026-01-16 21:33:49	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	134534.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
731	8fa54fca-307f-4845-895b-6c3b7bbc2bcb	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	completada	2026-01-16 22:11:03	2026-01-16 22:11:03	2026-01-16 22:11:07	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	161440.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
732	14f4d4da-80fc-45fb-be50-d54a19d13ead	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.56514100	-75.83641800	Cañasgordas - Santafé de Antioquia, 057057 Santa Fe de Antioquia, Antioquia, Colombia	55.02	82	completada	2026-01-16 22:21:29	2026-01-16 22:21:29	2026-01-16 22:21:48	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	161440.00	\N	\N	0.00	0	f	f	moto	\N	\N	\N
738	c99a5e21-d86e-408a-a6c8-a1d22d9544c5	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75498400	-76.02748400	Cañasgordas - Uramita, 057060 Cañasgordas, Antioquia, Colombia	1.14	4	completada	2026-01-18 00:26:06	2026-01-18 00:26:06	2026-01-18 00:26:12	2026-01-18 00:26:34	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	8741.00	2026-01-18 00:26:21.094091	\N	0.00	0	f	f	moto	\N	\N	\N
762	855c7950-154f-4175-b18d-611eb40af327	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 23:18:53	2026-01-18 23:18:53	\N	\N	\N	\N	2026-01-18 23:20:05	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
742	b07caacc-644d-4705-bad9-736f8af0e792	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 02:58:11	2026-01-18 02:58:11	2026-01-18 02:58:20	2026-01-18 02:58:37	2026-01-18 03:00:09	2026-01-18 03:00:09	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-18 02:58:31.801829	\N	0.00	1	f	f	moto	\N	\N	\N
740	9c6ee1a0-5270-475f-ae96-e03b028ac4a0	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.75566000	-76.02965500	Carrera 28 37 72, 057060 Cañasgordas, Antioquia, Colombia	0.69	4	completada	2026-01-18 02:08:16	2026-01-18 02:08:16	2026-01-18 02:08:25	2026-01-18 02:08:37	2026-01-18 02:10:13	2026-01-18 02:10:13	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	7654.00	2026-01-18 02:08:34.6578	\N	118.23	1	f	f	moto	\N	\N	\N
744	83cdda62-d619-4b58-baed-43d661019ba6	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-18 13:10:41	2026-01-18 13:10:41	2026-01-18 13:10:47	2026-01-18 13:11:28	2026-01-18 13:12:19	2026-01-18 13:12:19	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	63225.00	2026-01-18 13:10:59.20798	\N	0.00	1	t	t	moto	1	\N	\N
746	33620b1d-0873-44e9-bdd5-fd812ee29a5b	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	conductor_llego	2026-01-18 14:20:15	2026-01-18 14:20:15	2026-01-18 14:20:22	\N	\N	\N	\N	\N	f	f	f	\N	0.00	efectivo	f	\N	63225.00	2026-01-18 14:20:32.515372	\N	0.00	0	f	f	moto	1	\N	\N
764	19bd99ac-6631-4287-8ea4-3553e0e531e3	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-18 23:47:12	2026-01-18 23:47:12	2026-01-18 23:47:18	\N	\N	\N	2026-01-18 23:52:21	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
772	60992ec3-382b-42f7-98e3-37d3767b0d04	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 22:49:51	2026-01-19 22:49:51	2026-01-19 22:49:59	2026-01-19 22:50:28	2026-01-19 22:51:15	2026-01-19 22:51:15	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 22:50:17.802269	\N	0.00	1	t	t	moto	1	\N	6000.00
766	dac02d14-8082-4203-9164-00eb15eabe7f	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 00:00:57	2026-01-19 00:00:57	2026-01-19 00:01:02	2026-01-19 00:02:55	2026-01-19 00:12:07	2026-01-19 00:12:07	\N	\N	f	f	f	\N	7800.00	efectivo	f	\N	75869.00	2026-01-19 00:01:59.33322	\N	0.00	549	t	t	moto	1	\N	6287.50
778	6ecfa46f-7707-4cfc-b7e9-98cd153ff957	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 23:22:27	2026-01-19 23:22:27	2026-01-19 23:22:32	2026-01-19 23:22:45	2026-01-19 23:23:07	2026-01-19 23:23:07	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 23:22:39.90858	\N	0.00	1	t	t	moto	1	\N	6000.00
777	11167664-a1aa-4181-93d8-e36570aeacb3	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-19 23:21:39	2026-01-19 23:21:39	2026-01-19 23:21:45	2026-01-19 23:21:50	\N	\N	2026-01-19 23:22:20	Cancelado por el conductor	f	f	f	\N	0.00	efectivo	f	\N	75869.00	2026-01-19 23:21:47.784176	\N	0.00	26	f	f	moto	1	\N	6000.00
767	3a9e1276-dade-4e46-acf7-09973332a22d	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 03:24:08	2026-01-19 03:24:08	2026-01-19 03:24:14	2026-01-19 03:24:35	2026-01-19 03:26:09	2026-01-19 03:26:09	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 03:24:23.401633	\N	0.00	92	t	t	moto	1	\N	6000.00
773	c0ac9e14-79da-4858-9aa8-33eced978b4f	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-19 22:56:38	2026-01-19 22:56:38	\N	\N	\N	\N	2026-01-19 22:56:54	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
769	97b07103-e39a-4032-a631-2cf6ee9b9706	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 22:21:13	2026-01-19 22:21:13	2026-01-19 22:21:23	2026-01-19 22:22:22	2026-01-19 22:23:22	2026-01-19 22:23:22	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 22:22:03.32894	\N	0.00	1	t	t	moto	1	\N	6000.00
779	e71a330c-ac7f-4811-b498-d56da67790f2	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 00:02:25	2026-01-20 00:02:25	2026-01-20 00:02:32	2026-01-20 00:02:47	2026-01-20 00:03:40	2026-01-20 00:03:40	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 00:02:45.335332	\N	0.00	1	t	t	moto	1	\N	6000.00
768	901473ca-19b2-40a4-9a79-98cd86b814cf	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 03:38:12	2026-01-19 03:38:12	2026-01-19 03:39:26	2026-01-19 03:40:18	2026-01-19 03:40:29	2026-01-19 03:40:29	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 03:39:40.89617	\N	92.96	0	t	t	moto	1	\N	6000.00
770	fd810323-449a-4505-9d00-f627bd7229e4	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-19 22:27:44	2026-01-19 22:27:44	\N	\N	\N	\N	2026-01-19 22:28:26	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	121077.00	\N	\N	0.00	0	f	f	auto	1	\N	\N
771	7ed4b8bd-682a-4cdd-aed9-8434d5a12d10	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-19 22:49:31	2026-01-19 22:49:31	\N	\N	\N	\N	2026-01-19 22:49:42	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	121077.00	\N	\N	0.00	0	f	f	auto	1	\N	\N
780	fd2a442a-4f0c-44c6-a3be-bd09f203145a	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 00:32:46	2026-01-20 00:32:46	2026-01-20 00:32:52	2026-01-20 00:33:03	2026-01-20 00:33:32	2026-01-20 00:33:32	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 00:32:58.760083	\N	0.00	1	t	t	moto	1	\N	6000.00
774	69dec554-b5fb-4b1a-ace1-3f2047ddfc3c	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-19 22:57:02	2026-01-19 22:57:02	\N	\N	\N	\N	2026-01-19 22:57:51	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
781	9418edec-b718-4abc-90d2-844bf11bcfba	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	cancelada	2026-01-20 00:46:48	2026-01-20 00:46:48	2026-01-20 00:46:55	\N	\N	\N	2026-01-20 00:47:11	Cancelado por el cliente	f	f	f	\N	0.00	efectivo	f	\N	75869.00	\N	\N	0.00	0	f	f	moto	1	\N	\N
782	48501c44-14b7-42d2-b415-540fe6067fd2	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 00:51:36	2026-01-20 00:51:36	2026-01-20 00:51:39	2026-01-20 00:51:53	2026-01-20 00:52:14	2026-01-20 00:52:14	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 00:51:48.727922	\N	0.00	1	t	t	moto	1	\N	6000.00
775	b838c07f-0a34-4d03-9fe3-ea38b493f274	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 22:59:29	2026-01-19 22:59:29	2026-01-19 22:59:39	2026-01-19 23:00:00	2026-01-19 23:00:59	2026-01-19 23:00:59	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 22:59:51.132407	\N	92.96	1	t	t	moto	1	\N	6000.00
776	35e52b2a-74c9-4e56-8393-70b2a1d300fb	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-19 23:18:32	2026-01-19 23:18:32	2026-01-19 23:18:39	2026-01-19 23:18:48	2026-01-19 23:19:18	2026-01-19 23:19:18	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-19 23:18:46.369879	\N	0.00	1	t	t	moto	1	\N	6000.00
786	13b4ab22-c287-418a-a0e7-eb2fe2dda0fc	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 01:53:00	2026-01-20 01:53:00	2026-01-20 01:53:11	2026-01-20 01:53:39	2026-01-20 01:54:07	2026-01-20 01:54:07	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 01:53:27.943106	\N	0.00	1	t	t	moto	1	\N	6000.00
785	a42f7a19-8b30-400f-94a1-63ff829262e0	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 01:33:39	2026-01-20 01:33:39	2026-01-20 01:33:53	2026-01-20 01:35:17	2026-01-20 01:36:38	2026-01-20 01:36:38	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 01:35:09.349548	\N	0.00	2	t	t	moto	1	\N	6000.00
783	0e85a3a7-cc39-4e1c-83b6-6bf66bd40376	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 01:03:45	2026-01-20 01:03:45	2026-01-20 01:03:50	2026-01-20 01:04:12	2026-01-20 01:04:46	2026-01-20 01:04:46	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 01:04:05.379051	\N	0.00	1	t	t	moto	1	\N	6000.00
784	35291d5e-210d-4e3e-ae58-819403bcc8e3	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-20 01:19:02	2026-01-20 01:19:02	2026-01-20 01:19:07	2026-01-20 01:19:42	2026-01-20 01:20:29	2026-01-20 01:20:29	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-20 01:19:34.502432	\N	0.00	1	t	t	moto	1	\N	6000.00
787	ed00a03f-70dc-42e8-9042-5a8baa95807b	276	transporte	\N	\N	6.25462700	-75.53948800	Carrera 18B 62-185, 050013 Medellín, Antioquia, Colombia	6.68540050	-75.93167500	Sta. Fe de Antioquia - Cañasgordas, Giraldo, Antioquia, Colombia	24.49	41	completada	2026-01-21 01:37:12	2026-01-21 01:37:12	2026-01-21 01:37:24	2026-01-21 01:37:49	2026-01-21 01:38:49	2026-01-21 01:38:49	\N	\N	f	f	f	\N	6000.00	efectivo	f	\N	75869.00	2026-01-21 01:37:38.047449	\N	0.00	1	t	t	moto	1	\N	6000.00
\.


--
-- TOC entry 6130 (class 0 OID 91158)
-- Dependencies: 289
-- Data for Name: solicitudes_vinculacion_conductor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.solicitudes_vinculacion_conductor (id, conductor_id, empresa_id, estado, mensaje_conductor, respuesta_empresa, procesado_por, creado_en, procesado_en) FROM stdin;
12	277	1	aprobada	\N	\N	255	2026-01-13 20:33:30.115417	2026-01-13 20:48:12.115596
25	278	1	aprobada	Solicitud desde registro de conductor	\N	255	2026-01-14 00:47:31.436741	2026-01-14 13:20:10.556572
26	277	1	pendiente	Solicitud desde registro de conductor	\N	\N	2026-01-14 21:04:53.419857	\N
34	298	1	aprobada	Solicitud desde registro de conductor	\N	255	2026-01-20 03:27:43.510498	2026-01-20 03:29:49.121648
\.


--
-- TOC entry 6150 (class 0 OID 115689)
-- Dependencies: 312
-- Data for Name: tickets_soporte; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tickets_soporte (id, numero_ticket, usuario_id, categoria_id, asunto, descripcion, estado, prioridad, viaje_id, agente_id, created_at, updated_at, resuelto_en, cerrado_en) FROM stdin;
\.


--
-- TOC entry 6122 (class 0 OID 90972)
-- Dependencies: 280
-- Data for Name: tipos_notificacion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tipos_notificacion (id, codigo, nombre, descripcion, icono, color, activo, created_at) FROM stdin;
1	trip_accepted	Viaje Aceptado	Un conductor ha aceptado tu solicitud de viaje	directions_car	#4CAF50	t	2026-01-03 03:08:52.602908
2	trip_cancelled	Viaje Cancelado	Tu viaje ha sido cancelado	cancel	#F44336	t	2026-01-03 03:08:52.602908
3	trip_completed	Viaje Completado	Tu viaje ha finalizado exitosamente	check_circle	#4CAF50	t	2026-01-03 03:08:52.602908
4	driver_arrived	Conductor en Camino	El conductor está llegando a tu ubicación	near_me	#2196F3	t	2026-01-03 03:08:52.602908
5	driver_waiting	Conductor Esperando	El conductor te está esperando	access_time	#FF9800	t	2026-01-03 03:08:52.602908
6	payment_received	Pago Recibido	Tu pago ha sido procesado correctamente	payment	#4CAF50	t	2026-01-03 03:08:52.602908
7	payment_pending	Pago Pendiente	Tienes un pago pendiente por confirmar	pending	#FF9800	t	2026-01-03 03:08:52.602908
8	promo	Promoción	Nueva promoción disponible para ti	local_offer	#9C27B0	t	2026-01-03 03:08:52.602908
9	system	Sistema	Notificación del sistema	info	#607D8B	t	2026-01-03 03:08:52.602908
10	rating_received	Calificación Recibida	Has recibido una nueva calificación	star	#FFC107	t	2026-01-03 03:08:52.602908
11	chat_message	Mensaje Nuevo	Tienes un nuevo mensaje	chat	#2196F3	t	2026-01-03 03:08:52.602908
12	dispute_update	Actualización de Disputa	Hay una actualización en tu disputa	gavel	#FF5722	t	2026-01-03 03:08:52.602908
\.


--
-- TOC entry 6128 (class 0 OID 91031)
-- Dependencies: 286
-- Data for Name: tokens_push_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tokens_push_usuario (id, usuario_id, token, plataforma, device_id, device_name, activo, created_at, updated_at) FROM stdin;
\.


--
-- TOC entry 6081 (class 0 OID 16798)
-- Dependencies: 237
-- Data for Name: transacciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transacciones (id, solicitud_id, cliente_id, conductor_id, monto_tarifa, tarifa_distancia, tarifa_tiempo, multiplicador_demanda, tarifa_servicio, monto_total, metodo_pago, estado_pago, fecha_creacion, fecha_transaccion, completado_en, estado, comision_plataforma, monto_conductor) FROM stdin;
11	647	2	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-21 23:33:21	2025-12-21 23:33:21	completada	5000.00	45000.00
12	655	9	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 23:01:25	2025-12-22 23:01:25	completada	5000.00	45000.00
13	651	4	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 00:55:08	2025-12-22 00:55:08	completada	5000.00	45000.00
14	653	8	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 01:30:35	2025-12-22 01:30:35	completada	5000.00	45000.00
15	654	9	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 22:53:34	2025-12-22 22:53:34	completada	5000.00	45000.00
16	652	6	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 01:18:28	2025-12-22 01:18:28	completada	5000.00	45000.00
17	646	2	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-21 23:30:30	2025-12-21 23:30:30	completada	5000.00	45000.00
18	648	2	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 00:10:53	2025-12-22 00:10:53	completada	5000.00	45000.00
19	650	3	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-22 00:40:25	2025-12-22 00:40:25	completada	5000.00	45000.00
20	645	2	7	0.00	0.00	0.00	1.00	0.00	50000.00	efectivo	completado	2025-12-23 00:19:29	2025-12-21 23:23:54	2025-12-21 23:23:54	completada	5000.00	45000.00
21	657	2	7	0.00	0.00	0.00	1.00	0.00	38000.00	efectivo	completado	2025-12-23 00:22:08	2025-12-23 00:22:08	2025-12-23 00:22:08	completada	3800.00	34200.00
22	661	9	7	0.00	0.00	0.00	1.00	0.00	62062.94	efectivo	completado	2025-12-23 03:10:20	2025-12-23 03:10:20	2025-12-23 03:10:20	completada	6206.29	55856.64
23	662	9	7	0.00	0.00	0.00	1.00	0.00	61236.60	efectivo	completado	2025-12-23 03:17:13	2025-12-23 03:17:13	2025-12-23 03:17:13	completada	6123.66	55112.94
24	733	276	277	0.00	0.00	0.00	1.00	0.00	291440.84	efectivo	completado	2026-01-17 22:48:28	2026-01-17 22:48:28	2026-01-17 22:48:28	completada	29144.08	262296.76
\.


--
-- TOC entry 6082 (class 0 OID 16812)
-- Dependencies: 238
-- Data for Name: ubicaciones_usuario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ubicaciones_usuario (id, usuario_id, latitud, longitud, direccion, ciudad, departamento, pais, codigo_postal, es_principal, creado_en, actualizado_en) FROM stdin;
1	1	6.25461830	-75.53955670	Carrera 18B, Llanaditas, Comuna 8 - Villa Hermosa, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-09-29 21:11:52	\N
2	2	6.24546848	-75.54230341	Carrera 24BB, Cra 44BB#56EE 13, El Pinal, Comuna 8 - Villa Hermosa, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-10-06 22:47:34	\N
3	3	6.25504918	-75.53958122	Carrera 18B, Llanaditas, Comuna 8 - Villa Hermosa, Medellín, Antioquia, Colombia	Medellín	Antioquia	Colombia	\N	1	2025-10-06 23:13:22	\N
4	4	6.25490278	-75.54003060	Carrera 18B, Llanaditas, Comuna 8 - Villa Hermosa, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-10-19 16:39:10	\N
5	5	6.29540531	-75.54965768	Carrera 43B, Granizal, Comuna 1 - Popular, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-10-20 22:37:37	\N
6	6	6.25461830	-75.53955670	Carrera 18B, 62 - 191, Llanaditas, Comuna 8 - Villa Hermosa, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-10-22 14:08:47	\N
7	7	6.25461830	-75.53955670	Carrera 18B, 62 - 191, Llanaditas, Comuna 8 - Villa Hermosa, Perímetro Urbano Medellín, Antioquia, Colombia	Perímetro Urbano Medellín	Antioquia	Colombia	\N	1	2025-10-22 14:10:55	\N
8	8	6.24465400	-75.56650400	Dirección de Prueba	Medellín	Antioquia	Colombia	\N	1	2025-10-27 00:04:52	\N
9	9	6.24465400	-75.56650400	Dirección de Prueba	Medellín	Antioquia	Colombia	\N	1	2025-10-27 00:06:16	\N
\.


--
-- TOC entry 6083 (class 0 OID 16825)
-- Dependencies: 239
-- Data for Name: user_devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_devices (id, user_id, device_uuid, first_seen, last_seen, trusted, fail_attempts, locked_until) FROM stdin;
18	235	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2026-01-04 02:49:44	2026-01-04 02:49:59	1	0	\N
12	226	e381cf27-557a-56e6-b75b-8db8018535ea	2025-12-25 16:58:32	2025-12-30 22:38:10	0	0	\N
13	226	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2025-12-25 21:24:28	2026-01-01 23:03:08	1	0	\N
42	280	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 01:36:43	2026-01-14 01:42:23	1	0	\N
43	298	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2026-01-20 03:06:50	2026-01-20 03:07:03	1	0	\N
20	236	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2026-01-04 03:14:10	2026-01-04 03:14:25	0	0	\N
21	236	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-04 15:56:45	2026-01-04 15:56:54	1	0	\N
9	6	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2025-12-23 02:52:15	2026-01-01 20:32:05	0	0	\N
16	234	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-04 00:44:19	2026-01-04 00:44:31	0	0	\N
17	234	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2026-01-04 01:00:54	2026-01-04 01:01:10	1	0	\N
1	1	885b76e4-1a2d-454f-9f69-45a7638a1ef0	2025-11-08 22:27:47	2025-11-08 22:46:13	0	0	\N
8	1	test-device-999	2025-12-23 02:51:50	\N	0	1	\N
14	1	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2025-12-26 23:02:00	2026-01-02 03:20:13	0	0	\N
11	1	e381cf27-557a-56e6-b75b-8db8018535ea	2025-12-24 02:42:55	2026-01-04 01:29:10	1	0	\N
7	6	e381cf27-557a-56e6-b75b-8db8018535ea	2025-11-29 00:40:41	2026-01-08 23:33:01	1	0	\N
5	7	885b76e4-1a2d-454f-9f69-45a7638a1ef0	2025-11-09 02:52:16	2025-11-11 12:12:08	0	0	\N
10	7	5b6c1bac-2efb-55ae-8e03-4448fb1f52b5	2025-12-23 03:05:36	2025-12-23 23:52:45	0	0	\N
6	7	e381cf27-557a-56e6-b75b-8db8018535ea	2025-11-09 23:38:06	2025-12-29 20:47:30	1	0	\N
35	254	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-10 02:28:00	\N	1	0	\N
36	276	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-13 16:02:05	2026-01-13 16:03:01	1	0	\N
37	279	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 00:40:55	\N	1	0	\N
38	281	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 00:45:55	\N	1	0	\N
39	283	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 01:22:46	\N	1	0	\N
40	285	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 01:27:46	\N	1	0	\N
41	287	e381cf27-557a-56e6-b75b-8db8018535ea	2026-01-14 01:32:03	\N	1	0	\N
\.


--
-- TOC entry 6084 (class 0 OID 16835)
-- Dependencies: 240
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios (id, uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, foto_perfil, fecha_nacimiento, es_verificado, es_activo, fecha_registro, fecha_actualizacion, ultimo_acceso_en, tiene_disputa_activa, disputa_activa_id, empresa_id, empresa_preferida_id, calificacion_promedio, estado_vinculacion, google_id, apple_id, auth_provider) FROM stdin;
9	test_68feb77859998	Usuario	Prueba	test9034@example.com	3002706622	$2y$12$moeVRC4/at8LCvDkjHG4O.nGY94exZiqjRxTJc87Qe4BFap1QhgNW	cliente	\N	\N	0	1	2025-10-27 00:06:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
10	627acc09-0698-4379-849b-5d2fa43ce2ce	Usuario	Prueba	usuario.prueba@test.com	+573001234567	$2y$12$Yop4But6l2Mypc27SOHFneOsCnJ37cQ3ybUF4pV1gn/f9Lg4AIVUO	cliente	\N	\N	0	1	2025-10-27 00:27:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
12	bdd5da21-bd46-421b-9995-d6cc91a18703	Usuario	Test	usuario.test@ping.go	+573000000000	$2y$12$hPQETI8DY5/d4z/l4umuRuKQ2.x5WzOtkteWxTLxfNHgYXeKpLjuC	cliente	\N	\N	0	1	2025-10-27 00:34:39	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
13	user_69094c4af36515.15515353	usuario	oquendo	usuario@gmail.com	423432443	$2y$10$eRmX0cTeKUxCaqQC2WoymeSwt6vJYWVQc2E6a.Jc4t3owrT7FAglu	cliente	\N	\N	0	1	2025-11-04 00:43:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
14	test_690fc54c139117.99043866	Test	Device	test_device@viax.com	9999999999	$2y$12$uSnNV9H0SI6Uzfk2wATJeumxlFdxJ/m.DDg3vVnx7aZZf3c4EW5ie	cliente	\N	\N	0	1	2025-11-08 22:33:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
15	4d1f0e38-4a45-40dd-94e4-eda6848ea776	ClienteHot	Test1	cliente_hot_1_1764713379_0@test.local	+5009104844	$2y$12$86U62b807isLWBmpo4UBI.esiGy7OD0O/2.xRY6HBKFm7WHnXpKQK	cliente	\N	\N	0	1	2025-12-02 22:09:40	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
16	f30672dd-2d8e-4b5c-bd17-eb8872572b9a	ClienteHot	Test1	cliente_hot_1_1764713379_1@test.local	+5001211662	$2y$12$xRUJ2naS1PsMisjg4HRzlu41L59TjhmsiYXFCN6aRYQPm0waIpEvO	cliente	\N	\N	0	1	2025-12-02 22:09:40	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
17	cf639c02-48a7-4a33-83ab-a970e1a699a4	ClienteHot	Test1	cliente_hot_1_1764713379_2@test.local	+5006001224	$2y$12$vZbHEBfwinioHVlEVRbFdO15A9nCWXW2r8RyylguHcQXyqnf.gQlW	cliente	\N	\N	0	1	2025-12-02 22:09:40	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
18	01fb1d50-c731-4a6d-aa7a-c0e3ef383dbe	ClienteHot	Test1	cliente_hot_1_1764713380_3@test.local	+5006838906	$2y$12$bZy7LflRjNn2AxOgr6ouyuIUv0yY37AsqmaEbpKhJ09SLDuvMUf2.	cliente	\N	\N	0	1	2025-12-02 22:09:40	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
19	0523da03-90ce-4cc7-afd6-5339b1b68ca0	ClienteHot	Test1	cliente_hot_1_1764713380_4@test.local	+5008174689	$2y$12$1jYo2FJxZL2jv.fCk/kAcuwKFigP6jLebjvzhfD1UOEN762QhqgIy	cliente	\N	\N	0	1	2025-12-02 22:09:40	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
20	46bdd23e-fcff-43f0-9f30-9d3b5b81d289	ClienteHot	Test1	cliente_hot_1_1764713380_5@test.local	+5001142062	$2y$12$hDZKu2Yx0S18eSVDQ0kW9unZ6iGJFStv1ipU0pPhKwkKH8M.XNpFC	cliente	\N	\N	0	1	2025-12-02 22:09:41	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
21	2fe638f2-da37-4813-87fd-3c133a962488	ClienteHot	Test1	cliente_hot_1_1764713380_6@test.local	+5007009623	$2y$12$NUvW9ViK96es4xWKVZL3/etT7z4hzAMRQgHuk7r98wDoE9Y1b9s4S	cliente	\N	\N	0	1	2025-12-02 22:09:41	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
22	86290a3d-e26e-4c27-8b38-eb2e94174828	ClienteHot	Test1	cliente_hot_1_1764713380_7@test.local	+5009244593	$2y$12$cqymC1c9AD9FEgMhscmD9u82YD9eHa1FnqffR7K9Hxs/XWeBwFlLe	cliente	\N	\N	0	1	2025-12-02 22:09:41	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
23	eab0ef89-5ac0-436e-ae57-287dd0bde25d	ClienteHot	Test1	cliente_hot_1_1764713380_8@test.local	+5008002577	$2y$12$NwA4NDsdNZqNDQeueuTiL.X5xLD8sfSSthq9dU0N6flts9PnHrYz6	cliente	\N	\N	0	1	2025-12-02 22:09:41	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
24	03c47bba-b183-4e43-b854-4ce93968f3fb	ClienteHot	Test1	cliente_hot_1_1764713381_9@test.local	+5007712245	$2y$12$.vCDt28mmNz0oUJI44aoAOuWRZrDtRRx9r92WQsrR4jNT.txNTn7S	cliente	\N	\N	0	1	2025-12-02 22:09:41	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
25	58253d87-a8df-4f8d-82ea-4b0693692d1e	ClienteHot	Test1	cliente_hot_1_1764713381_10@test.local	+5006138174	$2y$12$TustY.T9bTCXsgDGu8kdNeItizcZLeKvF9yubGQ1jpeInQudEzJd2	cliente	\N	\N	0	1	2025-12-02 22:09:42	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
26	11ae569f-6495-4b49-a003-2c4cd7f46171	ClienteHot	Test1	cliente_hot_1_1764713381_11@test.local	+5006996751	$2y$12$0QYvM4wWuE4grWWbdF1LVuFb7uwsjedSVQuir8nVZGmrfFwl073Cq	cliente	\N	\N	0	1	2025-12-02 22:09:42	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
27	1f135c46-f4ad-4831-b2e6-7c90256011e4	ClienteHot	Test1	cliente_hot_1_1764713381_12@test.local	+5003291430	$2y$12$.ZZOWaOFO8FJntwNRVgZBuUG43EIP9oXEzPHxF.R1xbU4bqq2Jtzi	cliente	\N	\N	0	1	2025-12-02 22:09:42	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
28	0b8abe52-7811-4508-9f4f-4d3b8fef8711	ClienteHot	Test1	cliente_hot_1_1764713381_13@test.local	+5004301803	$2y$12$tRx/CJXDvXdl0Fi2G9cVKe11FgX2AD6lqgqkMwaGLi69SsVYVAtU.	cliente	\N	\N	0	1	2025-12-02 22:09:42	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
29	ab01eb40-b7f1-4592-9722-eedbae24cae3	ClienteHot	Test1	cliente_hot_1_1764713382_14@test.local	+5006818856	$2y$12$KJ68DkFQOkXgmn/dXkKCdOJuPCBoj.tfmhQCAK7wyqFh3DOE9WAT6	cliente	\N	\N	0	1	2025-12-02 22:09:42	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
30	3907399d-1d60-4f2c-a500-e281e51e5252	ClienteHot	Test1	cliente_hot_1_1764713382_15@test.local	+5004051197	$2y$12$CA.2mVUk36rSEx46sUpIC.kTytaKMJ8X0TJ7/52h2vYpY1h4vElY.	cliente	\N	\N	0	1	2025-12-02 22:09:43	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
31	d8e9d68e-db63-45c8-95aa-37e7a69d5f47	ClienteHot	Test1	cliente_hot_1_1764713382_16@test.local	+5006609148	$2y$12$WSn2s//pod3x8ujxoOy7A.bSXgPwVJonD6oWwgbpoVUtwcVzj0/uK	cliente	\N	\N	0	1	2025-12-02 22:09:43	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
32	88059d1a-4f5d-4722-a02d-8ef80ec1a610	ClienteHot	Test1	cliente_hot_1_1764713382_17@test.local	+5006424500	$2y$12$65RtkItopEK5c5ybhV4X0uMMXjcByHEDaAOpoBQ25vLq45zIK4WCK	cliente	\N	\N	0	1	2025-12-02 22:09:43	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
33	c8f6ec36-426b-43a8-820c-9fd309bb63cc	ClienteHot	Test1	cliente_hot_1_1764713382_18@test.local	+5006069908	$2y$12$J1F4a6s1R4yuYi8Z4ARp0uKjwb67FScrC3wfzFQuBsMOdeJtt/Hd2	cliente	\N	\N	0	1	2025-12-02 22:09:43	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
34	fa4cd50f-3a7e-4752-9302-5bc9fb5031b2	ClienteHot	Test1	cliente_hot_1_1764713383_19@test.local	+5007619693	$2y$12$UZT.TOL2lIK0.AccihGH2Om65Cn8d/5FinmAxgGadJbxHR8mzshvW	cliente	\N	\N	0	1	2025-12-02 22:09:43	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
35	92238023-bf60-4c3c-9061-e0965963f5de	ClienteHot	Test1	cliente_hot_1_1764713383_20@test.local	+5002382823	$2y$12$T.Lff/ESm7zPQQUWTo1VmecgO5ATtADbpQ2w7bZqWAv6sa5OY/TOC	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
36	f8313d58-1045-4c44-8a3b-5828dc4af7a4	ClienteHot	Test1	cliente_hot_1_1764713383_21@test.local	+5003478231	$2y$12$Xw9twwIFMQuvrd4RxfmvqOZyxfM0mkGLHxHERcYPMVo2xHp6wBVze	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
3	user_68e44d12079086.97442308	braianoquen79	oquendo	braianoquen79@gmail.com	34343434	$2y$10$6LhMx5vHi.3LrrM/EjFjw.ZztZWhhGQgqf1sD76h2RtJ4B7nN/sjC	cliente	\N	\N	0	1	2025-10-06 23:13:22	\N	\N	t	2	\N	\N	5.00	activo	\N	\N	email
4	user_68f5142e614579.71603626	braianoquen323	oquendo	braianoquen323@gmail.com	213131313131	$2y$10$qSZ1igIQd1BQJmq.MRMwM.2EUfUYhvXhsf4g0h7GJJDJ8uaR66/qy	cliente	\N	\N	0	1	2025-10-19 16:39:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
8	test_68feb7247e181	Usuario	Prueba	test5300@example.com	3004267353	$2y$12$IaYB.Y6RT7mjqA5ZQCKAi.KhAmswTlSHW2n/k1OY7hXF47knzU8Je	cliente	\N	\N	0	1	2025-10-27 00:04:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
6	user_68f8e56f0736b2.62296910	braianoquendurango	oquendo	braianoquendurango@gmail.com	323121	$2y$10$DDOIUEJ8jv1ILAu7PKj3LutCGRru.7sVUs2himDiKZ4yqY.VtvRb6	cliente	\N	\N	0	1	2025-10-22 14:08:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
5	user_68f6b9b1f1cb28.57297864	braianoquen324	oquendo	braianoquen324@gmail.com	4274672	$2y$10$Oji7gxZcVki50Pyk5aReKexUhCGPbXLGNe.rsnlzAaZvI.Bo.UexS	conductor	\N	\N	0	0	2025-10-20 22:37:37	2025-10-27 04:26:37	\N	f	\N	\N	\N	5.00	pendiente_empresa	\N	\N	email
37	affa63ca-c382-42f6-9ade-d493cf3cb5af	ClienteHot	Test1	cliente_hot_1_1764713383_22@test.local	+5001597633	$2y$12$R4QdwfQVd4x2mOCYflmwHeW8wzhzeGlcEpnoJKwDL4nrN90mq8yOO	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
38	1592438d-a341-4020-b3df-fa3011eb85eb	ClienteHot	Test1	cliente_hot_1_1764713383_23@test.local	+5002968366	$2y$12$RZqEML4FBHtb1QBY9xntx.52uab54F.qDKYFksvP58z10V1M/KOIC	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
39	a9d7ce75-af90-4665-a179-6b49d74b1688	ClienteHot	Test1	cliente_hot_1_1764713384_24@test.local	+5002348959	$2y$12$/vVCAGassogDXY6TkmKzdugmT9DwdVEkPXUvwLYIBVsIXBnI5DQ5u	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
40	81537948-74e7-4e5a-969f-3326ff036779	ClienteHot	Test1	cliente_hot_1_1764713384_25@test.local	+5008734481	$2y$12$6BnC0U9se.ks5l.oN2UEeeroVFvxpMM06h0IJahFpbNSKcf2R9mQ.	cliente	\N	\N	0	1	2025-12-02 22:09:44	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
41	8ecc0d91-bd6e-4101-a634-41f5042eb0da	ClienteHot	Test1	cliente_hot_1_1764713384_26@test.local	+5006228576	$2y$12$.yjbKCQewyE0aq6D453T5ONeQkCd00jWKzF21Ol5Nx4UEwXjyGbiO	cliente	\N	\N	0	1	2025-12-02 22:09:45	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
42	b6484bb0-1e04-46a7-beab-30bd58d3b0bd	ClienteHot	Test1	cliente_hot_1_1764713384_27@test.local	+5006270779	$2y$12$FAEnuEZ5CaPpyPXt6EB2nOy6DcSKFNiik3L8ksO9KFxad7.f7.rtO	cliente	\N	\N	0	1	2025-12-02 22:09:45	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
43	8dc6d018-098b-4d30-b20f-d1fa44802afc	ClienteHot	Test1	cliente_hot_1_1764713384_28@test.local	+5005625005	$2y$12$MNMNJn1G1HFmx0eHZ89fBOFWfZoFiKycZH2ZJZMP1Y0EQt.r4GK6a	cliente	\N	\N	0	1	2025-12-02 22:09:45	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
44	c4fed59b-2922-4946-a224-34f529f15cf4	ClienteHot	Test1	cliente_hot_1_1764713385_29@test.local	+5005317878	$2y$12$8iBV5cp9C35sEdPvLQYXlO2Ft0n53yXVwpHfBKMQv872ylSi4CKH2	cliente	\N	\N	0	1	2025-12-02 22:09:45	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
45	285688df-369c-4303-878f-513ea7de15f8	ClienteHot	Test1	cliente_hot_1_1764713385_30@test.local	+5008401635	$2y$12$ujJiGOe6daefDB7h2RG7E.mmpTpcedcWGv3C8A/MuwEWgJaDttvKm	cliente	\N	\N	0	1	2025-12-02 22:09:45	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
46	bf18ba45-1ecc-4003-8987-44dd9c4e200c	ClienteHot	Test1	cliente_hot_1_1764713385_31@test.local	+5004360340	$2y$12$.UScobI2lasHv1DQvK6bbuOvvtHy4n6nc./hW29prsCwOTenYrPxm	cliente	\N	\N	0	1	2025-12-02 22:09:46	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
47	b893cf64-00f3-4439-b834-bf6dc63977eb	ClienteHot	Test1	cliente_hot_1_1764713385_32@test.local	+5004623641	$2y$12$YnHhjnPqkDkaWNiWkvDhveu4q0tPly6YR9y2oj.fNBY7LsBvminnW	cliente	\N	\N	0	1	2025-12-02 22:09:46	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
48	8d33df7d-dcd3-47fe-b74e-1966bb24b1ff	ClienteHot	Test1	cliente_hot_1_1764713385_33@test.local	+5004211825	$2y$12$s6JFOLYbFLrPpGojSbK9ieYUzo4RRYc8bkyPVry0nFaerdeQSiIim	cliente	\N	\N	0	1	2025-12-02 22:09:46	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
49	efc93dce-6363-43db-96b3-ccd46dcf43a1	ClienteHot	Test1	cliente_hot_1_1764713386_34@test.local	+5003236445	$2y$12$HiGQHKDGtLhi9G7vDEFC7OpLpXY1H3miK74bm7ZmKF7qDlr8Tcv.C	cliente	\N	\N	0	1	2025-12-02 22:09:46	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
50	e5fb48fc-c420-4807-82f9-015ee27968fb	ClienteHot	Test1	cliente_hot_1_1764713386_35@test.local	+5005475476	$2y$12$RtoFGk4vDiGer/pSI0Wd1.u2v8NkjfpQxdMwXhvZcWkzDMiNefTG2	cliente	\N	\N	0	1	2025-12-02 22:09:46	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
51	c6a88796-58c1-42a9-bf57-de2460aaa96b	ClienteHot	Test1	cliente_hot_1_1764713386_36@test.local	+5005352949	$2y$12$lz6ngBTWQ80leNCC1RDxyeHtgbQR7s7ISTjjW1aHombVCbVd/afJu	cliente	\N	\N	0	1	2025-12-02 22:09:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
52	9879e4ad-a5ec-450a-842c-c33f049063f2	ClienteHot	Test1	cliente_hot_1_1764713386_37@test.local	+5002530223	$2y$12$Hbv0dJJbBVh2.QGGSfY2Ru319q16usvYshSogMPeDSx63xWNKoUnm	cliente	\N	\N	0	1	2025-12-02 22:09:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
53	738943ad-92a2-4cfe-ba38-6c1ae8f5b1e9	ClienteHot	Test1	cliente_hot_1_1764713386_38@test.local	+5003440748	$2y$12$O2QXgb1ECpi9dVb8IBWG..cGt0IGwTjahUYOer19DZzCdSsd3d3XO	cliente	\N	\N	0	1	2025-12-02 22:09:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
54	7460bd30-e9f6-4a38-9b67-f4fbcdcda90d	ClienteHot	Test1	cliente_hot_1_1764713387_39@test.local	+5001649756	$2y$12$6aw0RNu23BSK5A.zcGvgE.gZEbin8cCDY2ag4HzS3EYvDKT1DLsZy	cliente	\N	\N	0	1	2025-12-02 22:09:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
55	efaa6042-e3a2-480c-a93f-6140ccb3ae45	ClienteHot	Test1	cliente_hot_1_1764713387_40@test.local	+5003082726	$2y$12$skP7WJyQWCGhpgxp9M/3Z.8StZvd1Mxq.OEDuhLQXOwvJb8ctdemu	cliente	\N	\N	0	1	2025-12-02 22:09:47	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
56	8264384d-8c46-41ca-862e-825669069c90	ClienteHot	Test1	cliente_hot_1_1764713387_41@test.local	+5006277705	$2y$12$x28XB/3FFhgk7fNioV5fqOcMb4qGdK5W0Ik9g3RDTUBYbXXrGz6n2	cliente	\N	\N	0	1	2025-12-02 22:09:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
57	196f5042-a25d-4ead-b29d-5ac8077edaa4	ClienteHot	Test1	cliente_hot_1_1764713387_42@test.local	+5004049317	$2y$12$IvkC75u2/qHivs9ej.tYQOnrFYqXSUXYPi95gUB0opIAC2YgwN5hS	cliente	\N	\N	0	1	2025-12-02 22:09:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
58	d92c9a0a-9e55-4bff-8e5f-b268cc5ed35b	ClienteHot	Test1	cliente_hot_1_1764713387_43@test.local	+5005237698	$2y$12$roNZdG5MjJc4zCg8RVqw0u8FvimVKAMUq1PokYlylLXyyLbEvi1qi	cliente	\N	\N	0	1	2025-12-02 22:09:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
59	a25e7e2d-36e9-4349-86a7-c808727ea613	ClienteHot	Test1	cliente_hot_1_1764713387_44@test.local	+5004216410	$2y$12$JiNecwKg/NyjuRBcQlM8Be1c7SVlUvEFT71/blIe7E.4U.Pt9Z9la	cliente	\N	\N	0	1	2025-12-02 22:09:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
60	2aea7cff-6323-4c1e-b167-54fdd8937df8	ClienteHot	Test1	cliente_hot_1_1764713388_45@test.local	+5005585342	$2y$12$VensHS.TCBhq052gbH0kx.fmp2QVcROSlc3q.gEBDc9aKrfnqf49e	cliente	\N	\N	0	1	2025-12-02 22:09:48	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
61	683b9345-fcf4-4671-9304-ede67964d8e8	ClienteHot	Test1	cliente_hot_1_1764713388_46@test.local	+5005198409	$2y$12$YJ1APn2IKwTMhYiEWn9XhuVb9R7aCTSxeAfIMQk3XWXbHytqOtQVO	cliente	\N	\N	0	1	2025-12-02 22:09:49	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
62	68682b30-a65b-4870-870a-0dc95646e447	ClienteHot	Test1	cliente_hot_1_1764713388_47@test.local	+5009729973	$2y$12$B8rUcCTFwQzXMSR9WxCisuM0ZdM9xFU/floi5471MQY2MWrY1im1S	cliente	\N	\N	0	1	2025-12-02 22:09:49	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
63	f940c10b-71c3-4098-822f-df628b534a1d	ClienteHot	Test1	cliente_hot_1_1764713388_48@test.local	+5007018271	$2y$12$Te/tYwCyuwFwUSxS1bYlzOO6SkPpdJQ90cJEadGGKjYvj6yxY3Cp6	cliente	\N	\N	0	1	2025-12-02 22:09:49	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
64	f035b948-269c-471f-920c-d16f28fc03cd	ClienteHot	Test1	cliente_hot_1_1764713388_49@test.local	+5009320974	$2y$12$xwyrtvGsb7YiJUL/c4xZh.tE/pWV/qrRCqX8lfl.P71FXJpT4OQW2	cliente	\N	\N	0	1	2025-12-02 22:09:49	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
65	1269b9fa-4843-4c96-9150-c346c0626b88	ClienteHot	Test1	cliente_hot_1_1764713389_50@test.local	+5008223085	$2y$12$jo/tAzhbh1.w5pS9uCtX9OS23ux5ShsYuI.e0o3tqKm.dyj0lfLgK	cliente	\N	\N	0	1	2025-12-02 22:09:49	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
66	ad91f307-3255-4866-ac31-71727791ae59	ClienteHot	Test1	cliente_hot_1_1764713389_51@test.local	+5002990851	$2y$12$KZNgSvjPvKqIgNanmXxD3eqCZcBAa4wKXM5uCraY4IjaUVNlfOOAm	cliente	\N	\N	0	1	2025-12-02 22:09:50	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
67	5e5892a3-4b69-429c-a33d-4ae0827cbfc2	ClienteHot	Test1	cliente_hot_1_1764713389_52@test.local	+5008301585	$2y$12$U2eD3EpEYeorzA8ObeWTLuoR2.OPWPObSTxZCZ6WRoHpmgFOdRbem	cliente	\N	\N	0	1	2025-12-02 22:09:50	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
68	5ff7b595-93b7-4872-a5f3-13f626435ff9	ClienteHot	Test1	cliente_hot_1_1764713389_53@test.local	+5005550189	$2y$12$5yipdArFAGhnV.ipsRmFZOXAWGZ6k4RWFPfDXNVImGuqUVfbhcExS	cliente	\N	\N	0	1	2025-12-02 22:09:50	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
69	1fa36d5a-0360-41e6-8651-80647017fa5b	ClienteHot	Test1	cliente_hot_1_1764713389_54@test.local	+5005344435	$2y$12$EDPeTrpmOxDUeJy8FnRED.OEqDfkqVYfDArvp4eIk8jEGiMcENSYO	cliente	\N	\N	0	1	2025-12-02 22:09:50	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
70	f1e471d9-3039-4a7e-8650-565ac050200a	ClienteHot	Test1	cliente_hot_1_1764713390_55@test.local	+5006517567	$2y$12$74d6yDtvBG8xaP8aW61/9e.ziU4VxP8r.UsWIFhWbtFqlPnam9NXu	cliente	\N	\N	0	1	2025-12-02 22:09:50	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
71	b4ea7922-f067-45ab-b555-d23db095795d	ClienteHot	Test1	cliente_hot_1_1764713390_56@test.local	+5003084387	$2y$12$HCpImFWAE0IOyIACHl.Eg.2KFA2dQzk.QQzAmQfDr9M4eJS61JuGy	cliente	\N	\N	0	1	2025-12-02 22:09:51	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
72	ec59ded0-3a46-416e-b8b7-ffef8ad79355	ClienteHot	Test1	cliente_hot_1_1764713390_57@test.local	+5006740899	$2y$12$IwRlARV1EsDxYKaOWZNlOubrS18CrWU9Fg8MilUqVUUkTriNWSMLK	cliente	\N	\N	0	1	2025-12-02 22:09:51	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
73	6ce08439-3f74-4c00-8326-06448f763b57	ClienteHot	Test1	cliente_hot_1_1764713390_58@test.local	+5002856278	$2y$12$wfq605Ajyo5.waQK9zHxEOO3l2Y8gdfU75rqx76n1uXwyTQte/9yS	cliente	\N	\N	0	1	2025-12-02 22:09:51	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
74	68f83530-1061-4ed2-86fe-22ad380becc5	ClienteHot	Test1	cliente_hot_1_1764713390_59@test.local	+5003598193	$2y$12$5a9bYIWnLMYc1WZNFvbOkeQjk3En88RSa34iNFgaYOZ2RT4cuQdJS	cliente	\N	\N	0	1	2025-12-02 22:09:51	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
75	0b1afe09-d4a2-403d-81ba-7b86e7e434b0	ClienteHot	Test1	cliente_hot_1_1764713391_60@test.local	+5008293270	$2y$12$JahK8F3sme16IT8LzHxz7uvLahpuS8I4Jc07WJvrFnnHo73AXixBa	cliente	\N	\N	0	1	2025-12-02 22:09:51	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
76	905eb5b1-1930-4a9c-85a0-5d529093a74d	ClienteHot	Test1	cliente_hot_1_1764713391_61@test.local	+5008836802	$2y$12$9vri.EZMdtBLcxpr/MkR2e5B8rx4Kvvd30s8CEg6L3QkrbY/aWKaC	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
77	41db7253-d841-41c4-9db3-e5cd76e1cfcb	ClienteHot	Test1	cliente_hot_1_1764713391_62@test.local	+5006925520	$2y$12$TAa0/hQQPg/.cmkZ8WxHw.Y3znthHzoWm2bh6zXdnH.37fKUbQloa	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
78	85ed401c-6b66-4b19-9596-0232f5f33e60	ClienteHot	Test1	cliente_hot_1_1764713391_63@test.local	+5009044093	$2y$12$kfF.zBZimnPa/IykrsPDqepn6wl/w.p9JPhob6JyMWkwpzfNXjT4.	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
79	55356da0-c577-4e51-82f1-3d3f64fece96	ClienteHot	Test1	cliente_hot_1_1764713391_64@test.local	+5002589861	$2y$12$8ltPINbCurWRzS1qklKYOO2YeIua8qDPB1UZFbLmQ9Irf4Qr1CIeC	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
80	1492b9fc-2cd4-4d65-b545-297e839026c4	ClienteHot	Test1	cliente_hot_1_1764713392_65@test.local	+5007326280	$2y$12$IM/l5nMo41V7bx59ujDrFe.HlNwkiZqNSqgrt94O5pSwW2jx1hbJ2	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
81	2addc54e-fcf7-4abb-a187-3a2be007bb0f	ClienteHot	Test1	cliente_hot_1_1764713392_66@test.local	+5004170503	$2y$12$e24wI8Kxq6SNmUm35yS7KeUaEk3CBUHO2dnLJFZyWMaU6jz7rCQ8O	cliente	\N	\N	0	1	2025-12-02 22:09:52	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
82	0866f6dd-b0f5-40a1-bbe0-f464143fb7b3	ClienteHot	Test1	cliente_hot_1_1764713392_67@test.local	+5004493207	$2y$12$dYMEfRJYWWaXxuHucfG5ROW/ZrscBfQUL.eX1mNchte0Gb.wIgUsu	cliente	\N	\N	0	1	2025-12-02 22:09:53	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
83	81f94ab0-03d9-4882-bbc1-343a424a98a0	ClienteHot	Test1	cliente_hot_1_1764713392_68@test.local	+5009437113	$2y$12$1SCemReP9R84soWk4E/2wuVZVXLjWlviYbFFCVOHifkiX5QCug072	cliente	\N	\N	0	1	2025-12-02 22:09:53	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
84	a202a607-d118-4107-9aeb-3bde40e5aaeb	ClienteHot	Test1	cliente_hot_1_1764713392_69@test.local	+5001959155	$2y$12$/vJBaTEv22EyCZMR2.uu7.hULd.bbm2P8Il0OPLM581lQA/rnZrC.	cliente	\N	\N	0	1	2025-12-02 22:09:53	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
85	b21a9583-d77d-4e18-ae31-adee7fa91aca	ClienteHot	Test2	cliente_hot_2_1764713393_0@test.local	+5004541762	$2y$12$UhxlzGdTD3KKCS3NMQUeuuszuJwHZMIxA2.75hio2nZ5FuQyCNPKi	cliente	\N	\N	0	1	2025-12-02 22:09:53	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
86	73113de6-d9d9-4f01-b508-e44e0326bae1	ClienteHot	Test2	cliente_hot_2_1764713393_1@test.local	+5004724977	$2y$12$4xgFWNazUR5d32RyerjJ5e2gZdEeUK6IAdpHc6rsxQ/HuTsOfcgSu	cliente	\N	\N	0	1	2025-12-02 22:09:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
87	f76be3d8-0c19-4a36-aaf5-82a52f000250	ClienteHot	Test2	cliente_hot_2_1764713393_2@test.local	+5003409744	$2y$12$Ed8WQA4cf51fdx0CjA48MeF13f3TX66BJtAFw3XjIye28IoWlzu7S	cliente	\N	\N	0	1	2025-12-02 22:09:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
88	1bea07ea-4412-414b-99b7-a9ff4ad2863c	ClienteHot	Test2	cliente_hot_2_1764713393_3@test.local	+5008602972	$2y$12$E47mc6ccAswaKG/hILCA5OCS8cf67KFt2Ds4VO55Wat1c4JcTYt.O	cliente	\N	\N	0	1	2025-12-02 22:09:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
89	8c7c1830-771e-443e-8c25-a8b9f5589e6f	ClienteHot	Test2	cliente_hot_2_1764713393_4@test.local	+5001730201	$2y$12$f3.zMhrizb4JuXRUjLZzHuufV0bW8/.NoCVkXFFOurnfoPTdpCeh6	cliente	\N	\N	0	1	2025-12-02 22:09:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
90	562504f5-2991-485b-ae67-c7dfc6112399	ClienteHot	Test2	cliente_hot_2_1764713394_5@test.local	+5003587518	$2y$12$44uAPE/37O9e0fPK4pqudOZ.INQtfT3cuBt7nFN4zGsSqDyHn.O4C	cliente	\N	\N	0	1	2025-12-02 22:09:54	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
91	ea81470d-26ef-4c8b-828a-73465827b764	ClienteHot	Test2	cliente_hot_2_1764713394_6@test.local	+5009922752	$2y$12$BZelHUjgi6jKnx/YWfiLRO.bXLZ7Pg5h4WrXnAlJ5CAvJjq9bVEPq	cliente	\N	\N	0	1	2025-12-02 22:09:55	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
92	7aa8cf23-e22f-4d3d-a640-ee9a49aed8e5	ClienteHot	Test2	cliente_hot_2_1764713394_7@test.local	+5009574395	$2y$12$7pDOdSAeey2sj7WQ4cl5TOQMkszHo.i.q9sOqgw3eq.GlmZCd2NSy	cliente	\N	\N	0	1	2025-12-02 22:09:55	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
93	4260623f-57d6-4a1a-a8a7-4e5c9fb16547	ClienteHot	Test2	cliente_hot_2_1764713394_8@test.local	+5009086449	$2y$12$6/1MABzJlch1EA0mSsIP0.Etb.nBANZhAh4zYogKHBKiqFWv8gTm.	cliente	\N	\N	0	1	2025-12-02 22:09:55	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
94	7dcbad8c-a7ab-4266-81a8-6fa37642401a	ClienteHot	Test2	cliente_hot_2_1764713394_9@test.local	+5005313273	$2y$12$62IJF2k1JPSfzKKmkUPwMerU.V3yor3Zhdab4Bt/KsJwmjiaFD9P.	cliente	\N	\N	0	1	2025-12-02 22:09:55	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
95	f6f32e53-90a0-44ca-92ae-2b787ed0afe2	ClienteHot	Test2	cliente_hot_2_1764713395_10@test.local	+5001129159	$2y$12$U.GgQku0ZrVSmS4RIXLP1OAarnFDzkhVsTlGy1XxERJYFOSF0J0Bi	cliente	\N	\N	0	1	2025-12-02 22:09:55	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
96	54469c06-90f1-4252-bd38-1ae98f346bd9	ClienteHot	Test2	cliente_hot_2_1764713395_11@test.local	+5002283464	$2y$12$sDLQIvO.VrNix18O7mBIxendaJ8SSQe/PiAz0DSCkCK0iUExeAYoa	cliente	\N	\N	0	1	2025-12-02 22:09:56	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
97	86fd0b13-ead1-4adf-b26f-46a3780dcbaf	ClienteHot	Test2	cliente_hot_2_1764713395_12@test.local	+5005865329	$2y$12$sfAQnyrpHlIi0q5yh.eyXO2Y9lwAxJIoAL3ytV8ntTHckPJ4pfCPu	cliente	\N	\N	0	1	2025-12-02 22:09:56	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
98	c818ed0c-1ad0-4472-a948-8d5d8af32f2a	ClienteHot	Test2	cliente_hot_2_1764713395_13@test.local	+5003946130	$2y$12$FDXu7j1FkvzdUyPafnEkVOhvDcOmceL25zEETGJJuswalqgFlCxr.	cliente	\N	\N	0	1	2025-12-02 22:09:56	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
99	784b94d7-fb95-482e-8005-25040093615d	ClienteHot	Test2	cliente_hot_2_1764713395_14@test.local	+5001874705	$2y$12$6KNMSmubIwU.dXHSkNgP5Oylid5cphLc9kPQ1YKeF3hTRdxHQbB/u	cliente	\N	\N	0	1	2025-12-02 22:09:56	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
100	edad9b61-9b3e-4eb8-93dc-6cdbf3e56b91	ClienteHot	Test2	cliente_hot_2_1764713396_15@test.local	+5003271211	$2y$12$MTeGOLMnmK./e.rRLvHDtOancGeBWxPjzd3RqyBxUWWwRqe4NhlOe	cliente	\N	\N	0	1	2025-12-02 22:09:56	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
101	d365cc9c-7803-4654-9d80-c3b054b40aa2	ClienteHot	Test2	cliente_hot_2_1764713396_16@test.local	+5003539864	$2y$12$B5.SMf5TAaqu27TIu84.Q.5/67J7Heme5F0PO4iU1ekJC3dYWwUtC	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
102	1eab0dd4-3831-4d93-b0f1-8ab88219a442	ClienteHot	Test2	cliente_hot_2_1764713396_17@test.local	+5006106937	$2y$12$QihvawX29Rfe84T/b9mRRuTa9W3zpjt87yVuE2APVY1Og6otkdO5u	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
103	7e691b7a-d8da-4f96-8775-1cc06ebfb46e	ClienteHot	Test2	cliente_hot_2_1764713396_18@test.local	+5002778473	$2y$12$4scuFKnnDUkvWIypU6RCcuVNf/GDOhsG3yuDcMEPj/PiQIKV7SDdC	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
104	c344aeb5-489b-44b4-b265-e142ed1d170b	ClienteHot	Test2	cliente_hot_2_1764713396_19@test.local	+5009318399	$2y$12$Zqq8ybwyADiC3BTHSwpwWOe0Huh9eQUU893Nqr43WFFXrEf9Kp8Vi	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
105	7f51b13d-8f2d-4e15-a8bb-2e991b5319a5	ClienteHot	Test2	cliente_hot_2_1764713397_20@test.local	+5007826854	$2y$12$2kKgybxQA/I7duW4bt1pJePOBPEJThUIxdzsR9iC5foNktKBP9fau	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
106	dc34008e-dc44-494c-862f-6d35d083b146	ClienteHot	Test2	cliente_hot_2_1764713397_21@test.local	+5006588765	$2y$12$.ht1ik0AqA7dOTAYR8Ja1.wM9hj0LMhR15YqkQY3OS.5ZCz1WI6fu	cliente	\N	\N	0	1	2025-12-02 22:09:57	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
107	462ce525-bd9e-447f-89fb-86fa70a74316	ClienteHot	Test2	cliente_hot_2_1764713397_22@test.local	+5001828827	$2y$12$Tlr4.oNW5Bj5znpooEKxSu38/WUgNyyyGyttb1ohOqhg1bJXH6qJ2	cliente	\N	\N	0	1	2025-12-02 22:09:58	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
108	531204f4-44e0-46dd-8241-3bb5eb3847e2	ClienteHot	Test2	cliente_hot_2_1764713397_23@test.local	+5007416750	$2y$12$vBquEyvqScNZEsWpsVmFTeMLpoc/G4wFrRSZS8KFYooVQ4MMinRrK	cliente	\N	\N	0	1	2025-12-02 22:09:58	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
109	d19ab49e-5764-4bfd-ab0d-33e8717818d4	ClienteHot	Test2	cliente_hot_2_1764713397_24@test.local	+5004753011	$2y$12$..3ZBKDbS/wl3V7WIMX7N.18xeEpPC/aLS09LvBW9EM9kkeE9Zx/u	cliente	\N	\N	0	1	2025-12-02 22:09:58	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
110	9cfd89e6-9032-4b52-a418-385070b2d778	ClienteHot	Test2	cliente_hot_2_1764713398_25@test.local	+5001693095	$2y$12$IkQvFIAIPJzhU9QSGxPYguY6GnfONGPBwhR71VVWibTXxz.pJuskO	cliente	\N	\N	0	1	2025-12-02 22:09:58	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
111	4d206488-8120-47c8-a46d-8c648579f824	ClienteHot	Test2	cliente_hot_2_1764713398_26@test.local	+5009756866	$2y$12$pFuG//aSeyzSXnVMgAzD6OPpvDWk4iHinYxSyJ3Bn5AV42xvNOqDq	cliente	\N	\N	0	1	2025-12-02 22:09:58	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
112	57cb0690-7468-4485-bec9-58e32b4c0de7	ClienteHot	Test2	cliente_hot_2_1764713398_27@test.local	+5007157478	$2y$12$Ju3ttc33zrH6USGdheNRDOV4LY4v4GEul5loilDC3137EWd.VIDEu	cliente	\N	\N	0	1	2025-12-02 22:09:59	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
113	cccd661b-b0ae-4cca-b9f9-75c881593c85	ClienteHot	Test2	cliente_hot_2_1764713398_28@test.local	+5006945107	$2y$12$X6MchSvdqCMZUlcbTJ0KieWXUmQe7LDwKcPnL.OWtE3KjV3eENRNW	cliente	\N	\N	0	1	2025-12-02 22:09:59	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
114	7b08dcaf-7d4c-49a3-ba4a-8e585cc74c1b	ClienteHot	Test2	cliente_hot_2_1764713398_29@test.local	+5002651063	$2y$12$WiTlBuvEtW8LQ/LLYQLPOOEyVfGxgNbbUNsHrcD6k89Ik8U2R7fx2	cliente	\N	\N	0	1	2025-12-02 22:09:59	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
115	960da76c-4ee9-461f-b95d-3f5879a956a1	ClienteHot	Test2	cliente_hot_2_1764713399_30@test.local	+5008712882	$2y$12$cUXHCOBKeTFPQujayF0uL.iiBIT389ac5Vqo1b0X94OZrXpxNZWl6	cliente	\N	\N	0	1	2025-12-02 22:09:59	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
116	9ebc7eb7-e80b-449b-9daa-9c0453864f4c	ClienteHot	Test2	cliente_hot_2_1764713399_31@test.local	+5002147845	$2y$12$BsYxKR1mn78EXoN9SCRrXOrG0WQMG22cxhbmqJJQIKtbKiTG0w3Dq	cliente	\N	\N	0	1	2025-12-02 22:09:59	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
117	16958da7-4c5d-4155-a6a0-4e0b9442f24e	ClienteHot	Test2	cliente_hot_2_1764713399_32@test.local	+5008044193	$2y$12$yRhsXtAAdyYGqqlTFWCHJerieF.Mr.X9T54gTbzKaF8s/kDKOje2e	cliente	\N	\N	0	1	2025-12-02 22:10:00	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
118	b59cb45e-5d3d-4c23-bc8c-2833e514cf46	ClienteHot	Test2	cliente_hot_2_1764713399_33@test.local	+5002356588	$2y$12$wkBayqsr2C8oCJj6pOCJVOGU4jAT3auGuRkzhU2Zd3khhcJ/7t/3m	cliente	\N	\N	0	1	2025-12-02 22:10:00	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
119	3e780da6-691e-46f6-99ab-acaee4d450f8	ClienteHot	Test2	cliente_hot_2_1764713399_34@test.local	+5004088859	$2y$12$0v8AKk75K6XYbIvEl8rvdOPqm0/m60uiqkjC2vm30oADrKYXNSU4.	cliente	\N	\N	0	1	2025-12-02 22:10:00	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
120	9803b8e8-4f04-4401-8941-83cbc9503eda	ClienteHot	Test2	cliente_hot_2_1764713400_35@test.local	+5005530306	$2y$12$16tWuuUdPyWc7NWwtqOfBeVl/2kUQW9jON3uuHfms/9RXdIaaokmK	cliente	\N	\N	0	1	2025-12-02 22:10:00	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
121	a1922e12-9bf6-4a16-80ea-21fe179fc01f	ClienteHot	Test2	cliente_hot_2_1764713400_36@test.local	+5001355192	$2y$12$VnOFdv6pabtRBzfO53hJM./oH1rSPkcHJrZ.mEr9punGyA8GsoseW	cliente	\N	\N	0	1	2025-12-02 22:10:00	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
122	bf2b8b33-07c5-4d6c-bdb3-c0d29dfe17c1	ClienteHot	Test2	cliente_hot_2_1764713400_37@test.local	+5002714790	$2y$12$sAjD/8OeKiaLXoxkfhue2uPpxwVAK9bGeV7vEPeiLkkm1Uy1W8QaS	cliente	\N	\N	0	1	2025-12-02 22:10:01	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
123	e51e8c3b-8f94-451d-a13d-3bd6c702e3da	ClienteHot	Test2	cliente_hot_2_1764713400_38@test.local	+5007890058	$2y$12$3lFk1.ved7j5xoBLntVrw.J8/sg1je6JChZTBigZYzCUPUhEW8LM6	cliente	\N	\N	0	1	2025-12-02 22:10:01	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
124	f72b3f8d-8820-461f-b4a0-28c0b5c8d86b	ClienteHot	Test2	cliente_hot_2_1764713400_39@test.local	+5001529348	$2y$12$fhdQBHSplvbq21csRqsm1OYYqdD01IseEmfKSEc9ejPh.1CI2X5oe	cliente	\N	\N	0	1	2025-12-02 22:10:01	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
125	81a8200f-d666-44e5-9075-0a3e64b27a44	ClienteHot	Test2	cliente_hot_2_1764713400_40@test.local	+5001094811	$2y$12$OJFeCdMP3YYL32QABpWsZeOsUIrF37dL9JujuMBKeKRgwoQ0vV2ei	cliente	\N	\N	0	1	2025-12-02 22:10:01	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
126	6a5982f6-606b-4435-b970-553faf1309b5	ClienteHot	Test2	cliente_hot_2_1764713401_41@test.local	+5004108529	$2y$12$sEDIG9r3kurYtulR13PZ2.OrexZIYYoXKsj9TfenDVf6lusfKnNXe	cliente	\N	\N	0	1	2025-12-02 22:10:01	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
127	98af442b-89b7-4c94-8839-a8579793ec6c	ClienteHot	Test2	cliente_hot_2_1764713401_42@test.local	+5008940635	$2y$12$NLADWb6QCUCEsrUHNnVjIOzfmbZpRrknRLZcHspm.EqavrBLM9inW	cliente	\N	\N	0	1	2025-12-02 22:10:02	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
128	97fa9432-f933-47b0-ba74-235864fe8f0d	ClienteHot	Test2	cliente_hot_2_1764713401_43@test.local	+5007469978	$2y$12$pqBDUnb22o1.xn2xkNZFn.p.maYI.3c3HTS8kUivtMwfcfkuPpUbu	cliente	\N	\N	0	1	2025-12-02 22:10:02	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
129	0ebfe10b-6c8d-4216-88a8-72afd4872395	ClienteHot	Test2	cliente_hot_2_1764713401_44@test.local	+5003999216	$2y$12$fKd6vWDZDcGFkqzXD49ZDe3P9T9WeyhuBQ3px3YLvXI4TGJ5iAVd6	cliente	\N	\N	0	1	2025-12-02 22:10:02	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
130	9c16d4ed-12a0-411f-bb8f-426c1f1b302a	ClienteHot	Test2	cliente_hot_2_1764713401_45@test.local	+5008944544	$2y$12$qhDWClCNaHXuN3ia4F7iQuabM6cRS/iuD2HDK9k5Wf.am6fUsNzWG	cliente	\N	\N	0	1	2025-12-02 22:10:02	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
131	8760e6e6-470e-455f-a2c3-644dae4d7557	ClienteHot	Test2	cliente_hot_2_1764713402_46@test.local	+5009664398	$2y$12$B6W2eiac.anW41TUxcWPGOxHD1jfJW19RDx05/dBYx0agiV7ifbkS	cliente	\N	\N	0	1	2025-12-02 22:10:02	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
132	0f1dfcfb-aa1d-467b-b17e-94b5a56ce752	ClienteHot	Test2	cliente_hot_2_1764713402_47@test.local	+5003742229	$2y$12$Bk98ByJ8t.LSqeXYPw526uiJGZGcZETnV3oshEK2REnJILtT4991e	cliente	\N	\N	0	1	2025-12-02 22:10:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
133	3a7c46aa-4876-42d2-b65f-c69dbccf3e16	ClienteHot	Test2	cliente_hot_2_1764713402_48@test.local	+5004978394	$2y$12$LBlazrzu/7vAyNPQ.XkRm.vtiWbYlT1KI4diE3u3bfmB/urwV7SEa	cliente	\N	\N	0	1	2025-12-02 22:10:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
134	6a871a24-02de-4471-9307-c8e2ec7ee020	ClienteHot	Test2	cliente_hot_2_1764713402_49@test.local	+5008629177	$2y$12$fRQDKw.S5keLgV4Fcj2UMuBA5kodcp35YqzSvP/FLtF34XSHcIM5C	cliente	\N	\N	0	1	2025-12-02 22:10:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
135	4600d2f3-b3d6-4766-832d-78bfced6ee6e	ClienteHot	Test2	cliente_hot_2_1764713402_50@test.local	+5001564216	$2y$12$uIGwJWnuNqIn4s.aDkRnO.goROIAr6zSsSZ7PUF3IOLfcj3PxV4ge	cliente	\N	\N	0	1	2025-12-02 22:10:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
136	0bdc6cf7-0ded-4d7f-87dc-3320187d9f74	ClienteHot	Test2	cliente_hot_2_1764713403_51@test.local	+5004063354	$2y$12$/YWH7KdeL4FcQdowVfXiYeRext5bKuHwl333ugvFG4iD6059GdZM6	cliente	\N	\N	0	1	2025-12-02 22:10:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
137	e485e337-0a26-443c-904f-76c29bf0878f	ClienteHot	Test2	cliente_hot_2_1764713403_52@test.local	+5007310952	$2y$12$mQZZaFJ.pPhDtItMulOmMuVWRVR5uy61bdnbEmcDds/0wuH84vrFC	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
138	30284420-752e-4438-b2a1-2322868298c6	ClienteHot	Test2	cliente_hot_2_1764713403_53@test.local	+5004152484	$2y$12$gJKFzqaxBQe.e4Km7HLo1eU2rCVFe8e3fgZIVOixi9r4UhQgpSJMW	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
139	79c5bf79-647f-461a-bcf2-24ef9ff6b4cd	ClienteHot	Test2	cliente_hot_2_1764713403_54@test.local	+5007590593	$2y$12$agbewIgSnoQDLyl4tmmMVu80dhdRmdEN.HJVdnf43qiLf3c7xOgAi	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
140	7e9f7f65-52ef-42be-959e-daa8ee337478	ClienteHot	Test2	cliente_hot_2_1764713403_55@test.local	+5005277930	$2y$12$sS97PmJKgYEjbsKUSBrW1.7e6COq06B3Ww0ev87jwZx5b8QHu7dNa	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
141	9a2d2625-7f43-4b87-8bb4-112fc4280cee	ClienteHot	Test2	cliente_hot_2_1764713404_56@test.local	+5007226488	$2y$12$BhzRHmwy5J9ypsWYYdOkuOhe0SJ54rjEbFno80v7aqmsEoGu/Rq9m	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
142	1f7da79e-15d2-440c-a55c-e026d3e24ec3	ClienteHot	Test2	cliente_hot_2_1764713404_57@test.local	+5002495329	$2y$12$9HN5CGPGRZ9gk8B0enywtu2BWGwELax9pxzwUB7lNVpCJDjaq7jje	cliente	\N	\N	0	1	2025-12-02 22:10:04	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
143	44bf4301-f45a-4217-8b69-30354bf87cf8	ClienteHot	Test2	cliente_hot_2_1764713404_58@test.local	+5002435867	$2y$12$hzzlcEq15lWmP1zg9lwpIOmqzai36wUaYkQE46bkZ4XD31IDnZC.W	cliente	\N	\N	0	1	2025-12-02 22:10:05	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
144	698e6afb-2514-4431-9c01-26eb35cb0d5c	ClienteHot	Test2	cliente_hot_2_1764713404_59@test.local	+5005528481	$2y$12$GSEOz1fqGsIkG95CiSOEluNTT747uIUdbTA9qKsIFvOMuVDmVAdRe	cliente	\N	\N	0	1	2025-12-02 22:10:05	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
145	8a87c8cd-77f9-4d2a-8dfb-1b8a0dec2092	ClienteHot	Test2	cliente_hot_2_1764713404_60@test.local	+5006639223	$2y$12$NzaIXIebwnpWLW41kE7Zc.6MtLXs29CfLtJkSI0dSwj8uIdNF.T8u	cliente	\N	\N	0	1	2025-12-02 22:10:05	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
146	b2ef9ee8-9169-4420-993f-94fa7935149e	ClienteHot	Test2	cliente_hot_2_1764713405_61@test.local	+5004337200	$2y$12$S6f8DC./5DV7NL.tJvi1Uef2I7E1GY8nM62opROAkczc1v1PdXgG.	cliente	\N	\N	0	1	2025-12-02 22:10:05	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
147	cdaeb84c-9ddc-4260-a980-bd2d35240bf5	ClienteHot	Test2	cliente_hot_2_1764713405_62@test.local	+5002077683	$2y$12$cP07r5EVymksl8bF6AQK5Oosz61B0zPDuD.xtQZXWR2wpFqLRBdDq	cliente	\N	\N	0	1	2025-12-02 22:10:05	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
148	0060e837-8621-444b-b3c8-d2f19ad55714	ClienteHot	Test2	cliente_hot_2_1764713405_63@test.local	+5009426081	$2y$12$PeZkA/Uw9n7yRyIzdZM5RuJq.bFUz6dU/Zh3H1AkMakfJn7MlLKGS	cliente	\N	\N	0	1	2025-12-02 22:10:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
149	cc1694f7-19e7-4b5b-8bdd-302bcaa9b6a7	ClienteHot	Test2	cliente_hot_2_1764713405_64@test.local	+5002863972	$2y$12$CLfqByePx0GHKwEAAPIqteUYqlPKy.v8X1J55ewpyEAHT0.JgG2uy	cliente	\N	\N	0	1	2025-12-02 22:10:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
150	6fa7038a-fa04-464d-ad5e-4be729dfa4d3	ClienteHot	Test2	cliente_hot_2_1764713405_65@test.local	+5003025927	$2y$12$YAXHJjMwYkXw7qOkPElFqeCZVNEwBBJfv7oiLR9LEnoSfRSBFCE5m	cliente	\N	\N	0	1	2025-12-02 22:10:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
151	eb636a7a-389b-40e7-99df-c896a8a29ffc	ClienteHot	Test2	cliente_hot_2_1764713406_66@test.local	+5009219794	$2y$12$dOqURl42Ngxwde3xEOGeK.O/GzfVPbP1t5yTpLfZ0zruFrhd/4Vga	cliente	\N	\N	0	1	2025-12-02 22:10:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
152	0e079ae5-f675-4414-bb8e-26165798b913	ClienteHot	Test2	cliente_hot_2_1764713406_67@test.local	+5008148745	$2y$12$L9Mh7CSQCgZJ6eDW6qjTse1C72gNOmOQzhWv.HB8yOKGq3yg.qG32	cliente	\N	\N	0	1	2025-12-02 22:10:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
153	38d53fa7-a881-4fda-bf75-b82736dd0219	ClienteHot	Test2	cliente_hot_2_1764713406_68@test.local	+5003793988	$2y$12$pUB8OzJnGRNt2rrmmhXGX.XdzSn7iA6tq5q2/SmxraSaXUhluOn/e	cliente	\N	\N	0	1	2025-12-02 22:10:07	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
154	cb1a2ba2-72fc-498b-aa52-7008ae59eaa3	ClienteHot	Test2	cliente_hot_2_1764713406_69@test.local	+5007072062	$2y$12$O.qDnYrVilHioQZbXn3XeO3ChPTnQbFXY1PgmneeWzVAfgCTJCgBq	cliente	\N	\N	0	1	2025-12-02 22:10:07	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
155	c6bcaf90-b888-4051-8f1a-c447482f1ac1	ClienteHot	Test3	cliente_hot_3_1764713406_0@test.local	+5005495174	$2y$12$4JEhqDVHt4u20ONth1rRWOGoZdm7uzeC6ZaEzhK.aWZzXp57tJ1Ka	cliente	\N	\N	0	1	2025-12-02 22:10:07	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
156	9d56c551-baea-44c1-ac92-622a47d89ce0	ClienteHot	Test3	cliente_hot_3_1764713407_1@test.local	+5008614945	$2y$12$Ajqx//TYFElK5hKWFeonNOzmeGkZMbtUIVzmuJ.bVh0Oe1GuC6jrS	cliente	\N	\N	0	1	2025-12-02 22:10:07	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
157	43c3d81d-bbb6-451c-a8c0-0014256c5cf8	ClienteHot	Test3	cliente_hot_3_1764713407_2@test.local	+5003322564	$2y$12$l41gGEzjDisC9s/CBHZg1.LOI4Jkr7Ln5luYXTLcPMnKu/WSxF9CK	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
158	3ea2305b-ddfb-40f1-baea-6d51682f97b9	ClienteHot	Test3	cliente_hot_3_1764713407_3@test.local	+5008693218	$2y$12$HbyhuTrKEIwqonHfuHhCsOZ34J/BhlD3HTE2DmMZAUhY61l3OoZxC	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
159	98dda6f5-59d8-4d5e-b382-e71759f54c53	ClienteHot	Test3	cliente_hot_3_1764713407_4@test.local	+5004320416	$2y$12$5C9pi24ryHHpmi81mPhutu84Xu8kH7HY1LiTH8Wv2bAHXUbqwwNRa	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
160	7d6a9db6-7712-47ba-be96-c514f7694f0c	ClienteHot	Test3	cliente_hot_3_1764713407_5@test.local	+5007685048	$2y$12$A87AryUIZt5mkJWriVj6BuULj02MIYn3cO6pupQk70Hr/FS/U89eO	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
161	491799a0-2518-40c9-b151-b827058c8a4e	ClienteHot	Test3	cliente_hot_3_1764713408_6@test.local	+5008886802	$2y$12$hQWV5YRzE/nV42WqRxGDR.8MpaRi85QbOCFymgUWXBxmLqfLJU6Yq	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
162	ad5cc964-d829-4d9a-b7de-721f70ecb873	ClienteHot	Test3	cliente_hot_3_1764713408_7@test.local	+5003122860	$2y$12$LyZN0gZD3M3prAMSrsGTKOTmgOhtDSrcQMzhqG5GAK.2lKbEF6zoa	cliente	\N	\N	0	1	2025-12-02 22:10:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
163	55c091f0-81b2-4ee2-84cd-1e4bdd815caa	ClienteHot	Test3	cliente_hot_3_1764713408_8@test.local	+5002617614	$2y$12$BPoD.ASX/A5qLDMNlv/B8.L2Ayb3sLRc7jIXZNIs.R3O5uVnBRN5C	cliente	\N	\N	0	1	2025-12-02 22:10:09	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
164	154b11ca-9353-4944-aac6-287aa9a5a52a	ClienteHot	Test3	cliente_hot_3_1764713408_9@test.local	+5001594965	$2y$12$EgKmCRRGVunW3Xold6F2w.xAHblEz4h0p/WBiDjTC22AldblimMA6	cliente	\N	\N	0	1	2025-12-02 22:10:09	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
165	d85abe82-2630-4a33-b737-05cdb30a15fc	ClienteHot	Test3	cliente_hot_3_1764713408_10@test.local	+5006320299	$2y$12$qbyZDlIET.h5S11percG.uvyTNRI8M8lakha6sgrnscfGqKZSRpju	cliente	\N	\N	0	1	2025-12-02 22:10:09	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
166	15dfbd76-da0d-422d-8774-d4c48a4aeff8	ClienteHot	Test3	cliente_hot_3_1764713409_11@test.local	+5009745130	$2y$12$TqI/7P33ZmZ87g7YixjA9.i3Bfx3tRQP11HGMGbNFXbyI.HWH1HaW	cliente	\N	\N	0	1	2025-12-02 22:10:09	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
167	209f24b3-afba-4f59-b761-6fc95d236cda	ClienteHot	Test3	cliente_hot_3_1764713409_12@test.local	+5002541594	$2y$12$tCouqPAVt8v8tVH2rLRC/eoYBwgUbt6utmh5Xaku69nf2F5IhE4Bq	cliente	\N	\N	0	1	2025-12-02 22:10:09	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
168	718ff0ca-330b-4647-a57b-f6467bbf818b	ClienteHot	Test3	cliente_hot_3_1764713409_13@test.local	+5008418034	$2y$12$BI9k.zHM3SWF/5bnV/4FR./wkRCCQxjtDnb37yoQqHf1b3nIFM1.2	cliente	\N	\N	0	1	2025-12-02 22:10:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
169	4162fcee-bdee-4942-a38d-d64c82a842d7	ClienteHot	Test3	cliente_hot_3_1764713409_14@test.local	+5006277061	$2y$12$2nQTuAIfvxoAre74ktm2fODRgYdKKIDROvEdFGlp9sVi0QXUiwNJC	cliente	\N	\N	0	1	2025-12-02 22:10:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
170	0e499199-1601-401c-a886-d1a45c70fd7f	ClienteHot	Test3	cliente_hot_3_1764713409_15@test.local	+5009618275	$2y$12$h79f1xORSIdpQ6MK2BSYe.Tz5HOqs5NyGbg1tAH92SM0kA9.8vySm	cliente	\N	\N	0	1	2025-12-02 22:10:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
171	65b578d1-39c7-435e-8559-b6fdd566e7ce	ClienteHot	Test3	cliente_hot_3_1764713410_16@test.local	+5005985969	$2y$12$CfP5f0M2bAbdZ/9kFfA6V.VJ8nfn3e8jMDhU42jFlo90thKb5JN4m	cliente	\N	\N	0	1	2025-12-02 22:10:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
172	83108cd8-3c8b-4770-b19c-e809fcf553fc	ClienteHot	Test3	cliente_hot_3_1764713410_17@test.local	+5008537982	$2y$12$wuaS/aS76l/RwA6NzJlpQ.n7wcu6ZBXpVS5WXkdFGc62P5BqegY4m	cliente	\N	\N	0	1	2025-12-02 22:10:10	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
173	4890cb04-db40-4cac-a21c-6ad32b72ab48	ClienteHot	Test3	cliente_hot_3_1764713410_18@test.local	+5002549595	$2y$12$oOd4BdZs.vLnaDJWj78oc.Let.NEPnUgZSeYn3Tz1bhYVcI8dPIe6	cliente	\N	\N	0	1	2025-12-02 22:10:11	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
174	1137d14a-4ced-4f03-8d48-d367f450e042	ClienteHot	Test3	cliente_hot_3_1764713410_19@test.local	+5008674959	$2y$12$QIfZlbew/T3ih.PAENaPk.X1cj7.rt2GAkTFz/2B1I8PATBL5DRfy	cliente	\N	\N	0	1	2025-12-02 22:10:11	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
175	2e6d51ac-71d0-4722-b38f-77099022bdf1	ClienteHot	Test3	cliente_hot_3_1764713410_20@test.local	+5007114607	$2y$12$PjlOxvnIeEwQoEawdAbJ1OzT/PMX38rb/nkRpyzaVTJuAKg.97LGC	cliente	\N	\N	0	1	2025-12-02 22:10:11	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
176	e0ccf0ef-bb4a-4472-8b73-ad12605de830	ClienteHot	Test3	cliente_hot_3_1764713411_21@test.local	+5008701240	$2y$12$ayEEj.UKbyZFHzgYrxRYnOUyT0vzPwqUvWP7FEGjWq1HMborFLmsq	cliente	\N	\N	0	1	2025-12-02 22:10:11	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
177	534efc16-f234-4c94-8209-0b658278e08b	ClienteHot	Test3	cliente_hot_3_1764713411_22@test.local	+5003066119	$2y$12$pS1xhZLUDt2X98SsRrviKOVNzW5ds5c7VL1iLlL00EtmB1xB0fddW	cliente	\N	\N	0	1	2025-12-02 22:10:11	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
178	9f0d2830-db85-4851-957b-b91da04d118a	ClienteHot	Test3	cliente_hot_3_1764713411_23@test.local	+5003042849	$2y$12$BmwF/sOfB93L.yvjkOFdq.X9h1kuGMIslJB71YuvF38hmbr91VIk6	cliente	\N	\N	0	1	2025-12-02 22:10:12	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
179	bd3b8635-105b-4db1-bd1c-10c228237e75	ClienteHot	Test3	cliente_hot_3_1764713411_24@test.local	+5008162473	$2y$12$l9EGSj0k8scmXJNfdB8BTeeNriO4ELzvdsyeIi8BCrBeGCpBStaq2	cliente	\N	\N	0	1	2025-12-02 22:10:12	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
180	c3aca21f-c6bf-4294-98ac-4a232fd4167e	ClienteHot	Test3	cliente_hot_3_1764713411_25@test.local	+5006675082	$2y$12$chBf2rsGbC6KI48gIF4SR.wEJUZ0fa0BIUuCMFA1kcbujaCbcB4cC	cliente	\N	\N	0	1	2025-12-02 22:10:12	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
181	a6ef23c8-3e0c-4ac0-8cdd-84fa8ef2576d	ClienteHot	Test3	cliente_hot_3_1764713412_26@test.local	+5007702493	$2y$12$KcqnBuZoCtMEaqSDGBAyOeqmpHPDsun.b/IbnU4q0BCKcfWV72dP6	cliente	\N	\N	0	1	2025-12-02 22:10:12	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
182	2738c968-242d-49a5-8643-680b35b656f0	ClienteHot	Test3	cliente_hot_3_1764713412_27@test.local	+5001802220	$2y$12$2DJB8rKzpdQM2/7jO3Msuuf4eDy3FhcpEqqUfQcj7mMg5g8sQOZS6	cliente	\N	\N	0	1	2025-12-02 22:10:12	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
183	8f14a778-3255-4d68-9774-f572f00361d0	ClienteHot	Test3	cliente_hot_3_1764713412_28@test.local	+5002167734	$2y$12$fZOlzO8z.xBqFsxzNs6qO.MRa1tLeBpx9bHg2tkZYPElAo3gIJGPa	cliente	\N	\N	0	1	2025-12-02 22:10:13	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
184	b0df5d5b-e9ca-4fc7-a3b0-27f811f401e2	ClienteHot	Test3	cliente_hot_3_1764713412_29@test.local	+5001219317	$2y$12$sh4LvZPAaRQNLXSPH41lcOmmFP0X7J0LaxiF80wtnulP4HXrokeK6	cliente	\N	\N	0	1	2025-12-02 22:10:13	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
185	6d201f10-9aef-4a4f-9824-fb60df190e62	ClienteHot	Test3	cliente_hot_3_1764713412_30@test.local	+5009205340	$2y$12$952UnLViHs/wnc55d94syO/T0hql.jXrCSxfsldL9D6/Kcs7P/2Pi	cliente	\N	\N	0	1	2025-12-02 22:10:13	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
186	2c04a8e1-e2cd-4115-80a8-0b71d473a619	ClienteHot	Test3	cliente_hot_3_1764713412_31@test.local	+5007648341	$2y$12$Pg1KOZwY2IxwIGBDIETeJeNCu/xOYmeAI.042bGnabVuINUAHqSma	cliente	\N	\N	0	1	2025-12-02 22:10:13	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
187	9d2320f2-ea9f-483e-9c12-071d1ea01155	ClienteHot	Test3	cliente_hot_3_1764713413_32@test.local	+5007873722	$2y$12$7rNFwM73gFiCZ/Z.DhgtXeRUiic5xOoKd5Ccn3x8bDYJOPpocKSES	cliente	\N	\N	0	1	2025-12-02 22:10:13	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
188	a505ee45-21a3-49b1-a4b6-33369afad667	ClienteHot	Test3	cliente_hot_3_1764713413_33@test.local	+5004978792	$2y$12$br7EE.qcml9U1EbrQNxgAOsS3sdQtGqFKAkDatADRurEgd5VWTmQ6	cliente	\N	\N	0	1	2025-12-02 22:10:14	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
189	60935512-f21a-49c4-ad1c-b2971f233657	ClienteHot	Test3	cliente_hot_3_1764713413_34@test.local	+5001903202	$2y$12$ly2AOnEOxZWKs6LTgmh/H.madrP2uC4FkIN0Vq1Q/uPlYiaB4ynpS	cliente	\N	\N	0	1	2025-12-02 22:10:14	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
190	589c69b6-bc68-4f2b-bad7-a2716a44d362	ClienteHot	Test3	cliente_hot_3_1764713413_35@test.local	+5005786040	$2y$12$2UBqK46iWrfLeieTj9pDmOUfT0M8EL3zOP5V1Gy/2fj4A/x5XmQkG	cliente	\N	\N	0	1	2025-12-02 22:10:14	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
191	f50bd98e-255e-4f11-bd22-7c17a0ce96dd	ClienteHot	Test3	cliente_hot_3_1764713413_36@test.local	+5001591507	$2y$12$r19jJez83JExFbHa5PUxl.ZmyKs3n2QxYOfSLQrwSHE3c3kLRaYWW	cliente	\N	\N	0	1	2025-12-02 22:10:14	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
192	3e2c3aee-2bd7-4e4f-a7a6-340194705c1b	ClienteHot	Test3	cliente_hot_3_1764713414_37@test.local	+5002492851	$2y$12$ux51h9gND.sSqAk12vGgZuH197zyoelDspGjqf4ts0Yw7gqaQiTYW	cliente	\N	\N	0	1	2025-12-02 22:10:14	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
193	49a8ffe9-8b1a-47a6-9bf4-de63c3d23fa1	ClienteHot	Test3	cliente_hot_3_1764713414_38@test.local	+5006247414	$2y$12$xpJqZ0wFEGxlz5XpA35/yuTRN1xtk1AapxycQBWSwWWvi0r98iKpm	cliente	\N	\N	0	1	2025-12-02 22:10:15	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
194	18753db8-8db1-4250-a27f-343b2f95e41d	ClienteHot	Test3	cliente_hot_3_1764713414_39@test.local	+5007761585	$2y$12$N/ErfVkI6Tm4QbOph790ceykSYa66ouDGSZ5RHHtguyq6UGL/3i1u	cliente	\N	\N	0	1	2025-12-02 22:10:15	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
195	db883b63-adbb-43ae-8ae5-6002a159def2	ClienteHot	Test3	cliente_hot_3_1764713414_40@test.local	+5001579014	$2y$12$1p38M6Nc91b/yza28/l48eFH0H5B5d24tAm0NP6jRdtWtqgFKofg2	cliente	\N	\N	0	1	2025-12-02 22:10:15	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
196	4842b538-66b5-46b7-981e-0906c3c379f6	ClienteHot	Test3	cliente_hot_3_1764713414_41@test.local	+5008463907	$2y$12$ltqGWuGiuxoWIJZPX0atBOzCDUDZLsXx/3anUw8ksGshw8taMBqhu	cliente	\N	\N	0	1	2025-12-02 22:10:15	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
197	bd805538-9428-476f-a0a2-ca6196827e03	ClienteHot	Test3	cliente_hot_3_1764713415_42@test.local	+5006360398	$2y$12$MGC0CXpmaoDwqZ0QGsRGU.ceY0i3HtGfIxlkYNACi8y7nWkH4X9Pu	cliente	\N	\N	0	1	2025-12-02 22:10:15	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
198	b8780017-8ead-4621-91f7-32b8d98b4866	ClienteHot	Test3	cliente_hot_3_1764713415_43@test.local	+5005441781	$2y$12$kJW3ZqnAeBWSCQBSlSOb2uXm0qCVJjT/VBjHeT93vRlWz6z6IvwO6	cliente	\N	\N	0	1	2025-12-02 22:10:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
199	bfbdd578-bfbf-43b0-b05a-768b102352c7	ClienteHot	Test3	cliente_hot_3_1764713415_44@test.local	+5001288379	$2y$12$aQ7xSRL0kb06Wg9qUw/IWOU6xGYYe38UZFjBkKT.okRS/U.6Ig0tm	cliente	\N	\N	0	1	2025-12-02 22:10:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
200	b198e651-8d9f-4baa-a87d-dcbbf05861ad	ClienteHot	Test3	cliente_hot_3_1764713415_45@test.local	+5004116946	$2y$12$By6xQ0n225.3wwFBsWdTk.Qt7GWFngKqz4pGUsWtMR/lxtOiiykji	cliente	\N	\N	0	1	2025-12-02 22:10:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
201	cec2bc56-27ef-4027-b359-a25e1eb2bf48	ClienteHot	Test3	cliente_hot_3_1764713415_46@test.local	+5003913415	$2y$12$pBe.aOIy30aCt33ajn/Emu8GxVMISo8an4YvsWKlbcvYHRZfan85u	cliente	\N	\N	0	1	2025-12-02 22:10:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
202	d735bdc2-0b12-494e-b9a4-a436c5f8ebf7	ClienteHot	Test3	cliente_hot_3_1764713416_47@test.local	+5008101175	$2y$12$8p.zPeZq/9C1GHM8tgCxEuU1QJtIuSR/2c5hs6bGy6Bhf1WlS81.2	cliente	\N	\N	0	1	2025-12-02 22:10:16	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
203	29d6a3c6-92f8-483a-a225-bad5df59d2b2	ClienteHot	Test3	cliente_hot_3_1764713416_48@test.local	+5003192742	$2y$12$/sLZyk9N1Oe7BmNvmIkN4uyBs6CvV1J1lhLaOW34.zRGP0QrsWV0O	cliente	\N	\N	0	1	2025-12-02 22:10:17	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
204	5f6ecdc3-c203-475d-b322-ced8edf6ce83	ClienteHot	Test3	cliente_hot_3_1764713416_49@test.local	+5009206966	$2y$12$wwk1JbXNog6jvgiNGn8Gd.HLExELYnXfOrCPTG83hwetg9QUGLpCy	cliente	\N	\N	0	1	2025-12-02 22:10:17	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
205	e6a402d2-62bb-43e1-bd47-b83e16921397	ClienteHot	Test3	cliente_hot_3_1764713416_50@test.local	+5005691524	$2y$12$ZluGzrL5Q1yPT5fdCPCtOutNrZ54hzP5Iqe.y7CVRByJ7mGDFYB7C	cliente	\N	\N	0	1	2025-12-02 22:10:17	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
206	b7250d6a-af48-4e27-a083-b6b96293db3b	ClienteHot	Test3	cliente_hot_3_1764713416_51@test.local	+5004118316	$2y$12$z.j/OGNYOf.08rCsNINkz.h3P1LAOFwg.tskJGBZtxv7zNcxaSAem	cliente	\N	\N	0	1	2025-12-02 22:10:17	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
207	a39c9623-1dcf-4bb0-9d2e-f0e76a81e7ab	ClienteHot	Test3	cliente_hot_3_1764713417_52@test.local	+5004548886	$2y$12$n5X3d5xnxZ5rK7irKD.RuuuD10rsqsxbCRisYWPt17NZoo1NOSGke	cliente	\N	\N	0	1	2025-12-02 22:10:17	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
208	e98d9adf-b84e-4000-b692-10748217e705	ClienteHot	Test3	cliente_hot_3_1764713417_53@test.local	+5008593567	$2y$12$X0N4N90nrEbY/B6FpqtZ8OxSau85GMkqeB42K4rIVhzcyb3EdquLK	cliente	\N	\N	0	1	2025-12-02 22:10:18	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
209	487594f4-4c4d-4224-9775-d9462ef54f89	ClienteHot	Test3	cliente_hot_3_1764713417_54@test.local	+5002652642	$2y$12$d.05rk8O.b6Lj9iUt/v2KeYOok0O.WcdDt1sT4nf131/2UihorPJK	cliente	\N	\N	0	1	2025-12-02 22:10:18	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
210	fa91b492-29f6-46bf-b32b-a4b3a0774419	ClienteHot	Test3	cliente_hot_3_1764713417_55@test.local	+5002703863	$2y$12$prfSFPr9r5pC4WUQ/X3sVO1rMJ76mq4rLkFLKvL.GL19KU9bDAM7.	cliente	\N	\N	0	1	2025-12-02 22:10:18	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
211	c0ed932e-e33b-417c-bc39-b30e80f1f20c	ClienteHot	Test3	cliente_hot_3_1764713417_56@test.local	+5001897829	$2y$12$ZyvORIQ4ZTUmwCkDztHcge3CQ2uK/YrlQi72NtXehiWwpoqA.0c6e	cliente	\N	\N	0	1	2025-12-02 22:10:18	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
212	6ede2cca-d721-4ca0-ad83-ff349307bf21	ClienteHot	Test3	cliente_hot_3_1764713418_57@test.local	+5005595305	$2y$12$UIk7e6ji4sByavlp0JF9KOF8cvWvKSgOr6Rmp.yCKY.6WcbHpzQFS	cliente	\N	\N	0	1	2025-12-02 22:10:18	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
213	912d70a6-3dbc-42df-b080-bd29b0f925c9	ClienteHot	Test3	cliente_hot_3_1764713418_58@test.local	+5004361323	$2y$12$3l1.5nqIS4quTxwdz1rTSuHQXSKY8dUk/OZ9C.I2a7PtFutKFx6sO	cliente	\N	\N	0	1	2025-12-02 22:10:19	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
214	14fdd637-4274-4a9b-868c-80f65d00fce8	ClienteHot	Test3	cliente_hot_3_1764713418_59@test.local	+5005069163	$2y$12$9r70pUFD6YAMGuxzm7e6muPsZHQwgGS3PrETXW3kQNOPxznakfAQe	cliente	\N	\N	0	1	2025-12-02 22:10:19	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
216	fd1a8f15-417e-4c50-bcbd-04b5a1d2e61c	ClienteHot	Test3	cliente_hot_3_1764713418_61@test.local	+5003274689	$2y$12$oZCPn51oZZZTNodcmiE92uMWPCde0ZSyQ29lHqFsQdCH9zG4k/hkO	cliente	\N	\N	0	1	2025-12-02 22:10:19	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
217	795ed576-e82e-420c-b781-340da2441fd8	ClienteHot	Test3	cliente_hot_3_1764713419_62@test.local	+5008089748	$2y$12$A6vlIB5aZKdSxtlXIAeCTe4Fhon.sobdft68SJLSCdFQtU6qQL6Fq	cliente	\N	\N	0	1	2025-12-02 22:10:19	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
218	941a2c7a-217e-4234-8caf-e0664a9f4188	ClienteHot	Test3	cliente_hot_3_1764713419_63@test.local	+5005538460	$2y$12$VwAshr0N.Z4Wa.XcqJDn0OyuPvRKnMCvcpG9QAUnQigJUAbBdhSHu	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
219	145aea04-3fa5-4df4-9b2a-8cc300514226	ClienteHot	Test3	cliente_hot_3_1764713419_64@test.local	+5009845437	$2y$12$8OyEN9tpjaIvyci8lbragua0n7lT1AFvFMGGputVahoVxQxWagVpG	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
220	01123283-b262-409d-a236-94686ddd68d2	ClienteHot	Test3	cliente_hot_3_1764713419_65@test.local	+5009805060	$2y$12$xt7XXFgzbnfGrIs1A07RHudwL0hPPhufAwhwtamu15Bai/w6RMKxi	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
221	6282dbff-dd2a-4f31-bc59-f5636e1f5c76	ClienteHot	Test3	cliente_hot_3_1764713419_66@test.local	+5006645469	$2y$12$gniUZnqMJRvb4Om3ihvEGeaAIBEBp8s1Ty21h8r4w6vxQKHCT73H6	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
222	bb2b4600-e86f-460a-bba2-192ccded94e5	ClienteHot	Test3	cliente_hot_3_1764713420_67@test.local	+5009985042	$2y$12$LrrjejAchZt3D0cOCLgRceorHlpXw72y4hoP29Z0MWbTNKLHm1ZWq	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
223	3537073c-6ebf-4c9d-84b1-11b0e9e4f80b	ClienteHot	Test3	cliente_hot_3_1764713420_68@test.local	+5004094346	$2y$12$ukNjQYWeGWncEVO4RdLG0.phrnE04tNDy614VlyUOUHZpFYXN3fXO	cliente	\N	\N	0	1	2025-12-02 22:10:20	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
224	047909c5-00bf-450e-a523-dc3cea62cc67	ClienteHot	Test3	cliente_hot_3_1764713420_69@test.local	+5009303440	$2y$12$rIaueZh4drIHrO7imdvaJOwDvL3VPJYHmU7HWi8Mox.yQ3zvoKYXC	cliente	\N	\N	0	1	2025-12-02 22:10:21	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
278	user_6966bf047561c5.15146061	leidy andrea	durango durango	leidyandrea315@gmail.com	+573205899682	$2y$10$fWhki.9r3/7zMI6hR4m3EeYpWK3cRLxXQ13U5Z4sqGPiArAL2IxZi	conductor	https://lh3.googleusercontent.com/a/ACg8ocIu5nnDbKkRsJWBJykXiqekhhhqtJe-5_xMeSJtsccM3ML14Q=s96-c	\N	1	1	2026-01-13 21:54:13	2026-01-14 13:20:11	2026-01-14 00:46:58	f	\N	1	\N	5.00	vinculado	101036033552230941677	\N	email
2	user_68e44706c14db4.53994811	braian890	oquendo	braian890@gmail.com	32323232	$2y$10$NB9S4hWQLrK7HhTjc9yneu9RTb6otip3dtZ1muEgukWWLKcSpxRF6	cliente	\N	\N	0	1	2025-10-06 22:47:34	\N	\N	t	1	\N	\N	5.00	activo	\N	\N	email
298	user_696eeadd6c00d8.47929678	Santiago	Zapata	conductorbird@gmail.com	3532323	$2y$10$J0lYEf0yvUkbE78448B.LObZi4NjDJg3H0gEnnGvwKPo8j12T5Sg6	conductor	\N	\N	1	1	2026-01-20 02:39:25	2026-01-20 03:29:49	\N	f	\N	1	\N	5.00	vinculado	\N	\N	email
255	empresa_rep_6961b9306f2bf2.66858089	Braian Andres	Oquendo Durango	traconmaster@gmail.com	233232	$2y$10$ING2VgbKD.eXwpwDGnyAteGr/Ave0qV/q5Mpm/xoBzP18hgz5.zGK	empresa	https://lh3.googleusercontent.com/a/ACg8ocK3-3Zs26o26dpSe0Lkf4ZPUfGkj2RaGNbJy-Yn5YBtz-uw_eM=s96-c	\N	1	1	2026-01-10 02:28:00	\N	2026-01-20 21:37:12	f	\N	1	\N	5.00	activo	116860906216950009498	\N	email
226	user_694d686fc4d124.55220713	andres	oquendo	andresoquendo@gmail.com	313131313	$2y$10$rfpnS5Io8spwxDdnKsrvReiAHR49v0thMTYzPBx4Asj.AEqaPPPdq	cliente	\N	\N	0	1	2025-12-25 16:38:08	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
215	6aaaf173-e3e3-4ab5-a4b0-92258f9f9fff	ClienteHot	Test3	cliente_hot_3_1764713418_60@test.local	+5006699882	$2y$12$HBvylQXLdwYwToSMyAx2geMxdEWxOc.LsjvCnfJLxFYe8GdjRhjma	cliente	\N	\N	0	0	2025-12-02 22:10:19	2025-12-27 22:36:55	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
229	user_69571dbb2a3174.00297676	oquendo	Durango	oquendo@gmail.com	3535343343	$2y$10$veHd5T/xGZL/p8Rjk2I7kOZ9xdF/IW7VysMV1u8ZYZc79RODeMdlS	cliente	\N	\N	0	1	2026-01-02 01:22:03	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
230	user_69571f3ed3f491.48232952	durango	oquendo	durango@gmail.com	3205899683	$2y$10$/WNVrCQjnC3I0Pd4iZ4BHu29DNp.P0uivnV6pzflVyhaihOv3GUG6	cliente	\N	\N	0	1	2026-01-02 01:28:31	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
231	user_6957343e435b31.04662721	andres	oquendo	andres@gmail.com	3232323	$2y$10$JbC9twx7rS52OdmUsKdhp.j6p/DmbPpH8lUPD6myR6HNPgtXM0S8a	cliente	\N	\N	0	1	2026-01-02 02:58:06	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
232	user_695735c74308d8.57746176	braian	qoeund	braian@gmail.com	656564	$2y$10$Zz8ksSt.up6IEuBjbpoVm./PWIOOUslRcrS1CNYp9w2uEU9fPVTZu	cliente	\N	\N	0	1	2026-01-02 03:04:39	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
233	user_6957381a5431e2.78926664	pablo	oquendo	pablo@gmail.com	656565656	$2y$10$kSznHZhjjrpTwK2XyPCRLO7jlHX5b1A/CxaiH8FTafb5.KPbwJkpC	cliente	\N	\N	0	1	2026-01-02 03:14:34	\N	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
7	user_68f8e5efd5f888.59258279	braianoquen2	oqeundo	braianoquen2@gmail.com	3242442	$2y$10$DUUZdDrKiyespZGSJfk9JeGYuvOkAjrlMemg9BA/BZfyXlamgobjW	conductor	\N	\N	1	0	2025-10-22 14:10:55	2025-10-26 16:22:01	\N	f	\N	\N	\N	5.00	pendiente_empresa	\N	\N	email
227	user_694d69a68b8bf6.31096667	pruebawlcomer	oquendo	pruebawlcomer@gmail.com	233232323	$2y$10$EmEY5aQeDhwOGMHU.VNoVOtPVHoOJUWWy0BjmS/iCCIORH1p5l8L6	cliente	\N	\N	0	1	2025-12-25 16:43:19	2025-12-28 01:03:31	\N	f	\N	\N	\N	5.00	activo	\N	\N	email
234	user_6959a0ec74b016.75842336	victor	oquendo	victor@gmail.com	2332323	$2y$10$jl/x0XD7o4LJe1L4rNi0JehjW6dn/XT2hkRSZ/Zg7ereiG3xdREia	cliente	\N	\N	0	1	2026-01-03 23:06:20	\N	\N	f	\N	\N	\N	5.00	pendiente_aprobacion	\N	\N	email
1	user_68daf618780e50.65802566	braian	oquendo	braianoquen@gmail.com	3013636902	$2y$10$H2Un4DmxCsM6XOGA1fiX8.5VB42Z9v8uwqERrGBms83dk2CQVQKnO	administrador	https://lh3.googleusercontent.com/a/ACg8ocLGRW44x3yOuEc2Cto3I434ck4B-Zz8UBVPRWSAVXTUUM_KFw=s96-c	\N	1	1	2025-09-29 21:11:52	2025-10-22 14:16:12	2026-01-20 03:28:42	f	\N	\N	\N	5.00	activo	100021586628962750893	\N	email
11	bd852c00-8127-49ab-a6b1-17bc1128f0cd	Conductor	Prueba	conductor.prueba@test.com	+573009876543	$2y$12$t5I6QV69PHlcY4ozF2G5wObcdn8MK6vOawu0U./aLdWvWrhfxNBvS	conductor	\N	\N	1	0	2025-10-27 00:27:44	2026-01-04 17:52:26	\N	f	\N	\N	\N	5.00	pendiente_empresa	\N	\N	email
235	user_6959ce1194cf04.53594144	victor2	oquendo	victor2@gmail.com	323232	$2y$10$eoEK5r6Eq1NArh/imHFfGeZHKoYj2hRd60YHDUjVg4OsWn73nc6D.	conductor	\N	\N	1	0	2026-01-04 02:18:58	2026-01-04 17:58:45	\N	f	\N	\N	\N	5.00	pendiente_empresa	\N	\N	email
276	user_69642016735491.91239396	Alejandro	Zapata	tracongamescorreos@gmail.com	3213243222	$2y$10$59XENVeFt0FKg6mtRHiQI.pWRKPkpsdZGulpHTksiCcwzV7wdnYjC	cliente	profile/276_1768176614.jpg	\N	1	1	2026-01-11 22:11:34	2026-01-12 00:10:16	2026-01-20 01:16:11	f	\N	\N	\N	5.00	activo	102784292193798397096	\N	email
277	user_696676b59b57a9.80699283	Oscar Alejandro	Oquendo Durango	secretoestoico8052@gmail.com	326556566566	$2y$10$IklqjVXZNcgq/uEaK0S41OhwI7MPjrIB18i1pp9zVjJJJi8t/BhFy	conductor	https://lh3.googleusercontent.com/a/ACg8ocKrSsyN6lq-gOoqsHTzRMsi5aFdjM4yd1az8I9CZwF4ztJNnQ=s96-c	\N	1	1	2026-01-13 16:45:42	2026-01-13 20:48:12	2026-01-21 01:32:51	f	\N	1	\N	5.00	pendiente_aprobacion	114135017006116447797	\N	email
254	empresa_6961b9305a4592.56020642	Braian Andres	Oquendo Durango	bird@gmail.com	2434234	$2y$10$3s1NTs62TgFqYRp17ZjvSumjcEJ36O174Idez/L0lNmypKr2Mr6z.	empresa	\N	\N	0	1	2026-01-10 02:28:00	\N	\N	f	\N	1	\N	5.00	activo	\N	\N	email
274	empresa_6962e6317693b2.08987946	Juan	Oquendo	aguila@gmail.com4	32424	$2y$10$9r7ZRx1IeERSk6MRmEbYg.MD2ewf1/bUzEw0Xk.L1hZzdBPl9kTAW	empresa	\N	\N	0	1	2026-01-10 23:52:17	\N	\N	f	\N	11	\N	5.00	activo	\N	\N	email
275	empresa_rep_6962e6318a5930.51368404	Juan	Oquendo	angelow2025sen@gmail.com	43434553	$2y$10$BECzTxh9eKPMKfVjkFfHfuWHvGndfYMlV01YH7VYwILuB9lpV5b4u	empresa	\N	\N	0	1	2026-01-10 23:52:17	\N	\N	f	\N	11	\N	5.00	activo	\N	\N	email
284	empresa_rep_6966efe8310ec1.32182035	Pablo	Arrumedo	arcardpersonal@gmail.com	4553453	$2y$10$g.t1OjXX5NK80YppBK8IfOON.6u16WocgCZkuNP9NzGaqshhTIKS.	empresa	\N	\N	0	1	2026-01-14 01:22:46	\N	\N	f	\N	14	\N	5.00	activo	\N	\N	email
285	empresa_6966f1120a8e08.92150099	Victor	Proto	halal@gmail.com	4342423356	$2y$10$SeEQL.3Yyl5pLHy6nW7jfOlTFnUfkVkmFfA4TvDO9DVlxGDF2QHmS	empresa	\N	\N	0	1	2026-01-14 01:27:46	\N	\N	f	\N	15	\N	5.00	activo	\N	\N	email
279	empresa_6966e616d5eac3.67270518	Braian Andres	Gonzales	humany@gmail.com	45535435	$2y$10$WylALU93HlOK3LVt6nwdveyknHN8RbfoJHWimodhANu4C8YobazhW	empresa	\N	\N	0	1	2026-01-14 00:40:55	\N	\N	f	\N	12	\N	5.00	activo	\N	\N	email
280	empresa_rep_6966e617021643.96084786	Braian Andres	Gonzales	humanypersonal@gmail.com	5435365	$2y$10$7OiqaA4xoR/mcLiRGxVM7.olcsscCVXIzrOjtQbbzK06HHbjgP73K	empresa	\N	\N	0	1	2026-01-14 00:40:55	\N	\N	f	\N	12	\N	5.00	activo	\N	\N	email
289	user_6966ff7ea6abc6.69914356	Carlos	Perez	carlos.perez613@elite-test.com	3005538937	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:29:19	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
286	empresa_rep_6966f1121d1303.94418517	Victor	Proto	Halalpersonal@gmail.com	42345345	$2y$10$Hd7g/AVU9VjaMs4W0j8Wpehuj7LX95C0e.3Qsn.oSuJefwxWIYSyS	empresa	\N	\N	0	1	2026-01-14 01:27:46	\N	\N	f	\N	15	\N	5.00	activo	\N	\N	email
281	empresa_6966e7434bde78.23885224	Cristian	Zapata	elite@gmail.com	5646465	$2y$10$075cDfqlQ.KNUQB6A..CdOzIOWwwtupP3.bf8j0UhLi3Jrin8sdRG	empresa	\N	\N	0	1	2026-01-14 00:45:55	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
282	empresa_rep_6966e74363d099.33310045	Cristian	Zapata	elitepersonal@gmail.com	4554665	$2y$10$opQg8BeskDxArYH3MYyr8.Tld24iBMauDKOBxKKS/Fw3uOhsGYt/6	empresa	\N	\N	0	1	2026-01-14 00:45:55	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
287	empresa_6966f2134583c9.34898702	Hector	Gustavo	friends@gmail.com	3243453	$2y$10$JRciJrIXnMr7xdNjXQUXTejUz6EnM262ufgpXNqFIFZqxgI4ugN2S	empresa	\N	\N	0	1	2026-01-14 01:32:03	\N	\N	f	\N	16	\N	5.00	activo	\N	\N	email
288	empresa_rep_6966f213587b68.27894116	Hector	Gustavo	friendspersonal@gmail.com	5423	$2y$10$VECjacTCIpt1zoszbTsmSOpBnNpMPqHbDyrKne0M9dVvG7oP3hbQy	empresa	\N	\N	0	1	2026-01-14 01:32:03	\N	\N	f	\N	16	\N	5.00	activo	\N	\N	email
290	user_6966ffa1861c80.54814918	Carlos	Perez	carlos.perez825@elite-test.com	3008037524	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:29:54	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
291	user_6966ffb48513a3.28220378	Carlos	Perez	carlos.perez337@elite-test.com	3001385359	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:30:13	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
283	empresa_6966efe6688213.10593412	Pablo	Arrumedo	acard@gmail.com	43424	$2y$10$AM6zAhe7BYGEGpy9r8sChekJGxgWtLob3SB4N7hj3LYLT004EyXNq	empresa	\N	\N	0	1	2026-01-14 01:22:46	\N	\N	f	\N	14	\N	5.00	activo	\N	\N	email
292	user_6966ffdd66bf04.83518428	Carlos	Perez	carlos.perez178@elite-test.com	3008010482	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:30:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
293	user_69670018b78745.62437346	Carlos	Perez	carlos.perez@elite-test.com	3000000000	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:31:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
294	user_69670018bc6278.71192726	Juan	Gomez	juan.gomez@elite-test.com	3000123456	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:31:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
295	user_69670018bdbfd1.07698441	Andres	Rodriguez	andres.rodriguez@elite-test.com	3000246912	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:31:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
296	user_69670018bf0993.55743235	Felipe	Lopez	felipe.lopez@elite-test.com	3000370368	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:31:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
297	user_69670018bfdc51.91298050	Luis	Martinez	luis.martinez@elite-test.com	3000493824	dummy_hash	conductor	\N	\N	0	1	2026-01-14 02:31:53	\N	\N	f	\N	13	\N	5.00	activo	\N	\N	email
\.


--
-- TOC entry 6085 (class 0 OID 16849)
-- Dependencies: 241
-- Data for Name: usuarios_backup_20251023; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuarios_backup_20251023 (id, uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, url_imagen_perfil, fecha_nacimiento, verificado, activo, creado_en, actualizado_en, ultimo_acceso_en) FROM stdin;
1	user_68daf618780e50.65802566	braian	oquendo	braianoquen@gmail.com	3013636902	$2y$10$H2Un4DmxCsM6XOGA1fiX8.5VB42Z9v8uwqERrGBms83dk2CQVQKnO	administrador	\N	\N	0	1	2025-09-29 21:11:52	2025-10-22 14:16:12	\N
2	user_68e44706c14db4.53994811	braian890	oquendo	braian890@gmail.com	32323232	$2y$10$NB9S4hWQLrK7HhTjc9yneu9RTb6otip3dtZ1muEgukWWLKcSpxRF6	cliente	\N	\N	0	1	2025-10-06 22:47:34	\N	\N
3	user_68e44d12079086.97442308	braianoquen79	oquendo	braianoquen79@gmail.com	34343434	$2y$10$6LhMx5vHi.3LrrM/EjFjw.ZztZWhhGQgqf1sD76h2RtJ4B7nN/sjC	cliente	\N	\N	0	1	2025-10-06 23:13:22	\N	\N
4	user_68f5142e614579.71603626	braianoquen323	oquendo	braianoquen323@gmail.com	213131313131	$2y$10$qSZ1igIQd1BQJmq.MRMwM.2EUfUYhvXhsf4g0h7GJJDJ8uaR66/qy	cliente	\N	\N	0	1	2025-10-19 16:39:10	\N	\N
5	user_68f6b9b1f1cb28.57297864	braianoquen324	oquendo	braianoquen324@gmail.com	4274672	$2y$10$Oji7gxZcVki50Pyk5aReKexUhCGPbXLGNe.rsnlzAaZvI.Bo.UexS	cliente	\N	\N	0	1	2025-10-20 22:37:37	\N	\N
6	user_68f8e56f0736b2.62296910	braianoquendurango	oquendo	braianoquendurango@gmail.com	323121	$2y$10$DDOIUEJ8jv1ILAu7PKj3LutCGRru.7sVUs2himDiKZ4yqY.VtvRb6	cliente	\N	\N	0	1	2025-10-22 14:08:47	\N	\N
7	user_68f8e5efd5f888.59258279	braianoquen2	oqeundo	braianoquen2@gmail.com	3242442	$2y$10$DUUZdDrKiyespZGSJfk9JeGYuvOkAjrlMemg9BA/BZfyXlamgobjW	conductor	\N	\N	0	1	2025-10-22 14:10:55	2025-10-22 14:15:38	\N
\.


--
-- TOC entry 6086 (class 0 OID 16863)
-- Dependencies: 242
-- Data for Name: verification_codes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.verification_codes (id, email, code, created_at, expires_at, used) FROM stdin;
1	braianoquen@gmail.com	184773	2025-09-22 00:02:19	2025-09-22 05:12:19	0
2	braianoquen@gmail.com	740721	2025-09-22 00:40:36	2025-09-22 05:50:36	0
3	braianoquen@gmail.com	470836	2025-09-22 03:16:18	2025-09-22 08:26:18	0
4	braianoquen@gmail.com	553736	2025-09-22 03:32:16	2025-09-22 08:42:16	0
5	braianoquen@gmail.com	558786	2025-09-22 03:42:09	2025-09-22 08:52:09	0
6	braianoquen@gmail.com	871431	2025-09-22 03:44:25	2025-09-22 08:54:25	0
7	braianoquen@gmail.com	109811	2025-09-22 03:48:08	2025-09-22 08:58:08	0
8	braianoquen@gmail.com	895561	2025-09-22 04:05:48	2025-09-22 09:15:48	0
9	traconmaster@gmail.com	517375	2025-09-22 04:09:27	2025-09-22 09:19:27	0
10	tracongames2@gmail.com	439802	2025-09-22 04:29:37	2025-09-22 09:39:37	0
11	tracongames3@gmail.com	928041	2025-09-22 04:40:27	2025-09-22 09:50:27	0
12	braianoquen@gmail.com	471108	2025-09-22 04:50:52	2025-09-22 10:00:52	0
13	braianoquen@gmail.com	289263	2025-09-22 04:59:38	2025-09-22 10:09:38	0
14	tracon2@gmail.com	972225	2025-09-22 23:15:48	2025-09-23 04:25:48	0
15	braianoquen@gmail.com	532386	2025-09-22 23:17:22	2025-09-23 04:27:22	0
16	gellen@gmail.com	836288	2025-09-29 16:33:39	2025-09-29 21:43:39	0
17	gellen2@gmail.com	618398	2025-09-29 16:42:48	2025-09-29 21:52:48	0
18	gellen4@gmail.com	503956	2025-09-29 16:59:45	2025-09-29 22:09:45	0
19	gellen4@gmail.com	215305	2025-09-29 17:06:30	2025-09-29 22:16:30	0
20	gellen2@gmail.com	309347	2025-09-29 17:12:20	2025-09-29 22:22:20	0
21	gellen2@gmail.com	430759	2025-09-29 17:16:52	2025-09-29 22:26:52	0
22	gellen2@gmail.com	571778	2025-09-29 17:24:00	2025-09-29 22:34:00	0
23	gellen2@gmail.com	641077	2025-09-29 17:30:09	2025-09-29 22:40:09	0
24	gellen2@gmail.com	129852	2025-09-29 17:36:07	2025-09-29 22:46:07	0
25	gellen2@gmail.com	644993	2025-09-29 17:43:12	2025-09-29 22:53:12	0
26	gellen2@gmail.com	931663	2025-09-29 17:47:56	2025-09-29 22:57:56	0
27	gellen2@gmail.com	661112	2025-09-29 17:50:41	2025-09-29 23:00:41	0
28	gellen2@gmail.com	580543	2025-09-29 17:51:12	2025-09-29 23:01:12	0
29	gellen2@gmail.com	105869	2025-09-29 17:55:34	2025-09-29 23:05:34	0
30	gellen34@gmail.com	345823	2025-09-29 18:02:16	2025-09-29 23:12:16	0
31	gellen2@gmail.com	749371	2025-09-29 18:06:18	2025-09-29 23:16:18	0
32	gellen2@gmail.com	108467	2025-09-29 18:11:22	2025-09-29 23:21:22	0
33	gellen2@gmail.com	828608	2025-09-29 18:17:44	2025-09-29 23:27:44	0
34	andres80@gmail.com	263140	2025-09-29 19:18:28	2025-09-30 00:28:28	0
35	braianoquen@gmail.com	891517	2025-09-29 19:26:17	2025-09-30 00:36:17	0
36	braianoquen@gmail.com	557643	2025-09-29 19:37:35	2025-09-30 00:47:35	0
37	braianoquen@gmail.com	898296	2025-09-29 19:44:37	2025-09-30 00:54:37	0
38	braianoquen@gmail.com	750790	2025-09-29 20:11:50	2025-09-30 01:21:50	0
39	braianoquendurango@gmail.com	636850	2025-09-29 20:13:08	2025-09-30 01:23:08	0
40	braianoquendurango@gmail.com	619818	2025-09-29 20:23:00	2025-09-30 01:33:00	0
41	braianoquendurango@gmail.com	906593	2025-09-29 20:29:27	2025-09-30 01:39:27	0
42	braianoquen@gmail.com	824558	2025-09-29 20:31:55	2025-09-30 01:41:55	0
43	braianoquen@gmail.com	819688	2025-09-29 20:36:15	2025-09-30 01:46:15	0
44	braianoquen@gmail.com	311995	2025-09-29 20:37:09	2025-09-30 01:47:09	0
45	braianoquen@gmail.com	187066	2025-09-29 20:37:48	2025-09-30 01:47:48	0
46	braianoquen@gmail.com	501886	2025-09-29 20:55:37	2025-09-30 02:05:37	0
47	braianoquen@gmail.com	274084	2025-09-29 21:02:39	2025-09-30 02:12:39	0
48	braianoquen@gmail.com	614962	2025-09-29 21:08:06	2025-09-30 02:18:06	0
49	braianoquen@gmail.com	377184	2025-09-29 21:10:58	2025-09-30 02:20:58	0
50	braianoquendurango@gmail.com	940771	2025-10-05 12:31:26	2025-10-05 17:41:26	0
51	braianoquendurango@gmail.com	156648	2025-10-05 12:33:09	2025-10-05 17:43:09	0
52	braianoquendurango@gmail.com	360795	2025-10-05 13:14:57	2025-10-05 18:24:57	0
53	braianoquendurango@gmail.com	270293	2025-10-05 13:18:24	2025-10-05 18:28:24	0
54	braianoquendurango@gmail.com	366137	2025-10-05 13:22:20	2025-10-05 18:32:20	0
55	braianoquendurango@gmail.com	219856	2025-10-05 13:22:53	2025-10-05 18:32:53	0
56	braianoquendurango@gmail.com	246651	2025-10-05 13:43:15	2025-10-05 18:53:15	0
57	braianoquendurango@gmail.com	170449	2025-10-05 13:48:15	2025-10-05 18:58:15	0
58	braianoquendurango@gmail.com	897340	2025-10-05 13:53:37	2025-10-05 19:03:37	0
59	braianoquendurango@gmail.com	816291	2025-10-05 13:57:58	2025-10-05 19:07:58	0
60	braianoquendurango@gmail.com	834542	2025-10-05 14:02:31	2025-10-05 19:12:31	0
61	braianoquendurango@gmail.com	220660	2025-10-05 14:07:14	2025-10-05 19:17:14	0
62	braianoquendurango@gmail.com	527698	2025-10-05 16:34:49	2025-10-05 21:44:49	0
63	braianoquendurango@gmail.com	947445	2025-10-05 16:46:56	2025-10-05 21:56:56	0
64	braianoquendurango@gmail.com	687214	2025-10-05 17:05:14	2025-10-05 22:15:14	0
65	braianoquendurango@gmail.com	586620	2025-10-05 17:35:18	2025-10-05 22:45:18	0
66	braianoquendurango@gmail.com	476004	2025-10-05 17:42:10	2025-10-05 22:52:10	0
67	braianoquen@gmail.com	822586	2025-10-05 18:51:09	2025-10-06 00:01:09	0
68	braianoquen@gmail.com	768999	2025-10-05 20:15:24	2025-10-06 01:25:24	0
69	braianoquen@gmail.com	635063	2025-10-05 20:16:32	2025-10-06 01:26:32	0
70	braianoquen@gmail.com	663502	2025-10-05 20:31:20	2025-10-06 01:41:20	0
71	braianoquen@gmail.com	656436	2025-10-05 20:55:10	2025-10-06 02:05:10	0
72	braianoquen@gmail.com	950733	2025-10-06 22:42:36	2025-10-07 03:52:36	0
73	braianoquen@gmail.com	972074	2025-10-06 22:44:02	2025-10-07 03:54:02	0
74	braian890@gmail.com	174360	2025-10-06 22:45:51	2025-10-07 03:55:51	0
75	braianoquen@gmail.com	701975	2025-10-06 22:49:07	2025-10-07 03:59:07	0
76	braianoquen79@gmail.com	185834	2025-10-06 23:07:49	2025-10-07 04:17:49	0
77	braianoquen80@gmail.com	367890	2025-10-17 03:02:29	2025-10-17 08:12:29	0
78	braianoquen@gmail.com	893059	2025-10-17 12:40:14	2025-10-17 17:50:14	0
79	braianoquen@gmail.com	894968	2025-10-17 12:55:02	2025-10-17 18:05:02	0
80	braianoquen@gmail.com	342619	2025-10-17 13:18:43	2025-10-17 18:28:43	0
81	braianoquen@gmail.com	575878	2025-10-19 14:35:11	2025-10-19 19:45:11	0
82	braaian80@gmail.com	109667	2025-10-19 16:11:09	2025-10-19 21:21:09	0
83	braianoquen13231@gmail.com	881509	2025-10-19 16:30:14	2025-10-19 21:40:14	0
84	braianoquen323@gmail.com	700367	2025-10-19 16:37:32	2025-10-19 21:47:32	0
85	braianoquen324@gmail.com	648366	2025-10-20 22:33:07	2025-10-21 03:43:07	0
86	braianoquen2@gmail.com	245192	2025-10-22 14:05:51	2025-10-22 19:15:51	0
87	braianoquendurango@gmail.com	948056	2025-10-22 14:07:51	2025-10-22 19:17:51	0
88	braianoquen2@gmail.com	607965	2025-10-22 14:10:18	2025-10-22 19:20:18	0
89	braianoquen@gmail.com	108760	2025-10-22 14:37:06	2025-10-22 19:47:06	0
90	braianoquen2@gmail.com	578807	2025-10-24 11:11:08	2025-10-24 16:21:08	0
\.


--
-- TOC entry 6158 (class 0 OID 123797)
-- Dependencies: 321
-- Data for Name: viaje_resumen_tracking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.viaje_resumen_tracking (id, solicitud_id, distancia_real_km, tiempo_real_minutos, distancia_estimada_km, tiempo_estimado_minutos, diferencia_distancia_km, diferencia_tiempo_min, porcentaje_desvio_distancia, precio_estimado, precio_final_calculado, precio_final_aplicado, velocidad_promedio_kmh, velocidad_maxima_kmh, total_puntos_gps, tiene_desvio_ruta, km_desvio_detectado, inicio_viaje_real, fin_viaje_real, creado_en, actualizado_en) FROM stdin;
1	740	0.000	2	0.000	0	0.000	0	0.00	0.00	0.00	0.00	0.00	0.00	2	f	0.000	2026-01-18 02:08:38.871771	\N	2026-01-18 02:08:38.871771	2026-01-18 02:10:13.13505
3	741	0.000	2	0.000	0	0.000	0	0.00	0.00	0.00	0.00	0.00	0.00	2	f	0.000	2026-01-18 02:23:10.368402	\N	2026-01-18 02:23:10.368402	2026-01-18 02:24:15.18838
5	742	0.000	2	0.000	0	0.000	0	0.00	0.00	0.00	0.00	0.00	0.00	2	f	0.000	2026-01-18 02:58:38.936533	\N	2026-01-18 02:58:38.936533	2026-01-18 03:00:08.397349
7	743	0.000	2	0.000	0	0.000	0	0.00	0.00	0.00	0.00	0.00	0.00	2	f	0.000	2026-01-18 03:20:05.42157	\N	2026-01-18 03:20:05.42157	2026-01-18 03:21:07.324165
35	747	0.000	2	24.490	41	-24.490	-39	-100.00	63225.00	6000.00	6000.00	0.00	0.00	21	t	0.000	2026-01-18 14:29:04.995422	2026-01-18 14:30:40.813843	2026-01-18 14:29:04.995422	2026-01-18 14:30:40.813843
230	775	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	13	t	0.000	2026-01-19 23:00:01.712867	2026-01-19 23:00:59.311955	2026-01-19 23:00:01.712867	2026-01-19 23:00:59.311955
179	767	0.000	2	24.490	41	-24.490	-39	-100.00	75869.00	6000.00	6000.00	0.00	0.00	20	t	0.000	2026-01-19 03:24:36.700765	2026-01-19 03:26:09.15052	2026-01-19 03:24:36.700765	2026-01-19 03:26:09.15052
200	768	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	3	t	0.000	2026-01-19 03:40:20.071255	2026-01-19 03:40:28.72373	2026-01-19 03:40:20.071255	2026-01-19 03:40:28.72373
57	748	0.000	1	24.490	41	-24.490	-40	-100.00	63225.00	6000.00	6000.00	0.00	0.00	9	t	0.000	2026-01-18 15:05:15.319767	2026-01-18 15:05:51.442411	2026-01-18 15:05:15.319767	2026-01-18 15:05:51.442411
9	744	0.000	1	24.490	41	-24.490	-40	-100.00	63225.00	6000.00	6000.00	0.00	0.00	13	t	0.000	2026-01-18 13:11:29.56679	2026-01-18 13:12:19.004516	2026-01-18 13:11:29.56679	2026-01-18 13:12:19.272806
277	780	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	7	t	0.000	2026-01-20 00:33:05.386262	2026-01-20 00:33:32.334503	2026-01-20 00:33:05.386262	2026-01-20 00:33:32.334503
337	787	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	13	t	0.000	2026-01-21 01:37:52.692324	2026-01-21 01:38:49.155455	2026-01-21 01:37:52.692324	2026-01-21 01:38:49.155455
244	776	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	7	t	0.000	2026-01-19 23:18:50.45494	2026-01-19 23:19:17.708476	2026-01-19 23:18:50.45494	2026-01-19 23:19:17.708476
23	745	0.000	1	24.490	41	-24.490	-40	-100.00	63225.00	6000.00	6000.00	0.00	0.00	10	t	0.000	2026-01-18 13:56:55.778445	2026-01-18 14:04:36.323496	2026-01-18 13:56:55.778445	2026-01-18 14:04:36.323496
285	782	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	5	t	0.000	2026-01-20 00:51:55.333611	2026-01-20 00:52:14.293434	2026-01-20 00:51:55.333611	2026-01-20 00:52:14.293434
252	777	0.000	1	0.000	0	0.000	0	0.00	0.00	0.00	0.00	0.00	0.00	6	f	0.000	2026-01-19 23:21:50.83374	\N	2026-01-19 23:21:50.83374	2026-01-19 23:22:15.924989
204	769	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	13	t	0.000	2026-01-19 22:22:22.573852	2026-01-19 22:23:21.801625	2026-01-19 22:22:22.573852	2026-01-19 22:23:21.801625
67	766	0.000	10	24.490	41	-24.490	-31	-100.00	75869.00	7800.00	7800.00	0.00	0.00	111	t	0.000	2026-01-19 00:02:58.553311	2026-01-19 00:12:06.560003	2026-01-19 00:02:58.553311	2026-01-19 00:12:06.560003
258	778	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	5	t	0.000	2026-01-19 23:22:47.066413	2026-01-19 23:23:06.64876	2026-01-19 23:22:47.066413	2026-01-19 23:23:06.64876
311	785	0.000	2	24.490	41	-24.490	-39	-100.00	75869.00	6000.00	6000.00	0.00	0.00	17	t	0.000	2026-01-20 01:35:19.154306	2026-01-20 01:36:38.164935	2026-01-20 01:35:19.154306	2026-01-20 01:36:38.164935
291	783	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	8	t	0.000	2026-01-20 01:04:13.891843	2026-01-20 01:04:46.008966	2026-01-20 01:04:13.891843	2026-01-20 01:04:46.008966
218	772	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	11	t	0.000	2026-01-19 22:50:28.487567	2026-01-19 22:51:14.819323	2026-01-19 22:50:28.487567	2026-01-19 22:51:14.819323
264	779	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	12	t	0.000	2026-01-20 00:02:47.909505	2026-01-20 00:03:40.321989	2026-01-20 00:02:47.909505	2026-01-20 00:03:40.321989
329	786	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	7	t	0.000	2026-01-20 01:53:41.13328	2026-01-20 01:54:06.776444	2026-01-20 01:53:41.13328	2026-01-20 01:54:06.776444
300	784	0.000	1	24.490	41	-24.490	-40	-100.00	75869.00	6000.00	6000.00	0.00	0.00	10	t	0.000	2026-01-20 01:19:44.970697	2026-01-20 01:20:28.971069	2026-01-20 01:19:44.970697	2026-01-20 01:20:28.971069
\.


--
-- TOC entry 6156 (class 0 OID 123764)
-- Dependencies: 319
-- Data for Name: viaje_tracking_realtime; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.viaje_tracking_realtime (id, solicitud_id, conductor_id, latitud, longitud, precision_gps, altitud, velocidad, bearing, distancia_acumulada_km, tiempo_transcurrido_seg, distancia_desde_anterior_m, precio_parcial, timestamp_gps, timestamp_servidor, fase_viaje, evento, sincronizado) FROM stdin;
1	740	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	0.00	2026-01-18 02:08:38.871771	2026-01-18 02:08:38.871771	hacia_destino	inicio	t
2	740	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	94	0.00	0.00	2026-01-18 02:10:13.13505	2026-01-18 02:10:13.13505	hacia_destino	fin	t
3	741	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	0.00	2026-01-18 02:23:10.368402	2026-01-18 02:23:10.368402	hacia_destino	inicio	t
4	741	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	64	0.00	0.00	2026-01-18 02:24:15.18838	2026-01-18 02:24:15.18838	hacia_destino	fin	t
5	742	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	0.00	2026-01-18 02:58:38.936533	2026-01-18 02:58:38.936533	hacia_destino	inicio	t
6	742	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	89	0.00	0.00	2026-01-18 03:00:08.397349	2026-01-18 03:00:08.397349	hacia_destino	fin	t
7	743	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	0.00	2026-01-18 03:20:05.42157	2026-01-18 03:20:05.42157	hacia_destino	inicio	t
8	743	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	61	0.00	0.00	2026-01-18 03:21:07.324165	2026-01-18 03:21:07.324165	hacia_destino	fin	t
9	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:29.56679	2026-01-18 13:11:29.56679	hacia_destino	inicio	t
10	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:34.670158	2026-01-18 13:11:34.670158	hacia_destino	inicio	t
11	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:39.670894	2026-01-18 13:11:39.670894	hacia_destino	inicio	t
12	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:44.678027	2026-01-18 13:11:44.678027	hacia_destino	inicio	t
13	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:49.675935	2026-01-18 13:11:49.675935	hacia_destino	inicio	t
14	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:54.707857	2026-01-18 13:11:54.707857	hacia_destino	inicio	t
15	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:11:59.76455	2026-01-18 13:11:59.76455	hacia_destino	inicio	t
16	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:12:04.666513	2026-01-18 13:12:04.666513	hacia_destino	inicio	t
17	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:12:09.660159	2026-01-18 13:12:09.660159	hacia_destino	inicio	t
18	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:12:14.658673	2026-01-18 13:12:14.658673	hacia_destino	inicio	t
19	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	49	0.00	6000.00	2026-01-18 13:12:18.92544	2026-01-18 13:12:18.92544	hacia_destino	fin	t
20	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:12:19.195401	2026-01-18 13:12:19.195401	hacia_destino	inicio	t
21	744	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	49	0.00	6000.00	2026-01-18 13:12:19.272806	2026-01-18 13:12:19.272806	hacia_destino	fin	t
22	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:56:55.778445	2026-01-18 13:56:55.778445	hacia_destino	inicio	t
23	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:00.890733	2026-01-18 13:57:00.890733	hacia_destino	inicio	t
24	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:05.881268	2026-01-18 13:57:05.881268	hacia_destino	inicio	t
25	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:10.868328	2026-01-18 13:57:10.868328	hacia_destino	inicio	t
26	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:15.883352	2026-01-18 13:57:15.883352	hacia_destino	inicio	t
27	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:20.882934	2026-01-18 13:57:20.882934	hacia_destino	inicio	t
28	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:25.893201	2026-01-18 13:57:25.893201	hacia_destino	inicio	t
29	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	31	0.00	6000.00	2026-01-18 13:57:27.590776	2026-01-18 13:57:27.590776	hacia_destino	fin	t
30	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 13:57:27.736057	2026-01-18 13:57:27.736057	hacia_destino	inicio	t
31	745	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	31	0.00	6000.00	2026-01-18 13:57:27.907246	2026-01-18 13:57:27.907246	hacia_destino	fin	t
32	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 14:29:04.995422	2026-01-18 14:29:04.995422	hacia_destino	inicio	t
33	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-18 14:29:10.105054	2026-01-18 14:29:10.105054	hacia_destino	\N	t
34	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-18 14:29:15.11655	2026-01-18 14:29:15.11655	hacia_destino	\N	t
35	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-18 14:29:20.207438	2026-01-18 14:29:20.207438	hacia_destino	\N	t
36	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-18 14:29:25.103036	2026-01-18 14:29:25.103036	hacia_destino	\N	t
37	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-18 14:29:30.121269	2026-01-18 14:29:30.121269	hacia_destino	\N	t
38	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-18 14:29:35.104141	2026-01-18 14:29:35.104141	hacia_destino	\N	t
39	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-18 14:29:40.100749	2026-01-18 14:29:40.100749	hacia_destino	\N	t
40	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-18 14:29:45.113896	2026-01-18 14:29:45.113896	hacia_destino	\N	t
41	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-18 14:29:50.175576	2026-01-18 14:29:50.175576	hacia_destino	\N	t
42	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-18 14:29:55.13249	2026-01-18 14:29:55.13249	hacia_destino	\N	t
43	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-18 14:30:00.118988	2026-01-18 14:30:00.118988	hacia_destino	\N	t
44	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	60	0.00	6000.00	2026-01-18 14:30:05.111097	2026-01-18 14:30:05.111097	hacia_destino	\N	t
45	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	65	0.00	6000.00	2026-01-18 14:30:10.112484	2026-01-18 14:30:10.112484	hacia_destino	\N	t
46	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	70	0.00	6000.00	2026-01-18 14:30:15.133368	2026-01-18 14:30:15.133368	hacia_destino	\N	t
47	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	75	0.00	6000.00	2026-01-18 14:30:20.193466	2026-01-18 14:30:20.193466	hacia_destino	\N	t
48	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	80	0.00	6000.00	2026-01-18 14:30:25.151314	2026-01-18 14:30:25.151314	hacia_destino	\N	t
49	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	85	0.00	6000.00	2026-01-18 14:30:30.128579	2026-01-18 14:30:30.128579	hacia_destino	\N	t
50	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	90	0.00	6000.00	2026-01-18 14:30:35.104242	2026-01-18 14:30:35.104242	hacia_destino	\N	t
51	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	95	0.00	6000.00	2026-01-18 14:30:40.217725	2026-01-18 14:30:40.217725	hacia_destino	\N	t
52	747	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	95	0.00	6000.00	2026-01-18 14:30:40.744206	2026-01-18 14:30:40.744206	hacia_destino	fin	t
53	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-18 15:05:15.319767	2026-01-18 15:05:15.319767	hacia_destino	inicio	t
54	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-18 15:05:20.437455	2026-01-18 15:05:20.437455	hacia_destino	\N	t
55	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-18 15:05:25.410267	2026-01-18 15:05:25.410267	hacia_destino	\N	t
56	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-18 15:05:30.40266	2026-01-18 15:05:30.40266	hacia_destino	\N	t
57	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-18 15:05:35.413843	2026-01-18 15:05:35.413843	hacia_destino	\N	t
58	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-18 15:05:40.401222	2026-01-18 15:05:40.401222	hacia_destino	\N	t
59	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-18 15:05:45.412393	2026-01-18 15:05:45.412393	hacia_destino	\N	t
60	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-18 15:05:50.406626	2026-01-18 15:05:50.406626	hacia_destino	\N	t
61	748	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	36	0.00	6000.00	2026-01-18 15:05:51.359814	2026-01-18 15:05:51.359814	hacia_destino	fin	t
62	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	1	0.00	6000.00	2026-01-19 00:02:58.553311	2026-01-19 00:02:58.553311	hacia_destino	inicio	t
63	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	6	0.00	6000.00	2026-01-19 00:03:03.73015	2026-01-19 00:03:03.73015	hacia_destino	\N	t
64	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	11	0.00	6000.00	2026-01-19 00:03:08.725534	2026-01-19 00:03:08.725534	hacia_destino	\N	t
65	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	16	0.00	6000.00	2026-01-19 00:03:13.685717	2026-01-19 00:03:13.685717	hacia_destino	\N	t
66	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	21	0.00	6000.00	2026-01-19 00:03:18.738561	2026-01-19 00:03:18.738561	hacia_destino	\N	t
67	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	26	0.00	6000.00	2026-01-19 00:03:23.67413	2026-01-19 00:03:23.67413	hacia_destino	\N	t
68	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	31	0.00	6000.00	2026-01-19 00:03:28.671494	2026-01-19 00:03:28.671494	hacia_destino	\N	t
69	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	36	0.00	6000.00	2026-01-19 00:03:33.69812	2026-01-19 00:03:33.69812	hacia_destino	\N	t
70	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	41	0.00	6000.00	2026-01-19 00:03:38.692173	2026-01-19 00:03:38.692173	hacia_destino	\N	t
71	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	46	0.00	6000.00	2026-01-19 00:03:43.684792	2026-01-19 00:03:43.684792	hacia_destino	\N	t
72	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	51	0.00	6000.00	2026-01-19 00:03:48.754097	2026-01-19 00:03:48.754097	hacia_destino	\N	t
73	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	56	0.00	6000.00	2026-01-19 00:03:53.741383	2026-01-19 00:03:53.741383	hacia_destino	\N	t
74	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	61	0.00	6000.00	2026-01-19 00:03:58.816617	2026-01-19 00:03:58.816617	hacia_destino	\N	t
75	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	66	0.00	6000.00	2026-01-19 00:04:03.685437	2026-01-19 00:04:03.685437	hacia_destino	\N	t
76	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	71	0.00	6000.00	2026-01-19 00:04:08.693127	2026-01-19 00:04:08.693127	hacia_destino	\N	t
77	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	76	0.00	6000.00	2026-01-19 00:04:13.689865	2026-01-19 00:04:13.689865	hacia_destino	\N	t
78	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	81	0.00	6000.00	2026-01-19 00:04:18.672696	2026-01-19 00:04:18.672696	hacia_destino	\N	t
79	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	86	0.00	6000.00	2026-01-19 00:04:23.680972	2026-01-19 00:04:23.680972	hacia_destino	\N	t
80	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	91	0.00	6000.00	2026-01-19 00:04:28.681822	2026-01-19 00:04:28.681822	hacia_destino	\N	t
81	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	96	0.00	6000.00	2026-01-19 00:04:33.690991	2026-01-19 00:04:33.690991	hacia_destino	\N	t
82	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	101	0.00	6000.00	2026-01-19 00:04:38.708729	2026-01-19 00:04:38.708729	hacia_destino	\N	t
83	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	106	0.00	6000.00	2026-01-19 00:04:43.691779	2026-01-19 00:04:43.691779	hacia_destino	\N	t
84	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	111	0.00	6000.00	2026-01-19 00:04:48.695332	2026-01-19 00:04:48.695332	hacia_destino	\N	t
85	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	116	0.00	6000.00	2026-01-19 00:04:53.687349	2026-01-19 00:04:53.687349	hacia_destino	\N	t
86	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	121	0.00	6000.00	2026-01-19 00:04:58.775123	2026-01-19 00:04:58.775123	hacia_destino	\N	t
87	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	126	0.00	6000.00	2026-01-19 00:05:03.693343	2026-01-19 00:05:03.693343	hacia_destino	\N	t
88	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	131	0.00	6000.00	2026-01-19 00:05:08.830604	2026-01-19 00:05:08.830604	hacia_destino	\N	t
89	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	136	0.00	6000.00	2026-01-19 00:05:13.708428	2026-01-19 00:05:13.708428	hacia_destino	\N	t
90	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	141	0.00	6000.00	2026-01-19 00:05:18.679879	2026-01-19 00:05:18.679879	hacia_destino	\N	t
91	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	146	0.00	6000.00	2026-01-19 00:05:23.745456	2026-01-19 00:05:23.745456	hacia_destino	\N	t
92	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	151	0.00	6000.00	2026-01-19 00:05:28.675653	2026-01-19 00:05:28.675653	hacia_destino	\N	t
93	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	156	0.00	6000.00	2026-01-19 00:05:33.683822	2026-01-19 00:05:33.683822	hacia_destino	\N	t
94	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	161	0.00	6000.00	2026-01-19 00:05:38.692779	2026-01-19 00:05:38.692779	hacia_destino	\N	t
95	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	166	0.00	6000.00	2026-01-19 00:05:43.675192	2026-01-19 00:05:43.675192	hacia_destino	\N	t
96	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	171	0.00	6000.00	2026-01-19 00:05:48.680817	2026-01-19 00:05:48.680817	hacia_destino	\N	t
97	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	176	0.00	6000.00	2026-01-19 00:05:53.727932	2026-01-19 00:05:53.727932	hacia_destino	\N	t
98	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	181	0.00	6000.00	2026-01-19 00:05:58.704882	2026-01-19 00:05:58.704882	hacia_destino	\N	t
99	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	186	0.00	6000.00	2026-01-19 00:06:03.675943	2026-01-19 00:06:03.675943	hacia_destino	\N	t
100	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	191	0.00	6000.00	2026-01-19 00:06:08.714468	2026-01-19 00:06:08.714468	hacia_destino	\N	t
101	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	196	0.00	6000.00	2026-01-19 00:06:13.687355	2026-01-19 00:06:13.687355	hacia_destino	\N	t
102	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	201	0.00	6000.00	2026-01-19 00:06:18.691042	2026-01-19 00:06:18.691042	hacia_destino	\N	t
103	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	206	0.00	6000.00	2026-01-19 00:06:23.790468	2026-01-19 00:06:23.790468	hacia_destino	\N	t
104	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	211	0.00	6000.00	2026-01-19 00:06:28.675324	2026-01-19 00:06:28.675324	hacia_destino	\N	t
105	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	216	0.00	6000.00	2026-01-19 00:06:33.705338	2026-01-19 00:06:33.705338	hacia_destino	\N	t
106	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	221	0.00	6000.00	2026-01-19 00:06:38.685048	2026-01-19 00:06:38.685048	hacia_destino	\N	t
107	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	226	0.00	6000.00	2026-01-19 00:06:43.712637	2026-01-19 00:06:43.712637	hacia_destino	\N	t
108	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	231	0.00	6000.00	2026-01-19 00:06:48.761841	2026-01-19 00:06:48.761841	hacia_destino	\N	t
109	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	236	0.00	6000.00	2026-01-19 00:06:53.729062	2026-01-19 00:06:53.729062	hacia_destino	\N	t
110	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	241	0.00	6000.00	2026-01-19 00:06:58.744877	2026-01-19 00:06:58.744877	hacia_destino	\N	t
111	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	246	0.00	6000.00	2026-01-19 00:07:03.703969	2026-01-19 00:07:03.703969	hacia_destino	\N	t
112	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	251	0.00	6000.00	2026-01-19 00:07:08.713638	2026-01-19 00:07:08.713638	hacia_destino	\N	t
113	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	256	0.00	6000.00	2026-01-19 00:07:13.699244	2026-01-19 00:07:13.699244	hacia_destino	\N	t
114	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	261	0.00	6000.00	2026-01-19 00:07:18.815094	2026-01-19 00:07:18.815094	hacia_destino	\N	t
115	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	266	0.00	6000.00	2026-01-19 00:07:23.734221	2026-01-19 00:07:23.734221	hacia_destino	\N	t
116	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	271	0.00	6000.00	2026-01-19 00:07:28.670167	2026-01-19 00:07:28.670167	hacia_destino	\N	t
117	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	276	0.00	6000.00	2026-01-19 00:07:33.715083	2026-01-19 00:07:33.715083	hacia_destino	\N	t
118	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	281	0.00	6000.00	2026-01-19 00:07:38.725049	2026-01-19 00:07:38.725049	hacia_destino	\N	t
119	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	286	0.00	6000.00	2026-01-19 00:07:43.696564	2026-01-19 00:07:43.696564	hacia_destino	\N	t
120	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	291	0.00	6000.00	2026-01-19 00:07:48.883738	2026-01-19 00:07:48.883738	hacia_destino	\N	t
121	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	296	0.00	6000.00	2026-01-19 00:07:53.852382	2026-01-19 00:07:53.852382	hacia_destino	\N	t
122	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	301	0.00	6000.00	2026-01-19 00:07:58.70261	2026-01-19 00:07:58.70261	hacia_destino	\N	t
123	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	306	0.00	6000.00	2026-01-19 00:08:03.679569	2026-01-19 00:08:03.679569	hacia_destino	\N	t
124	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	311	0.00	6000.00	2026-01-19 00:08:08.821022	2026-01-19 00:08:08.821022	hacia_destino	\N	t
125	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	316	0.00	6000.00	2026-01-19 00:08:13.68876	2026-01-19 00:08:13.68876	hacia_destino	\N	t
126	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	321	0.00	6000.00	2026-01-19 00:08:18.683946	2026-01-19 00:08:18.683946	hacia_destino	\N	t
127	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	326	0.00	6000.00	2026-01-19 00:08:23.692502	2026-01-19 00:08:23.692502	hacia_destino	\N	t
128	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	331	0.00	6000.00	2026-01-19 00:08:28.669693	2026-01-19 00:08:28.669693	hacia_destino	\N	t
129	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	336	0.00	6000.00	2026-01-19 00:08:33.706274	2026-01-19 00:08:33.706274	hacia_destino	\N	t
130	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	341	0.00	6000.00	2026-01-19 00:08:38.67207	2026-01-19 00:08:38.67207	hacia_destino	\N	t
131	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	346	0.00	6000.00	2026-01-19 00:08:43.68704	2026-01-19 00:08:43.68704	hacia_destino	\N	t
132	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	351	0.00	6000.00	2026-01-19 00:08:48.71261	2026-01-19 00:08:48.71261	hacia_destino	\N	t
133	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	356	0.00	6000.00	2026-01-19 00:08:53.753064	2026-01-19 00:08:53.753064	hacia_destino	\N	t
134	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	361	0.00	6000.00	2026-01-19 00:08:58.684979	2026-01-19 00:08:58.684979	hacia_destino	\N	t
135	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	366	0.00	6000.00	2026-01-19 00:09:03.714413	2026-01-19 00:09:03.714413	hacia_destino	\N	t
136	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	371	0.00	6000.00	2026-01-19 00:09:08.701358	2026-01-19 00:09:08.701358	hacia_destino	\N	t
137	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	376	0.00	6000.00	2026-01-19 00:09:13.682187	2026-01-19 00:09:13.682187	hacia_destino	\N	t
138	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	381	0.00	6000.00	2026-01-19 00:09:18.674101	2026-01-19 00:09:18.674101	hacia_destino	\N	t
139	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	386	0.00	6000.00	2026-01-19 00:09:23.690236	2026-01-19 00:09:23.690236	hacia_destino	\N	t
140	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	391	0.00	6000.00	2026-01-19 00:09:28.684024	2026-01-19 00:09:28.684024	hacia_destino	\N	t
141	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	396	0.00	6000.00	2026-01-19 00:09:33.693096	2026-01-19 00:09:33.693096	hacia_destino	\N	t
142	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	401	0.00	6000.00	2026-01-19 00:09:38.814585	2026-01-19 00:09:38.814585	hacia_destino	\N	t
143	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	406	0.00	6000.00	2026-01-19 00:09:43.683721	2026-01-19 00:09:43.683721	hacia_destino	\N	t
144	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	411	0.00	6000.00	2026-01-19 00:09:49.057001	2026-01-19 00:09:49.057001	hacia_destino	\N	t
145	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	416	0.00	6000.00	2026-01-19 00:09:53.890183	2026-01-19 00:09:53.890183	hacia_destino	\N	t
146	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	421	0.00	6000.00	2026-01-19 00:09:58.735569	2026-01-19 00:09:58.735569	hacia_destino	\N	t
147	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	426	0.00	6000.00	2026-01-19 00:10:03.689998	2026-01-19 00:10:03.689998	hacia_destino	\N	t
148	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	431	0.00	6000.00	2026-01-19 00:10:08.703098	2026-01-19 00:10:08.703098	hacia_destino	\N	t
149	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	436	0.00	6000.00	2026-01-19 00:10:13.675308	2026-01-19 00:10:13.675308	hacia_destino	\N	t
150	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	441	0.00	6000.00	2026-01-19 00:10:18.683047	2026-01-19 00:10:18.683047	hacia_destino	\N	t
151	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	446	0.00	6000.00	2026-01-19 00:10:23.708181	2026-01-19 00:10:23.708181	hacia_destino	\N	t
152	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	451	0.00	6000.00	2026-01-19 00:10:28.69667	2026-01-19 00:10:28.69667	hacia_destino	\N	t
153	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	456	0.00	6000.00	2026-01-19 00:10:33.691968	2026-01-19 00:10:33.691968	hacia_destino	\N	t
154	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	461	0.00	6000.00	2026-01-19 00:10:38.673314	2026-01-19 00:10:38.673314	hacia_destino	\N	t
155	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	466	0.00	6000.00	2026-01-19 00:10:43.674796	2026-01-19 00:10:43.674796	hacia_destino	\N	t
156	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	471	0.00	6000.00	2026-01-19 00:10:48.670898	2026-01-19 00:10:48.670898	hacia_destino	\N	t
157	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	476	0.00	6000.00	2026-01-19 00:10:53.70398	2026-01-19 00:10:53.70398	hacia_destino	\N	t
158	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	481	0.00	6004.17	2026-01-19 00:10:58.778988	2026-01-19 00:10:58.778988	hacia_destino	\N	t
159	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	486	0.00	6025.00	2026-01-19 00:11:03.6687	2026-01-19 00:11:03.6687	hacia_destino	\N	t
160	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	491	0.00	6045.83	2026-01-19 00:11:08.67393	2026-01-19 00:11:08.67393	hacia_destino	\N	t
161	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	496	0.00	6066.67	2026-01-19 00:11:13.671205	2026-01-19 00:11:13.671205	hacia_destino	\N	t
162	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	501	0.00	6087.50	2026-01-19 00:11:18.668765	2026-01-19 00:11:18.668765	hacia_destino	\N	t
163	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	506	0.00	6108.33	2026-01-19 00:11:23.673939	2026-01-19 00:11:23.673939	hacia_destino	\N	t
164	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	511	0.00	6129.17	2026-01-19 00:11:28.664074	2026-01-19 00:11:28.664074	hacia_destino	\N	t
165	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	516	0.00	6150.00	2026-01-19 00:11:33.683504	2026-01-19 00:11:33.683504	hacia_destino	\N	t
166	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	521	0.00	6170.83	2026-01-19 00:11:38.669524	2026-01-19 00:11:38.669524	hacia_destino	\N	t
167	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	526	0.00	6191.67	2026-01-19 00:11:43.771001	2026-01-19 00:11:43.771001	hacia_destino	\N	t
168	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	531	0.00	6212.50	2026-01-19 00:11:48.722052	2026-01-19 00:11:48.722052	hacia_destino	\N	t
169	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	536	0.00	6233.33	2026-01-19 00:11:53.774621	2026-01-19 00:11:53.774621	hacia_destino	\N	t
170	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	541	0.00	6254.17	2026-01-19 00:11:58.71773	2026-01-19 00:11:58.71773	hacia_destino	\N	t
171	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	546	0.00	6275.00	2026-01-19 00:12:03.679113	2026-01-19 00:12:03.679113	hacia_destino	\N	t
172	766	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	549	0.00	6287.50	2026-01-19 00:12:06.449716	2026-01-19 00:12:06.449716	hacia_destino	fin	t
173	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 03:24:36.700765	2026-01-19 03:24:36.700765	hacia_destino	inicio	t
174	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 03:24:42.255003	2026-01-19 03:24:42.255003	hacia_destino	\N	t
175	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 03:24:46.864953	2026-01-19 03:24:46.864953	hacia_destino	\N	t
176	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 03:24:51.866274	2026-01-19 03:24:51.866274	hacia_destino	\N	t
177	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-19 03:24:56.870569	2026-01-19 03:24:56.870569	hacia_destino	\N	t
178	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-19 03:25:01.898612	2026-01-19 03:25:01.898612	hacia_destino	\N	t
179	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-19 03:25:06.882707	2026-01-19 03:25:06.882707	hacia_destino	\N	t
180	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-19 03:25:11.835235	2026-01-19 03:25:11.835235	hacia_destino	\N	t
181	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-19 03:25:16.84098	2026-01-19 03:25:16.84098	hacia_destino	\N	t
182	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-19 03:25:21.853596	2026-01-19 03:25:21.853596	hacia_destino	\N	t
183	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-19 03:25:26.845197	2026-01-19 03:25:26.845197	hacia_destino	\N	t
184	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-19 03:25:31.854116	2026-01-19 03:25:31.854116	hacia_destino	\N	t
185	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	60	0.00	6000.00	2026-01-19 03:25:36.861051	2026-01-19 03:25:36.861051	hacia_destino	\N	t
186	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	65	0.00	6000.00	2026-01-19 03:25:41.847797	2026-01-19 03:25:41.847797	hacia_destino	\N	t
187	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	70	0.00	6000.00	2026-01-19 03:25:46.863368	2026-01-19 03:25:46.863368	hacia_destino	\N	t
188	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	75	0.00	6000.00	2026-01-19 03:25:51.897783	2026-01-19 03:25:51.897783	hacia_destino	\N	t
189	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	80	0.00	6000.00	2026-01-19 03:25:56.864463	2026-01-19 03:25:56.864463	hacia_destino	\N	t
190	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	85	0.00	6000.00	2026-01-19 03:26:01.900904	2026-01-19 03:26:01.900904	hacia_destino	\N	t
191	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	90	0.00	6000.00	2026-01-19 03:26:06.87776	2026-01-19 03:26:06.87776	hacia_destino	\N	t
192	767	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	92	0.00	6000.00	2026-01-19 03:26:09.068253	2026-01-19 03:26:09.068253	hacia_destino	fin	t
193	768	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 03:40:20.071255	2026-01-19 03:40:20.071255	hacia_destino	inicio	t
194	768	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 03:40:25.201599	2026-01-19 03:40:25.201599	hacia_destino	\N	t
195	768	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	8	0.00	6000.00	2026-01-19 03:40:28.606286	2026-01-19 03:40:28.606286	hacia_destino	fin	t
196	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 22:22:22.573852	2026-01-19 22:22:22.573852	hacia_destino	inicio	t
197	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 22:22:27.67688	2026-01-19 22:22:27.67688	hacia_destino	\N	t
198	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 22:22:32.666757	2026-01-19 22:22:32.666757	hacia_destino	\N	t
199	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 22:22:37.662477	2026-01-19 22:22:37.662477	hacia_destino	\N	t
200	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-19 22:22:42.665169	2026-01-19 22:22:42.665169	hacia_destino	\N	t
201	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-19 22:22:47.664129	2026-01-19 22:22:47.664129	hacia_destino	\N	t
202	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-19 22:22:52.656962	2026-01-19 22:22:52.656962	hacia_destino	\N	t
203	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-19 22:22:57.774196	2026-01-19 22:22:57.774196	hacia_destino	\N	t
204	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-19 22:23:02.669557	2026-01-19 22:23:02.669557	hacia_destino	\N	t
205	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-19 22:23:07.653743	2026-01-19 22:23:07.653743	hacia_destino	\N	t
206	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-19 22:23:12.655246	2026-01-19 22:23:12.655246	hacia_destino	\N	t
207	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-19 22:23:17.673578	2026-01-19 22:23:17.673578	hacia_destino	\N	t
208	769	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	59	0.00	6000.00	2026-01-19 22:23:21.738806	2026-01-19 22:23:21.738806	hacia_destino	fin	t
209	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 22:50:28.487567	2026-01-19 22:50:28.487567	hacia_destino	inicio	t
210	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 22:50:33.588931	2026-01-19 22:50:33.588931	hacia_destino	\N	t
211	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 22:50:38.573462	2026-01-19 22:50:38.573462	hacia_destino	\N	t
212	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 22:50:43.587828	2026-01-19 22:50:43.587828	hacia_destino	\N	t
213	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-19 22:50:48.687045	2026-01-19 22:50:48.687045	hacia_destino	\N	t
214	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-19 22:50:53.577453	2026-01-19 22:50:53.577453	hacia_destino	\N	t
215	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-19 22:50:58.566594	2026-01-19 22:50:58.566594	hacia_destino	\N	t
216	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-19 22:51:03.575323	2026-01-19 22:51:03.575323	hacia_destino	\N	t
217	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-19 22:51:08.688723	2026-01-19 22:51:08.688723	hacia_destino	\N	t
218	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-19 22:51:13.589517	2026-01-19 22:51:13.589517	hacia_destino	\N	t
219	772	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	46	0.00	6000.00	2026-01-19 22:51:14.724301	2026-01-19 22:51:14.724301	hacia_destino	fin	t
220	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 23:00:01.712867	2026-01-19 23:00:01.712867	hacia_destino	inicio	t
221	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 23:00:06.792059	2026-01-19 23:00:06.792059	hacia_destino	\N	t
222	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 23:00:11.80929	2026-01-19 23:00:11.80929	hacia_destino	\N	t
223	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 23:00:16.79342	2026-01-19 23:00:16.79342	hacia_destino	\N	t
224	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-19 23:00:21.816817	2026-01-19 23:00:21.816817	hacia_destino	\N	t
225	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-19 23:00:26.871879	2026-01-19 23:00:26.871879	hacia_destino	\N	t
226	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-19 23:00:31.816888	2026-01-19 23:00:31.816888	hacia_destino	\N	t
227	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-19 23:00:36.817952	2026-01-19 23:00:36.817952	hacia_destino	\N	t
228	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-19 23:00:41.794568	2026-01-19 23:00:41.794568	hacia_destino	\N	t
229	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-19 23:00:46.842748	2026-01-19 23:00:46.842748	hacia_destino	\N	t
230	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-19 23:00:51.794458	2026-01-19 23:00:51.794458	hacia_destino	\N	t
231	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-19 23:00:56.791687	2026-01-19 23:00:56.791687	hacia_destino	\N	t
232	775	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	57	0.00	6000.00	2026-01-19 23:00:59.246423	2026-01-19 23:00:59.246423	hacia_destino	fin	t
233	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 23:18:50.45494	2026-01-19 23:18:50.45494	hacia_destino	inicio	t
234	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 23:18:55.650032	2026-01-19 23:18:55.650032	hacia_destino	\N	t
235	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 23:19:00.604812	2026-01-19 23:19:00.604812	hacia_destino	\N	t
236	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 23:19:05.63583	2026-01-19 23:19:05.63583	hacia_destino	\N	t
237	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-19 23:19:10.610152	2026-01-19 23:19:10.610152	hacia_destino	\N	t
238	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-19 23:19:15.609957	2026-01-19 23:19:15.609957	hacia_destino	\N	t
239	776	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	27	0.00	6000.00	2026-01-19 23:19:17.628954	2026-01-19 23:19:17.628954	hacia_destino	fin	t
240	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	1	0.00	6000.00	2026-01-19 23:21:50.83374	2026-01-19 23:21:50.83374	hacia_destino	inicio	t
241	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	6	0.00	6000.00	2026-01-19 23:21:55.929363	2026-01-19 23:21:55.929363	hacia_destino	\N	t
242	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	11	0.00	6000.00	2026-01-19 23:22:00.922023	2026-01-19 23:22:00.922023	hacia_destino	\N	t
243	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	16	0.00	6000.00	2026-01-19 23:22:05.932649	2026-01-19 23:22:05.932649	hacia_destino	\N	t
244	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	21	0.00	6000.00	2026-01-19 23:22:10.932572	2026-01-19 23:22:10.932572	hacia_destino	\N	t
245	777	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	26	0.00	6000.00	2026-01-19 23:22:15.924989	2026-01-19 23:22:15.924989	hacia_destino	\N	t
246	778	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-19 23:22:47.066413	2026-01-19 23:22:47.066413	hacia_destino	inicio	t
247	778	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-19 23:22:52.173944	2026-01-19 23:22:52.173944	hacia_destino	\N	t
248	778	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-19 23:22:57.162827	2026-01-19 23:22:57.162827	hacia_destino	\N	t
249	778	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-19 23:23:02.180698	2026-01-19 23:23:02.180698	hacia_destino	\N	t
250	778	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	19	0.00	6000.00	2026-01-19 23:23:06.560576	2026-01-19 23:23:06.560576	hacia_destino	fin	t
251	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 00:02:47.909505	2026-01-20 00:02:47.909505	hacia_destino	inicio	t
252	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 00:02:53.009008	2026-01-20 00:02:53.009008	hacia_destino	\N	t
253	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 00:02:58.000493	2026-01-20 00:02:58.000493	hacia_destino	\N	t
254	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 00:03:03.034269	2026-01-20 00:03:03.034269	hacia_destino	\N	t
255	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 00:03:07.985483	2026-01-20 00:03:07.985483	hacia_destino	\N	t
256	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 00:03:12.990694	2026-01-20 00:03:12.990694	hacia_destino	\N	t
257	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-20 00:03:17.980211	2026-01-20 00:03:17.980211	hacia_destino	\N	t
258	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-20 00:03:22.9968	2026-01-20 00:03:22.9968	hacia_destino	\N	t
259	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-20 00:03:28.012221	2026-01-20 00:03:28.012221	hacia_destino	\N	t
260	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-20 00:03:32.998811	2026-01-20 00:03:32.998811	hacia_destino	\N	t
261	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-20 00:03:37.991849	2026-01-20 00:03:37.991849	hacia_destino	\N	t
262	779	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	52	0.00	6000.00	2026-01-20 00:03:40.236064	2026-01-20 00:03:40.236064	hacia_destino	fin	t
263	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 00:33:05.386262	2026-01-20 00:33:05.386262	hacia_destino	inicio	t
264	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 00:33:10.510937	2026-01-20 00:33:10.510937	hacia_destino	\N	t
265	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 00:33:15.513318	2026-01-20 00:33:15.513318	hacia_destino	\N	t
266	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 00:33:20.516831	2026-01-20 00:33:20.516831	hacia_destino	\N	t
267	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 00:33:25.513077	2026-01-20 00:33:25.513077	hacia_destino	\N	t
268	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 00:33:30.629474	2026-01-20 00:33:30.629474	hacia_destino	\N	t
269	780	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	27	0.00	6000.00	2026-01-20 00:33:32.254316	2026-01-20 00:33:32.254316	hacia_destino	fin	t
270	782	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 00:51:55.333611	2026-01-20 00:51:55.333611	hacia_destino	inicio	t
271	782	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 00:52:00.44823	2026-01-20 00:52:00.44823	hacia_destino	\N	t
272	782	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 00:52:05.427224	2026-01-20 00:52:05.427224	hacia_destino	\N	t
273	782	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 00:52:10.446297	2026-01-20 00:52:10.446297	hacia_destino	\N	t
274	782	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	18	0.00	6000.00	2026-01-20 00:52:14.195244	2026-01-20 00:52:14.195244	hacia_destino	fin	t
275	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 01:04:13.891843	2026-01-20 01:04:13.891843	hacia_destino	inicio	t
276	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 01:04:19.031741	2026-01-20 01:04:19.031741	hacia_destino	\N	t
277	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 01:04:24.011924	2026-01-20 01:04:24.011924	hacia_destino	\N	t
278	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 01:04:28.971168	2026-01-20 01:04:28.971168	hacia_destino	\N	t
279	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 01:04:33.977018	2026-01-20 01:04:33.977018	hacia_destino	\N	t
280	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 01:04:38.966987	2026-01-20 01:04:38.966987	hacia_destino	\N	t
281	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-20 01:04:44.021794	2026-01-20 01:04:44.021794	hacia_destino	\N	t
282	783	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	32	0.00	6000.00	2026-01-20 01:04:45.832897	2026-01-20 01:04:45.832897	hacia_destino	fin	t
283	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 01:19:44.970697	2026-01-20 01:19:44.970697	hacia_destino	inicio	t
284	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 01:19:50.107896	2026-01-20 01:19:50.107896	hacia_destino	\N	t
285	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 01:19:55.080581	2026-01-20 01:19:55.080581	hacia_destino	\N	t
286	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 01:20:00.090941	2026-01-20 01:20:00.090941	hacia_destino	\N	t
287	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 01:20:05.164293	2026-01-20 01:20:05.164293	hacia_destino	\N	t
288	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 01:20:10.198534	2026-01-20 01:20:10.198534	hacia_destino	\N	t
289	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-20 01:20:15.116735	2026-01-20 01:20:15.116735	hacia_destino	\N	t
290	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-20 01:20:20.145618	2026-01-20 01:20:20.145618	hacia_destino	\N	t
291	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-20 01:20:25.10674	2026-01-20 01:20:25.10674	hacia_destino	\N	t
292	784	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	44	0.00	6000.00	2026-01-20 01:20:28.857423	2026-01-20 01:20:28.857423	hacia_destino	fin	t
293	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 01:35:19.154306	2026-01-20 01:35:19.154306	hacia_destino	inicio	t
294	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 01:35:24.270453	2026-01-20 01:35:24.270453	hacia_destino	\N	t
295	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 01:35:29.266164	2026-01-20 01:35:29.266164	hacia_destino	\N	t
296	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 01:35:34.283632	2026-01-20 01:35:34.283632	hacia_destino	\N	t
297	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 01:35:39.27877	2026-01-20 01:35:39.27877	hacia_destino	\N	t
298	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 01:35:44.297472	2026-01-20 01:35:44.297472	hacia_destino	\N	t
299	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-20 01:35:49.292126	2026-01-20 01:35:49.292126	hacia_destino	\N	t
300	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-20 01:35:54.27422	2026-01-20 01:35:54.27422	hacia_destino	\N	t
301	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-20 01:35:59.277592	2026-01-20 01:35:59.277592	hacia_destino	\N	t
302	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-20 01:36:04.290365	2026-01-20 01:36:04.290365	hacia_destino	\N	t
303	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-20 01:36:09.296684	2026-01-20 01:36:09.296684	hacia_destino	\N	t
304	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-20 01:36:14.277292	2026-01-20 01:36:14.277292	hacia_destino	\N	t
305	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	60	0.00	6000.00	2026-01-20 01:36:19.299325	2026-01-20 01:36:19.299325	hacia_destino	\N	t
306	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	65	0.00	6000.00	2026-01-20 01:36:24.284826	2026-01-20 01:36:24.284826	hacia_destino	\N	t
307	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	70	0.00	6000.00	2026-01-20 01:36:29.279165	2026-01-20 01:36:29.279165	hacia_destino	\N	t
308	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	75	0.00	6000.00	2026-01-20 01:36:34.29246	2026-01-20 01:36:34.29246	hacia_destino	\N	t
309	785	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	78	0.00	6000.00	2026-01-20 01:36:38.054432	2026-01-20 01:36:38.054432	hacia_destino	fin	t
310	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-20 01:53:41.13328	2026-01-20 01:53:41.13328	hacia_destino	inicio	t
311	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-20 01:53:46.342817	2026-01-20 01:53:46.342817	hacia_destino	\N	t
312	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-20 01:53:51.313253	2026-01-20 01:53:51.313253	hacia_destino	\N	t
313	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-20 01:53:56.31432	2026-01-20 01:53:56.31432	hacia_destino	\N	t
314	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-20 01:54:01.326748	2026-01-20 01:54:01.326748	hacia_destino	\N	t
315	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 01:54:06.34887	2026-01-20 01:54:06.34887	hacia_destino	\N	t
316	786	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-20 01:54:06.556608	2026-01-20 01:54:06.556608	hacia_destino	fin	t
317	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	0	0.00	6000.00	2026-01-21 01:37:52.692324	2026-01-21 01:37:52.692324	hacia_destino	inicio	t
318	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	5	0.00	6000.00	2026-01-21 01:37:57.840657	2026-01-21 01:37:57.840657	hacia_destino	\N	t
319	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	10	0.00	6000.00	2026-01-21 01:38:02.845092	2026-01-21 01:38:02.845092	hacia_destino	\N	t
320	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	15	0.00	6000.00	2026-01-21 01:38:07.839286	2026-01-21 01:38:07.839286	hacia_destino	\N	t
321	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	20	0.00	6000.00	2026-01-21 01:38:12.962051	2026-01-21 01:38:12.962051	hacia_destino	\N	t
322	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	25	0.00	6000.00	2026-01-21 01:38:17.984496	2026-01-21 01:38:17.984496	hacia_destino	\N	t
323	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	30	0.00	6000.00	2026-01-21 01:38:22.849715	2026-01-21 01:38:22.849715	hacia_destino	\N	t
324	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	35	0.00	6000.00	2026-01-21 01:38:27.864039	2026-01-21 01:38:27.864039	hacia_destino	\N	t
325	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	40	0.00	6000.00	2026-01-21 01:38:32.869437	2026-01-21 01:38:32.869437	hacia_destino	\N	t
326	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	45	0.00	6000.00	2026-01-21 01:38:37.841913	2026-01-21 01:38:37.841913	hacia_destino	\N	t
327	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	50	0.00	6000.00	2026-01-21 01:38:42.871839	2026-01-21 01:38:42.871839	hacia_destino	\N	t
328	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	55	0.00	6000.00	2026-01-21 01:38:47.984969	2026-01-21 01:38:47.984969	hacia_destino	\N	t
329	787	277	6.25373000	-75.53883670	5.00	0.00	0.00	0.00	0.000	56	0.00	6000.00	2026-01-21 01:38:48.935768	2026-01-21 01:38:48.935768	hacia_destino	fin	t
\.


--
-- TOC entry 6266 (class 0 OID 0)
-- Dependencies: 245
-- Name: asignaciones_conductor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asignaciones_conductor_id_seq', 204, true);


--
-- TOC entry 6267 (class 0 OID 0)
-- Dependencies: 254
-- Name: cache_direcciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cache_direcciones_id_seq', 1, false);


--
-- TOC entry 6268 (class 0 OID 0)
-- Dependencies: 255
-- Name: cache_geocodificacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cache_geocodificacion_id_seq', 1, false);


--
-- TOC entry 6269 (class 0 OID 0)
-- Dependencies: 246
-- Name: calificaciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.calificaciones_id_seq', 78, true);


--
-- TOC entry 6270 (class 0 OID 0)
-- Dependencies: 299
-- Name: catalogo_tipos_vehiculo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.catalogo_tipos_vehiculo_id_seq', 4, true);


--
-- TOC entry 6271 (class 0 OID 0)
-- Dependencies: 309
-- Name: categorias_soporte_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categorias_soporte_id_seq', 8, true);


--
-- TOC entry 6272 (class 0 OID 0)
-- Dependencies: 272
-- Name: colores_vehiculo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.colores_vehiculo_id_seq', 26, true);


--
-- TOC entry 6273 (class 0 OID 0)
-- Dependencies: 256
-- Name: conductores_favoritos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.conductores_favoritos_id_seq', 1, false);


--
-- TOC entry 6274 (class 0 OID 0)
-- Dependencies: 283
-- Name: configuracion_notificaciones_usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configuracion_notificaciones_usuario_id_seq', 3, true);


--
-- TOC entry 6275 (class 0 OID 0)
-- Dependencies: 247
-- Name: configuracion_precios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configuracion_precios_id_seq', 13, true);


--
-- TOC entry 6276 (class 0 OID 0)
-- Dependencies: 248
-- Name: configuraciones_app_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.configuraciones_app_id_seq', 9, false);


--
-- TOC entry 6277 (class 0 OID 0)
-- Dependencies: 249
-- Name: detalles_conductor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalles_conductor_id_seq', 35, true);


--
-- TOC entry 6278 (class 0 OID 0)
-- Dependencies: 263
-- Name: disputas_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.disputas_pago_id_seq', 5, true);


--
-- TOC entry 6279 (class 0 OID 0)
-- Dependencies: 270
-- Name: documentos_verificacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.documentos_verificacion_id_seq', 119, true);


--
-- TOC entry 6280 (class 0 OID 0)
-- Dependencies: 303
-- Name: empresa_tipos_vehiculo_historial_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresa_tipos_vehiculo_historial_id_seq', 1, false);


--
-- TOC entry 6281 (class 0 OID 0)
-- Dependencies: 301
-- Name: empresa_tipos_vehiculo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresa_tipos_vehiculo_id_seq', 52, true);


--
-- TOC entry 6282 (class 0 OID 0)
-- Dependencies: 305
-- Name: empresa_vehiculo_notificaciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresa_vehiculo_notificaciones_id_seq', 1, false);


--
-- TOC entry 6283 (class 0 OID 0)
-- Dependencies: 297
-- Name: empresas_configuracion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_configuracion_id_seq', 8, true);


--
-- TOC entry 6284 (class 0 OID 0)
-- Dependencies: 291
-- Name: empresas_contacto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_contacto_id_seq', 8, true);


--
-- TOC entry 6285 (class 0 OID 0)
-- Dependencies: 295
-- Name: empresas_metricas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_metricas_id_seq', 33, true);


--
-- TOC entry 6286 (class 0 OID 0)
-- Dependencies: 293
-- Name: empresas_representante_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_representante_id_seq', 3, true);


--
-- TOC entry 6287 (class 0 OID 0)
-- Dependencies: 268
-- Name: empresas_transporte_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empresas_transporte_id_seq', 16, true);


--
-- TOC entry 6288 (class 0 OID 0)
-- Dependencies: 258
-- Name: historial_confianza_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.historial_confianza_id_seq', 1, false);


--
-- TOC entry 6289 (class 0 OID 0)
-- Dependencies: 274
-- Name: logs_auditoria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.logs_auditoria_id_seq', 159, true);


--
-- TOC entry 6290 (class 0 OID 0)
-- Dependencies: 261
-- Name: mensajes_chat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mensajes_chat_id_seq', 48, true);


--
-- TOC entry 6291 (class 0 OID 0)
-- Dependencies: 313
-- Name: mensajes_ticket_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mensajes_ticket_id_seq', 1, false);


--
-- TOC entry 6292 (class 0 OID 0)
-- Dependencies: 281
-- Name: notificaciones_usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_usuario_id_seq', 6, true);


--
-- TOC entry 6293 (class 0 OID 0)
-- Dependencies: 275
-- Name: pagos_empresas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_empresas_id_seq', 1, false);


--
-- TOC entry 6294 (class 0 OID 0)
-- Dependencies: 265
-- Name: pagos_viaje_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_viaje_id_seq', 14, true);


--
-- TOC entry 6295 (class 0 OID 0)
-- Dependencies: 253
-- Name: paradas_solicitud_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.paradas_solicitud_id_seq', 3, false);


--
-- TOC entry 6296 (class 0 OID 0)
-- Dependencies: 277
-- Name: plantillas_bloqueadas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.plantillas_bloqueadas_id_seq', 1, false);


--
-- TOC entry 6297 (class 0 OID 0)
-- Dependencies: 315
-- Name: solicitudes_callback_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.solicitudes_callback_id_seq', 1, false);


--
-- TOC entry 6298 (class 0 OID 0)
-- Dependencies: 244
-- Name: solicitudes_servicio_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.solicitudes_servicio_id_seq', 787, true);


--
-- TOC entry 6299 (class 0 OID 0)
-- Dependencies: 288
-- Name: solicitudes_vinculacion_conductor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.solicitudes_vinculacion_conductor_id_seq', 34, true);


--
-- TOC entry 6300 (class 0 OID 0)
-- Dependencies: 311
-- Name: tickets_soporte_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tickets_soporte_id_seq', 1, false);


--
-- TOC entry 6301 (class 0 OID 0)
-- Dependencies: 279
-- Name: tipos_notificacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tipos_notificacion_id_seq', 12, true);


--
-- TOC entry 6302 (class 0 OID 0)
-- Dependencies: 285
-- Name: tokens_push_usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tokens_push_usuario_id_seq', 1, false);


--
-- TOC entry 6303 (class 0 OID 0)
-- Dependencies: 250
-- Name: transacciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transacciones_id_seq', 24, true);


--
-- TOC entry 6304 (class 0 OID 0)
-- Dependencies: 251
-- Name: ubicaciones_usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ubicaciones_usuario_id_seq', 10, false);


--
-- TOC entry 6305 (class 0 OID 0)
-- Dependencies: 267
-- Name: user_devices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_devices_id_seq', 43, true);


--
-- TOC entry 6306 (class 0 OID 0)
-- Dependencies: 252
-- Name: usuarios_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_id_seq', 298, true);


--
-- TOC entry 6307 (class 0 OID 0)
-- Dependencies: 320
-- Name: viaje_resumen_tracking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.viaje_resumen_tracking_id_seq', 350, true);


--
-- TOC entry 6308 (class 0 OID 0)
-- Dependencies: 318
-- Name: viaje_tracking_realtime_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.viaje_tracking_realtime_id_seq', 329, true);


--
-- TOC entry 5517 (class 2606 OID 16881)
-- Name: asignaciones_conductor asignaciones_conductor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignaciones_conductor
    ADD CONSTRAINT asignaciones_conductor_pkey PRIMARY KEY (id);


--
-- TOC entry 5521 (class 2606 OID 16885)
-- Name: cache_direcciones cache_direcciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache_direcciones
    ADD CONSTRAINT cache_direcciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5524 (class 2606 OID 16888)
-- Name: cache_geocodificacion cache_geocodificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cache_geocodificacion
    ADD CONSTRAINT cache_geocodificacion_pkey PRIMARY KEY (id);


--
-- TOC entry 5527 (class 2606 OID 16891)
-- Name: calificaciones calificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5775 (class 2606 OID 115567)
-- Name: catalogo_tipos_vehiculo catalogo_tipos_vehiculo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catalogo_tipos_vehiculo
    ADD CONSTRAINT catalogo_tipos_vehiculo_codigo_key UNIQUE (codigo);


--
-- TOC entry 5777 (class 2606 OID 115565)
-- Name: catalogo_tipos_vehiculo catalogo_tipos_vehiculo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.catalogo_tipos_vehiculo
    ADD CONSTRAINT catalogo_tipos_vehiculo_pkey PRIMARY KEY (id);


--
-- TOC entry 5795 (class 2606 OID 115687)
-- Name: categorias_soporte categorias_soporte_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias_soporte
    ADD CONSTRAINT categorias_soporte_codigo_key UNIQUE (codigo);


--
-- TOC entry 5797 (class 2606 OID 115685)
-- Name: categorias_soporte categorias_soporte_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias_soporte
    ADD CONSTRAINT categorias_soporte_pkey PRIMARY KEY (id);


--
-- TOC entry 5714 (class 2606 OID 33664)
-- Name: colores_vehiculo colores_vehiculo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colores_vehiculo
    ADD CONSTRAINT colores_vehiculo_pkey PRIMARY KEY (id);


--
-- TOC entry 5670 (class 2606 OID 17173)
-- Name: conductores_favoritos conductores_favoritos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conductores_favoritos
    ADD CONSTRAINT conductores_favoritos_pkey PRIMARY KEY (id);


--
-- TOC entry 5736 (class 2606 OID 91026)
-- Name: configuracion_notificaciones_usuario configuracion_notificaciones_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_notificaciones_usuario
    ADD CONSTRAINT configuracion_notificaciones_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 5738 (class 2606 OID 91028)
-- Name: configuracion_notificaciones_usuario configuracion_notificaciones_usuario_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_notificaciones_usuario
    ADD CONSTRAINT configuracion_notificaciones_usuario_usuario_id_key UNIQUE (usuario_id);


--
-- TOC entry 5541 (class 2606 OID 16901)
-- Name: configuracion_precios configuracion_precios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_precios
    ADD CONSTRAINT configuracion_precios_pkey PRIMARY KEY (id);


--
-- TOC entry 5536 (class 2606 OID 16896)
-- Name: configuraciones_app configuraciones_app_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuraciones_app
    ADD CONSTRAINT configuraciones_app_pkey PRIMARY KEY (id);


--
-- TOC entry 5547 (class 2606 OID 16905)
-- Name: detalles_conductor detalles_conductor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_conductor
    ADD CONSTRAINT detalles_conductor_pkey PRIMARY KEY (id);


--
-- TOC entry 5561 (class 2606 OID 16917)
-- Name: detalles_paquete detalles_paquete_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_paquete
    ADD CONSTRAINT detalles_paquete_pkey PRIMARY KEY (id);


--
-- TOC entry 5564 (class 2606 OID 16920)
-- Name: detalles_viaje detalles_viaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_viaje
    ADD CONSTRAINT detalles_viaje_pkey PRIMARY KEY (id);


--
-- TOC entry 5691 (class 2606 OID 17294)
-- Name: disputas_pago disputas_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_pkey PRIMARY KEY (id);


--
-- TOC entry 5693 (class 2606 OID 17296)
-- Name: disputas_pago disputas_pago_solicitud_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_solicitud_id_key UNIQUE (solicitud_id);


--
-- TOC entry 5567 (class 2606 OID 16923)
-- Name: documentos_conductor_historial documentos_conductor_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_conductor_historial
    ADD CONSTRAINT documentos_conductor_historial_pkey PRIMARY KEY (id);


--
-- TOC entry 5711 (class 2606 OID 33649)
-- Name: documentos_verificacion documentos_verificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_verificacion
    ADD CONSTRAINT documentos_verificacion_pkey PRIMARY KEY (id);


--
-- TOC entry 5787 (class 2606 OID 115619)
-- Name: empresa_tipos_vehiculo_historial empresa_tipos_vehiculo_historial_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo_historial
    ADD CONSTRAINT empresa_tipos_vehiculo_historial_pkey PRIMARY KEY (id);


--
-- TOC entry 5779 (class 2606 OID 115582)
-- Name: empresa_tipos_vehiculo empresa_tipos_vehiculo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT empresa_tipos_vehiculo_pkey PRIMARY KEY (id);


--
-- TOC entry 5791 (class 2606 OID 115643)
-- Name: empresa_vehiculo_notificaciones empresa_vehiculo_notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_vehiculo_notificaciones
    ADD CONSTRAINT empresa_vehiculo_notificaciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5770 (class 2606 OID 91290)
-- Name: empresas_configuracion empresas_configuracion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_configuracion
    ADD CONSTRAINT empresas_configuracion_pkey PRIMARY KEY (id);


--
-- TOC entry 5754 (class 2606 OID 91217)
-- Name: empresas_contacto empresas_contacto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_contacto
    ADD CONSTRAINT empresas_contacto_pkey PRIMARY KEY (id);


--
-- TOC entry 5765 (class 2606 OID 91264)
-- Name: empresas_metricas empresas_metricas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_metricas
    ADD CONSTRAINT empresas_metricas_pkey PRIMARY KEY (id);


--
-- TOC entry 5760 (class 2606 OID 91238)
-- Name: empresas_representante empresas_representante_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_representante
    ADD CONSTRAINT empresas_representante_pkey PRIMARY KEY (id);


--
-- TOC entry 5703 (class 2606 OID 25452)
-- Name: empresas_transporte empresas_transporte_nit_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_transporte
    ADD CONSTRAINT empresas_transporte_nit_key UNIQUE (nit);


--
-- TOC entry 5705 (class 2606 OID 25450)
-- Name: empresas_transporte empresas_transporte_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_transporte
    ADD CONSTRAINT empresas_transporte_pkey PRIMARY KEY (id);


--
-- TOC entry 5574 (class 2606 OID 16928)
-- Name: estadisticas_sistema estadisticas_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadisticas_sistema
    ADD CONSTRAINT estadisticas_sistema_pkey PRIMARY KEY (id);


--
-- TOC entry 5676 (class 2606 OID 17201)
-- Name: historial_confianza historial_confianza_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_confianza
    ADD CONSTRAINT historial_confianza_pkey PRIMARY KEY (id);


--
-- TOC entry 5578 (class 2606 OID 16932)
-- Name: historial_precios historial_precios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_precios
    ADD CONSTRAINT historial_precios_pkey PRIMARY KEY (id);


--
-- TOC entry 5583 (class 2606 OID 16937)
-- Name: historial_seguimiento historial_seguimiento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_seguimiento
    ADD CONSTRAINT historial_seguimiento_pkey PRIMARY KEY (id);


--
-- TOC entry 5538 (class 2606 OID 16898)
-- Name: configuraciones_app idx_clave; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuraciones_app
    ADD CONSTRAINT idx_clave UNIQUE (clave);


--
-- TOC entry 5559 (class 2606 OID 16907)
-- Name: detalles_conductor idx_detalles_conductor_usuario; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_conductor
    ADD CONSTRAINT idx_detalles_conductor_usuario UNIQUE (usuario_id);


--
-- TOC entry 5576 (class 2606 OID 16930)
-- Name: estadisticas_sistema idx_fecha; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadisticas_sistema
    ADD CONSTRAINT idx_fecha UNIQUE (fecha);


--
-- TOC entry 5632 (class 2606 OID 16977)
-- Name: transacciones idx_transacciones_solicitud; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT idx_transacciones_solicitud UNIQUE (solicitud_id);


--
-- TOC entry 5591 (class 2606 OID 16942)
-- Name: logs_auditoria logs_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs_auditoria
    ADD CONSTRAINT logs_auditoria_pkey PRIMARY KEY (id);


--
-- TOC entry 5689 (class 2606 OID 17258)
-- Name: mensajes_chat mensajes_chat_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_chat
    ADD CONSTRAINT mensajes_chat_pkey PRIMARY KEY (id);


--
-- TOC entry 5809 (class 2606 OID 115728)
-- Name: mensajes_ticket mensajes_ticket_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_ticket
    ADD CONSTRAINT mensajes_ticket_pkey PRIMARY KEY (id);


--
-- TOC entry 5594 (class 2606 OID 16947)
-- Name: metodos_pago_usuario metodos_pago_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metodos_pago_usuario
    ADD CONSTRAINT metodos_pago_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 5734 (class 2606 OID 90999)
-- Name: notificaciones_usuario notificaciones_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones_usuario
    ADD CONSTRAINT notificaciones_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 5719 (class 2606 OID 58214)
-- Name: pagos_empresas pagos_empresas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_empresas
    ADD CONSTRAINT pagos_empresas_pkey PRIMARY KEY (id);


--
-- TOC entry 5699 (class 2606 OID 17356)
-- Name: pagos_viaje pagos_viaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_viaje
    ADD CONSTRAINT pagos_viaje_pkey PRIMARY KEY (id);


--
-- TOC entry 5701 (class 2606 OID 17358)
-- Name: pagos_viaje pagos_viaje_solicitud_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_viaje
    ADD CONSTRAINT pagos_viaje_solicitud_id_key UNIQUE (solicitud_id);


--
-- TOC entry 5597 (class 2606 OID 16950)
-- Name: paradas_solicitud paradas_solicitud_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paradas_solicitud
    ADD CONSTRAINT paradas_solicitud_pkey PRIMARY KEY (id);


--
-- TOC entry 5723 (class 2606 OID 82790)
-- Name: plantillas_bloqueadas plantillas_bloqueadas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_bloqueadas
    ADD CONSTRAINT plantillas_bloqueadas_pkey PRIMARY KEY (id);


--
-- TOC entry 5599 (class 2606 OID 16955)
-- Name: proveedores_mapa proveedores_mapa_nombre_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores_mapa
    ADD CONSTRAINT proveedores_mapa_nombre_unique UNIQUE (nombre);


--
-- TOC entry 5601 (class 2606 OID 16953)
-- Name: proveedores_mapa proveedores_mapa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores_mapa
    ADD CONSTRAINT proveedores_mapa_pkey PRIMARY KEY (id);


--
-- TOC entry 5603 (class 2606 OID 16957)
-- Name: reglas_precios reglas_precios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reglas_precios
    ADD CONSTRAINT reglas_precios_pkey PRIMARY KEY (id);


--
-- TOC entry 5610 (class 2606 OID 16959)
-- Name: reportes_usuarios reportes_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reportes_usuarios
    ADD CONSTRAINT reportes_usuarios_pkey PRIMARY KEY (id);


--
-- TOC entry 5813 (class 2606 OID 115748)
-- Name: solicitudes_callback solicitudes_callback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_callback
    ADD CONSTRAINT solicitudes_callback_pkey PRIMARY KEY (id);


--
-- TOC entry 5622 (class 2606 OID 16966)
-- Name: solicitudes_servicio solicitudes_servicio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT solicitudes_servicio_pkey PRIMARY KEY (id);


--
-- TOC entry 5750 (class 2606 OID 91167)
-- Name: solicitudes_vinculacion_conductor solicitudes_vinculacion_conductor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor
    ADD CONSTRAINT solicitudes_vinculacion_conductor_pkey PRIMARY KEY (id);


--
-- TOC entry 5803 (class 2606 OID 115704)
-- Name: tickets_soporte tickets_soporte_numero_ticket_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets_soporte
    ADD CONSTRAINT tickets_soporte_numero_ticket_key UNIQUE (numero_ticket);


--
-- TOC entry 5805 (class 2606 OID 115702)
-- Name: tickets_soporte tickets_soporte_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets_soporte
    ADD CONSTRAINT tickets_soporte_pkey PRIMARY KEY (id);


--
-- TOC entry 5725 (class 2606 OID 90985)
-- Name: tipos_notificacion tipos_notificacion_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_notificacion
    ADD CONSTRAINT tipos_notificacion_codigo_key UNIQUE (codigo);


--
-- TOC entry 5727 (class 2606 OID 90983)
-- Name: tipos_notificacion tipos_notificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipos_notificacion
    ADD CONSTRAINT tipos_notificacion_pkey PRIMARY KEY (id);


--
-- TOC entry 5742 (class 2606 OID 91041)
-- Name: tokens_push_usuario tokens_push_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens_push_usuario
    ADD CONSTRAINT tokens_push_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 5744 (class 2606 OID 91043)
-- Name: tokens_push_usuario tokens_push_usuario_usuario_id_token_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tokens_push_usuario
    ADD CONSTRAINT tokens_push_usuario_usuario_id_token_key UNIQUE (usuario_id, token);


--
-- TOC entry 5634 (class 2606 OID 16975)
-- Name: transacciones transacciones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_pkey PRIMARY KEY (id);


--
-- TOC entry 5637 (class 2606 OID 16982)
-- Name: ubicaciones_usuario ubicaciones_usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicaciones_usuario
    ADD CONSTRAINT ubicaciones_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 5534 (class 2606 OID 123860)
-- Name: calificaciones unique_calificacion_por_usuario_solicitud; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT unique_calificacion_por_usuario_solicitud UNIQUE (solicitud_id, usuario_calificador_id);


--
-- TOC entry 5641 (class 2606 OID 16985)
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);


--
-- TOC entry 5643 (class 2606 OID 16987)
-- Name: user_devices user_devices_user_id_device_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_user_id_device_uuid_unique UNIQUE (user_id, device_uuid);


--
-- TOC entry 5654 (class 2606 OID 99167)
-- Name: usuarios usuarios_apple_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_apple_id_key UNIQUE (apple_id);


--
-- TOC entry 5656 (class 2606 OID 16995)
-- Name: usuarios usuarios_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_email_unique UNIQUE (email);


--
-- TOC entry 5658 (class 2606 OID 99164)
-- Name: usuarios usuarios_google_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_google_id_key UNIQUE (google_id);


--
-- TOC entry 5660 (class 2606 OID 16991)
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- TOC entry 5662 (class 2606 OID 16997)
-- Name: usuarios usuarios_telefono_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_telefono_unique UNIQUE (telefono);


--
-- TOC entry 5664 (class 2606 OID 16993)
-- Name: usuarios usuarios_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_uuid_unique UNIQUE (uuid);


--
-- TOC entry 5624 (class 2606 OID 16968)
-- Name: solicitudes_servicio uuid_solicitud_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT uuid_solicitud_unique UNIQUE (uuid_solicitud);


--
-- TOC entry 5674 (class 2606 OID 17175)
-- Name: conductores_favoritos ux_conductores_favoritos_usuario_conductor; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conductores_favoritos
    ADD CONSTRAINT ux_conductores_favoritos_usuario_conductor UNIQUE (usuario_id, conductor_id);


--
-- TOC entry 5773 (class 2606 OID 91292)
-- Name: empresas_configuracion ux_empresa_configuracion; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_configuracion
    ADD CONSTRAINT ux_empresa_configuracion UNIQUE (empresa_id);


--
-- TOC entry 5758 (class 2606 OID 91219)
-- Name: empresas_contacto ux_empresa_contacto; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_contacto
    ADD CONSTRAINT ux_empresa_contacto UNIQUE (empresa_id);


--
-- TOC entry 5768 (class 2606 OID 91266)
-- Name: empresas_metricas ux_empresa_metricas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_metricas
    ADD CONSTRAINT ux_empresa_metricas UNIQUE (empresa_id);


--
-- TOC entry 5763 (class 2606 OID 91240)
-- Name: empresas_representante ux_empresa_representante; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_representante
    ADD CONSTRAINT ux_empresa_representante UNIQUE (empresa_id);


--
-- TOC entry 5785 (class 2606 OID 115584)
-- Name: empresa_tipos_vehiculo ux_empresa_tipo_vehiculo; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT ux_empresa_tipo_vehiculo UNIQUE (empresa_id, tipo_vehiculo_codigo);


--
-- TOC entry 5682 (class 2606 OID 17203)
-- Name: historial_confianza ux_historial_confianza_usuario_conductor; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_confianza
    ADD CONSTRAINT ux_historial_confianza_usuario_conductor UNIQUE (usuario_id, conductor_id);


--
-- TOC entry 5752 (class 2606 OID 91169)
-- Name: solicitudes_vinculacion_conductor ux_solicitud_pendiente; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor
    ADD CONSTRAINT ux_solicitud_pendiente UNIQUE (conductor_id, empresa_id, estado);


--
-- TOC entry 5668 (class 2606 OID 17002)
-- Name: verification_codes verification_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.verification_codes
    ADD CONSTRAINT verification_codes_pkey PRIMARY KEY (id);


--
-- TOC entry 5822 (class 2606 OID 123819)
-- Name: viaje_resumen_tracking viaje_resumen_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_resumen_tracking
    ADD CONSTRAINT viaje_resumen_tracking_pkey PRIMARY KEY (id);


--
-- TOC entry 5824 (class 2606 OID 123821)
-- Name: viaje_resumen_tracking viaje_resumen_tracking_solicitud_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_resumen_tracking
    ADD CONSTRAINT viaje_resumen_tracking_solicitud_id_key UNIQUE (solicitud_id);


--
-- TOC entry 5819 (class 2606 OID 123782)
-- Name: viaje_tracking_realtime viaje_tracking_realtime_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_tracking_realtime
    ADD CONSTRAINT viaje_tracking_realtime_pkey PRIMARY KEY (id);


--
-- TOC entry 5518 (class 1259 OID 16883)
-- Name: idx_asignaciones_conductor_conductor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asignaciones_conductor_conductor_id ON public.asignaciones_conductor USING btree (conductor_id);


--
-- TOC entry 5519 (class 1259 OID 16882)
-- Name: idx_asignaciones_conductor_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asignaciones_conductor_solicitud_id ON public.asignaciones_conductor USING btree (solicitud_id);


--
-- TOC entry 5522 (class 1259 OID 16886)
-- Name: idx_cache_dir_ruta; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cache_dir_ruta ON public.cache_direcciones USING btree (latitud_origen, longitud_origen, latitud_destino, longitud_destino);


--
-- TOC entry 5525 (class 1259 OID 16889)
-- Name: idx_cache_geo_coordenadas; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cache_geo_coordenadas ON public.cache_geocodificacion USING btree (latitud, longitud);


--
-- TOC entry 5528 (class 1259 OID 41836)
-- Name: idx_calificaciones_solicitud; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_calificaciones_solicitud ON public.calificaciones USING btree (solicitud_id);


--
-- TOC entry 5529 (class 1259 OID 123861)
-- Name: idx_calificaciones_solicitud_calificador; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_calificaciones_solicitud_calificador ON public.calificaciones USING btree (solicitud_id, usuario_calificador_id);


--
-- TOC entry 5530 (class 1259 OID 16892)
-- Name: idx_calificaciones_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_calificaciones_solicitud_id ON public.calificaciones USING btree (solicitud_id);


--
-- TOC entry 5531 (class 1259 OID 16894)
-- Name: idx_calificaciones_usuario_calificado_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_calificaciones_usuario_calificado_id ON public.calificaciones USING btree (usuario_calificado_id);


--
-- TOC entry 5532 (class 1259 OID 16893)
-- Name: idx_calificaciones_usuario_calificador_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_calificaciones_usuario_calificador_id ON public.calificaciones USING btree (usuario_calificador_id);


--
-- TOC entry 5810 (class 1259 OID 115750)
-- Name: idx_callback_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_callback_estado ON public.solicitudes_callback USING btree (estado);


--
-- TOC entry 5811 (class 1259 OID 115749)
-- Name: idx_callback_usuario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_callback_usuario ON public.solicitudes_callback USING btree (usuario_id);


--
-- TOC entry 5715 (class 1259 OID 33665)
-- Name: idx_color_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_color_activo ON public.colores_vehiculo USING btree (activo);


--
-- TOC entry 5677 (class 1259 OID 17233)
-- Name: idx_conductor_confianza; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_conductor_confianza ON public.historial_confianza USING btree (conductor_id);


--
-- TOC entry 5671 (class 1259 OID 17231)
-- Name: idx_conductor_favoritos; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_conductor_favoritos ON public.conductores_favoritos USING btree (conductor_id);


--
-- TOC entry 5678 (class 1259 OID 17236)
-- Name: idx_confianza_score_viajes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_confianza_score_viajes ON public.historial_confianza USING btree (conductor_id, score_confianza DESC, total_viajes DESC);


--
-- TOC entry 5739 (class 1259 OID 91029)
-- Name: idx_config_notif_usuario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_config_notif_usuario ON public.configuracion_notificaciones_usuario USING btree (usuario_id);


--
-- TOC entry 5542 (class 1259 OID 16903)
-- Name: idx_configuracion_precios_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_configuracion_precios_activo ON public.configuracion_precios USING btree (activo);


--
-- TOC entry 5543 (class 1259 OID 16902)
-- Name: idx_configuracion_precios_tipo_vehiculo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_configuracion_precios_tipo_vehiculo ON public.configuracion_precios USING btree (tipo_vehiculo);


--
-- TOC entry 5539 (class 1259 OID 16899)
-- Name: idx_configuraciones_app_categoria; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_configuraciones_app_categoria ON public.configuraciones_app USING btree (categoria);


--
-- TOC entry 5548 (class 1259 OID 82796)
-- Name: idx_dc_estado_bio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dc_estado_bio ON public.detalles_conductor USING btree (estado_biometrico) WHERE (estado_biometrico IS NOT NULL);


--
-- TOC entry 5549 (class 1259 OID 82797)
-- Name: idx_dc_plantilla_exists; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dc_plantilla_exists ON public.detalles_conductor USING btree (usuario_id) WHERE (plantilla_biometrica IS NOT NULL);


--
-- TOC entry 5550 (class 1259 OID 16908)
-- Name: idx_detalles_conductor_disponible; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_disponible ON public.detalles_conductor USING btree (disponible);


--
-- TOC entry 5551 (class 1259 OID 16912)
-- Name: idx_detalles_conductor_estado_verificacion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_estado_verificacion ON public.detalles_conductor USING btree (estado_verificacion);


--
-- TOC entry 5552 (class 1259 OID 16910)
-- Name: idx_detalles_conductor_licencia; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_licencia ON public.detalles_conductor USING btree (licencia_conduccion);


--
-- TOC entry 5553 (class 1259 OID 16913)
-- Name: idx_detalles_conductor_licencia_vencimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_licencia_vencimiento ON public.detalles_conductor USING btree (licencia_vencimiento);


--
-- TOC entry 5554 (class 1259 OID 16911)
-- Name: idx_detalles_conductor_placa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_placa ON public.detalles_conductor USING btree (vehiculo_placa);


--
-- TOC entry 5555 (class 1259 OID 16914)
-- Name: idx_detalles_conductor_soat_vencimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_soat_vencimiento ON public.detalles_conductor USING btree (soat_vencimiento);


--
-- TOC entry 5556 (class 1259 OID 16915)
-- Name: idx_detalles_conductor_tecnomecanica_vencimiento; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_tecnomecanica_vencimiento ON public.detalles_conductor USING btree (tecnomecanica_vencimiento);


--
-- TOC entry 5557 (class 1259 OID 16909)
-- Name: idx_detalles_conductor_ubicacion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_conductor_ubicacion ON public.detalles_conductor USING btree (latitud_actual, longitud_actual);


--
-- TOC entry 5562 (class 1259 OID 16918)
-- Name: idx_detalles_paquete_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_paquete_solicitud_id ON public.detalles_paquete USING btree (solicitud_id);


--
-- TOC entry 5565 (class 1259 OID 16921)
-- Name: idx_detalles_viaje_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_detalles_viaje_solicitud_id ON public.detalles_viaje USING btree (solicitud_id);


--
-- TOC entry 5694 (class 1259 OID 17332)
-- Name: idx_disputas_cliente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_disputas_cliente ON public.disputas_pago USING btree (cliente_id);


--
-- TOC entry 5695 (class 1259 OID 17333)
-- Name: idx_disputas_conductor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_disputas_conductor ON public.disputas_pago USING btree (conductor_id);


--
-- TOC entry 5696 (class 1259 OID 17334)
-- Name: idx_disputas_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_disputas_estado ON public.disputas_pago USING btree (estado);


--
-- TOC entry 5697 (class 1259 OID 17331)
-- Name: idx_disputas_solicitud; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_disputas_solicitud ON public.disputas_pago USING btree (solicitud_id);


--
-- TOC entry 5568 (class 1259 OID 66401)
-- Name: idx_doc_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_doc_empresa ON public.documentos_conductor_historial USING btree (asignado_empresa_id);


--
-- TOC entry 5712 (class 1259 OID 33656)
-- Name: idx_docs_tipo_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_docs_tipo_estado ON public.documentos_verificacion USING btree (tipo_documento, estado);


--
-- TOC entry 5569 (class 1259 OID 16926)
-- Name: idx_documentos_conductor_historial_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documentos_conductor_historial_activo ON public.documentos_conductor_historial USING btree (activo);


--
-- TOC entry 5570 (class 1259 OID 16924)
-- Name: idx_documentos_conductor_historial_conductor_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documentos_conductor_historial_conductor_tipo ON public.documentos_conductor_historial USING btree (conductor_id, tipo_documento);


--
-- TOC entry 5571 (class 1259 OID 16925)
-- Name: idx_documentos_conductor_historial_fecha_carga; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documentos_conductor_historial_fecha_carga ON public.documentos_conductor_historial USING btree (fecha_carga);


--
-- TOC entry 5572 (class 1259 OID 74593)
-- Name: idx_documentos_historial_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_documentos_historial_tipo ON public.documentos_conductor_historial USING btree (tipo_documento, tipo_archivo);


--
-- TOC entry 5771 (class 1259 OID 91298)
-- Name: idx_empresas_configuracion_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_configuracion_empresa ON public.empresas_configuracion USING btree (empresa_id);


--
-- TOC entry 5755 (class 1259 OID 91225)
-- Name: idx_empresas_contacto_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_contacto_empresa ON public.empresas_contacto USING btree (empresa_id);


--
-- TOC entry 5756 (class 1259 OID 91226)
-- Name: idx_empresas_contacto_municipio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_contacto_municipio ON public.empresas_contacto USING btree (municipio);


--
-- TOC entry 5766 (class 1259 OID 91272)
-- Name: idx_empresas_metricas_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_metricas_empresa ON public.empresas_metricas USING btree (empresa_id);


--
-- TOC entry 5761 (class 1259 OID 91246)
-- Name: idx_empresas_representante_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_representante_empresa ON public.empresas_representante USING btree (empresa_id);


--
-- TOC entry 5706 (class 1259 OID 25465)
-- Name: idx_empresas_transporte_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_transporte_estado ON public.empresas_transporte USING btree (estado);


--
-- TOC entry 5707 (class 1259 OID 25466)
-- Name: idx_empresas_transporte_municipio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_transporte_municipio ON public.empresas_transporte USING btree (municipio);


--
-- TOC entry 5708 (class 1259 OID 25464)
-- Name: idx_empresas_transporte_nit; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_transporte_nit ON public.empresas_transporte USING btree (nit);


--
-- TOC entry 5709 (class 1259 OID 25463)
-- Name: idx_empresas_transporte_nombre; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_empresas_transporte_nombre ON public.empresas_transporte USING btree (nombre);


--
-- TOC entry 5672 (class 1259 OID 17232)
-- Name: idx_es_favorito; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_es_favorito ON public.conductores_favoritos USING btree (es_favorito);


--
-- TOC entry 5780 (class 1259 OID 115607)
-- Name: idx_etv_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etv_activo ON public.empresa_tipos_vehiculo USING btree (activo);


--
-- TOC entry 5781 (class 1259 OID 115605)
-- Name: idx_etv_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etv_empresa ON public.empresa_tipos_vehiculo USING btree (empresa_id);


--
-- TOC entry 5782 (class 1259 OID 115608)
-- Name: idx_etv_empresa_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etv_empresa_activo ON public.empresa_tipos_vehiculo USING btree (empresa_id, activo);


--
-- TOC entry 5783 (class 1259 OID 115606)
-- Name: idx_etv_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etv_tipo ON public.empresa_tipos_vehiculo USING btree (tipo_vehiculo_codigo);


--
-- TOC entry 5788 (class 1259 OID 115630)
-- Name: idx_etvh_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etvh_empresa ON public.empresa_tipos_vehiculo_historial USING btree (empresa_id);


--
-- TOC entry 5789 (class 1259 OID 115631)
-- Name: idx_etvh_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_etvh_fecha ON public.empresa_tipos_vehiculo_historial USING btree (fecha_cambio);


--
-- TOC entry 5792 (class 1259 OID 115654)
-- Name: idx_evn_conductor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_evn_conductor ON public.empresa_vehiculo_notificaciones USING btree (conductor_id);


--
-- TOC entry 5793 (class 1259 OID 115655)
-- Name: idx_evn_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_evn_estado ON public.empresa_vehiculo_notificaciones USING btree (estado);


--
-- TOC entry 5579 (class 1259 OID 16933)
-- Name: idx_historial_precios_configuracion_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_precios_configuracion_id ON public.historial_precios USING btree (configuracion_id);


--
-- TOC entry 5580 (class 1259 OID 16934)
-- Name: idx_historial_precios_fecha_cambio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_precios_fecha_cambio ON public.historial_precios USING btree (fecha_cambio);


--
-- TOC entry 5581 (class 1259 OID 16935)
-- Name: idx_historial_precios_usuario_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_precios_usuario_id ON public.historial_precios USING btree (usuario_id);


--
-- TOC entry 5584 (class 1259 OID 16938)
-- Name: idx_historial_seguimiento_conductor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_seguimiento_conductor_id ON public.historial_seguimiento USING btree (conductor_id);


--
-- TOC entry 5585 (class 1259 OID 16939)
-- Name: idx_historial_seguimiento_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_seguimiento_solicitud_id ON public.historial_seguimiento USING btree (solicitud_id);


--
-- TOC entry 5586 (class 1259 OID 16940)
-- Name: idx_historial_seguimiento_timestamp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_historial_seguimiento_timestamp ON public.historial_seguimiento USING btree (timestamp_seguimiento);


--
-- TOC entry 5587 (class 1259 OID 16944)
-- Name: idx_logs_auditoria_accion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_auditoria_accion ON public.logs_auditoria USING btree (accion);


--
-- TOC entry 5588 (class 1259 OID 16945)
-- Name: idx_logs_auditoria_fecha_creacion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_auditoria_fecha_creacion ON public.logs_auditoria USING btree (fecha_creacion);


--
-- TOC entry 5589 (class 1259 OID 16943)
-- Name: idx_logs_auditoria_usuario_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_logs_auditoria_usuario_id ON public.logs_auditoria USING btree (usuario_id);


--
-- TOC entry 5806 (class 1259 OID 115735)
-- Name: idx_mensajes_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_created ON public.mensajes_ticket USING btree (created_at);


--
-- TOC entry 5683 (class 1259 OID 17276)
-- Name: idx_mensajes_destinatario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_destinatario ON public.mensajes_chat USING btree (destinatario_id);


--
-- TOC entry 5684 (class 1259 OID 17277)
-- Name: idx_mensajes_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_fecha ON public.mensajes_chat USING btree (fecha_creacion DESC);


--
-- TOC entry 5685 (class 1259 OID 17278)
-- Name: idx_mensajes_no_leidos; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_no_leidos ON public.mensajes_chat USING btree (destinatario_id, leido) WHERE (leido = false);


--
-- TOC entry 5686 (class 1259 OID 17275)
-- Name: idx_mensajes_remitente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_remitente ON public.mensajes_chat USING btree (remitente_id);


--
-- TOC entry 5687 (class 1259 OID 17274)
-- Name: idx_mensajes_solicitud; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_solicitud ON public.mensajes_chat USING btree (solicitud_id);


--
-- TOC entry 5807 (class 1259 OID 115734)
-- Name: idx_mensajes_ticket; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_mensajes_ticket ON public.mensajes_ticket USING btree (ticket_id);


--
-- TOC entry 5592 (class 1259 OID 16948)
-- Name: idx_metodos_pago_usuario_usuario_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_metodos_pago_usuario_usuario_id ON public.metodos_pago_usuario USING btree (usuario_id);


--
-- TOC entry 5728 (class 1259 OID 91009)
-- Name: idx_notif_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notif_created_at ON public.notificaciones_usuario USING btree (created_at);


--
-- TOC entry 5729 (class 1259 OID 91008)
-- Name: idx_notif_referencia; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notif_referencia ON public.notificaciones_usuario USING btree (referencia_tipo, referencia_id) WHERE (referencia_id IS NOT NULL);


--
-- TOC entry 5730 (class 1259 OID 91007)
-- Name: idx_notif_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notif_tipo ON public.notificaciones_usuario USING btree (tipo_id);


--
-- TOC entry 5731 (class 1259 OID 91005)
-- Name: idx_notif_usuario_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notif_usuario_fecha ON public.notificaciones_usuario USING btree (usuario_id, created_at DESC) WHERE (eliminada = false);


--
-- TOC entry 5732 (class 1259 OID 91006)
-- Name: idx_notif_usuario_no_leidas; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notif_usuario_no_leidas ON public.notificaciones_usuario USING btree (usuario_id, leida) WHERE ((eliminada = false) AND (leida = false));


--
-- TOC entry 5716 (class 1259 OID 58220)
-- Name: idx_pagos_empresas_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pagos_empresas_empresa ON public.pagos_empresas USING btree (empresa_id);


--
-- TOC entry 5717 (class 1259 OID 58221)
-- Name: idx_pagos_empresas_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pagos_empresas_fecha ON public.pagos_empresas USING btree (creado_en);


--
-- TOC entry 5595 (class 1259 OID 16951)
-- Name: idx_paradas_solicitud_solicitud_orden; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_paradas_solicitud_solicitud_orden ON public.paradas_solicitud USING btree (solicitud_id, orden);


--
-- TOC entry 5720 (class 1259 OID 82799)
-- Name: idx_pb_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pb_activo ON public.plantillas_bloqueadas USING btree (activo) WHERE (activo = true);


--
-- TOC entry 5721 (class 1259 OID 82798)
-- Name: idx_pb_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_pb_hash ON public.plantillas_bloqueadas USING btree (plantilla_hash) WHERE (activo = true);


--
-- TOC entry 5544 (class 1259 OID 50020)
-- Name: idx_precios_empresa_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_precios_empresa_unique ON public.configuracion_precios USING btree (empresa_id, tipo_vehiculo) WHERE (empresa_id IS NOT NULL);


--
-- TOC entry 5545 (class 1259 OID 50019)
-- Name: idx_precios_global_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_precios_global_unique ON public.configuracion_precios USING btree (tipo_vehiculo) WHERE (empresa_id IS NULL);


--
-- TOC entry 5604 (class 1259 OID 16964)
-- Name: idx_reportes_usuarios_admin_revisor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reportes_usuarios_admin_revisor_id ON public.reportes_usuarios USING btree (admin_revisor_id);


--
-- TOC entry 5605 (class 1259 OID 16962)
-- Name: idx_reportes_usuarios_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reportes_usuarios_estado ON public.reportes_usuarios USING btree (estado);


--
-- TOC entry 5606 (class 1259 OID 16961)
-- Name: idx_reportes_usuarios_reportado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reportes_usuarios_reportado ON public.reportes_usuarios USING btree (usuario_reportado_id);


--
-- TOC entry 5607 (class 1259 OID 16960)
-- Name: idx_reportes_usuarios_reportante; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reportes_usuarios_reportante ON public.reportes_usuarios USING btree (usuario_reportante_id);


--
-- TOC entry 5608 (class 1259 OID 16963)
-- Name: idx_reportes_usuarios_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reportes_usuarios_solicitud_id ON public.reportes_usuarios USING btree (solicitud_id);


--
-- TOC entry 5820 (class 1259 OID 123838)
-- Name: idx_resumen_con_desvio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_resumen_con_desvio ON public.viaje_resumen_tracking USING btree (solicitud_id) WHERE (tiene_desvio_ruta = true);


--
-- TOC entry 5679 (class 1259 OID 17234)
-- Name: idx_score_confianza; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_score_confianza ON public.historial_confianza USING btree (score_confianza);


--
-- TOC entry 5745 (class 1259 OID 91185)
-- Name: idx_solicitud_vinc_conductor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitud_vinc_conductor ON public.solicitudes_vinculacion_conductor USING btree (conductor_id);


--
-- TOC entry 5746 (class 1259 OID 91188)
-- Name: idx_solicitud_vinc_creado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitud_vinc_creado ON public.solicitudes_vinculacion_conductor USING btree (creado_en);


--
-- TOC entry 5747 (class 1259 OID 91186)
-- Name: idx_solicitud_vinc_empresa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitud_vinc_empresa ON public.solicitudes_vinculacion_conductor USING btree (empresa_id);


--
-- TOC entry 5748 (class 1259 OID 91187)
-- Name: idx_solicitud_vinc_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitud_vinc_estado ON public.solicitudes_vinculacion_conductor USING btree (estado);


--
-- TOC entry 5611 (class 1259 OID 41832)
-- Name: idx_solicitudes_conductor_llego; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_conductor_llego ON public.solicitudes_servicio USING btree (conductor_llego_en);


--
-- TOC entry 5612 (class 1259 OID 123841)
-- Name: idx_solicitudes_empresa_vehiculo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_empresa_vehiculo ON public.solicitudes_servicio USING btree (empresa_id, tipo_vehiculo) WHERE ((estado)::text = 'pendiente'::text);


--
-- TOC entry 5613 (class 1259 OID 17343)
-- Name: idx_solicitudes_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_estado ON public.solicitudes_servicio USING btree (estado);


--
-- TOC entry 5614 (class 1259 OID 123842)
-- Name: idx_solicitudes_estado_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_estado_fecha ON public.solicitudes_servicio USING btree (estado, solicitado_en DESC);


--
-- TOC entry 5615 (class 1259 OID 17344)
-- Name: idx_solicitudes_precio; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_precio ON public.solicitudes_servicio USING btree (precio_final);


--
-- TOC entry 5616 (class 1259 OID 16971)
-- Name: idx_solicitudes_servicio_cliente_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_servicio_cliente_id ON public.solicitudes_servicio USING btree (cliente_id);


--
-- TOC entry 5617 (class 1259 OID 16972)
-- Name: idx_solicitudes_servicio_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_servicio_estado ON public.solicitudes_servicio USING btree (estado);


--
-- TOC entry 5618 (class 1259 OID 16973)
-- Name: idx_solicitudes_servicio_solicitado_en; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_servicio_solicitado_en ON public.solicitudes_servicio USING btree (solicitado_en);


--
-- TOC entry 5619 (class 1259 OID 16970)
-- Name: idx_solicitudes_servicio_ubicacion_destino_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_servicio_ubicacion_destino_id ON public.solicitudes_servicio USING btree (ubicacion_destino_id);


--
-- TOC entry 5620 (class 1259 OID 16969)
-- Name: idx_solicitudes_servicio_ubicacion_recogida_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_solicitudes_servicio_ubicacion_recogida_id ON public.solicitudes_servicio USING btree (ubicacion_recogida_id);


--
-- TOC entry 5798 (class 1259 OID 115714)
-- Name: idx_tickets_categoria; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_categoria ON public.tickets_soporte USING btree (categoria_id);


--
-- TOC entry 5799 (class 1259 OID 115715)
-- Name: idx_tickets_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_created ON public.tickets_soporte USING btree (created_at DESC);


--
-- TOC entry 5800 (class 1259 OID 115713)
-- Name: idx_tickets_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_estado ON public.tickets_soporte USING btree (estado);


--
-- TOC entry 5801 (class 1259 OID 115712)
-- Name: idx_tickets_usuario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_usuario ON public.tickets_soporte USING btree (usuario_id);


--
-- TOC entry 5740 (class 1259 OID 91044)
-- Name: idx_tokens_push_usuario_activo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tokens_push_usuario_activo ON public.tokens_push_usuario USING btree (usuario_id) WHERE (activo = true);


--
-- TOC entry 5814 (class 1259 OID 123795)
-- Name: idx_tracking_conductor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tracking_conductor_id ON public.viaje_tracking_realtime USING btree (conductor_id);


--
-- TOC entry 5815 (class 1259 OID 123794)
-- Name: idx_tracking_solicitud_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tracking_solicitud_id ON public.viaje_tracking_realtime USING btree (solicitud_id);


--
-- TOC entry 5816 (class 1259 OID 123793)
-- Name: idx_tracking_solicitud_tiempo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tracking_solicitud_tiempo ON public.viaje_tracking_realtime USING btree (solicitud_id, timestamp_gps DESC);


--
-- TOC entry 5817 (class 1259 OID 123837)
-- Name: idx_tracking_timestamp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tracking_timestamp ON public.viaje_tracking_realtime USING btree (timestamp_gps);


--
-- TOC entry 5625 (class 1259 OID 16978)
-- Name: idx_transacciones_cliente_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_cliente_id ON public.transacciones USING btree (cliente_id);


--
-- TOC entry 5626 (class 1259 OID 17359)
-- Name: idx_transacciones_conductor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_conductor ON public.transacciones USING btree (conductor_id);


--
-- TOC entry 5627 (class 1259 OID 16979)
-- Name: idx_transacciones_conductor_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_conductor_id ON public.transacciones USING btree (conductor_id);


--
-- TOC entry 5628 (class 1259 OID 17341)
-- Name: idx_transacciones_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_estado ON public.transacciones USING btree (estado);


--
-- TOC entry 5629 (class 1259 OID 16980)
-- Name: idx_transacciones_estado_pago; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_estado_pago ON public.transacciones USING btree (estado_pago);


--
-- TOC entry 5630 (class 1259 OID 17342)
-- Name: idx_transacciones_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transacciones_fecha ON public.transacciones USING btree (fecha_transaccion);


--
-- TOC entry 5635 (class 1259 OID 16983)
-- Name: idx_ubicaciones_usuario_usuario_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ubicaciones_usuario_usuario_id ON public.ubicaciones_usuario USING btree (usuario_id);


--
-- TOC entry 5638 (class 1259 OID 16988)
-- Name: idx_user_devices_device_uuid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_devices_device_uuid ON public.user_devices USING btree (device_uuid);


--
-- TOC entry 5639 (class 1259 OID 16989)
-- Name: idx_user_devices_trusted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_user_devices_trusted ON public.user_devices USING btree (trusted);


--
-- TOC entry 5644 (class 1259 OID 99168)
-- Name: idx_usuarios_apple_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_apple_id ON public.usuarios USING btree (apple_id) WHERE (apple_id IS NOT NULL);


--
-- TOC entry 5645 (class 1259 OID 17335)
-- Name: idx_usuarios_disputa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_disputa ON public.usuarios USING btree (tiene_disputa_activa) WHERE (tiene_disputa_activa = true);


--
-- TOC entry 5646 (class 1259 OID 16998)
-- Name: idx_usuarios_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);


--
-- TOC entry 5647 (class 1259 OID 25472)
-- Name: idx_usuarios_empresa_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_empresa_id ON public.usuarios USING btree (empresa_id);


--
-- TOC entry 5648 (class 1259 OID 25478)
-- Name: idx_usuarios_empresa_preferida; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_empresa_preferida ON public.usuarios USING btree (empresa_preferida_id);


--
-- TOC entry 5649 (class 1259 OID 91156)
-- Name: idx_usuarios_estado_vinculacion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_estado_vinculacion ON public.usuarios USING btree (estado_vinculacion);


--
-- TOC entry 5650 (class 1259 OID 99165)
-- Name: idx_usuarios_google_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_google_id ON public.usuarios USING btree (google_id) WHERE (google_id IS NOT NULL);


--
-- TOC entry 5651 (class 1259 OID 16999)
-- Name: idx_usuarios_telefono; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_telefono ON public.usuarios USING btree (telefono);


--
-- TOC entry 5652 (class 1259 OID 17000)
-- Name: idx_usuarios_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_usuarios_tipo ON public.usuarios USING btree (tipo_usuario);


--
-- TOC entry 5665 (class 1259 OID 17004)
-- Name: idx_verification_codes_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_verification_codes_code ON public.verification_codes USING btree (code);


--
-- TOC entry 5666 (class 1259 OID 17003)
-- Name: idx_verification_codes_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_verification_codes_email ON public.verification_codes USING btree (email);


--
-- TOC entry 5680 (class 1259 OID 17235)
-- Name: idx_zona_frecuente; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_zona_frecuente ON public.historial_confianza USING btree (zona_frecuente_lat, zona_frecuente_lng);


--
-- TOC entry 5907 (class 2620 OID 123831)
-- Name: viaje_tracking_realtime trg_actualizar_resumen_tracking; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_actualizar_resumen_tracking AFTER INSERT ON public.viaje_tracking_realtime FOR EACH ROW EXECUTE FUNCTION public.actualizar_resumen_tracking();


--
-- TOC entry 5898 (class 2620 OID 17238)
-- Name: historial_confianza trg_historial_confianza_actualizado_en; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_historial_confianza_actualizado_en BEFORE UPDATE ON public.historial_confianza FOR EACH ROW EXECUTE FUNCTION public.set_actualizado_en();


--
-- TOC entry 5896 (class 2620 OID 115671)
-- Name: usuarios trigger_actualizar_metricas_empresa; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_actualizar_metricas_empresa AFTER INSERT OR UPDATE OF empresa_id ON public.usuarios FOR EACH ROW WHEN (((new.tipo_usuario)::text = 'conductor'::text)) EXECUTE FUNCTION public.actualizar_metricas_empresa();


--
-- TOC entry 5904 (class 2620 OID 115711)
-- Name: tickets_soporte trigger_generar_numero_ticket; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_generar_numero_ticket BEFORE INSERT ON public.tickets_soporte FOR EACH ROW WHEN (((new.numero_ticket IS NULL) OR ((new.numero_ticket)::text = ''::text))) EXECUTE FUNCTION public.generar_numero_ticket();


--
-- TOC entry 5902 (class 2620 OID 115659)
-- Name: empresa_tipos_vehiculo trigger_log_etv_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_log_etv_change AFTER UPDATE ON public.empresa_tipos_vehiculo FOR EACH ROW EXECUTE FUNCTION public.log_empresa_tipo_vehiculo_change();


--
-- TOC entry 5906 (class 2620 OID 115753)
-- Name: solicitudes_callback trigger_update_callback_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_callback_timestamp BEFORE UPDATE ON public.solicitudes_callback FOR EACH ROW EXECUTE FUNCTION public.update_support_timestamp();


--
-- TOC entry 5901 (class 2620 OID 91053)
-- Name: configuracion_notificaciones_usuario trigger_update_config_notif_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_config_notif_timestamp BEFORE UPDATE ON public.configuracion_notificaciones_usuario FOR EACH ROW EXECUTE FUNCTION public.update_config_notif_timestamp();


--
-- TOC entry 5900 (class 2620 OID 41837)
-- Name: empresas_transporte trigger_update_empresas_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_empresas_timestamp BEFORE UPDATE ON public.empresas_transporte FOR EACH ROW EXECUTE FUNCTION public.update_empresas_transporte_timestamp();


--
-- TOC entry 5903 (class 2620 OID 115657)
-- Name: empresa_tipos_vehiculo trigger_update_etv_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_etv_timestamp BEFORE UPDATE ON public.empresa_tipos_vehiculo FOR EACH ROW EXECUTE FUNCTION public.update_empresa_tipos_vehiculo_timestamp();


--
-- TOC entry 5899 (class 2620 OID 41834)
-- Name: mensajes_chat trigger_update_mensajes_chat; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_mensajes_chat BEFORE UPDATE ON public.mensajes_chat FOR EACH ROW EXECUTE FUNCTION public.update_mensajes_chat_timestamp();


--
-- TOC entry 5905 (class 2620 OID 115752)
-- Name: tickets_soporte trigger_update_ticket_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_ticket_timestamp BEFORE UPDATE ON public.tickets_soporte FOR EACH ROW EXECUTE FUNCTION public.update_support_timestamp();


--
-- TOC entry 5897 (class 2620 OID 91205)
-- Name: usuarios trigger_validar_conductor_empresa; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_validar_conductor_empresa BEFORE INSERT OR UPDATE ON public.usuarios FOR EACH ROW WHEN (((new.tipo_usuario)::text = 'conductor'::text)) EXECUTE FUNCTION public.validar_conductor_nueva_empresa();


--
-- TOC entry 5825 (class 2606 OID 17005)
-- Name: asignaciones_conductor asignaciones_conductor_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignaciones_conductor
    ADD CONSTRAINT asignaciones_conductor_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5826 (class 2606 OID 17010)
-- Name: asignaciones_conductor asignaciones_conductor_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignaciones_conductor
    ADD CONSTRAINT asignaciones_conductor_ibfk_2 FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5827 (class 2606 OID 17015)
-- Name: calificaciones calificaciones_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id);


--
-- TOC entry 5828 (class 2606 OID 17020)
-- Name: calificaciones calificaciones_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_ibfk_2 FOREIGN KEY (usuario_calificador_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5829 (class 2606 OID 17025)
-- Name: calificaciones calificaciones_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.calificaciones
    ADD CONSTRAINT calificaciones_ibfk_3 FOREIGN KEY (usuario_calificado_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5859 (class 2606 OID 17181)
-- Name: conductores_favoritos conductores_favoritos_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conductores_favoritos
    ADD CONSTRAINT conductores_favoritos_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5860 (class 2606 OID 17176)
-- Name: conductores_favoritos conductores_favoritos_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.conductores_favoritos
    ADD CONSTRAINT conductores_favoritos_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5831 (class 2606 OID 17030)
-- Name: detalles_conductor detalles_conductor_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_conductor
    ADD CONSTRAINT detalles_conductor_ibfk_1 FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5832 (class 2606 OID 17035)
-- Name: detalles_paquete detalles_paquete_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_paquete
    ADD CONSTRAINT detalles_paquete_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5833 (class 2606 OID 17040)
-- Name: detalles_viaje detalles_viaje_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalles_viaje
    ADD CONSTRAINT detalles_viaje_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5866 (class 2606 OID 17302)
-- Name: disputas_pago disputas_pago_cliente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5867 (class 2606 OID 17307)
-- Name: disputas_pago disputas_pago_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5868 (class 2606 OID 17312)
-- Name: disputas_pago disputas_pago_resuelto_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_resuelto_por_fkey FOREIGN KEY (resuelto_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5869 (class 2606 OID 17297)
-- Name: disputas_pago disputas_pago_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.disputas_pago
    ADD CONSTRAINT disputas_pago_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id);


--
-- TOC entry 5872 (class 2606 OID 33650)
-- Name: documentos_verificacion documentos_verificacion_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_verificacion
    ADD CONSTRAINT documentos_verificacion_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5883 (class 2606 OID 115590)
-- Name: empresa_tipos_vehiculo empresa_tipos_vehiculo_activado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT empresa_tipos_vehiculo_activado_por_fkey FOREIGN KEY (activado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5884 (class 2606 OID 115595)
-- Name: empresa_tipos_vehiculo empresa_tipos_vehiculo_desactivado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT empresa_tipos_vehiculo_desactivado_por_fkey FOREIGN KEY (desactivado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5885 (class 2606 OID 115585)
-- Name: empresa_tipos_vehiculo empresa_tipos_vehiculo_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT empresa_tipos_vehiculo_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5887 (class 2606 OID 115620)
-- Name: empresa_tipos_vehiculo_historial empresa_tipos_vehiculo_historial_empresa_tipo_vehiculo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo_historial
    ADD CONSTRAINT empresa_tipos_vehiculo_historial_empresa_tipo_vehiculo_id_fkey FOREIGN KEY (empresa_tipo_vehiculo_id) REFERENCES public.empresa_tipos_vehiculo(id) ON DELETE CASCADE;


--
-- TOC entry 5888 (class 2606 OID 115625)
-- Name: empresa_tipos_vehiculo_historial empresa_tipos_vehiculo_historial_realizado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo_historial
    ADD CONSTRAINT empresa_tipos_vehiculo_historial_realizado_por_fkey FOREIGN KEY (realizado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5889 (class 2606 OID 115649)
-- Name: empresa_vehiculo_notificaciones empresa_vehiculo_notificaciones_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_vehiculo_notificaciones
    ADD CONSTRAINT empresa_vehiculo_notificaciones_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5890 (class 2606 OID 115644)
-- Name: empresa_vehiculo_notificaciones empresa_vehiculo_notificaciones_historial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_vehiculo_notificaciones
    ADD CONSTRAINT empresa_vehiculo_notificaciones_historial_id_fkey FOREIGN KEY (historial_id) REFERENCES public.empresa_tipos_vehiculo_historial(id);


--
-- TOC entry 5882 (class 2606 OID 91293)
-- Name: empresas_configuracion empresas_configuracion_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_configuracion
    ADD CONSTRAINT empresas_configuracion_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5879 (class 2606 OID 91220)
-- Name: empresas_contacto empresas_contacto_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_contacto
    ADD CONSTRAINT empresas_contacto_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5881 (class 2606 OID 91267)
-- Name: empresas_metricas empresas_metricas_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_metricas
    ADD CONSTRAINT empresas_metricas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5880 (class 2606 OID 91241)
-- Name: empresas_representante empresas_representante_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_representante
    ADD CONSTRAINT empresas_representante_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5870 (class 2606 OID 25458)
-- Name: empresas_transporte empresas_transporte_creado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_transporte
    ADD CONSTRAINT empresas_transporte_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5871 (class 2606 OID 25453)
-- Name: empresas_transporte empresas_transporte_verificado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresas_transporte
    ADD CONSTRAINT empresas_transporte_verificado_por_fkey FOREIGN KEY (verificado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5834 (class 2606 OID 17045)
-- Name: documentos_conductor_historial fk_doc_historial_conductor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_conductor_historial
    ADD CONSTRAINT fk_doc_historial_conductor FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5835 (class 2606 OID 66396)
-- Name: documentos_conductor_historial fk_doc_historial_empresa; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documentos_conductor_historial
    ADD CONSTRAINT fk_doc_historial_empresa FOREIGN KEY (asignado_empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE SET NULL;


--
-- TOC entry 5836 (class 2606 OID 17050)
-- Name: historial_precios fk_historial_config; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_precios
    ADD CONSTRAINT fk_historial_config FOREIGN KEY (configuracion_id) REFERENCES public.configuracion_precios(id) ON DELETE CASCADE;


--
-- TOC entry 5837 (class 2606 OID 17055)
-- Name: historial_precios fk_historial_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_precios
    ADD CONSTRAINT fk_historial_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- TOC entry 5840 (class 2606 OID 17070)
-- Name: logs_auditoria fk_logs_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logs_auditoria
    ADD CONSTRAINT fk_logs_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- TOC entry 5842 (class 2606 OID 17080)
-- Name: paradas_solicitud fk_paradas_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paradas_solicitud
    ADD CONSTRAINT fk_paradas_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5830 (class 2606 OID 50014)
-- Name: configuracion_precios fk_precios_empresa; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.configuracion_precios
    ADD CONSTRAINT fk_precios_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5843 (class 2606 OID 17085)
-- Name: reportes_usuarios fk_reporte_admin; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reportes_usuarios
    ADD CONSTRAINT fk_reporte_admin FOREIGN KEY (admin_revisor_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- TOC entry 5844 (class 2606 OID 17090)
-- Name: reportes_usuarios fk_reporte_reportado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reportes_usuarios
    ADD CONSTRAINT fk_reporte_reportado FOREIGN KEY (usuario_reportado_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5845 (class 2606 OID 17095)
-- Name: reportes_usuarios fk_reporte_reportante; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reportes_usuarios
    ADD CONSTRAINT fk_reporte_reportante FOREIGN KEY (usuario_reportante_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5846 (class 2606 OID 17100)
-- Name: reportes_usuarios fk_reporte_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reportes_usuarios
    ADD CONSTRAINT fk_reporte_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE SET NULL;


--
-- TOC entry 5895 (class 2606 OID 123822)
-- Name: viaje_resumen_tracking fk_resumen_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_resumen_tracking
    ADD CONSTRAINT fk_resumen_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5847 (class 2606 OID 123844)
-- Name: solicitudes_servicio fk_solicitudes_empresa; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT fk_solicitudes_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE SET NULL;


--
-- TOC entry 5886 (class 2606 OID 115600)
-- Name: empresa_tipos_vehiculo fk_tipo_vehiculo_catalogo; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empresa_tipos_vehiculo
    ADD CONSTRAINT fk_tipo_vehiculo_catalogo FOREIGN KEY (tipo_vehiculo_codigo) REFERENCES public.catalogo_tipos_vehiculo(codigo) ON UPDATE CASCADE;


--
-- TOC entry 5893 (class 2606 OID 123788)
-- Name: viaje_tracking_realtime fk_tracking_conductor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_tracking_realtime
    ADD CONSTRAINT fk_tracking_conductor FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5894 (class 2606 OID 123783)
-- Name: viaje_tracking_realtime fk_tracking_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.viaje_tracking_realtime
    ADD CONSTRAINT fk_tracking_solicitud FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5861 (class 2606 OID 17209)
-- Name: historial_confianza historial_confianza_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_confianza
    ADD CONSTRAINT historial_confianza_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5862 (class 2606 OID 17204)
-- Name: historial_confianza historial_confianza_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_confianza
    ADD CONSTRAINT historial_confianza_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5838 (class 2606 OID 17060)
-- Name: historial_seguimiento historial_seguimiento_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_seguimiento
    ADD CONSTRAINT historial_seguimiento_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5839 (class 2606 OID 17065)
-- Name: historial_seguimiento historial_seguimiento_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.historial_seguimiento
    ADD CONSTRAINT historial_seguimiento_ibfk_2 FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5863 (class 2606 OID 17269)
-- Name: mensajes_chat mensajes_chat_destinatario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_chat
    ADD CONSTRAINT mensajes_chat_destinatario_id_fkey FOREIGN KEY (destinatario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5864 (class 2606 OID 17264)
-- Name: mensajes_chat mensajes_chat_remitente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_chat
    ADD CONSTRAINT mensajes_chat_remitente_id_fkey FOREIGN KEY (remitente_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5865 (class 2606 OID 17259)
-- Name: mensajes_chat mensajes_chat_solicitud_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_chat
    ADD CONSTRAINT mensajes_chat_solicitud_id_fkey FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id) ON DELETE CASCADE;


--
-- TOC entry 5892 (class 2606 OID 115729)
-- Name: mensajes_ticket mensajes_ticket_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mensajes_ticket
    ADD CONSTRAINT mensajes_ticket_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets_soporte(id) ON DELETE CASCADE;


--
-- TOC entry 5841 (class 2606 OID 17075)
-- Name: metodos_pago_usuario metodos_pago_usuario_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.metodos_pago_usuario
    ADD CONSTRAINT metodos_pago_usuario_ibfk_1 FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5875 (class 2606 OID 91000)
-- Name: notificaciones_usuario notificaciones_usuario_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notificaciones_usuario
    ADD CONSTRAINT notificaciones_usuario_tipo_id_fkey FOREIGN KEY (tipo_id) REFERENCES public.tipos_notificacion(id);


--
-- TOC entry 5873 (class 2606 OID 58215)
-- Name: pagos_empresas pagos_empresas_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pagos_empresas
    ADD CONSTRAINT pagos_empresas_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5874 (class 2606 OID 82791)
-- Name: plantillas_bloqueadas plantillas_bloqueadas_usuario_origen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plantillas_bloqueadas
    ADD CONSTRAINT plantillas_bloqueadas_usuario_origen_id_fkey FOREIGN KEY (usuario_origen_id) REFERENCES public.usuarios(id) ON DELETE SET NULL;


--
-- TOC entry 5848 (class 2606 OID 17320)
-- Name: solicitudes_servicio solicitudes_servicio_disputa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT solicitudes_servicio_disputa_id_fkey FOREIGN KEY (disputa_id) REFERENCES public.disputas_pago(id);


--
-- TOC entry 5849 (class 2606 OID 17105)
-- Name: solicitudes_servicio solicitudes_servicio_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT solicitudes_servicio_ibfk_1 FOREIGN KEY (cliente_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5850 (class 2606 OID 17110)
-- Name: solicitudes_servicio solicitudes_servicio_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT solicitudes_servicio_ibfk_2 FOREIGN KEY (ubicacion_recogida_id) REFERENCES public.ubicaciones_usuario(id);


--
-- TOC entry 5851 (class 2606 OID 17115)
-- Name: solicitudes_servicio solicitudes_servicio_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_servicio
    ADD CONSTRAINT solicitudes_servicio_ibfk_3 FOREIGN KEY (ubicacion_destino_id) REFERENCES public.ubicaciones_usuario(id);


--
-- TOC entry 5876 (class 2606 OID 91170)
-- Name: solicitudes_vinculacion_conductor solicitudes_vinculacion_conductor_conductor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor
    ADD CONSTRAINT solicitudes_vinculacion_conductor_conductor_id_fkey FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5877 (class 2606 OID 91175)
-- Name: solicitudes_vinculacion_conductor solicitudes_vinculacion_conductor_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor
    ADD CONSTRAINT solicitudes_vinculacion_conductor_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id) ON DELETE CASCADE;


--
-- TOC entry 5878 (class 2606 OID 91180)
-- Name: solicitudes_vinculacion_conductor solicitudes_vinculacion_conductor_procesado_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.solicitudes_vinculacion_conductor
    ADD CONSTRAINT solicitudes_vinculacion_conductor_procesado_por_fkey FOREIGN KEY (procesado_por) REFERENCES public.usuarios(id);


--
-- TOC entry 5891 (class 2606 OID 115705)
-- Name: tickets_soporte tickets_soporte_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets_soporte
    ADD CONSTRAINT tickets_soporte_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias_soporte(id);


--
-- TOC entry 5852 (class 2606 OID 17120)
-- Name: transacciones transacciones_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_ibfk_1 FOREIGN KEY (solicitud_id) REFERENCES public.solicitudes_servicio(id);


--
-- TOC entry 5853 (class 2606 OID 17125)
-- Name: transacciones transacciones_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_ibfk_2 FOREIGN KEY (cliente_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5854 (class 2606 OID 17130)
-- Name: transacciones transacciones_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_ibfk_3 FOREIGN KEY (conductor_id) REFERENCES public.usuarios(id);


--
-- TOC entry 5855 (class 2606 OID 17135)
-- Name: ubicaciones_usuario ubicaciones_usuario_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ubicaciones_usuario
    ADD CONSTRAINT ubicaciones_usuario_ibfk_1 FOREIGN KEY (usuario_id) REFERENCES public.usuarios(id) ON DELETE CASCADE;


--
-- TOC entry 5856 (class 2606 OID 17326)
-- Name: usuarios usuarios_disputa_activa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_disputa_activa_id_fkey FOREIGN KEY (disputa_activa_id) REFERENCES public.disputas_pago(id);


--
-- TOC entry 5857 (class 2606 OID 25467)
-- Name: usuarios usuarios_empresa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES public.empresas_transporte(id);


--
-- TOC entry 5858 (class 2606 OID 25473)
-- Name: usuarios usuarios_empresa_preferida_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_empresa_preferida_id_fkey FOREIGN KEY (empresa_preferida_id) REFERENCES public.empresas_transporte(id);


-- Completed on 2026-01-20 20:50:48

--
-- PostgreSQL database dump complete
--

\unrestrict Dq3oD9jINVut0lUKABlMd9ADHtI5cuvjIbq7nWdarCIibKXRE12hetzNNYge0ca

