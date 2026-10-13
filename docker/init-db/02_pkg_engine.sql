-- ============================================================================
-- CORE TRANSACTOR ENGINE - LÓGICA PL/SQL (02_pkg_engine.sql)
-- Paquete transaccional y triggers de auditoría
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ESPECIFICACIÓN DEL PAQUETE (PACKAGE SPECIFICATION)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_TRANSACTION_ENGINE AS

    -- Códigos de error de aplicación (-20000 a -20999)
    C_ERR_INSUFFICIENT_FUNDS CONSTANT NUMBER := -20001;
    C_ERR_ACCOUNT_INACTIVE   CONSTANT NUMBER := -20002;
    C_ERR_ACCOUNT_NOT_FOUND  CONSTANT NUMBER := -20003;
    C_ERR_CURRENCY_MISMATCH  CONSTANT NUMBER := -20004;

    -- Procedimiento principal para procesar transferencias atómicas
    PROCEDURE PROCESS_TRANSFER(
        p_uuid              IN  VARCHAR2,
        p_source_acc_id     IN  NUMBER,
        p_target_acc_id     IN  NUMBER,
        p_amount            IN  NUMBER,
        p_currency          IN  VARCHAR2,
        p_description       IN  VARCHAR2,
        o_tx_id             OUT NUMBER
    );

    -- Función auxiliar de consulta de balance consolidado
    FUNCTION GET_ACCOUNT_BALANCE(
        p_account_id IN NUMBER
    ) RETURN NUMBER;

END PKG_TRANSACTION_ENGINE;
/

-- ----------------------------------------------------------------------------
-- 2. CUERPO DEL PAQUETE (PACKAGE BODY)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PKG_TRANSACTION_ENGINE AS

    PROCEDURE PROCESS_TRANSFER(
        p_uuid              IN  VARCHAR2,
        p_source_acc_id     IN  NUMBER,
        p_target_acc_id     IN  NUMBER,
        p_amount            IN  NUMBER,
        p_currency          IN  VARCHAR2,
        p_description       IN  VARCHAR2,
        o_tx_id             OUT NUMBER
    ) IS
        v_first_acc_id   NUMBER;
        v_second_acc_id  NUMBER;

        v_src_balance    ACCOUNTS.BALANCE%TYPE;
        v_src_status     ACCOUNTS.STATUS%TYPE;
        v_src_currency   ACCOUNTS.CURRENCY%TYPE;

        v_tgt_balance    ACCOUNTS.BALANCE%TYPE;
        v_tgt_status     ACCOUNTS.STATUS%TYPE;
        v_tgt_currency   ACCOUNTS.CURRENCY%TYPE;

        v_tx_id          NUMBER;
    BEGIN
        SAVEPOINT sp_transfer_start;

        -- 1. Ordenar IDs de cuentas para prevenir Deadlocks en ejecuciones concurrentes
        IF p_source_acc_id < p_target_acc_id THEN
            v_first_acc_id  := p_source_acc_id;
            v_second_acc_id := p_target_acc_id;
        ELSE
            v_first_acc_id  := p_target_acc_id;
            v_second_acc_id := p_source_acc_id;
        END IF;

        -- 2. Bloqueo pesimista ordenado de ambas cuentas
        BEGIN
            SELECT BALANCE, STATUS, CURRENCY
              INTO v_src_balance, v_src_status, v_src_currency
              FROM ACCOUNTS
             WHERE ACCOUNT_ID = p_source_acc_id
               FOR UPDATE WAIT 5;

            SELECT BALANCE, STATUS, CURRENCY
              INTO v_tgt_balance, v_tgt_status, v_tgt_currency
              FROM ACCOUNTS
             WHERE ACCOUNT_ID = p_target_acc_id
               FOR UPDATE WAIT 5;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(C_ERR_ACCOUNT_NOT_FOUND, 'Una o ambas cuentas no existen en el sistema.');
        END;

        -- 3. Validaciones de regla de negocio
        IF v_src_status != 'ACTIVE' OR v_tgt_status != 'ACTIVE' THEN
            RAISE_APPLICATION_ERROR(C_ERR_ACCOUNT_INACTIVE, 'Operación denegada: Una de las cuentas no se encuentra activa.');
        END IF;

        IF v_src_currency != p_currency OR v_tgt_currency != p_currency THEN
            RAISE_APPLICATION_ERROR(C_ERR_CURRENCY_MISMATCH, 'La divisa de la transferencia no coincide con las cuentas involucradas.');
        END IF;

        IF v_src_balance < p_amount THEN
            RAISE_APPLICATION_ERROR(C_ERR_INSUFFICIENT_FUNDS, 'Fondos insuficientes en la cuenta origen.');
        END IF;

        -- 4. Actualización atómica de saldos y versiones
        UPDATE ACCOUNTS
           SET BALANCE    = BALANCE - p_amount,
               VERSION    = VERSION + 1,
               UPDATED_AT = SYSTIMESTAMP
         WHERE ACCOUNT_ID = p_source_acc_id;

        UPDATE ACCOUNTS
           SET BALANCE    = BALANCE + p_amount,
               VERSION    = VERSION + 1,
               UPDATED_AT = SYSTIMESTAMP
         WHERE ACCOUNT_ID = p_target_acc_id;

        -- 5. Registro transaccional auditado
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
            p_uuid,
            p_source_acc_id,
            p_target_acc_id,
            p_amount,
            p_currency,
            'TRANSFER',
            'SETTLED',
            p_description,
            SYSTIMESTAMP
        ) RETURNING TRANSACTION_ID INTO v_tx_id;

        o_tx_id := v_tx_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_transfer_start;
            RAISE;
    END PROCESS_TRANSFER;

    FUNCTION GET_ACCOUNT_BALANCE(
        p_account_id IN NUMBER
    ) RETURN NUMBER IS
        v_balance ACCOUNTS.BALANCE%TYPE;
    BEGIN
        SELECT BALANCE
          INTO v_balance
          FROM ACCOUNTS
         WHERE ACCOUNT_ID = p_account_id;

        RETURN v_balance;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END GET_ACCOUNT_BALANCE;

END PKG_TRANSACTION_ENGINE;
/

-- ----------------------------------------------------------------------------
-- 3. TRIGGER DE AUDITORÍA AUTOMÁTICA EN ACCOUNTS
-- Captura mutaciones de balance y estado en formato JSON
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_ACCOUNTS_AUDIT
AFTER UPDATE OR DELETE ON ACCOUNTS
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
BEGIN
    IF UPDATING THEN
        v_operation := 'UPDATE';
    ELSIF DELETING THEN
        v_operation := 'DELETE';
    END IF;

    INSERT INTO AUDIT_LOG (
        ENTITY_NAME,
        ENTITY_ID,
        OPERATION,
        OLD_PAYLOAD,
        NEW_PAYLOAD,
        PERFORMED_BY,
        PERFORMED_AT
    ) VALUES (
        'ACCOUNTS',
        :OLD.ACCOUNT_ID,
        v_operation,
        '{"balance":' || :OLD.BALANCE || ', "status":"' || :OLD.STATUS || '", "version":' || :OLD.VERSION || '}',
        CASE WHEN UPDATING THEN '{"balance":' || :NEW.BALANCE || ', "status":"' || :NEW.STATUS || '", "version":' || :NEW.VERSION || '}' ELSE NULL END,
        USER,
        SYSTIMESTAMP
    );
END;
/