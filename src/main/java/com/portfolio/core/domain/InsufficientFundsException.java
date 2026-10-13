package com.portfolio.core.domain;

public class InsufficientFundsException extends CoreEngineException {
    public InsufficientFundsException(String message) {
        super(20001, message);
    }
}