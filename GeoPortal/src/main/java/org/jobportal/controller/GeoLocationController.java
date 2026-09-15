/*
package org.jobportal.controller;



import lombok.RequiredArgsConstructor;
import org.jobportal.dto.ApiDTO;
import org.jobportal.dto.EmployeeDistanceRequestDTO;
import org.jobportal.dto.GeofanceRequestDTO;
import org.jobportal.service.DutyMonitoringService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;


@Controller
@RequestMapping("/api/geoportal/employee-duty-monitoring")
@RequiredArgsConstructor
public class GeoLocationController {

    private final DutyMonitoringService employeeDutyMonitoringService;


    @PreAuthorize("hasRole('hr-portal')")
    @PostMapping("/geofance-config")
    public ResponseEntity<ApiDTO> geofanceConfig(
            @RequestBody GeofanceRequestDTO request,
            @AuthenticationPrincipal Jwt principal
    ) {
        ApiDTO response = employeeDutyMonitoringService.geofanceConfig(request , principal.getClaimAsString("preferred_username"));
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @GetMapping("/employees-geofance")
    public ResponseEntity<ApiDTO> employeesGeofance(
            @RequestParam(required = false) Long facultyId,
            @RequestParam(required = false) Long departmentId,
            @RequestParam(required = false) String employeeIds,
            @RequestParam(required = false) Boolean isAssigned,
            @RequestParam(required = false) Integer pageNumber,
            @RequestParam(required = false) Integer pageSize
    ) {
        ApiDTO response = employeeDutyMonitoringService.employeeGeofance(facultyId,departmentId,employeeIds,isAssigned,pageNumber,pageSize);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @GetMapping("/geofance-list")
    public ResponseEntity<ApiDTO> getGeofanceList(
    ) {
        ApiDTO response = employeeDutyMonitoringService.getGeofanceList();
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @GetMapping("/enroll-user")
    public ResponseEntity<ApiDTO> enrollUser(
            @RequestParam(required = false) String publicRsa,  // ✅ MADE OPTIONAL,
            @AuthenticationPrincipal Jwt principal
    ) {
        ApiDTO response = employeeDutyMonitoringService.enrollUser(principal.getClaimAsString("preferred_username"), publicRsa);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @PostMapping("/sync-employee-location")
    public ResponseEntity<ApiDTO> syncEmployeeLocation(
            @RequestBody EmployeeDistanceRequestDTO request,
            // RSA digital signature sent by Flutter
            @RequestHeader(value = "X-Signature", required = false) String signature,
            @AuthenticationPrincipal Jwt principal
    ) {
        String preferredUsername = principal.getClaimAsString("preferred_username");
        // Pass RSA signature to service.
        // Service will retrieve the employee's stored public key
        // and verify the signature before saving the location.
        ApiDTO response = employeeDutyMonitoringService.syncEmployeeLocation(request, signature, preferredUsername);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }



    @GetMapping("/my-location-graph")
    public ResponseEntity<ApiDTO> myLocationGraph(@AuthenticationPrincipal Jwt principal) {
        String preferredUsername = principal.getClaimAsString("preferred_username");
        ApiDTO response = employeeDutyMonitoringService.myLocationGraph(preferredUsername, LocalDate.now());
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


}
*/
