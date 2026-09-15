package org.jobportal.dto;


import lombok.Data;

import java.time.LocalDateTime;

@Data
public class EmployeeDistanceRequestDTO {
    private String employeeId;
    private Double longitude;
    private Double latitude;
    private LocalDateTime date;
    private String accessToken;
}
