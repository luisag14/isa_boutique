--
-- PostgreSQL database dump
--

\restrict DQcJNKS5Vpdt1TnsDy3FuxvC6Wk8p5kD4KEy10aT8O5sMabPSOtqH1Kbk5e1d7C

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

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
-- Name: estado_devolucion; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.estado_devolucion AS ENUM (
    'pendiente',
    'aprobada',
    'rechazada'
);


ALTER TYPE public.estado_devolucion OWNER TO postgres;

--
-- Name: estado_producto; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.estado_producto AS ENUM (
    'activo',
    'inactivo',
    'agotado'
);


ALTER TYPE public.estado_producto OWNER TO postgres;

--
-- Name: estado_venta; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.estado_venta AS ENUM (
    'pagada',
    'pendiente',
    'cancelada',
    'devuelta'
);


ALTER TYPE public.estado_venta OWNER TO postgres;

--
-- Name: medio_pago; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.medio_pago AS ENUM (
    'efectivo',
    'transferencia',
    'tarjeta_debito',
    'tarjeta_credito'
);


ALTER TYPE public.medio_pago OWNER TO postgres;

--
-- Name: rol_usuario; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.rol_usuario AS ENUM (
    'admin',
    'vendedor'
);


ALTER TYPE public.rol_usuario OWNER TO postgres;

--
-- Name: tipo_movimiento; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.tipo_movimiento AS ENUM (
    'ingreso_inicial',
    'ingreso_stock',
    'ajuste_stock',
    'venta',
    'devolucion',
    'activacion',
    'desactivacion',
    'eliminacion',
    'cambio_precio'
);


ALTER TYPE public.tipo_movimiento OWNER TO postgres;

--
-- Name: fn_actualizar_estado_producto(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_actualizar_estado_producto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.cantidad = 0 THEN
        NEW.estado := 'agotado';
    ELSIF NEW.cantidad > 0 AND NEW.estado = 'agotado' THEN
        NEW.estado := 'activo';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_actualizar_estado_producto() OWNER TO postgres;

--
-- Name: fn_auditoria_general(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_auditoria_general() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            NULL,
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria_log (
            tabla_afectada,
            operacion,
            datos_anteriores,
            datos_nuevos
        )
        VALUES (
            TG_TABLE_NAME,
            TG_OP,
            to_jsonb(OLD),
            NULL
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.fn_auditoria_general() OWNER TO postgres;

--
-- Name: fn_descontar_stock_venta(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_descontar_stock_venta() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
        usuario_venta INT;
    BEGIN
        SELECT id_usuario
        INTO usuario_venta
        FROM venta
        WHERE id_venta = NEW.id_venta;

        IF NEW.cantidad > (
            SELECT cantidad
            FROM producto
            WHERE id_producto = NEW.id_producto
        ) THEN
            RAISE EXCEPTION 'Stock insuficiente para realizar la venta';
        END IF;

        UPDATE producto
        SET cantidad = cantidad - NEW.cantidad
        WHERE id_producto = NEW.id_producto;

        INSERT INTO movimiento_inventario (
            id_producto,
            id_usuario,
            tipo,
            cantidad,
            detalle
        )
        VALUES (
            NEW.id_producto,
            usuario_venta,
            'venta',
            NEW.cantidad,
            'Venta registrada y stock descontado automáticamente'
        );

        RETURN NEW;
    END;
    $$;


ALTER FUNCTION public.fn_descontar_stock_venta() OWNER TO postgres;

--
-- Name: fn_registrar_cambio_precio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_registrar_cambio_precio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO cambio_precio (
            id_producto,
            precio_anterior,
            precio_nuevo,
            detalle
        )
        VALUES (
            OLD.id_producto,
            OLD.precio,
            NEW.precio,
            'Cambio de precio registrado automáticamente'
        );

        INSERT INTO movimiento_inventario (
            id_producto,
            tipo,
            cantidad,
            detalle
        )
        VALUES (
            OLD.id_producto,
            'cambio_precio',
            0,
            'Precio anterior: ' || OLD.precio || ' | Precio nuevo: ' || NEW.precio
        );
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_registrar_cambio_precio() OWNER TO postgres;

--
-- Name: fn_sumar_stock_devolucion(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_sumar_stock_devolucion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE producto
    SET cantidad = cantidad + NEW.cantidad
    WHERE id_producto = NEW.id_producto;

    INSERT INTO movimiento_inventario (
        id_producto,
        tipo,
        cantidad,
        detalle
    )
    VALUES (
        NEW.id_producto,
        'devolucion',
        NEW.cantidad,
        'Devolución registrada y stock aumentado automáticamente'
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_sumar_stock_devolucion() OWNER TO postgres;

--
-- Name: fn_total_ventas_netas(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_ventas_netas() RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    total_ventas NUMERIC;
    total_devoluciones NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total), 0)
    INTO total_ventas
    FROM venta
    WHERE estado IN ('pagada', 'devuelta');

    SELECT COALESCE(SUM(total_devuelto), 0)
    INTO total_devoluciones
    FROM devolucion
    WHERE estado = 'aprobada';

    RETURN total_ventas - total_devoluciones;
END;
$$;


ALTER FUNCTION public.fn_total_ventas_netas() OWNER TO postgres;

--
-- Name: sp_registrar_movimiento(integer, integer, public.tipo_movimiento, integer, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_registrar_movimiento(IN p_id_producto integer, IN p_id_usuario integer, IN p_tipo public.tipo_movimiento, IN p_cantidad integer, IN p_detalle text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO movimiento_inventario (
        id_producto,
        id_usuario,
        tipo,
        cantidad,
        detalle
    )
    VALUES (
        p_id_producto,
        p_id_usuario,
        p_tipo,
        p_cantidad,
        p_detalle
    );
END;
$$;


ALTER PROCEDURE public.sp_registrar_movimiento(IN p_id_producto integer, IN p_id_usuario integer, IN p_tipo public.tipo_movimiento, IN p_cantidad integer, IN p_detalle text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auditoria_log (
    id_auditoria integer NOT NULL,
    tabla_afectada character varying(100) NOT NULL,
    operacion character varying(20) NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    usuario_bd character varying(100) DEFAULT CURRENT_USER,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT auditoria_log_operacion_check CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE public.auditoria_log OWNER TO postgres;

--
-- Name: auditoria_log_id_auditoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auditoria_log_id_auditoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.auditoria_log_id_auditoria_seq OWNER TO postgres;

--
-- Name: auditoria_log_id_auditoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auditoria_log_id_auditoria_seq OWNED BY public.auditoria_log.id_auditoria;


--
-- Name: cambio_precio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cambio_precio (
    id_cambio_precio integer NOT NULL,
    id_producto integer NOT NULL,
    id_usuario integer,
    precio_anterior numeric(12,2) NOT NULL,
    precio_nuevo numeric(12,2) NOT NULL,
    detalle text,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cambio_precio_precio_anterior_check CHECK ((precio_anterior > (0)::numeric)),
    CONSTRAINT cambio_precio_precio_nuevo_check CHECK ((precio_nuevo > (0)::numeric)),
    CONSTRAINT chk_precio_diferente CHECK ((precio_anterior <> precio_nuevo))
);


ALTER TABLE public.cambio_precio OWNER TO postgres;

--
-- Name: cambio_precio_id_cambio_precio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cambio_precio_id_cambio_precio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cambio_precio_id_cambio_precio_seq OWNER TO postgres;

--
-- Name: cambio_precio_id_cambio_precio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cambio_precio_id_cambio_precio_seq OWNED BY public.cambio_precio.id_cambio_precio;


--
-- Name: categoria; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categoria (
    id_categoria integer NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion text,
    estado boolean DEFAULT true,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.categoria OWNER TO postgres;

--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categoria_id_categoria_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categoria_id_categoria_seq OWNER TO postgres;

--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categoria_id_categoria_seq OWNED BY public.categoria.id_categoria;


--
-- Name: cliente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cliente (
    id_cliente integer NOT NULL,
    nombre character varying(100) NOT NULL,
    telefono character varying(30) NOT NULL,
    correo character varying(100),
    direccion text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.cliente OWNER TO postgres;

--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cliente_id_cliente_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cliente_id_cliente_seq OWNER TO postgres;

--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cliente_id_cliente_seq OWNED BY public.cliente.id_cliente;


--
-- Name: compra_mercancia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.compra_mercancia (
    id_compra integer NOT NULL,
    id_proveedor integer,
    id_usuario integer,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    costo_envio numeric(12,2) DEFAULT 0 NOT NULL,
    total_productos numeric(12,2) DEFAULT 0 NOT NULL,
    total_compra numeric(12,2) DEFAULT 0 NOT NULL,
    detalle text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT compra_mercancia_costo_envio_check CHECK ((costo_envio >= (0)::numeric)),
    CONSTRAINT compra_mercancia_total_compra_check CHECK ((total_compra >= (0)::numeric)),
    CONSTRAINT compra_mercancia_total_productos_check CHECK ((total_productos >= (0)::numeric))
);


ALTER TABLE public.compra_mercancia OWNER TO postgres;

--
-- Name: compra_mercancia_id_compra_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.compra_mercancia_id_compra_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.compra_mercancia_id_compra_seq OWNER TO postgres;

--
-- Name: compra_mercancia_id_compra_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.compra_mercancia_id_compra_seq OWNED BY public.compra_mercancia.id_compra;


--
-- Name: detalle_compra_mercancia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_compra_mercancia (
    id_detalle_compra integer NOT NULL,
    id_compra integer NOT NULL,
    id_producto integer NOT NULL,
    talla character varying(20),
    cantidad integer NOT NULL,
    costo_unitario numeric(12,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    CONSTRAINT detalle_compra_mercancia_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT detalle_compra_mercancia_costo_unitario_check CHECK ((costo_unitario >= (0)::numeric)),
    CONSTRAINT detalle_compra_mercancia_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE public.detalle_compra_mercancia OWNER TO postgres;

--
-- Name: detalle_compra_mercancia_id_detalle_compra_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detalle_compra_mercancia_id_detalle_compra_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detalle_compra_mercancia_id_detalle_compra_seq OWNER TO postgres;

--
-- Name: detalle_compra_mercancia_id_detalle_compra_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalle_compra_mercancia_id_detalle_compra_seq OWNED BY public.detalle_compra_mercancia.id_detalle_compra;


--
-- Name: detalle_devolucion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_devolucion (
    id_detalle_devolucion integer NOT NULL,
    id_devolucion integer NOT NULL,
    id_producto integer NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(12,2) NOT NULL,
    subtotal_devuelto numeric(12,2) NOT NULL,
    talla character varying(20),
    costo_unitario numeric(12,2) DEFAULT 0 NOT NULL,
    subtotal_costo_devuelto numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT detalle_devolucion_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT detalle_devolucion_costo_unitario_check CHECK ((costo_unitario >= (0)::numeric)),
    CONSTRAINT detalle_devolucion_precio_unitario_check CHECK ((precio_unitario > (0)::numeric)),
    CONSTRAINT detalle_devolucion_subtotal_costo_devuelto_check CHECK ((subtotal_costo_devuelto >= (0)::numeric)),
    CONSTRAINT detalle_devolucion_subtotal_devuelto_check CHECK ((subtotal_devuelto >= (0)::numeric))
);


ALTER TABLE public.detalle_devolucion OWNER TO postgres;

--
-- Name: detalle_devolucion_id_detalle_devolucion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detalle_devolucion_id_detalle_devolucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detalle_devolucion_id_detalle_devolucion_seq OWNER TO postgres;

--
-- Name: detalle_devolucion_id_detalle_devolucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalle_devolucion_id_detalle_devolucion_seq OWNED BY public.detalle_devolucion.id_detalle_devolucion;


--
-- Name: detalle_venta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalle_venta (
    id_detalle_venta integer NOT NULL,
    id_venta integer NOT NULL,
    id_producto integer NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(12,2) NOT NULL,
    subtotal numeric(12,2) NOT NULL,
    talla character varying(20),
    costo_unitario numeric(12,2) DEFAULT 0 NOT NULL,
    subtotal_costo numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT detalle_venta_cantidad_check CHECK ((cantidad > 0)),
    CONSTRAINT detalle_venta_costo_unitario_check CHECK ((costo_unitario >= (0)::numeric)),
    CONSTRAINT detalle_venta_precio_unitario_check CHECK ((precio_unitario > (0)::numeric)),
    CONSTRAINT detalle_venta_subtotal_check CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT detalle_venta_subtotal_costo_check CHECK ((subtotal_costo >= (0)::numeric))
);


ALTER TABLE public.detalle_venta OWNER TO postgres;

--
-- Name: detalle_venta_id_detalle_venta_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detalle_venta_id_detalle_venta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detalle_venta_id_detalle_venta_seq OWNER TO postgres;

--
-- Name: detalle_venta_id_detalle_venta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detalle_venta_id_detalle_venta_seq OWNED BY public.detalle_venta.id_detalle_venta;


--
-- Name: devolucion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devolucion (
    id_devolucion integer NOT NULL,
    id_venta integer NOT NULL,
    id_cliente integer NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    motivo text NOT NULL,
    total_devuelto numeric(12,2) NOT NULL,
    estado public.estado_devolucion DEFAULT 'aprobada'::public.estado_devolucion NOT NULL,
    CONSTRAINT devolucion_total_devuelto_check CHECK ((total_devuelto >= (0)::numeric))
);


ALTER TABLE public.devolucion OWNER TO postgres;

--
-- Name: devolucion_id_devolucion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.devolucion_id_devolucion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.devolucion_id_devolucion_seq OWNER TO postgres;

--
-- Name: devolucion_id_devolucion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.devolucion_id_devolucion_seq OWNED BY public.devolucion.id_devolucion;


--
-- Name: gasto_negocio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gasto_negocio (
    id_gasto integer NOT NULL,
    id_usuario integer,
    tipo character varying(30) NOT NULL,
    concepto character varying(120) NOT NULL,
    valor numeric(12,2) NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    detalle text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT gasto_negocio_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['primario'::character varying, 'secundario'::character varying, 'servicio'::character varying, 'nomina'::character varying, 'transporte'::character varying, 'publicidad'::character varying, 'empaque'::character varying, 'mantenimiento'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT gasto_negocio_valor_check CHECK ((valor > (0)::numeric))
);


ALTER TABLE public.gasto_negocio OWNER TO postgres;

--
-- Name: gasto_negocio_id_gasto_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.gasto_negocio_id_gasto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.gasto_negocio_id_gasto_seq OWNER TO postgres;

--
-- Name: gasto_negocio_id_gasto_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.gasto_negocio_id_gasto_seq OWNED BY public.gasto_negocio.id_gasto;


--
-- Name: inversion_negocio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inversion_negocio (
    id_inversion integer NOT NULL,
    id_usuario integer,
    tipo character varying(30) NOT NULL,
    concepto character varying(120) NOT NULL,
    valor numeric(12,2) NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    detalle text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inversion_negocio_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['capital'::character varying, 'mercancia'::character varying, 'adecuacion'::character varying, 'publicidad'::character varying, 'tecnologia'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT inversion_negocio_valor_check CHECK ((valor > (0)::numeric))
);


ALTER TABLE public.inversion_negocio OWNER TO postgres;

--
-- Name: inversion_negocio_id_inversion_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inversion_negocio_id_inversion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inversion_negocio_id_inversion_seq OWNER TO postgres;

--
-- Name: inversion_negocio_id_inversion_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inversion_negocio_id_inversion_seq OWNED BY public.inversion_negocio.id_inversion;


--
-- Name: movimiento_inventario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimiento_inventario (
    id_movimiento integer NOT NULL,
    id_producto integer NOT NULL,
    id_usuario integer,
    tipo public.tipo_movimiento NOT NULL,
    cantidad integer DEFAULT 0 NOT NULL,
    detalle text,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT movimiento_inventario_cantidad_check CHECK ((cantidad >= 0))
);


ALTER TABLE public.movimiento_inventario OWNER TO postgres;

--
-- Name: movimiento_inventario_id_movimiento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.movimiento_inventario_id_movimiento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.movimiento_inventario_id_movimiento_seq OWNER TO postgres;

--
-- Name: movimiento_inventario_id_movimiento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.movimiento_inventario_id_movimiento_seq OWNED BY public.movimiento_inventario.id_movimiento;


--
-- Name: pago_trabajador; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pago_trabajador (
    id_pago_trabajador integer NOT NULL,
    id_trabajador integer NOT NULL,
    id_usuario integer,
    tipo_pago character varying(30) NOT NULL,
    valor numeric(12,2) NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    detalle text,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pago_trabajador_tipo_pago_check CHECK (((tipo_pago)::text = ANY ((ARRAY['salario'::character varying, 'comision'::character varying, 'adelanto'::character varying, 'bono'::character varying, 'deduccion'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT pago_trabajador_valor_check CHECK ((valor > (0)::numeric))
);


ALTER TABLE public.pago_trabajador OWNER TO postgres;

--
-- Name: pago_trabajador_id_pago_trabajador_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pago_trabajador_id_pago_trabajador_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pago_trabajador_id_pago_trabajador_seq OWNER TO postgres;

--
-- Name: pago_trabajador_id_pago_trabajador_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pago_trabajador_id_pago_trabajador_seq OWNED BY public.pago_trabajador.id_pago_trabajador;


--
-- Name: producto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producto (
    id_producto integer NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(100) NOT NULL,
    marca character varying(80) NOT NULL,
    id_categoria integer NOT NULL,
    precio numeric(12,2) NOT NULL,
    cantidad integer DEFAULT 0 NOT NULL,
    estado public.estado_producto DEFAULT 'activo'::public.estado_producto NOT NULL,
    imagen text,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    costo_unitario numeric(12,2) DEFAULT 0 NOT NULL,
    CONSTRAINT producto_cantidad_check CHECK ((cantidad >= 0)),
    CONSTRAINT producto_costo_unitario_check CHECK ((costo_unitario >= (0)::numeric)),
    CONSTRAINT producto_precio_check CHECK ((precio > (0)::numeric))
);


ALTER TABLE public.producto OWNER TO postgres;

--
-- Name: producto_id_producto_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.producto_id_producto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.producto_id_producto_seq OWNER TO postgres;

--
-- Name: producto_id_producto_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.producto_id_producto_seq OWNED BY public.producto.id_producto;


--
-- Name: producto_talla; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producto_talla (
    id_producto_talla integer NOT NULL,
    id_producto integer NOT NULL,
    talla character varying(20) NOT NULL,
    cantidad integer DEFAULT 0 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT producto_talla_cantidad_check CHECK ((cantidad >= 0))
);


ALTER TABLE public.producto_talla OWNER TO postgres;

--
-- Name: producto_talla_id_producto_talla_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.producto_talla_id_producto_talla_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.producto_talla_id_producto_talla_seq OWNER TO postgres;

--
-- Name: producto_talla_id_producto_talla_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.producto_talla_id_producto_talla_seq OWNED BY public.producto_talla.id_producto_talla;


--
-- Name: proveedor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proveedor (
    id_proveedor integer NOT NULL,
    nombre character varying(120) NOT NULL,
    telefono character varying(40),
    ciudad character varying(80),
    producto_suministra character varying(160),
    estado boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.proveedor OWNER TO postgres;

--
-- Name: proveedor_id_proveedor_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proveedor_id_proveedor_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proveedor_id_proveedor_seq OWNER TO postgres;

--
-- Name: proveedor_id_proveedor_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proveedor_id_proveedor_seq OWNED BY public.proveedor.id_proveedor;


--
-- Name: trabajador; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trabajador (
    id_trabajador integer NOT NULL,
    nombre character varying(120) NOT NULL,
    documento character varying(40),
    telefono character varying(40),
    cargo character varying(80) NOT NULL,
    salario_base numeric(12,2) DEFAULT 0 NOT NULL,
    estado boolean DEFAULT true NOT NULL,
    fecha_ingreso date DEFAULT CURRENT_DATE NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT trabajador_salario_base_check CHECK ((salario_base >= (0)::numeric))
);


ALTER TABLE public.trabajador OWNER TO postgres;

--
-- Name: trabajador_id_trabajador_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trabajador_id_trabajador_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trabajador_id_trabajador_seq OWNER TO postgres;

--
-- Name: trabajador_id_trabajador_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trabajador_id_trabajador_seq OWNED BY public.trabajador.id_trabajador;


--
-- Name: usuario_sistema; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.usuario_sistema (
    id_usuario integer NOT NULL,
    nombre character varying(100) NOT NULL,
    correo character varying(100) NOT NULL,
    contrasena character varying(255) NOT NULL,
    rol public.rol_usuario DEFAULT 'vendedor'::public.rol_usuario NOT NULL,
    estado boolean DEFAULT true,
    sesion_token character varying(128),
    sesion_actualizada timestamp without time zone,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.usuario_sistema OWNER TO postgres;

--
-- Name: usuario_sistema_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.usuario_sistema_id_usuario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuario_sistema_id_usuario_seq OWNER TO postgres;

--
-- Name: usuario_sistema_id_usuario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.usuario_sistema_id_usuario_seq OWNED BY public.usuario_sistema.id_usuario;


--
-- Name: venta; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venta (
    id_venta integer NOT NULL,
    id_cliente integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    medio_pago public.medio_pago NOT NULL,
    canal_venta character varying(30) DEFAULT 'tienda_fisica'::character varying NOT NULL,
    tipo_entrega character varying(30) DEFAULT 'recoger_tienda'::character varying NOT NULL,
    total numeric(12,2) DEFAULT 0 NOT NULL,
    estado public.estado_venta DEFAULT 'pagada'::public.estado_venta NOT NULL,
    CONSTRAINT venta_canal_venta_check CHECK (((canal_venta)::text = ANY ((ARRAY['tienda_fisica'::character varying, 'pagina_web'::character varying, 'whatsapp'::character varying, 'instagram'::character varying])::text[]))),
    CONSTRAINT venta_tipo_entrega_check CHECK (((tipo_entrega)::text = ANY ((ARRAY['recoger_tienda'::character varying, 'envio_local'::character varying, 'envio_nacional'::character varying])::text[]))),
    CONSTRAINT venta_total_check CHECK ((total >= (0)::numeric))
);


ALTER TABLE public.venta OWNER TO postgres;

--
-- Name: venta_id_venta_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venta_id_venta_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venta_id_venta_seq OWNER TO postgres;

--
-- Name: venta_id_venta_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venta_id_venta_seq OWNED BY public.venta.id_venta;


--
-- Name: vista_inventario_general; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_inventario_general AS
 SELECT p.id_producto,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    c.nombre AS categoria,
    p.precio,
    p.cantidad,
    p.estado,
    p.imagen,
    p.fecha_creacion
   FROM (public.producto p
     JOIN public.categoria c ON ((p.id_categoria = c.id_categoria)));


ALTER VIEW public.vista_inventario_general OWNER TO postgres;

--
-- Name: vista_ranking_productos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_ranking_productos AS
 SELECT p.id_producto,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    sum(dv.cantidad) AS total_vendido,
    rank() OVER (ORDER BY (sum(dv.cantidad)) DESC) AS ranking_producto
   FROM ((public.producto p
     JOIN public.detalle_venta dv ON ((p.id_producto = dv.id_producto)))
     JOIN public.venta v ON ((dv.id_venta = v.id_venta)))
  WHERE (v.estado = ANY (ARRAY['pagada'::public.estado_venta, 'devuelta'::public.estado_venta]))
  GROUP BY p.id_producto, p.codigo, p.nombre, p.marca;


ALTER VIEW public.vista_ranking_productos OWNER TO postgres;

--
-- Name: vista_reporte_mensual; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_reporte_mensual AS
 SELECT ventas_mes.mes,
    ventas_mes.ventas_brutas,
    COALESCE(devoluciones_mes.devoluciones, (0)::numeric) AS devoluciones,
    (ventas_mes.ventas_brutas - COALESCE(devoluciones_mes.devoluciones, (0)::numeric)) AS neto
   FROM (( SELECT date_trunc('month'::text, v.fecha) AS mes,
            sum(dv.subtotal) AS ventas_brutas
           FROM (public.venta v
             JOIN public.detalle_venta dv ON ((v.id_venta = dv.id_venta)))
          WHERE (v.estado = ANY (ARRAY['pagada'::public.estado_venta, 'devuelta'::public.estado_venta]))
          GROUP BY (date_trunc('month'::text, v.fecha))) ventas_mes
     LEFT JOIN ( SELECT date_trunc('month'::text, d.fecha) AS mes,
            sum(d.total_devuelto) AS devoluciones
           FROM public.devolucion d
          WHERE (d.estado = 'aprobada'::public.estado_devolucion)
          GROUP BY (date_trunc('month'::text, d.fecha))) devoluciones_mes ON ((ventas_mes.mes = devoluciones_mes.mes)));


ALTER VIEW public.vista_reporte_mensual OWNER TO postgres;

--
-- Name: vista_ventas_acumuladas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_ventas_acumuladas AS
 SELECT v.id_venta,
    v.fecha,
    cl.nombre AS cliente,
    v.total,
    sum(v.total) OVER (ORDER BY v.fecha ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_acumulado
   FROM (public.venta v
     JOIN public.cliente cl ON ((v.id_cliente = cl.id_cliente)))
  WHERE (v.estado = 'pagada'::public.estado_venta);


ALTER VIEW public.vista_ventas_acumuladas OWNER TO postgres;

--
-- Name: vista_ventas_detalladas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_ventas_detalladas AS
 SELECT v.id_venta,
    v.fecha,
    cl.nombre AS cliente,
    cl.telefono,
    u.nombre AS usuario,
    p.codigo,
    p.nombre AS producto,
    p.marca,
    dv.cantidad,
    dv.precio_unitario,
    dv.subtotal,
    v.medio_pago,
    v.canal_venta,
    v.tipo_entrega,
    v.total,
    v.estado
   FROM ((((public.venta v
     JOIN public.cliente cl ON ((v.id_cliente = cl.id_cliente)))
     JOIN public.usuario_sistema u ON ((v.id_usuario = u.id_usuario)))
     JOIN public.detalle_venta dv ON ((v.id_venta = dv.id_venta)))
     JOIN public.producto p ON ((dv.id_producto = p.id_producto)));


ALTER VIEW public.vista_ventas_detalladas OWNER TO postgres;

--
-- Name: auditoria_log id_auditoria; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria_log ALTER COLUMN id_auditoria SET DEFAULT nextval('public.auditoria_log_id_auditoria_seq'::regclass);


--
-- Name: cambio_precio id_cambio_precio; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambio_precio ALTER COLUMN id_cambio_precio SET DEFAULT nextval('public.cambio_precio_id_cambio_precio_seq'::regclass);


--
-- Name: categoria id_categoria; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria ALTER COLUMN id_categoria SET DEFAULT nextval('public.categoria_id_categoria_seq'::regclass);


--
-- Name: cliente id_cliente; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente ALTER COLUMN id_cliente SET DEFAULT nextval('public.cliente_id_cliente_seq'::regclass);


--
-- Name: compra_mercancia id_compra; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compra_mercancia ALTER COLUMN id_compra SET DEFAULT nextval('public.compra_mercancia_id_compra_seq'::regclass);


--
-- Name: detalle_compra_mercancia id_detalle_compra; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra_mercancia ALTER COLUMN id_detalle_compra SET DEFAULT nextval('public.detalle_compra_mercancia_id_detalle_compra_seq'::regclass);


--
-- Name: detalle_devolucion id_detalle_devolucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_devolucion ALTER COLUMN id_detalle_devolucion SET DEFAULT nextval('public.detalle_devolucion_id_detalle_devolucion_seq'::regclass);


--
-- Name: detalle_venta id_detalle_venta; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta ALTER COLUMN id_detalle_venta SET DEFAULT nextval('public.detalle_venta_id_detalle_venta_seq'::regclass);


--
-- Name: devolucion id_devolucion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devolucion ALTER COLUMN id_devolucion SET DEFAULT nextval('public.devolucion_id_devolucion_seq'::regclass);


--
-- Name: gasto_negocio id_gasto; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gasto_negocio ALTER COLUMN id_gasto SET DEFAULT nextval('public.gasto_negocio_id_gasto_seq'::regclass);


--
-- Name: inversion_negocio id_inversion; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inversion_negocio ALTER COLUMN id_inversion SET DEFAULT nextval('public.inversion_negocio_id_inversion_seq'::regclass);


--
-- Name: movimiento_inventario id_movimiento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimiento_inventario ALTER COLUMN id_movimiento SET DEFAULT nextval('public.movimiento_inventario_id_movimiento_seq'::regclass);


--
-- Name: pago_trabajador id_pago_trabajador; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_trabajador ALTER COLUMN id_pago_trabajador SET DEFAULT nextval('public.pago_trabajador_id_pago_trabajador_seq'::regclass);


--
-- Name: producto id_producto; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto ALTER COLUMN id_producto SET DEFAULT nextval('public.producto_id_producto_seq'::regclass);


--
-- Name: producto_talla id_producto_talla; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto_talla ALTER COLUMN id_producto_talla SET DEFAULT nextval('public.producto_talla_id_producto_talla_seq'::regclass);


--
-- Name: proveedor id_proveedor; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedor ALTER COLUMN id_proveedor SET DEFAULT nextval('public.proveedor_id_proveedor_seq'::regclass);


--
-- Name: trabajador id_trabajador; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajador ALTER COLUMN id_trabajador SET DEFAULT nextval('public.trabajador_id_trabajador_seq'::regclass);


--
-- Name: usuario_sistema id_usuario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_sistema ALTER COLUMN id_usuario SET DEFAULT nextval('public.usuario_sistema_id_usuario_seq'::regclass);


--
-- Name: venta id_venta; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venta ALTER COLUMN id_venta SET DEFAULT nextval('public.venta_id_venta_seq'::regclass);


--
-- Name: auditoria_log auditoria_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auditoria_log
    ADD CONSTRAINT auditoria_log_pkey PRIMARY KEY (id_auditoria);


--
-- Name: cambio_precio cambio_precio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambio_precio
    ADD CONSTRAINT cambio_precio_pkey PRIMARY KEY (id_cambio_precio);


--
-- Name: categoria categoria_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_nombre_key UNIQUE (nombre);


--
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id_categoria);


--
-- Name: cliente cliente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente);


--
-- Name: compra_mercancia compra_mercancia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compra_mercancia
    ADD CONSTRAINT compra_mercancia_pkey PRIMARY KEY (id_compra);


--
-- Name: detalle_compra_mercancia detalle_compra_mercancia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra_mercancia
    ADD CONSTRAINT detalle_compra_mercancia_pkey PRIMARY KEY (id_detalle_compra);


--
-- Name: detalle_devolucion detalle_devolucion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_devolucion
    ADD CONSTRAINT detalle_devolucion_pkey PRIMARY KEY (id_detalle_devolucion);


--
-- Name: detalle_venta detalle_venta_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_pkey PRIMARY KEY (id_detalle_venta);


--
-- Name: devolucion devolucion_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devolucion
    ADD CONSTRAINT devolucion_pkey PRIMARY KEY (id_devolucion);


--
-- Name: gasto_negocio gasto_negocio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gasto_negocio
    ADD CONSTRAINT gasto_negocio_pkey PRIMARY KEY (id_gasto);


--
-- Name: inversion_negocio inversion_negocio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inversion_negocio
    ADD CONSTRAINT inversion_negocio_pkey PRIMARY KEY (id_inversion);


--
-- Name: movimiento_inventario movimiento_inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimiento_inventario
    ADD CONSTRAINT movimiento_inventario_pkey PRIMARY KEY (id_movimiento);


--
-- Name: pago_trabajador pago_trabajador_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_trabajador
    ADD CONSTRAINT pago_trabajador_pkey PRIMARY KEY (id_pago_trabajador);


--
-- Name: producto producto_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_codigo_key UNIQUE (codigo);


--
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id_producto);


--
-- Name: producto_talla producto_talla_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto_talla
    ADD CONSTRAINT producto_talla_pkey PRIMARY KEY (id_producto_talla);


--
-- Name: proveedor proveedor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedor
    ADD CONSTRAINT proveedor_pkey PRIMARY KEY (id_proveedor);


--
-- Name: trabajador trabajador_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trabajador
    ADD CONSTRAINT trabajador_pkey PRIMARY KEY (id_trabajador);


--
-- Name: producto_talla uq_producto_talla; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto_talla
    ADD CONSTRAINT uq_producto_talla UNIQUE (id_producto, talla);


--
-- Name: usuario_sistema usuario_sistema_correo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_sistema
    ADD CONSTRAINT usuario_sistema_correo_key UNIQUE (correo);


--
-- Name: usuario_sistema usuario_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.usuario_sistema
    ADD CONSTRAINT usuario_sistema_pkey PRIMARY KEY (id_usuario);


--
-- Name: venta venta_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venta
    ADD CONSTRAINT venta_pkey PRIMARY KEY (id_venta);


--
-- Name: producto trg_actualizar_estado_producto; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_actualizar_estado_producto BEFORE INSERT OR UPDATE OF cantidad ON public.producto FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_estado_producto();


--
-- Name: cliente trg_auditoria_cliente; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_cliente AFTER INSERT OR DELETE OR UPDATE ON public.cliente FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_general();


--
-- Name: devolucion trg_auditoria_devolucion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_devolucion AFTER INSERT OR DELETE OR UPDATE ON public.devolucion FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_general();


--
-- Name: producto trg_auditoria_producto; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_producto AFTER INSERT OR DELETE OR UPDATE ON public.producto FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_general();


--
-- Name: venta trg_auditoria_venta; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditoria_venta AFTER INSERT OR DELETE OR UPDATE ON public.venta FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_general();


--
-- Name: detalle_venta trg_descontar_stock_venta; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_descontar_stock_venta AFTER INSERT ON public.detalle_venta FOR EACH ROW EXECUTE FUNCTION public.fn_descontar_stock_venta();


--
-- Name: producto trg_registrar_cambio_precio; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_registrar_cambio_precio AFTER UPDATE OF precio ON public.producto FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_cambio_precio();


--
-- Name: detalle_devolucion trg_sumar_stock_devolucion; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_sumar_stock_devolucion AFTER INSERT ON public.detalle_devolucion FOR EACH ROW EXECUTE FUNCTION public.fn_sumar_stock_devolucion();


--
-- Name: cambio_precio fk_cambio_precio_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambio_precio
    ADD CONSTRAINT fk_cambio_precio_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto);


--
-- Name: cambio_precio fk_cambio_precio_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cambio_precio
    ADD CONSTRAINT fk_cambio_precio_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: compra_mercancia fk_compra_proveedor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compra_mercancia
    ADD CONSTRAINT fk_compra_proveedor FOREIGN KEY (id_proveedor) REFERENCES public.proveedor(id_proveedor);


--
-- Name: compra_mercancia fk_compra_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compra_mercancia
    ADD CONSTRAINT fk_compra_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: detalle_compra_mercancia fk_detalle_compra; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra_mercancia
    ADD CONSTRAINT fk_detalle_compra FOREIGN KEY (id_compra) REFERENCES public.compra_mercancia(id_compra) ON DELETE CASCADE;


--
-- Name: detalle_compra_mercancia fk_detalle_compra_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_compra_mercancia
    ADD CONSTRAINT fk_detalle_compra_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto);


--
-- Name: detalle_devolucion fk_detalle_devolucion; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_devolucion
    ADD CONSTRAINT fk_detalle_devolucion FOREIGN KEY (id_devolucion) REFERENCES public.devolucion(id_devolucion) ON DELETE CASCADE;


--
-- Name: detalle_devolucion fk_detalle_devolucion_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_devolucion
    ADD CONSTRAINT fk_detalle_devolucion_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto);


--
-- Name: detalle_venta fk_detalle_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto);


--
-- Name: detalle_venta fk_detalle_venta; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES public.venta(id_venta) ON DELETE CASCADE;


--
-- Name: devolucion fk_devolucion_cliente; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devolucion
    ADD CONSTRAINT fk_devolucion_cliente FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente);


--
-- Name: devolucion fk_devolucion_venta; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devolucion
    ADD CONSTRAINT fk_devolucion_venta FOREIGN KEY (id_venta) REFERENCES public.venta(id_venta);


--
-- Name: gasto_negocio fk_gasto_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gasto_negocio
    ADD CONSTRAINT fk_gasto_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: inversion_negocio fk_inversion_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inversion_negocio
    ADD CONSTRAINT fk_inversion_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: movimiento_inventario fk_movimiento_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto);


--
-- Name: movimiento_inventario fk_movimiento_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimiento_inventario
    ADD CONSTRAINT fk_movimiento_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: pago_trabajador fk_pago_trabajador; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_trabajador
    ADD CONSTRAINT fk_pago_trabajador FOREIGN KEY (id_trabajador) REFERENCES public.trabajador(id_trabajador);


--
-- Name: pago_trabajador fk_pago_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pago_trabajador
    ADD CONSTRAINT fk_pago_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- Name: producto fk_producto_categoria; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES public.categoria(id_categoria);


--
-- Name: producto_talla fk_producto_talla_producto; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producto_talla
    ADD CONSTRAINT fk_producto_talla_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto) ON DELETE CASCADE;


--
-- Name: venta fk_venta_cliente; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venta
    ADD CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente);


--
-- Name: venta fk_venta_usuario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venta
    ADD CONSTRAINT fk_venta_usuario FOREIGN KEY (id_usuario) REFERENCES public.usuario_sistema(id_usuario);


--
-- PostgreSQL database dump complete
--

\unrestrict DQcJNKS5Vpdt1TnsDy3FuxvC6Wk8p5kD4KEy10aT8O5sMabPSOtqH1Kbk5e1d7C
