package com.smartfarmer.controller;

import com.smartfarmer.model.User;
import com.smartfarmer.service.JwtService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final JwtService jwtService;
    private final List<User> users = new ArrayList<>();

    public AuthController(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody Map<String, String> body) {
        try {
            String name = body.get("name");
            String email = body.get("email");
            String password = body.get("password");
            String farmLocation = body.getOrDefault("farmLocation", "");
            String farmSize = body.getOrDefault("farmSize", "");

            boolean exists = users.stream().anyMatch(u -> u.getEmail().equals(email));
            if (exists) {
                return ResponseEntity.badRequest().body(Map.of("message", "User already exists"));
            }

            User user = new User(
                String.valueOf(System.currentTimeMillis()),
                name, email, password, farmLocation, farmSize
            );
            users.add(user);

            String token = jwtService.generateToken(user.getId());
            return ResponseEntity.ok(Map.of("token", token));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "Server Error"));
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) {
        try {
            String email = body.get("email");
            String password = body.get("password");

            User user = users.stream()
                .filter(u -> u.getEmail().equals(email))
                .findFirst().orElse(null);

            if (user == null) {
                return ResponseEntity.badRequest().body(Map.of("message", "Invalid Credentials"));
            }
            if (!password.equals(user.getPassword())) {
                return ResponseEntity.badRequest().body(Map.of("message", "Invalid Credentials"));
            }

            String token = jwtService.generateToken(user.getId());
            return ResponseEntity.ok(Map.of("token", token));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "Server Error"));
        }
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, String> body) {
        try {
            String email = body.get("email");
            boolean exists = users.stream().anyMatch(u -> u.getEmail().equals(email));
            if (!exists) {
                return ResponseEntity.badRequest().body(Map.of("message", "No account found with that email address"));
            }
            return ResponseEntity.ok(Map.of("message", "Password reset instructions have been sent to your email address."));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "Server Error"));
        }
    }
}
