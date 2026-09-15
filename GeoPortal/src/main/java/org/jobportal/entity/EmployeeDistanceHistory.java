package org.jobportal.entity;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;

@Entity
@Table(name="UM_HR_DM_Employee_Distance_History")
@Data
@NamedStoredProcedureQuery(
        name = "employee_distance_history_save",
        procedureName = "SP_UM_HR_DM_Employee_Distance_History_Save",
        parameters = {
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "employee_id", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "longitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "latitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_longitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_latitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_radius", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "distance_from_office", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "outside_of_office", type = Boolean.class),
                //@StoredProcedureParameter(mode = ParameterMode.IN, name = "date", type = LocalDate.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "user", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "operation", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_code", type = Integer.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_description", type = String.class)
        }
)
public class EmployeeDistanceHistory {
    @Id
    @GeneratedValue(strategy= GenerationType.IDENTITY)
    private Long id;

    @Column(name="employee_id")
    private String employeeId;

    @Column(name="office_latitude")
    private Double officeLatitude;

    @Column(name="office_longitude")
    private Double officeLongitude;

    @Column(name="office_radius")
    private Double officeRadius;

    @Column(name="latitude")
    private Double latitude;

    @Column(name="longitude")
    private Double longitude;

    @Column(name="distance_from_office")
    private Double distanceFromOffice;

    @Column(name="outside_of_office")
    private Boolean outsideOfOffice;

    @Column(name="date")
    private LocalDateTime date;

    @Column(name="created_at")
    private LocalDateTime createdAt;

    @Column(name="created_by")
    private String createdBy;

    @Column(name="updated_at")
    private LocalDateTime updatedAt;

    @Column(name="updated_by")
    private String updatedBy;

}
