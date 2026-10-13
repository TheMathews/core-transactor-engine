package com.portfolio.core.infrastructure;

import com.portfolio.core.application.TransferRequest;
import com.portfolio.core.application.TransferResponse;
import com.portfolio.core.application.TransferService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/transfers")
public class TransactionController {

    private final TransferService transferService;

    public TransactionController(TransferService transferService) {
        this.transferService = transferService;
    }

    @PostMapping
    public ResponseEntity<TransferResponse> createTransfer(@Valid @RequestBody TransferRequest request) {
        TransferResponse response = transferService.processTransfer(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}