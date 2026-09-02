package bd.edu.diu.derpemployeeattendanceleaveservice.services;

import bd.edu.diu.derpcore.dto.ApiDTO;
import bd.edu.diu.derpcore.dto.dutyMonitoring.EmployeeDistanceRequestDTO;
import bd.edu.diu.derpcore.dto.dutyMonitoring.GeofanceRequestDTO;
import bd.edu.diu.derpcore.entity.dutyMonitoring.EmployeeGeofance;
import bd.edu.diu.derpcore.entity.dutyMonitoring.UsersEnrollment;
import bd.edu.diu.derpcore.repository.EmployeeAttendanceScheduleRepository;
import bd.edu.diu.derpcore.repository.dutyMonitoring.EmployeeDistanceHistoryRepository;
import bd.edu.diu.derpcore.repository.dutyMonitoring.EmployeeGeofanceRepository;
import bd.edu.diu.derpcore.repository.dutyMonitoring.UsersEnrollmentRepository;
import bd.edu.diu.derpcore.utility.CommonService;
import bd.edu.diu.derpcore.utility.RsaSignatureUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class DutyMonitoringService {

    private final EmployeeAttendanceScheduleRepository employeeAttendanceScheduleRepository;
    private final EmployeeGeofanceRepository employeeGeofanceRepository;
    private final UsersEnrollmentRepository usersEnrollmentRepository;
    private final EmployeeDistanceHistoryRepository employeeDistanceHistoryRepository;
    private final CommonService commonService;

    public ApiDTO enrollUser(String employeeId, String appServerDate, String publicRsa) {
        LocalDate ld = LocalDate.parse(appServerDate);
        Map<String, Object> info = employeeAttendanceScheduleRepository.geBasicInfo(employeeId, ld.getDayOfWeek().getValue());
        Map<String, Object> result = usersEnrollmentRepository.spUsersEnrollmentSave(null, employeeId, publicRsa, (LocalTime) info.get("startTime"), (LocalTime) info.get("endTime"), employeeId, "E");
        if (result.get("out_message_code").equals(1)) {
            return ApiDTO.builder().data(info).status(false).message((String) result.get("out_message_description")).build();
        }
        return ApiDTO.builder().data(info).message((String) result.get("out_message_description")).status(true).build();
    }

    public ApiDTO geofanceConfig(GeofanceRequestDTO request, String operation, String preferredUsername) {
        try {
            Map<String, Object> result = employeeGeofanceRepository.spEmployeeGeofanceSave(
                    request.getGeofanceId(),
                    request.getFacultyId(),
                    request.getDepartmentId(),
                    request.getEmployeeIds(),
                    preferredUsername,
                    operation);
            if (result.get("out_message_code").equals(0)) {
                return ApiDTO.builder().status(true).message((String) result.get("out_message_description")).build();
            } else {
                return ApiDTO.builder().status(false).message((String) result.get("out_message_description")).build();
            }
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }


    public ApiDTO syncEmployeeLocation(EmployeeDistanceRequestDTO request, String signature, String preferredUsername) {
        try {
            UsersEnrollment usersEnrollment = usersEnrollmentRepository.findByEmployeeId(request.getEmployeeId());
            if (usersEnrollment == null) {
                return ApiDTO.builder().status(false).message("Employee is not enrolled").build();
            }
            // 1. Digital Signature Justification / Verification with stored RSA Public Key
            String publicRsa = usersEnrollment.getPublicRsa();
            if (publicRsa != null && !publicRsa.isBlank()) {
                if (signature == null || signature.isBlank()) {
                    return ApiDTO.builder().status(false).message("Signature verification failed: Missing digital signature header (X-Signature).").build();
                }
                boolean isValid = verifyRequestSignature(request, signature, publicRsa);
                if (!isValid) {
                    return ApiDTO.builder().status(false).message("Signature verification failed: Invalid device digital signature.").build();
                }
            }
            Double officeLongitude = usersEnrollment.getGeofance().getLongitude();
            Double officeLatitude = usersEnrollment.getGeofance().getLatitude();
            Double officeRadius = usersEnrollment.getGeofance().getRadius();
            Double distanceFromOffice = commonService.distanceBetweenTwoLocation(officeLongitude, officeLatitude, request.getLongitude(), request.getLatitude());
            Map<String, Object> result = employeeDistanceHistoryRepository.spEmployeeDistanceHistorySave(null, request.getEmployeeId(), request.getLongitude(), request.getLatitude(), officeLongitude, officeLatitude, officeRadius, distanceFromOffice, distanceFromOffice > officeRadius, preferredUsername, "I");
            boolean status = result.get("out_message_code").equals(0);
            return ApiDTO.builder().status(status).message((String) result.get("out_message_description")).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }


    private boolean verifyRequestSignature(EmployeeDistanceRequestDTO request, String signature, String publicRsa) {
        // 1. Check formatted JSON matching Flutter jsonEncode structure
        try {
            Map<String, Object> jsonMap = new HashMap<>();
            jsonMap.put("employeeId", request.getEmployeeId());
            jsonMap.put("longitude", request.getLongitude());
            jsonMap.put("latitude", request.getLatitude());
            if (request.getDate() != null) {
                jsonMap.put("date", request.getDate().toString());
            }
            ObjectMapper mapper = new ObjectMapper();
            String jsonPayload = mapper.writeValueAsString(jsonMap);
            if (RsaSignatureUtil.verifySignature(jsonPayload, signature, publicRsa)) {
                return true;
            }
        } catch (Exception ignored) {}
        // 2. Check Jackson DTO serialization
        try {
            ObjectMapper mapper = new ObjectMapper();
            mapper.registerModule(new JavaTimeModule());
            String jsonPayload = mapper.writeValueAsString(request);
            if (RsaSignatureUtil.verifySignature(jsonPayload, signature, publicRsa)) {
                return true;
            }
        } catch (Exception ignored) {}
        // 3. Check Canonical string format: employeeId|longitude|latitude
        String canonical = request.getEmployeeId() + "|" + request.getLongitude() + "|" + request.getLatitude();
        if (RsaSignatureUtil.verifySignature(canonical, signature, publicRsa)) {
            return true;
        }
        return false;
    }

    public ApiDTO myLocationGraph(String userId, LocalDate now) {
        try {
            List<Map<String, Double>> locationPoints = employeeDistanceHistoryRepository.myLocationGraph(userId, now);
            EmployeeGeofance employeeGeofance = employeeGeofanceRepository.findByEmployeeId(userId);
            Map<String, Object> response = new HashMap<>();
            response.put("officeLatitude", employeeGeofance.getGeofance().getLatitude());
            response.put("officeLongitude", employeeGeofance.getGeofance().getLongitude());
            response.put("locationPoints", locationPoints);
            return ApiDTO.builder().data(response).status(true).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }
}