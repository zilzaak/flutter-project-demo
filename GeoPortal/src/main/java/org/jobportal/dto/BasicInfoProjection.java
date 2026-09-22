package org.jobportal.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

public interface BasicInfoProjection {
    String getEmployeeId();
    String getFullName();
    String getDesignation();
    String getDepartment();
    LocalDate getJoiningDate();
    LocalTime getStartTime();
    LocalDateTime getFirstPunch();
    LocalTime getEndTime();
    Boolean getHoliday();
    Boolean getWeekend();
}