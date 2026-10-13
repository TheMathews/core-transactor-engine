package com.portfolio.core.application;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record TransferResponse(
    Long transactionId,
    String transactionUuid,
    Long sourceAccountId,
    Long targetAccountId,
    BigDecimal amount,
    String currency,
    String status,
    OffsetDateTime timestamp
) {}