package org.jobportal.service;


import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.RequiredArgsConstructor;
import org.jobportal.dto.ApiDTO;
import org.jobportal.dto.BasicInfoProjection;
import org.jobportal.dto.EmployeeDistanceRequestDTO;
import org.jobportal.dto.GeofanceRequestDTO;
import org.jobportal.entity.EmployeeGeofance;
import org.jobportal.entity.UsersEnrollment;
import org.jobportal.repository.EmployeeDistanceHistoryRepository;
import org.jobportal.repository.EmployeeGeofanceRepository;
import org.jobportal.repository.GeofanceRepository;
import org.jobportal.repository.UsersEnrollmentRepository;
import org.jobportal.utility.CommonService;
import org.jobportal.utility.RsaSignatureUtil;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class DutyMonitoringService {

    private final EmployeeGeofanceRepository employeeGeofanceRepository;
    private final GeofanceRepository geofanceRepository;
    private final UsersEnrollmentRepository usersEnrollmentRepository;
    private final EmployeeDistanceHistoryRepository employeeDistanceHistoryRepository;
    private final CommonService commonService;

    public ApiDTO enrollUser(String employeeId, String publicRsa, String accessToken, String signature) {
        // If an RSA signature is provided, verify it against the public key
        if (publicRsa != null && !publicRsa.isBlank() && signature != null && !signature.isBlank()) {
            String canonicalPayload = employeeId + "|" + publicRsa;
            boolean isValid = RsaSignatureUtil.verifySignature(canonicalPayload, signature, publicRsa)
                    || RsaSignatureUtil.verifySignature(employeeId, signature, publicRsa);
            if (!isValid) {
                return ApiDTO.builder().status(false).message("Signature verification failed: Invalid device digital signature.").build();
            }
        }
        LocalDate ld = LocalDate.now();
        List<BasicInfoProjection> list = employeeGeofanceRepository.geBasicInfo(employeeId, ld.getDayOfWeek().getValue(),LocalDate.now());
        BasicInfoProjection info = list.get(0);
        Map<String, Object> result = usersEnrollmentRepository.spUsersEnrollmentSave(null, employeeId, publicRsa, accessToken,info.getStartTime(), info.getEndTime(), employeeId, "E");
        if (result.get("out_message_code").equals(1)) {
            return ApiDTO.builder().data(info).status(false).message((String) result.get("out_message_description")).build();
        }
        return ApiDTO.builder().data(info).message((String) result.get("out_message_description")).status(true).build();
    }

    public ApiDTO geofanceConfig(GeofanceRequestDTO request, String preferredUsername) {
        Boolean createResponse=request.getNewEmployeeIds()==null?true:false;
        Boolean updateResponse=request.getExistEmployeeIds()==null?true:false;
        String createMessage=null;
        String updateMessage=null;


            try {
                if(request.getNewEmployeeIds()!=null){
                    Map<String, Object> result = employeeGeofanceRepository.spEmployeeGeofanceSave(
                            request.getGeofanceId(),
                            request.getFacultyId(),
                            request.getDepartmentId(),
                            request.getNewEmployeeIds(),
                            request.getOfficeLatitude(),
                            request.getOfficeLongitude(),
                            request.getOfficeRadius(),
                            request.getOfficeName(),
                            preferredUsername,"E");
                    if (result.get("out_message_code").equals(0)) {
                        createResponse=true;
                    } else {
                        createResponse=false;
                    }
                    createMessage=result.get("out_message_description").toString();
                }
                if(request.getExistEmployeeIds()!=null){
                    Map<String, Object> result = employeeGeofanceRepository.spEmployeeGeofanceSave(
                            request.getGeofanceId(),
                            request.getFacultyId(),
                            request.getDepartmentId(),
                            request.getNewEmployeeIds(),
                            request.getOfficeLatitude(),
                            request.getOfficeLongitude(),
                            request.getOfficeRadius(),
                            request.getOfficeName(),
                            preferredUsername,"U");
                    if (result.get("out_message_code").equals(0)) {
                        updateResponse=true;
                    } else {
                        updateResponse=false;
                    }
                    updateMessage=result.get("out_message_description").toString();
                }

                if(!createResponse && !updateResponse){
                    return ApiDTO.builder().status(false).message(createMessage+','+updateMessage).build();
                }
                return ApiDTO.builder().status(false).message(createMessage+','+updateMessage).build();
            } catch (Exception e) {
                return ApiDTO.builder().status(false).message(e.getMessage()).build();
            }


    }


    public ApiDTO syncEmployeeLocation(EmployeeDistanceRequestDTO request, String signature, String preferredUsername) {
        try {
            UsersEnrollment usersEnrollment = usersEnrollmentRepository.findByEmployeeIdAndActive(request.getEmployeeId(),true);
            if (usersEnrollment == null || !usersEnrollment.getAccessToken().equals(request.getAccessToken())) {
                return ApiDTO.builder().status(false).message("Employee is not enrolled or invalid token").build();
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

    public ApiDTO myLocationGraph(String userId, String accessToken, String signature, LocalDate now) {
        UsersEnrollment usersEnrollment = usersEnrollmentRepository.findByEmployeeIdAndActive(userId, true);
        if (usersEnrollment == null || usersEnrollment.getAccessToken() == null || !usersEnrollment.getAccessToken().equals(accessToken)) {
            return ApiDTO.builder().status(false).message("Employee is not enrolled or invalid token").build();
        }

        // Digital Signature Verification with stored RSA Public Key
        String publicRsa = usersEnrollment.getPublicRsa();
        if (publicRsa != null && !publicRsa.isBlank()) {
            if (signature == null || signature.isBlank()) {
                return ApiDTO.builder().status(false).message("Signature verification failed: Missing digital signature header (X-Signature).").build();
            }
            String canonicalPayload = userId + "|" + now.toString();
            boolean isValid = RsaSignatureUtil.verifySignature(canonicalPayload, signature, publicRsa)
                    || RsaSignatureUtil.verifySignature(userId, signature, publicRsa);
            if (!isValid) {
                return ApiDTO.builder().status(false).message("Signature verification failed: Invalid device digital signature.").build();
            }
        }

        try {
            List<Map<String, Double>> locationPoints = employeeDistanceHistoryRepository.myLocationGraph(userId, now);
            EmployeeGeofance employeeGeofance = employeeGeofanceRepository.findByEmployeeId(userId);
            Map<String, Object> response = new HashMap<>();
            response.put("officeLatitude", employeeGeofance != null && employeeGeofance.getGeofance() != null ? employeeGeofance.getGeofance().getLatitude() : null);
            response.put("officeLongitude", employeeGeofance != null && employeeGeofance.getGeofance() != null ? employeeGeofance.getGeofance().getLongitude() : null);
            response.put("locationPoints", locationPoints);
            return ApiDTO.builder().data(response).status(true).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }


    public ApiDTO LocationGraph(String employeeId, String dateString) {
        try {
            List<Map<String, Double>> locationPoints = employeeDistanceHistoryRepository.myLocationGraph(employeeId, LocalDate.parse(dateString));
            EmployeeGeofance employeeGeofance = employeeGeofanceRepository.findByEmployeeId(employeeId);
            Map<String, Object> response = new HashMap<>();
            response.put("officeLatitude", employeeGeofance.getGeofance().getLatitude());
            response.put("officeLongitude", employeeGeofance.getGeofance().getLongitude());
            response.put("locationPoints", locationPoints);
            return ApiDTO.builder().data(response).status(true).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }


    public ApiDTO getGeofanceList() {
        try {
            List<Map<String, Object>> geofanceList = geofanceRepository.geofanceList();
            return ApiDTO.builder().data(geofanceList).status(true).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }

    public ApiDTO employeeGeofance(Long facultyId,Long departmentId,String employeeIds,Boolean isAssigned,Integer pageNo,Integer pageSize) {
        if(facultyId!=null){
            departmentId=null;
            employeeIds=null;
        }
        if(departmentId!=null){
            facultyId=null;
            employeeIds=null;
        }
        if(employeeIds!=null && employeeIds.trim().isEmpty()){
            facultyId=null;
            departmentId=null;
        }
        if(pageNo==null){
            pageNo=1;
            pageSize=20;
        }
        try {
            Page<Map<String, Object>> page = employeeGeofanceRepository.employeeGeofanc(facultyId,departmentId,employeeIds,isAssigned, PageRequest.of(pageNo-1,pageSize));
            return ApiDTO.builder().data(page.getContent()).status(true).totalPages(page.getTotalPages()).totalRecords((int) page.getTotalElements()).build();
        } catch (Exception e) {
            return ApiDTO.builder().status(false).message(e.getMessage()).build();
        }
    }
}