package org.jobportal.dto;

import lombok.Data;

@Data
public class GeofanceRequestDTO {
    private Long facultyId;
    private Long departmentId;
    private String newEmployeeIds;
    private String employeeIds;
    private String existEmployeeIds;
    private Long geofanceId;
    private Double officeLatitude;
    private Double officeLongitude;
    private String officeName;
    private Double officeRadius;
}
