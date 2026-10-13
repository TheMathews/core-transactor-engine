package com.portfolio.core.infrastructure;

import com.portfolio.core.domain.CoreEngineException;
import com.portfolio.core.domain.InsufficientFundsException;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.SqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.sql.Types;

@Component
public class OracleTransactionAdapter {

    private final SimpleJdbcCall processTransferCall;

    public OracleTransactionAdapter(JdbcTemplate jdbcTemplate) {
        this.processTransferCall = new SimpleJdbcCall(jdbcTemplate)
                .withCatalogName("PKG_TRANSACTION_ENGINE")
                .withProcedureName("PROCESS_TRANSFER")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new org.springframework.jdbc.core.SqlParameter("p_uuid", Types.VARCHAR),
                        new org.springframework.jdbc.core.SqlParameter("p_source_acc_id", Types.NUMERIC),
                        new org.springframework.jdbc.core.SqlParameter("p_target_acc_id", Types.NUMERIC),
                        new org.springframework.jdbc.core.SqlParameter("p_amount", Types.NUMERIC),
                        new org.springframework.jdbc.core.SqlParameter("p_currency", Types.VARCHAR),
                        new org.springframework.jdbc.core.SqlParameter("p_description", Types.VARCHAR),
                        new org.springframework.jdbc.core.SqlOutParameter("o_tx_id", Types.NUMERIC)
                );
    }

    public Long executeTransfer(String uuid, Long sourceId, Long targetId, BigDecimal amount, String currency, String description) {
        SqlParameterSource inParams = new MapSqlParameterSource()
                .addValue("p_uuid", uuid)
                .addValue("p_source_acc_id", sourceId)
                .addValue("p_target_acc_id", targetId)
                .addValue("p_amount", amount)
                .addValue("p_currency", currency)
                .addValue("p_description", description);

        try {
            var out = processTransferCall.execute(inParams);
            Number generatedId = (Number) out.get("o_tx_id");
            return generatedId != null ? generatedId.longValue() : null;

        } catch (DataAccessException ex) {
            handleOracleException(ex);
            throw ex;
        }
    }

    private void handleOracleException(DataAccessException ex) {
        Throwable root = ex.getRootCause();
        if (root instanceof SQLException sqlEx) {
            int errorCode = sqlEx.getErrorCode(); // Oracle devuelve valores positivos para ORA-2000X
            String message = sqlEx.getMessage();

            switch (errorCode) {
                case 20001 -> throw new InsufficientFundsException("Fondos insuficientes en la cuenta origen.");
                case 20002 -> throw new CoreEngineException(20002, "Una o ambas cuentas no están activas.");
                case 20003 -> throw new CoreEngineException(20003, "Una o ambas cuentas no existen.");
                case 20004 -> throw new CoreEngineException(20004, "Discrepancia en la divisa de la transferencia.");
                default -> throw new CoreEngineException(errorCode, "Error del motor transaccional Oracle: " + message);
            }
        }
    }
}