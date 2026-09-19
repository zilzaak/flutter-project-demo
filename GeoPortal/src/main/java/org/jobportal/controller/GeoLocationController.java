package org.jobportal.controller;

import lombok.RequiredArgsConstructor;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.jobportal.dto.ApiDTO;
import org.jobportal.dto.EmployeeDistanceRequestDTO;
import org.jobportal.dto.EnrollRequest;
import org.jobportal.service.DutyMonitoringService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;


@Controller
@RequestMapping("/api/geo/portal/geo-location")
@RequiredArgsConstructor
public class GeoLocationController {

    private final DutyMonitoringService employeeDutyMonitoringService;


    @PostMapping("/enroll-user")
    public ResponseEntity<ApiDTO> enrollUser(
            @RequestBody EnrollRequest request,
            @RequestHeader(value = "X-Signature") String signature,
            @AuthenticationPrincipal Jwt principal
    ) {
        ApiDTO response = employeeDutyMonitoringService.enrollUser(principal.getClaimAsString("preferred_username"), request.getPublicRsa(), request.getAccessToken(), signature);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }



/*
    @PostMapping("/sync-employee-location")
    public ResponseEntity<ApiDTO> syncEmployeeLocation(
            @RequestBody EmployeeDistanceRequestDTO request,
            @AuthenticationPrincipal Jwt principal,
            // RSA digital signature sent by Flutter
            @RequestHeader(value = "X-Signature") String signature
    ) {
        // Pass RSA signature to service.
        // Service will retrieve the employee's stored public key
        // and verify the signature before saving the location.
        ApiDTO response = employeeDutyMonitoringService.syncEmployeeLocation(request, signature, principal.getClaimAsString("preferred_username"));
        return new ResponseEntity<>(response, HttpStatus.OK);
    }
*/


    @PostMapping("/sync-employee-location")
    public ResponseEntity<ApiDTO> syncEmployeeLocation(
            @RequestBody List<EmployeeDistanceRequestDTO> request,
            @AuthenticationPrincipal Jwt principal
    ) {
        ApiDTO response = employeeDutyMonitoringService.syncEmployeeLocation(request,principal.getClaimAsString("preferred_username"));
        return new ResponseEntity<>(response, HttpStatus.OK);
      }


    @GetMapping("/my-location-graph")
    public ResponseEntity<ApiDTO> myLocationGraph(
            @AuthenticationPrincipal Jwt principal,
            @RequestParam String accessToken,
            @RequestHeader(value = "X-Signature", required = false) String signature
    ) {
        String employeeId = principal.getClaimAsString("preferred_username");
        ApiDTO response = employeeDutyMonitoringService.myLocationGraph(employeeId, accessToken, signature, LocalDate.now());
        return new ResponseEntity<>(response, HttpStatus.OK);
    }

}

