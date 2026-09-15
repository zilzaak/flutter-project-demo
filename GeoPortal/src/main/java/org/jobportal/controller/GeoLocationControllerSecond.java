package org.jobportal.controller;



import lombok.RequiredArgsConstructor;
import org.jobportal.dto.ApiDTO;
import org.jobportal.dto.EmployeeDistanceRequestDTO;
import org.jobportal.dto.EnrollRequest;
import org.jobportal.dto.GeofanceRequestDTO;
import org.jobportal.service.DutyMonitoringService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;


@Controller
@RequestMapping("/api/geoportal/geo-location")
@RequiredArgsConstructor
public class GeoLocationControllerSecond {

    private final DutyMonitoringService employeeDutyMonitoringService;

/*
    @PostMapping("/geofance-config")
    public ResponseEntity<ApiDTO> geofanceConfig(
            @RequestBody GeofanceRequestDTO request
    ) {
        ApiDTO response = employeeDutyMonitoringService.geofanceConfig(request , request.getEmployeeIds());
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
    }*/


    @PostMapping("/enroll-user")
    public ResponseEntity<ApiDTO> enrollUser(
            @RequestBody EnrollRequest request,
            @RequestHeader(value = "X-Signature", required = false) String signature
    ) {
        ApiDTO response = employeeDutyMonitoringService.enrollUser(request.getEmployeeId(), request.getPublicRsa(), request.getAccessToken(), signature);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @PostMapping("/sync-employee-location")
    public ResponseEntity<ApiDTO> syncEmployeeLocation(
            @RequestBody EmployeeDistanceRequestDTO request,
            // RSA digital signature sent by Flutter
            @RequestHeader(value = "X-Signature", required = false) String signature
    ) {
        // Pass RSA signature to service.
        // Service will retrieve the employee's stored public key
        // and verify the signature before saving the location.
        ApiDTO response = employeeDutyMonitoringService.syncEmployeeLocation(request, signature, request.getEmployeeId());
        return new ResponseEntity<>(response, HttpStatus.OK);
    }



    @GetMapping("/my-location-graph")
    public ResponseEntity<ApiDTO> myLocationGraph(
            @RequestParam String employeeId,
            @RequestParam String accessToken,
            @RequestHeader(value = "X-Signature", required = false) String signature
    ) {
        ApiDTO response = employeeDutyMonitoringService.myLocationGraph(employeeId, accessToken, signature, LocalDate.now());
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


}
