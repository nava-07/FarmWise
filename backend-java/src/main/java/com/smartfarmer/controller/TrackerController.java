package com.smartfarmer.controller;

import com.smartfarmer.service.GeminiService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/tracker")
public class TrackerController {

    private final GeminiService geminiService;
    private final ObjectMapper mapper = new ObjectMapper();

    public TrackerController(GeminiService geminiService) {
        this.geminiService = geminiService;
    }

    @PostMapping("/schedule")
    public ResponseEntity<?> generateSchedule(@RequestBody Map<String, String> body) {
        try {
            String crop = body.get("crop");
            String plantingDate = body.get("plantingDate");

            if (crop == null || plantingDate == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Crop and planting date are required"));
            }

            String prompt = "You are a Smart Farming AI. The user planted \"" + crop + "\" on " + plantingDate + ".\n" +
                "Generate a care schedule for the next 30 days. Provide exactly 3 upcoming events (e.g. watering, fertilizing, pest check).\n" +
                "Return ONLY a valid JSON array of objects with the following keys:\n" +
                "- \"title\": short title of the task\n" +
                "- \"date\": the exact date to perform the task (YYYY-MM-DD format, calculated from " + plantingDate + ")\n" +
                "- \"description\": a short instruction.\n\n" +
                "Do not include any markdown formatting or ```json block. Just the raw JSON array.";

            String result = geminiService.generateContent(prompt);
            // Clean markdown formatting
            String cleaned = result.replaceAll("```json", "").replaceAll("```", "").trim();
            Object schedule = mapper.readValue(cleaned, Object.class);
            return ResponseEntity.ok(schedule);
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to generate schedule"));
        }
    }
}
