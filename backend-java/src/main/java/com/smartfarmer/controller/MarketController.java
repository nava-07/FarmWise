package com.smartfarmer.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/market")
public class MarketController {

    @GetMapping("/prices")
    public ResponseEntity<?> getPrices() {
        List<Map<String, Object>> prices = List.of(
            Map.of("id", 1, "crop", "Wheat", "price", "₹2,125/quintal", "trend", "+2.5%"),
            Map.of("id", 2, "crop", "Rice (Paddy)", "price", "₹2,183/quintal", "trend", "-1.2%"),
            Map.of("id", 3, "crop", "Sugarcane", "price", "₹315/quintal", "trend", "0.0%"),
            Map.of("id", 4, "crop", "Cotton", "price", "₹6,620/quintal", "trend", "+5.1%"),
            Map.of("id", 5, "crop", "Soybean", "price", "₹4,600/quintal", "trend", "-0.5%"),
            Map.of("id", 6, "crop", "Maize", "price", "₹2,090/quintal", "trend", "+1.1%"),
            Map.of("id", 7, "crop", "Bajra (Pearl Millet)", "price", "₹2,500/quintal", "trend", "+0.4%"),
            Map.of("id", 8, "crop", "Jowar (Sorghum)", "price", "₹3,180/quintal", "trend", "+3.2%"),
            Map.of("id", 9, "crop", "Tur (Arhar)", "price", "₹7,000/quintal", "trend", "-2.1%"),
            Map.of("id", 10, "crop", "Moong (Green Gram)", "price", "₹8,558/quintal", "trend", "+0.8%"),
            Map.of("id", 11, "crop", "Urad (Black Gram)", "price", "₹6,950/quintal", "trend", "-1.5%"),
            Map.of("id", 12, "crop", "Groundnut", "price", "₹6,377/quintal", "trend", "+4.2%"),
            Map.of("id", 13, "crop", "Sunflower Seed", "price", "₹6,760/quintal", "trend", "-3.0%"),
            Map.of("id", 14, "crop", "Mustard", "price", "₹5,450/quintal", "trend", "+1.7%"),
            Map.of("id", 15, "crop", "Barley", "price", "₹1,735/quintal", "trend", "0.0%"),
            Map.of("id", 16, "crop", "Gram (Chana)", "price", "₹5,335/quintal", "trend", "+2.2%"),
            Map.of("id", 17, "crop", "Lentil (Masur)", "price", "₹6,000/quintal", "trend", "-0.9%"),
            Map.of("id", 18, "crop", "Onion", "price", "₹1,200/quintal", "trend", "+8.5%"),
            Map.of("id", 19, "crop", "Potato", "price", "₹1,450/quintal", "trend", "-4.2%"),
            Map.of("id", 20, "crop", "Tomato", "price", "₹2,200/quintal", "trend", "+12.1%")
        );
        return ResponseEntity.ok(prices);
    }

    @GetMapping("/schemes")
    public ResponseEntity<?> getSchemes() {
        List<Map<String, Object>> schemes = List.of(
            Map.of("id", 1, "title", "PM Kisan Samman Nidhi",
                "description", "Financial benefit of ₹6,000 per year.",
                "eligibility", "Small and marginal farmers."),
            Map.of("id", 2, "title", "Pradhan Mantri Fasal Bima Yojana",
                "description", "Crop insurance scheme against natural calamities.",
                "eligibility", "All farmers growing notified crops."),
            Map.of("id", 3, "title", "Soil Health Card Scheme",
                "description", "Provides soil health cards to farmers with crop-wise recommendations.",
                "eligibility", "All farmers.")
        );
        return ResponseEntity.ok(schemes);
    }
}
