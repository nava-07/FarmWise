package com.smartfarmer.controller;

import com.smartfarmer.model.Transaction;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.*;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
@RequestMapping("/api/finance")
public class FinanceController {

    private final List<Transaction> transactions = new CopyOnWriteArrayList<>();

    @GetMapping
    public ResponseEntity<?> getAll() {
        return ResponseEntity.ok(transactions);
    }

    @PostMapping
    public ResponseEntity<?> add(@RequestBody Map<String, Object> body) {
        String type = (String) body.get("type");
        Object amountObj = body.get("amount");
        String category = (String) body.get("category");

        if (type == null || amountObj == null || category == null) {
            return ResponseEntity.badRequest().body(Map.of("message", "Please provide type, amount, and category"));
        }

        double amount = amountObj instanceof Number ? ((Number) amountObj).doubleValue() : Double.parseDouble(amountObj.toString());
        String date = body.containsKey("date") ? (String) body.get("date") : LocalDate.now().toString();
        String description = body.containsKey("description") ? (String) body.get("description") : "";
        String linkedId = body.containsKey("linkedId") ? (String) body.get("linkedId") : null;

        Transaction t = new Transaction(String.valueOf(System.currentTimeMillis()), type, amount, category, date, description, linkedId);
        transactions.add(t);
        return ResponseEntity.status(201).body(t);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable String id) {
        boolean removed = transactions.removeIf(t -> t.getId().equals(id));
        if (!removed) {
            return ResponseEntity.status(404).body(Map.of("message", "Transaction not found"));
        }
        return ResponseEntity.ok(Map.of("message", "Transaction deleted"));
    }

    @GetMapping("/summary")
    public ResponseEntity<?> summary() {
        double totalIncome = transactions.stream()
            .filter(t -> "income".equals(t.getType()))
            .mapToDouble(Transaction::getAmount).sum();
        double totalExpense = transactions.stream()
            .filter(t -> "expense".equals(t.getType()))
            .mapToDouble(Transaction::getAmount).sum();

        return ResponseEntity.ok(Map.of(
            "totalIncome", totalIncome,
            "totalExpense", totalExpense,
            "profit", totalIncome - totalExpense
        ));
    }
}
