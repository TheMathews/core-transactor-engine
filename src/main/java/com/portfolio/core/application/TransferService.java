package com.portfolio.core.application;

import com.portfolio.core.infrastructure.OracleTransactionAdapter;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
public class TransferService {

    private final OracleTransactionAdapter oracleTransactionAdapter;

    public TransferService(OracleTransactionAdapter oracleTransactionAdapter) {
        this.oracleTransactionAdapter = oracleTransactionAdapter;
    }

    public TransferResponse processTransfer(TransferRequest request) {
        String transactionUuid = UUID.randomUUID().toString();

        Long txId = oracleTransactionAdapter.executeTransfer(
                transactionUuid,
                request.sourceAccountId(),
                request.targetAccountId(),
                request.amount(),
                request.currency(),
                request.description()
        );

        return new TransferResponse(
                txId,
                transactionUuid,
                request.sourceAccountId(),
                request.targetAccountId(),
                request.amount(),
                request.currency(),
                "SETTLED",
                OffsetDateTime.now()
        );
    }
}