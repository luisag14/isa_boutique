--
-- PostgreSQL database dump
--

\restrict PRKtSJqfnElTJlNcakHwj6D7CUfbP15Vq56AdSeMIUxItabBpJpkdDFnUjpDf75

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
    total numeric(12,2) DEFAULT 0 NOT NULL,
    estado public.estado_venta DEFAULT 'pagada'::public.estado_venta NOT NULL,
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
-- Data for Name: auditoria_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auditoria_log (id_auditoria, tabla_afectada, operacion, datos_anteriores, datos_nuevos, usuario_bd, fecha) FROM stdin;
1	cliente	INSERT	\N	{"correo": "maria@correo.com", "nombre": "María Pérez", "telefono": "3001234567", "direccion": "Cartagena", "id_cliente": 1, "fecha_registro": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
2	cliente	INSERT	\N	{"correo": "laura@correo.com", "nombre": "Laura Gómez", "telefono": "3019876543", "direccion": "Cartagena", "id_cliente": 2, "fecha_registro": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
3	cliente	INSERT	\N	{"correo": "cliente@correo.com", "nombre": "Cliente Prueba", "telefono": "3025558899", "direccion": "Cartagena", "id_cliente": 3, "fecha_registro": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
4	producto	INSERT	\N	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
5	producto	INSERT	\N	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 45000.00, "cantidad": 8, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
6	producto	INSERT	\N	{"marca": "Cello", "codigo": "IB-003", "estado": "activo", "imagen": "img/Vermuda.jpg", "nombre": "Short denim", "precio": 70000.00, "cantidad": 6, "id_producto": 3, "id_categoria": 4, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
7	producto	INSERT	\N	{"marca": "Beloved", "codigo": "IB-004", "estado": "activo", "imagen": "img/pantalon.jpg", "nombre": "Jean clásico", "precio": 120000.00, "cantidad": 4, "id_producto": 4, "id_categoria": 5, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
8	producto	INSERT	\N	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 3, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
9	producto	INSERT	\N	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 10, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
10	venta	INSERT	\N	{"fecha": "2026-05-10T21:09:12.585654", "total": 85000.00, "estado": "pagada", "id_venta": 1, "id_cliente": 1, "id_usuario": 1, "medio_pago": "efectivo"}	postgres	2026-05-10 21:09:12.585654
11	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 4, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
12	devolucion	INSERT	\N	{"fecha": "2026-05-10T21:09:12.585654", "estado": "aprobada", "motivo": "Cambio de talla", "id_venta": 1, "id_cliente": 1, "id_devolucion": 1, "total_devuelto": 85000.00}	postgres	2026-05-10 21:09:12.585654
13	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 4, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
14	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 85000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-10 21:09:12.585654
15	producto	INSERT	\N	{"marca": "Isa Boutique", "codigo": "774576", "estado": "activo", "imagen": "img/productos/producto_6a0325f157209.png", "nombre": "Prueba real PostgreSQL", "precio": 20000.00, "cantidad": 2, "id_producto": 7, "id_categoria": 8, "fecha_creacion": "2026-05-12T08:06:57.388662"}	postgres	2026-05-12 08:06:57.388662
16	producto	INSERT	\N	{"marca": "ela", "codigo": "3256436", "estado": "activo", "imagen": "img/productos/producto_6a032c745caec.png", "nombre": "top corto", "precio": 12243.00, "cantidad": 3, "id_producto": 8, "id_categoria": 2, "fecha_creacion": "2026-05-12T08:34:44.385559"}	postgres	2026-05-12 08:34:44.385559
17	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "IB-001", "estado": "inactivo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-12 08:48:40.742232
18	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "inactivo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-12 08:48:59.168652
19	producto	UPDATE	{"marca": "ANWND", "codigo": "IB-001", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "2143", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-12 10:37:11.923342
20	cliente	INSERT	\N	{"correo": null, "nombre": "isa", "telefono": "12444", "direccion": null, "id_cliente": 4, "fecha_registro": "2026-05-13T01:12:35.543771"}	postgres	2026-05-13 01:12:35.543771
21	venta	INSERT	\N	{"fecha": "2026-05-13T01:12:35.543771", "total": 180000.00, "estado": "pagada", "id_venta": 2, "id_cliente": 4, "id_usuario": 1, "medio_pago": "transferencia"}	postgres	2026-05-13 01:12:35.543771
22	producto	UPDATE	{"marca": "ANWND", "codigo": "2143", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 5, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "ANWND", "codigo": "2143", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 3, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 01:12:35.543771
23	cliente	INSERT	\N	{"correo": null, "nombre": "ela", "telefono": "24234", "direccion": null, "id_cliente": 5, "fecha_registro": "2026-05-13T01:18:36.263121"}	postgres	2026-05-13 01:18:36.263121
24	venta	INSERT	\N	{"fecha": "2026-05-13T01:18:36.263121", "total": 45000.00, "estado": "pagada", "id_venta": 3, "id_cliente": 5, "id_usuario": 1, "medio_pago": "transferencia"}	postgres	2026-05-13 01:18:36.263121
25	producto	UPDATE	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 45000.00, "cantidad": 8, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 45000.00, "cantidad": 7, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 01:18:36.263121
26	cliente	INSERT	\N	{"correo": null, "nombre": "www", "telefono": "2334", "direccion": null, "id_cliente": 6, "fecha_registro": "2026-05-13T01:37:44.74802"}	postgres	2026-05-13 01:37:44.74802
27	venta	INSERT	\N	{"fecha": "2026-05-13T01:37:44.74802", "total": 70000.00, "estado": "pagada", "id_venta": 4, "id_cliente": 6, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	postgres	2026-05-13 01:37:44.74802
28	producto	UPDATE	{"marca": "Cello", "codigo": "IB-003", "estado": "activo", "imagen": "img/Vermuda.jpg", "nombre": "Short denim", "precio": 70000.00, "cantidad": 6, "id_producto": 3, "id_categoria": 4, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Cello", "codigo": "IB-003", "estado": "activo", "imagen": "img/Vermuda.jpg", "nombre": "Short denim", "precio": 70000.00, "cantidad": 5, "id_producto": 3, "id_categoria": 4, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 01:37:44.74802
29	cliente	INSERT	\N	{"correo": null, "nombre": "esdeq", "telefono": "32r341", "direccion": null, "id_cliente": 7, "fecha_registro": "2026-05-13T15:00:57.648287"}	postgres	2026-05-13 15:00:57.648287
30	venta	INSERT	\N	{"fecha": "2026-05-13T15:00:57.648287", "total": 50000.00, "estado": "pagada", "id_venta": 5, "id_cliente": 7, "id_usuario": 1, "medio_pago": "transferencia"}	postgres	2026-05-13 15:00:57.648287
31	producto	UPDATE	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 10, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 8, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 15:00:57.648287
32	cliente	INSERT	\N	{"correo": null, "nombre": "wqsq", "telefono": "1234", "direccion": null, "id_cliente": 8, "fecha_registro": "2026-05-13T15:20:17.42644"}	postgres	2026-05-13 15:20:17.42644
33	venta	INSERT	\N	{"fecha": "2026-05-13T15:20:17.42644", "total": 60000.00, "estado": "pagada", "id_venta": 6, "id_cliente": 8, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	postgres	2026-05-13 15:20:17.42644
34	producto	UPDATE	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 3, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 2, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 15:20:17.42644
35	devolucion	INSERT	\N	{"fecha": "2026-05-13T16:12:30.999715", "estado": "aprobada", "motivo": "daño", "id_venta": 5, "id_cliente": 7, "id_devolucion": 2, "total_devuelto": 25000.00}	postgres	2026-05-13 16:12:30.999715
36	producto	UPDATE	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 8, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 9, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 16:12:30.999715
37	producto	UPDATE	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 45000.00, "cantidad": 7, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 100000.00, "cantidad": 7, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-13 23:12:22.136463
38	producto	INSERT	\N	{"marca": "anwnd", "codigo": "8U'9'¿", "estado": "activo", "imagen": "img/productos/producto_6a07f5e8eca4f.png", "nombre": "top corto", "precio": 23235.00, "cantidad": 4, "id_producto": 9, "id_categoria": 3, "fecha_creacion": "2026-05-15T23:43:20.978493"}	postgres	2026-05-15 23:43:20.978493
39	devolucion	INSERT	\N	{"fecha": "2026-05-16T09:33:08.025023", "estado": "aprobada", "motivo": "feDS}", "id_venta": 6, "id_cliente": 8, "id_devolucion": 3, "total_devuelto": 60000.00}	postgres	2026-05-16 09:33:08.025023
64	venta	INSERT	\N	{"fecha": "2026-05-16T18:55:45.528616", "total": 70000.00, "estado": "pagada", "id_venta": 7, "id_cliente": 9, "id_usuario": 2, "medio_pago": "transferencia"}	postgres	2026-05-16 18:55:45.528616
40	producto	UPDATE	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 2, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 3, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	postgres	2026-05-16 09:33:08.025023
41	venta	UPDATE	{"fecha": "2026-05-13T15:20:17.42644", "total": 60000.00, "estado": "pagada", "id_venta": 6, "id_cliente": 8, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	{"fecha": "2026-05-13T15:20:17.42644", "total": 60000.00, "estado": "devuelta", "id_venta": 6, "id_cliente": 8, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	postgres	2026-05-16 09:33:08.025023
42	producto	DELETE	{"marca": "Beloved", "codigo": "IB-004", "estado": "activo", "imagen": "img/pantalon.jpg", "nombre": "Jean clásico", "precio": 120000.00, "cantidad": 4, "id_producto": 4, "id_categoria": 5, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:35:21.792245
43	producto	DELETE	{"marca": "anwnd", "codigo": "8U'9'¿", "estado": "activo", "imagen": "img/productos/producto_6a07f5e8eca4f.png", "nombre": "top corto", "precio": 23235.00, "cantidad": 4, "id_producto": 9, "id_categoria": 3, "fecha_creacion": "2026-05-15T23:43:20.978493"}	\N	postgres	2026-05-16 09:35:35.825456
44	producto	DELETE	{"marca": "ela", "codigo": "3256436", "estado": "activo", "imagen": "img/productos/producto_6a032c745caec.png", "nombre": "top corto", "precio": 12243.00, "cantidad": 3, "id_producto": 8, "id_categoria": 2, "fecha_creacion": "2026-05-12T08:34:44.385559"}	\N	postgres	2026-05-16 09:35:42.315168
45	producto	DELETE	{"marca": "Isa Boutique", "codigo": "774576", "estado": "activo", "imagen": "img/productos/producto_6a0325f157209.png", "nombre": "Prueba real PostgreSQL", "precio": 20000.00, "cantidad": 2, "id_producto": 7, "id_categoria": 8, "fecha_creacion": "2026-05-12T08:06:57.388662"}	\N	postgres	2026-05-16 09:35:47.609699
46	devolucion	DELETE	{"fecha": "2026-05-10T21:09:12.585654", "estado": "aprobada", "motivo": "Cambio de talla", "id_venta": 1, "id_cliente": 1, "id_devolucion": 1, "total_devuelto": 85000.00}	\N	postgres	2026-05-16 09:36:49.313459
47	venta	DELETE	{"fecha": "2026-05-10T21:09:12.585654", "total": 85000.00, "estado": "pagada", "id_venta": 1, "id_cliente": 1, "id_usuario": 1, "medio_pago": "efectivo"}	\N	postgres	2026-05-16 09:36:49.313459
48	venta	DELETE	{"fecha": "2026-05-13T01:12:35.543771", "total": 180000.00, "estado": "pagada", "id_venta": 2, "id_cliente": 4, "id_usuario": 1, "medio_pago": "transferencia"}	\N	postgres	2026-05-16 09:36:49.313459
49	producto	DELETE	{"marca": "ANWND", "codigo": "2143", "estado": "activo", "imagen": "img/vestido1.png", "nombre": "Vestido elegante rosa", "precio": 90000.00, "cantidad": 3, "id_producto": 1, "id_categoria": 1, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:36:49.313459
50	venta	DELETE	{"fecha": "2026-05-13T01:18:36.263121", "total": 45000.00, "estado": "pagada", "id_venta": 3, "id_cliente": 5, "id_usuario": 1, "medio_pago": "transferencia"}	\N	postgres	2026-05-16 09:36:58.738133
51	producto	DELETE	{"marca": "Zenana", "codigo": "IB-002", "estado": "activo", "imagen": "img/blusas.png", "nombre": "Blusa crop blanca", "precio": 100000.00, "cantidad": 7, "id_producto": 2, "id_categoria": 2, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:36:58.738133
52	venta	DELETE	{"fecha": "2026-05-13T01:37:44.74802", "total": 70000.00, "estado": "pagada", "id_venta": 4, "id_cliente": 6, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	\N	postgres	2026-05-16 09:37:08.262754
53	producto	DELETE	{"marca": "Cello", "codigo": "IB-003", "estado": "activo", "imagen": "img/Vermuda.jpg", "nombre": "Short denim", "precio": 70000.00, "cantidad": 5, "id_producto": 3, "id_categoria": 4, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:37:08.262754
54	devolucion	DELETE	{"fecha": "2026-05-16T09:33:08.025023", "estado": "aprobada", "motivo": "feDS}", "id_venta": 6, "id_cliente": 8, "id_devolucion": 3, "total_devuelto": 60000.00}	\N	postgres	2026-05-16 09:37:19.198413
55	venta	DELETE	{"fecha": "2026-05-13T15:20:17.42644", "total": 60000.00, "estado": "devuelta", "id_venta": 6, "id_cliente": 8, "id_usuario": 1, "medio_pago": "tarjeta_debito"}	\N	postgres	2026-05-16 09:37:19.198413
56	producto	DELETE	{"marca": "Isa Boutique", "codigo": "IB-005", "estado": "activo", "imagen": "img/falda.jpg", "nombre": "Falda casual", "precio": 60000.00, "cantidad": 3, "id_producto": 5, "id_categoria": 7, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:37:19.198413
57	devolucion	DELETE	{"fecha": "2026-05-13T16:12:30.999715", "estado": "aprobada", "motivo": "daño", "id_venta": 5, "id_cliente": 7, "id_devolucion": 2, "total_devuelto": 25000.00}	\N	postgres	2026-05-16 09:37:28.063265
58	venta	DELETE	{"fecha": "2026-05-13T15:00:57.648287", "total": 50000.00, "estado": "pagada", "id_venta": 5, "id_cliente": 7, "id_usuario": 1, "medio_pago": "transferencia"}	\N	postgres	2026-05-16 09:37:28.063265
59	producto	DELETE	{"marca": "Isa Boutique", "codigo": "IB-006", "estado": "activo", "imagen": "img/Zapatos.jpg", "nombre": "Accesorio dorado", "precio": 25000.00, "cantidad": 9, "id_producto": 6, "id_categoria": 8, "fecha_creacion": "2026-05-10T21:09:12.585654"}	\N	postgres	2026-05-16 09:37:28.063265
60	producto	INSERT	\N	{"marca": "ANWND", "codigo": "1234", "estado": "activo", "imagen": "img/productos/producto_6a08ff8367aa5.png", "nombre": "body", "precio": 75000.00, "cantidad": 6, "id_producto": 10, "id_categoria": 2, "fecha_creacion": "2026-05-16T18:36:35.429687"}	postgres	2026-05-16 18:36:35.429687
61	producto	DELETE	{"marca": "ANWND", "codigo": "1234", "estado": "activo", "imagen": "img/productos/producto_6a08ff8367aa5.png", "nombre": "body", "precio": 75000.00, "cantidad": 6, "id_producto": 10, "id_categoria": 2, "fecha_creacion": "2026-05-16T18:36:35.429687"}	\N	postgres	2026-05-16 18:41:37.632638
62	producto	INSERT	\N	{"marca": "ANWND", "codigo": "1234", "estado": "activo", "imagen": "img/productos/producto_6a0900e815c8d.png", "nombre": "body", "precio": 70000.00, "cantidad": 6, "id_producto": 11, "id_categoria": 2, "fecha_creacion": "2026-05-16T18:42:32.091981"}	postgres	2026-05-16 18:42:32.091981
63	cliente	INSERT	\N	{"correo": null, "nombre": "luisa", "telefono": "31124556", "direccion": null, "id_cliente": 9, "fecha_registro": "2026-05-16T18:55:45.528616"}	postgres	2026-05-16 18:55:45.528616
65	producto	UPDATE	{"marca": "ANWND", "codigo": "1234", "estado": "activo", "imagen": "img/productos/producto_6a0900e815c8d.png", "nombre": "body", "precio": 70000.00, "cantidad": 6, "id_producto": 11, "id_categoria": 2, "fecha_creacion": "2026-05-16T18:42:32.091981"}	{"marca": "ANWND", "codigo": "1234", "estado": "activo", "imagen": "img/productos/producto_6a0900e815c8d.png", "nombre": "body", "precio": 70000.00, "cantidad": 5, "id_producto": 11, "id_categoria": 2, "fecha_creacion": "2026-05-16T18:42:32.091981"}	postgres	2026-05-16 18:55:45.528616
66	producto	INSERT	\N	{"marca": "amwnd", "codigo": "1237", "estado": "activo", "imagen": "img/productos/producto_6a090db457955.png", "nombre": "body", "precio": 70000.00, "cantidad": 6, "id_producto": 12, "id_categoria": 2, "fecha_creacion": "2026-05-16T19:37:08.361596"}	postgres	2026-05-16 19:37:08.361596
\.


--
-- Data for Name: cambio_precio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cambio_precio (id_cambio_precio, id_producto, id_usuario, precio_anterior, precio_nuevo, detalle, fecha) FROM stdin;
\.


--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categoria (id_categoria, nombre, descripcion, estado, fecha_creacion) FROM stdin;
1	vestidos	Vestidos para ocasiones especiales	t	2026-05-10 21:09:12.585654
2	blusas	Blusas femeninas y modernas	t	2026-05-10 21:09:12.585654
3	conjuntos	Conjuntos completos	t	2026-05-10 21:09:12.585654
4	shorts	Shorts y bermudas	t	2026-05-10 21:09:12.585654
5	jeans	Jeans y pantalones	t	2026-05-10 21:09:12.585654
6	bodys	Bodys femeninos	t	2026-05-10 21:09:12.585654
7	faldas	Faldas para dama	t	2026-05-10 21:09:12.585654
8	accesorios	Accesorios de moda	t	2026-05-10 21:09:12.585654
\.


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cliente (id_cliente, nombre, telefono, correo, direccion, fecha_registro) FROM stdin;
1	María Pérez	3001234567	maria@correo.com	Cartagena	2026-05-10 21:09:12.585654
2	Laura Gómez	3019876543	laura@correo.com	Cartagena	2026-05-10 21:09:12.585654
3	Cliente Prueba	3025558899	cliente@correo.com	Cartagena	2026-05-10 21:09:12.585654
4	isa	12444	\N	\N	2026-05-13 01:12:35.543771
5	ela	24234	\N	\N	2026-05-13 01:18:36.263121
6	www	2334	\N	\N	2026-05-13 01:37:44.74802
7	esdeq	32r341	\N	\N	2026-05-13 15:00:57.648287
8	wqsq	1234	\N	\N	2026-05-13 15:20:17.42644
9	luisa	31124556	\N	\N	2026-05-16 18:55:45.528616
\.


--
-- Data for Name: compra_mercancia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.compra_mercancia (id_compra, id_proveedor, id_usuario, fecha, costo_envio, total_productos, total_compra, detalle, fecha_registro) FROM stdin;
\.


--
-- Data for Name: detalle_compra_mercancia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_compra_mercancia (id_detalle_compra, id_compra, id_producto, talla, cantidad, costo_unitario, subtotal) FROM stdin;
\.


--
-- Data for Name: detalle_devolucion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_devolucion (id_detalle_devolucion, id_devolucion, id_producto, cantidad, precio_unitario, subtotal_devuelto, talla, costo_unitario, subtotal_costo_devuelto) FROM stdin;
\.


--
-- Data for Name: detalle_venta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalle_venta (id_detalle_venta, id_venta, id_producto, cantidad, precio_unitario, subtotal, talla, costo_unitario, subtotal_costo) FROM stdin;
7	7	11	1	70000.00	70000.00	\N	0.00	0.00
\.


--
-- Data for Name: devolucion; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.devolucion (id_devolucion, id_venta, id_cliente, fecha, motivo, total_devuelto, estado) FROM stdin;
\.


--
-- Data for Name: gasto_negocio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gasto_negocio (id_gasto, id_usuario, tipo, concepto, valor, fecha, detalle, fecha_registro) FROM stdin;
\.


--
-- Data for Name: inversion_negocio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inversion_negocio (id_inversion, id_usuario, tipo, concepto, valor, fecha, detalle, fecha_registro) FROM stdin;
\.


--
-- Data for Name: movimiento_inventario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movimiento_inventario (id_movimiento, id_producto, id_usuario, tipo, cantidad, detalle, fecha) FROM stdin;
12	11	2	venta	1	Venta registrada y stock descontado automáticamente	2026-05-16 18:55:45.528616
\.


--
-- Data for Name: pago_trabajador; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pago_trabajador (id_pago_trabajador, id_trabajador, id_usuario, tipo_pago, valor, fecha, detalle, fecha_registro) FROM stdin;
\.


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.producto (id_producto, codigo, nombre, marca, id_categoria, precio, cantidad, estado, imagen, fecha_creacion, costo_unitario) FROM stdin;
11	1234	body	ANWND	2	70000.00	5	activo	img/productos/producto_6a0900e815c8d.png	2026-05-16 18:42:32.091981	0.00
12	1237	body	amwnd	2	70000.00	6	activo	img/productos/producto_6a090db457955.png	2026-05-16 19:37:08.361596	0.00
\.


--
-- Data for Name: producto_talla; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.producto_talla (id_producto_talla, id_producto, talla, cantidad, fecha_creacion) FROM stdin;
1	11	Unica	5	2026-05-16 19:02:36.958568
2	12	S	2	2026-05-16 19:37:08.361596
3	12	M	2	2026-05-16 19:37:08.361596
4	12	L	2	2026-05-16 19:37:08.361596
\.


--
-- Data for Name: proveedor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proveedor (id_proveedor, nombre, telefono, ciudad, producto_suministra, estado, fecha_registro) FROM stdin;
\.


--
-- Data for Name: trabajador; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trabajador (id_trabajador, nombre, documento, telefono, cargo, salario_base, estado, fecha_ingreso, fecha_registro) FROM stdin;
\.


--
-- Data for Name: usuario_sistema; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.usuario_sistema (id_usuario, nombre, correo, contrasena, rol, estado, fecha_creacion) FROM stdin;
2	Vendedora Principal	vendedora@isaboutique.com	$2y$10$E3k6Q4/e43fy3o.w6oUhMONgNXxBvgq/YJUAre3QlNHqFfUEFFnYm	vendedor	t	2026-05-10 21:09:12.585654
1	Administrador Isa Boutique	admin@isaboutique.com	$2y$10$vwGzrD7g72F0aiYPZmnIzeKP9a1vHhv1allaZhS1r5wF3kfYCN3GO	admin	t	2026-05-10 21:09:12.585654
\.


--
-- Data for Name: venta; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venta (id_venta, id_cliente, id_usuario, fecha, medio_pago, total, estado) FROM stdin;
7	9	2	2026-05-16 18:55:45.528616	transferencia	70000.00	pagada
\.


--
-- Name: auditoria_log_id_auditoria_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auditoria_log_id_auditoria_seq', 66, true);


--
-- Name: cambio_precio_id_cambio_precio_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cambio_precio_id_cambio_precio_seq', 2, true);


--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categoria_id_categoria_seq', 8, true);


--
-- Name: cliente_id_cliente_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cliente_id_cliente_seq', 9, true);


--
-- Name: compra_mercancia_id_compra_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.compra_mercancia_id_compra_seq', 1, false);


--
-- Name: detalle_compra_mercancia_id_detalle_compra_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_compra_mercancia_id_detalle_compra_seq', 1, false);


--
-- Name: detalle_devolucion_id_detalle_devolucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_devolucion_id_detalle_devolucion_seq', 3, true);


--
-- Name: detalle_venta_id_detalle_venta_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalle_venta_id_detalle_venta_seq', 7, true);


--
-- Name: devolucion_id_devolucion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devolucion_id_devolucion_seq', 3, true);


--
-- Name: gasto_negocio_id_gasto_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.gasto_negocio_id_gasto_seq', 1, false);


--
-- Name: inversion_negocio_id_inversion_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inversion_negocio_id_inversion_seq', 1, false);


--
-- Name: movimiento_inventario_id_movimiento_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.movimiento_inventario_id_movimiento_seq', 12, true);


--
-- Name: pago_trabajador_id_pago_trabajador_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pago_trabajador_id_pago_trabajador_seq', 1, false);


--
-- Name: producto_id_producto_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.producto_id_producto_seq', 12, true);


--
-- Name: producto_talla_id_producto_talla_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.producto_talla_id_producto_talla_seq', 4, true);


--
-- Name: proveedor_id_proveedor_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proveedor_id_proveedor_seq', 1, false);


--
-- Name: trabajador_id_trabajador_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trabajador_id_trabajador_seq', 1, false);


--
-- Name: usuario_sistema_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuario_sistema_id_usuario_seq', 2, true);


--
-- Name: venta_id_venta_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venta_id_venta_seq', 7, true);


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

\unrestrict PRKtSJqfnElTJlNcakHwj6D7CUfbP15Vq56AdSeMIUxItabBpJpkdDFnUjpDf75

