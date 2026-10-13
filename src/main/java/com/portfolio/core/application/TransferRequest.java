package com.portfolio.core.application;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record TransferRequest(
    @NotNull(message = "El ID de la cuenta origen es obligatorio")
    Long sourceAccountId,

    @NotNull(message = "El ID de la cuenta destino es obligatorio")
    Long targetAccountId,

    @NotNull(message = "El importe es obligatorio")
    @DecimalMin(value = "0.01", message = "El importe mínimo debe ser 0.01")
    BigDecimal amount,

    @NotNull(message = "La divisa es obligatoria")
    @Size(min = 3, max = 3, message = "La divisa debe tener formato ISO de 3 caracteres (ej. EUR)")
    String currency,

    String description
) {}