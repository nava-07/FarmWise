package com.smartfarmer.controller;

import com.smartfarmer.service.GeminiService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/recommendations")
public class RecommendationController {

    private final GeminiService geminiService;

    public RecommendationController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping("/crop")
    public ResponseEntity<?> cropRecommendation(@RequestBody Map<String, String> body) {
        try {
            String soilType = body.get("soilType");
            String location = body.get("location");
            String season = body.getOrDefault("season", "Not specified");
            String waterAvailability = body.getOrDefault("waterAvailability", "Not specified");

            if (soilType == null || location == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Soil type and location are required"));
            }

            String prompt = "You are an expert agronomist AI for the Smart Farmer Guidance System.\n" +
                "Given the following conditions:\n" +
                "- Soil Type: " + soilType + "\n" +
                "- Location: " + location + "\n" +
                "- Season: " + season + "\n" +
                "- Water Availability: " + waterAvailability + "\n\n" +
                "Recommend the top 3 best crops to grow. For each crop, provide a brief reason why it's suitable. Keep it structured and concise.";

            String result = geminiService.generateContent(prompt);
            return ResponseEntity.ok(Map.of("recommendation", result));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to generate recommendation"));
        }
    }

    @PostMapping("/fertilizer")
    public ResponseEntity<?> fertilizerRecommendation(@RequestBody Map<String, String> body) {
        try {
            String crop = body.get("crop");
            String soilCondition = body.getOrDefault("soilCondition", "Average");

            if (crop == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Crop is required"));
            }

            String prompt = "You are an expert agronomist AI.\n" +
                "Given the crop \"" + crop + "\" and soil condition \"" + soilCondition + "\", " +
                "recommend the best fertilizers to use. Include the type of fertilizer, dosage advice, and application schedule.";

            String result = geminiService.generateContent(prompt);
            return ResponseEntity.ok(Map.of("recommendation", result));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to generate recommendation"));
        }
    }
}
