package org.jobportal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;


@SpringBootApplication
public class GeoPortalApplication {

    public static void main(String[] args) {
        SpringApplication.run(GeoPortalApplication.class, args);
    }
    @Bean
    CommandLineRunner runner() {
        return args -> {
            System.out.println("✅ Geo Portal application started successfully");
        };
    }
}