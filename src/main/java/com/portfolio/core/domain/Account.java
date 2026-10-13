package com.portfolio.core.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "ACCOUNTS")
@Getter
@Setter
@NoArgsConstructor
public class Account {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ACCOUNT_ID")
    private Long id;

    @Column(name = "ACCOUNT_NUMBER", nullable = false, unique = true, length = 34)
    private String accountNumber;

    @Column(name = "HOLDER_NAME", nullable = false, length = 120)
    private String holderName;

    @Column(name = "BALANCE", nullable = false, precision = 18, scale = 4)
    private BigDecimal balance;

    @Column(name = "CURRENCY", nullable = false, length = 3)
    private String currency;

    @Column(name = "STATUS", nullable = false, length = 20)
    private String status;

    @Version
    @Column(name = "VERSION", nullable = false)
    private Long version;

    @Column(name = "CREATED_AT", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "UPDATED_AT", nullable = false)
    private OffsetDateTime updatedAt;
}