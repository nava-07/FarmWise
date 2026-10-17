package com.smartfarmer.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/weather")
public class WeatherController {

    private final OkHttpClient client = new OkHttpClient();
    private final ObjectMapper mapper = new ObjectMapper();

    @GetMapping
    public ResponseEntity<?> getWeather(@RequestParam String lat, @RequestParam String lon) {
        try {
            String url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat +
                "&longitude=" + lon +
                "&current_weather=true&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,windspeed_10m_max&hourly=precipitation,precipitation_probability&timezone=auto";

            Request request = new Request.Builder().url(url).get().build();

            try (Response response = client.newCall(request).execute()) {
                String body = response.body().string();
                JsonNode data = mapper.readTree(body);
                return ResponseEntity.ok(data);
            }
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", "Failed to fetch weather data"));
        }
    }
}
