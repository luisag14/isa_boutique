-- No reconstruye datos historicos con datos actuales.
BEGIN;
ALTER TABLE factura ADD COLUMN IF NOT EXISTS datos_emision JSONB;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
        WHERE conrelid='factura'::regclass AND conname='factura_datos_emision_objeto') THEN
        ALTER TABLE factura ADD CONSTRAINT factura_datos_emision_objeto
            CHECK(datos_emision IS NULL OR jsonb_typeof(datos_emision)='object');
    END IF;
END $$;
COMMIT;
