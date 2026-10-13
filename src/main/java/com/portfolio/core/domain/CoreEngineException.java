package com.portfolio.core.domain;

public class CoreEngineException extends RuntimeException {

    private final int errorCode;

    public CoreEngineException(int errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
    }

    public int getErrorCode() {
        return errorCode;
    }
}