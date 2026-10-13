package com.portfolio.core.infrastructure;

import java.time.OffsetDateTime;
import java.util.Map;

public record ErrorResponse(
    int status,
    String error,
    String message,
    int errorCode,
    OffsetDateTime timestamp,
    Map<String, String> details
) {
    public static ErrorResponse of(int status, String error, String message, int errorCode) {
        return new ErrorResponse(status, error, message, errorCode, OffsetDateTime.now(), null);
    }

    public static ErrorResponse of(int status, String error, String message, int errorCode, Map<String, String> details) {
        return new ErrorResponse(status, error, message, errorCode, OffsetDateTime.now(), details);
    }
}