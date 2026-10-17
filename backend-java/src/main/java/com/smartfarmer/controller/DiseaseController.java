package com.smartfarmer.controller;

import com.smartfarmer.service.GeminiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/disease")
public class DiseaseController {

    private final GeminiService geminiService;

    public DiseaseController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping("/detect")
    public ResponseEntity<?> detect(@RequestBody Map<String, String> body) {
        try {
            String imageBase64 = body.get("imageBase64");
            String mimeType = body.getOrDefault("mimeType", "image/jpeg");

            if (imageBase64 == null || imageBase64.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Image data is required"));
            }

            String prompt = "You are an expert plant pathologist AI for the Smart Farmer Guidance System. " +
                "Analyze this crop image. Identify any visible diseases or pests. " +
                "Provide a clear diagnosis, a severity level, and specific treatment/prevention recommendations.";

            String result = geminiService.generateContentWithImage(prompt, imageBase64, mimeType);
            return ResponseEntity.ok(Map.of("analysis", result));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to analyze image"));
        }
    }
}
