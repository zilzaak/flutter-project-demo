
package bd.edu.diu.hressportal.controllers.dutyMonitoring;

import bd.edu.diu.derpcore.dto.ApiDTO;
import bd.edu.diu.derpcore.dto.dutyMonitoring.EmployeeDistanceRequestDTO;
import bd.edu.diu.derpcore.dto.dutyMonitoring.GeofanceRequestDTO;
import bd.edu.diu.derpemployeeattendanceleaveservice.services.DutyMonitoringService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@Slf4j
@RestController
@RequestMapping("/api/ess/portal/employee-duty-monitoring")
@Tag(name = "Employee Duty Monitoring")
@RequiredArgsConstructor
public class EmployeeDutyMonitoringController {

    private final DutyMonitoringService employeeDutyMonitoringService;

    @Operation(summary = "Configure office location")
    @PreAuthorize("hasRole('hr-portal')")
    @PostMapping("/geofance-config")
    public ResponseEntity<ApiDTO> geofanceConfig(
            @RequestBody GeofanceRequestDTO request,
            @AuthenticationPrincipal Jwt principal
    ) {
        ApiDTO response = employeeDutyMonitoringService.geofanceConfig(request , principal.getClaimAsString("preferred_username"));
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "Employees geofance")
    @PostMapping("/employees-geofance")
    public ResponseEntity<ApiDTO> employeesGeofance(
            @RequestParam Long facultyId,
            @RequestParam Long departmentId,
            @RequestParam String employeeIds
    ) {
        ApiDTO response = employeeDutyMonitoringService.employeeGeofance(facultyId,departmentId,employeeIds);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "Geofance List")
    @GetMapping("/geofance-list")
    public ResponseEntity<ApiDTO> getGeofanceList(
    ) {
        ApiDTO response = employeeDutyMonitoringService.getGeofanceList();
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "Enroll user first time otherwise update by current shift")
    @GetMapping("/enroll-user")
    public ResponseEntity<ApiDTO> enrollUser(
            @RequestParam String employeeId,
            @RequestParam String date,
            @RequestParam(required = false) String publicRsa  // ✅ MADE OPTIONAL
    ) {
            ApiDTO response = employeeDutyMonitoringService.enrollUser(employeeId, date, publicRsa);
            return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "Sync employees real time location in DB")
    @PostMapping("/sync-employee-location")
    public ResponseEntity<ApiDTO> syncEmployeeLocation(
            @RequestBody EmployeeDistanceRequestDTO request,
            // RSA digital signature sent by Flutter
            @RequestHeader(value = "X-Signature", required = false) String signature,
            @AuthenticationPrincipal Jwt principal
    ) {
        String preferredUsername = principal.getClaimAsString("preferred_username");
        log.info(
                "Location sync request received. Employee: {}, Signature present: {}",
                request.getEmployeeId(),
                signature != null && !signature.isBlank()
        );
        // Pass RSA signature to service.
        // Service will retrieve the employee's stored public key
        // and verify the signature before saving the location.
        ApiDTO response = employeeDutyMonitoringService.syncEmployeeLocation(request, signature, preferredUsername);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "My todays location graph")
    @GetMapping("/my-location-graph")
    public ResponseEntity<ApiDTO> myLocationGraph(@AuthenticationPrincipal Jwt principal) {
        String preferredUsername = principal.getClaimAsString("preferred_username");
        ApiDTO response = employeeDutyMonitoringService.myLocationGraph(preferredUsername, LocalDate.now());
        return new ResponseEntity<>(response, HttpStatus.OK);
    }


    @Operation(summary = "location graph for hr")
    //@PreAuthorize("hasRole('hr-portal')")
    @GetMapping("/location-graph")
    public ResponseEntity<ApiDTO> LocationGraph(@RequestParam String employeeId,@RequestParam String date) {
        ApiDTO response = employeeDutyMonitoringService.LocationGraph(employeeId, date);
        return new ResponseEntity<>(response, HttpStatus.OK);
    }
}