-- ============================================================================
-- CORE TRANSACTOR ENGINE - DATOS SEMILLA (03_seed_data.sql)
-- Carga de cuentas base y generación de transacciones multi-partición
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CUENTAS DETERMINISTAS PARA TESTING Y CASOS DE USO
-- ----------------------------------------------------------------------------
-- Cuenta Maestra / Tesorería (EUR)
INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1000, 'ES9121000418450200051000', 'Treasury Liquidity Pool', 1000000.0000, 'EUR', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '180' DAY, SYSTIMESTAMP);

-- Clientes activos operativos (EUR)
INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1001, 'ES9121000418450200051001', 'Acme Logistics S.L.', 45000.5000, 'EUR', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '120' DAY, SYSTIMESTAMP);

INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1002, 'ES9121000418450200051002', 'Novatech Solutions S.A.', 18250.7500, 'EUR', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '90' DAY, SYSTIMESTAMP);

INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1003, 'ES9121000418450200051003', 'Elena Gomez Serrano', 2400.0000, 'EUR', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '60' DAY, SYSTIMESTAMP);

-- Cuenta sin fondos (para tests de C_ERR_INSUFFICIENT_FUNDS)
INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1004, 'ES9121000418450200051004', 'Zero Balance Test Ltd', 0.0000, 'EUR', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '30' DAY, SYSTIMESTAMP);

-- Cuenta suspendida (para tests de C_ERR_ACCOUNT_INACTIVE)
INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1005, 'ES9121000418450200051005', 'Suspended Entity Corp', 15000.0000, 'EUR', 'SUSPENDED', 0, SYSTIMESTAMP - INTERVAL '45' DAY, SYSTIMESTAMP);

-- Cuenta en USD (para tests de C_ERR_CURRENCY_MISMATCH)
INSERT INTO ACCOUNTS (ACCOUNT_ID, ACCOUNT_NUMBER, HOLDER_NAME, BALANCE, CURRENCY, STATUS, VERSION, CREATED_AT, UPDATED_AT)
VALUES (1006, 'US1234567890123456789012', 'Global Ventures US LLC', 80000.0000, 'USD', 'ACTIVE', 0, SYSTIMESTAMP - INTERVAL '30' DAY, SYSTIMESTAMP);

-- Sincronizar secuencia SEQ_ACCOUNTS con los IDs fijos insertados
ALTER SEQUENCE SEQ_ACCOUNTS RESTART WITH 1010;

-- ----------------------------------------------------------------------------
-- 2. GENERACIÓN DE HISTÓRICO TRANSACCIONAL EN DISTINTAS PARTICIONES
-- Reparte movimientos en los últimos 6 meses para poblar particiones físicas
-- ----------------------------------------------------------------------------
DECLARE
    v_random_amount NUMBER(18, 4);
    v_target_acc    NUMBER;
    v_tx_date       TIMESTAMP WITH TIME ZONE;
BEGIN
    FOR i IN 1..500 LOOP
        -- Alternar cuentas destino entre 1001, 1002 y 1003
        v_target_acc := CASE MOD(i, 3)
                            WHEN 0 THEN 1001
                            WHEN 1 THEN 1002
                            ELSE 1003
                        END;

        -- Importe simulado entre 10 y 500 EUR
        v_random_amount := ROUND(DBMS_RANDOM.VALUE(10, 500), 2);

        -- Distribuir la fecha en un rango de 180 días hacia atrás
        v_tx_date := SYSTIMESTAMP - NUMTODSINTERVAL(MOD(i * 7, 180), 'DAY');

        INSERT INTO TRANSACTIONS (
            TRANSACTION_UUID,
            SOURCE_ACCOUNT_ID,
            TARGET_ACCOUNT_ID,
            AMOUNT,
            CURRENCY,
            TRANSACTION_TYPE,
            STATUS,
            DESCRIPTION,
            CREATED_AT
        ) VALUES (
            LOWER(REGEXP_REPLACE(RAWTOHEX(SYS_GUID()), '([A-F0-9]{8})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{12})', '\1-\2-\3-\4-\5')),
            1000,
            v_target_acc,
            v_random_amount,
            'EUR',
            'TRANSFER',
            'SETTLED',
            'Batch seed transaction #' || i,
            v_tx_date
        );
    END LOOP;

    COMMIT;
END;
/