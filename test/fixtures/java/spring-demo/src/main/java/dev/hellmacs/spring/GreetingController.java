package dev.hellmacs.spring;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GreetingController {
    @Value("${spring.application.name}")
    private String application;

    @GetMapping("/hello")
    public String hello(@RequestParam(defaultValue = "Hellmacs") String name) {
        String greeting = "Hello, " + name + ", from " + application;
        return greeting;
    }
}
