-- ============================================================================
-- CORE TRANSACTOR ENGINE - SCRIPT DDL INICIAL (01_ddl_tables.sql)
-- Motor: Oracle Database 19c / Free
-- Esquema: CORE_APP
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SECUENCIAS OPTIMIZADAS
-- Se define CACHE alto para minimizar bloqueos de diccionario en altas cargas
-- ----------------------------------------------------------------------------
CREATE SEQUENCE SEQ_ACCOUNTS
    START WITH 1000
    INCREMENT BY 1
    CACHE 50
    NOCYCLE;

CREATE SEQUENCE SEQ_TRANSACTIONS
    START WITH 1
    INCREMENT BY 1
    CACHE 1000
    NOCYCLE;

CREATE SEQUENCE SEQ_AUDIT_LOG
    START WITH 1
    INCREMENT BY 1
    CACHE 500
    NOCYCLE;

-- ----------------------------------------------------------------------------
-- 2. TABLA: ACCOUNTS (Cuentas y Balances)
-- Incluye campo VERSION para bloqueo optimista desde Java / Spring Data JPA
-- ----------------------------------------------------------------------------
CREATE TABLE ACCOUNTS (
    ACCOUNT_ID     NUMBER DEFAULT SEQ_ACCOUNTS.NEXTVAL NOT NULL,
    ACCOUNT_NUMBER VARCHAR2(34)                        NOT NULL,
    HOLDER_NAME    VARCHAR2(120)                       NOT NULL,
    BALANCE        NUMBER(18, 4) DEFAULT 0.0000        NOT NULL,
    CURRENCY       VARCHAR2(3)   DEFAULT 'EUR'         NOT NULL,
    STATUS         VARCHAR2(20)  DEFAULT 'ACTIVE'      NOT NULL,
    VERSION        NUMBER        DEFAULT 0             NOT NULL,
    CREATED_AT     TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    UPDATED_AT     TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_ACCOUNTS PRIMARY KEY (ACCOUNT_ID),
    CONSTRAINT UQ_ACCOUNTS_NUMBER UNIQUE (ACCOUNT_NUMBER),
    CONSTRAINT CHK_ACC_STATUS CHECK (STATUS IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    CONSTRAINT CHK_ACC_CURRENCY CHECK (CURRENCY IN ('EUR', 'USD', 'GBP')),
    CONSTRAINT CHK_ACC_BALANCE_NON_NEG CHECK (BALANCE >= 0)
);

-- ----------------------------------------------------------------------------
-- 3. TABLA: TRANSACTIONS (Registro Transaccional Masivo)
-- Particionada por rango de fecha mensual con Interval Partitioning
-- ----------------------------------------------------------------------------
CREATE TABLE TRANSACTIONS (
    TRANSACTION_ID    NUMBER DEFAULT SEQ_TRANSACTIONS.NEXTVAL NOT NULL,
    TRANSACTION_UUID  VARCHAR2(36)                            NOT NULL,
    SOURCE_ACCOUNT_ID NUMBER                                  NOT NULL,
    TARGET_ACCOUNT_ID NUMBER                                  NOT NULL,
    AMOUNT            NUMBER(18, 4)                           NOT NULL,
    CURRENCY          VARCHAR2(3)   DEFAULT 'EUR'             NOT NULL,
    TRANSACTION_TYPE  VARCHAR2(20)  DEFAULT 'TRANSFER'        NOT NULL,
    STATUS            VARCHAR2(20)  DEFAULT 'PENDING'         NOT NULL,
    DESCRIPTION       VARCHAR2(255),
    CREATED_AT        TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_TRANSACTIONS PRIMARY KEY (TRANSACTION_ID, CREATED_AT),
    CONSTRAINT FK_TX_SOURCE FOREIGN KEY (SOURCE_ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
    CONSTRAINT FK_TX_TARGET FOREIGN KEY (TARGET_ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
    CONSTRAINT CHK_TX_AMOUNT CHECK (AMOUNT > 0),
    CONSTRAINT CHK_TX_STATUS CHECK (STATUS IN ('PENDING', 'SETTLED', 'FAILED', 'REVERSED')),
    CONSTRAINT CHK_TX_TYPE CHECK (TRANSACTION_TYPE IN ('TRANSFER', 'PAYMENT', 'ADJUSTMENT')),
    CONSTRAINT CHK_TX_DISTINCT_ACCS CHECK (SOURCE_ACCOUNT_ID != TARGET_ACCOUNT_ID)
)
PARTITION BY RANGE (CREATED_AT)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION P_INITIAL VALUES LESS THAN (TIMESTAMP '2026-01-01 00:00:00 +00:00')
);

-- ----------------------------------------------------------------------------
-- 4. ÍNDICES ESTRATÉGICOS PARA CONSULTAS Y RENDIMIENTO
-- ----------------------------------------------------------------------------
-- Clave idempotente global para evitar procesamiento duplicado de peticiones
CREATE UNIQUE INDEX IDX_TX_UUID ON TRANSACTIONS (TRANSACTION_UUID);

-- Índices locales particionados para acelerar histórico de transacciones por cuenta
CREATE INDEX IDX_TX_SRC_DATE ON TRANSACTIONS (SOURCE_ACCOUNT_ID, CREATED_AT) LOCAL;
CREATE INDEX IDX_TX_TGT_DATE ON TRANSACTIONS (TARGET_ACCOUNT_ID, CREATED_AT) LOCAL;

-- ----------------------------------------------------------------------------
-- 5. TABLA: AUDIT_LOG (Trazabilidad y Auditoría Estricta)
-- Registro append-only de modificaciones de saldos y cambios de estado
-- ----------------------------------------------------------------------------
CREATE TABLE AUDIT_LOG (
    AUDIT_ID       NUMBER DEFAULT SEQ_AUDIT_LOG.NEXTVAL NOT NULL,
    ENTITY_NAME    VARCHAR2(50)                         NOT NULL,
    ENTITY_ID      NUMBER                               NOT NULL,
    OPERATION      VARCHAR2(10)                         NOT NULL,
    OLD_PAYLOAD    CLOB,
    NEW_PAYLOAD    CLOB,
    PERFORMED_BY   VARCHAR2(100) DEFAULT USER           NOT NULL,
    PERFORMED_AT   TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_AUDIT_LOG PRIMARY KEY (AUDIT_ID),
    CONSTRAINT CHK_AUDIT_OPERATION CHECK (OPERATION IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX IDX_AUDIT_ENTITY ON AUDIT_LOG (ENTITY_NAME, ENTITY_ID, PERFORMED_AT);

-- ----------------------------------------------------------------------------
-- 6. VISTAS ANALÍTICAS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_ACTIVE_ACCOUNT_BALANCES AS
SELECT 
    ACCOUNT_ID,
    ACCOUNT_NUMBER,
    HOLDER_NAME,
    BALANCE,
    CURRENCY,
    UPDATED_AT
FROM ACCOUNTS
WHERE STATUS = 'ACTIVE';