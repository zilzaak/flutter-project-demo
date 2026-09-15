package org.jobportal.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;

import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {
    /**
     * Custom JwtDecoder that verifies the token SIGNATURE using Keycloak's public keys
     * but intentionally SKIPS the expiration ('exp') claim validation.
     *
     * ⚠️  Security Note: This means expired tokens will still be accepted by the backend.
     *     Use this only in controlled environments where long-lived sessions are required.
     */
    @Bean
    public JwtDecoder jwtDecoder() {
        // Keycloak JWK Set URI — used to fetch public keys for signature verification
        String jwkSetUri = "https://auth0.diu.edu.bd/realms/demo/protocol/openid-connect/certs";
        NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri).jwsAlgorithm(SignatureAlgorithm.RS256).build();
        //    Use an EMPTY validator list — this disables ALL claim validations,
        //    including 'exp' (expiration), 'nbf' (not before), and 'iss' (issuer).
        //    The signature is still verified via the JWK Set above.
        jwtDecoder.setJwtValidator(JwtValidators.createDefault());
        // ✅ Override with NO-OP validator to skip expiration entirely
        jwtDecoder.setJwtValidator(token -> org.springframework.security.oauth2.core.OAuth2TokenValidatorResult.success());
        return jwtDecoder;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity httpSecurity) throws Exception {
        httpSecurity
.cors(cors -> cors.configurationSource(request -> {

/*                    CorsConfiguration config = new CorsConfiguration();
                    config.setAllowCredentials(true);
                    config.setAllowedOrigins(
                            List.of(
                                    "http://192.168.90.9:4200",
                                    "http://192.168.90.9:65487",
                                    "http://192.168.90.9:4300",
                                    "http://192.168.155.223:7008",
                                    "https://hrportal.diu.edu.bd"
                            )
                    );
                    config.setAllowedHeaders(List.of("*"));
                    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                    return config;*/


                    CorsConfiguration config = new CorsConfiguration();
                    config.setAllowCredentials(true);
                    // ✅ ALLOW ALL ORIGINS (Development Only!)
                    config.setAllowedOriginPatterns(List.of("*"));
                    // ✅ ALLOW ALL HEADERS
                    config.setAllowedHeaders(List.of("*"));
                    // ✅ ALLOW ALL HTTP METHODS
                    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
                    // ✅ ALLOW EXPOSED HEADERS (optional)
                    config.setExposedHeaders(List.of("Authorization", "Content-Disposition"));
                    return config;
                }))
                .csrf(csrf -> csrf.disable())  // disable CSRF for REST APIs
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers("/api/geoportal/**").hasAnyRole("ess-portal","hr-portal")
                        .anyRequest().authenticated()
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .jwt(jwt -> jwt
                                // ✅ Wire in our custom JwtDecoder that skips expiration validation
                                .decoder(jwtDecoder())
                                .jwtAuthenticationConverter(jwtAuthenticationConverter())
                        )
                );

        return httpSecurity.build();
    }

    private Converter<Jwt, ? extends AbstractAuthenticationToken> jwtAuthenticationConverter() {
        JwtAuthenticationConverter jwtAuthenticationConverter = new JwtAuthenticationConverter();
        jwtAuthenticationConverter.setJwtGrantedAuthoritiesConverter(new KeycloakRealmRoleConverter());
        return jwtAuthenticationConverter;
    }

    private static class KeycloakRealmRoleConverter implements Converter<Jwt, Collection<GrantedAuthority>> {

        @Override
        public Collection<GrantedAuthority> convert(Jwt jwt) {
            Map<String, List<String>> realmAccess = (Map<String, List<String>>) jwt.getClaims().get("realm_access");
            List<String> roles = realmAccess != null ? realmAccess.getOrDefault("roles", List.of()) : List.of();
            return roles.stream()
                    .map(roleName -> "ROLE_" + roleName)
                    .map(SimpleGrantedAuthority::new)
                    .collect(Collectors.toList());
        }
    }
}

