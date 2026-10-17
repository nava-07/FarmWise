package com.smartfarmer.controller;

import com.smartfarmer.service.GeminiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/ai")
public class AiController {

    private final GeminiService geminiService;

    public AiController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping("/chat")
    public ResponseEntity<?> chat(@RequestBody Map<String, String> body) {
        try {
            String message = body.get("message");
            if (message == null && body.containsKey("prompt")) {
                message = body.get("prompt");
            }
            if (message == null || message.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Message is required"));
            }

            String prompt = "You are an AI Farming Assistant for the Smart Farmer Guidance System. " +
                "A farmer asks: \"" + message + "\". " +
                "Provide a concise, helpful, and culturally appropriate response. Include advice on crops, fertilizers, irrigation, or pest control if relevant.";

            String reply = geminiService.generateContent(prompt);
            return ResponseEntity.ok(Map.of("reply", reply, "response", reply));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to process AI request"));
        }
    }
}
