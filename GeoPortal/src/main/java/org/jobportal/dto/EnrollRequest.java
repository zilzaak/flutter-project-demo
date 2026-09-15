package org.jobportal.dto;


import lombok.Data;

@Data
public class EnrollRequest {
    private String employeeId;
    private String publicRsa;
    private String accessToken;
}
