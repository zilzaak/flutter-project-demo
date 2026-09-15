package org.jobportal.entity;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;


@Entity
@Table(name="UM_HR_DM_Employee_Geofance")
@Data
@NamedStoredProcedureQuery(
        name = "employee_geofance_save",
        procedureName = "SP_UM_HR_DM_Employee_Geofance_Save",
        parameters = {
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "geofance_id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "faculty_id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "department_id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "employee_ids", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_latitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_longitude", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_radius", type = Double.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_name", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "user", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "operation", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_code", type = Integer.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_description", type = String.class)
        }
)
public class EmployeeGeofance {
    @Id
    @GeneratedValue(strategy= GenerationType.IDENTITY)
    private Long id;

    @Column(name="employee_id")
    private String employeeId;

    @ManyToOne
    @JoinColumn(name="geofance_id")
    private Geofance geofance;

    @Column(name="created_at")
    private LocalDateTime createdAt;

    @Column(name="created_by")
    private String createdBy;

    @Column(name="updated_at")
    private LocalDateTime updatedAt;

    @Column(name="updated_by")
    private String updatedBy;
}
