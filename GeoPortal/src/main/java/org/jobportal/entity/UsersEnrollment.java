package org.jobportal.entity;

import jakarta.persistence.*;
import lombok.Data;

import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name="UM_HR_DM_Users_Enrollment")
@Data
@NamedStoredProcedureQuery(
        name = "users_enrollment_save",
        procedureName = "SP_UM_HR_DM_Users_Enrollment_Save",
        parameters = {
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "employee_id", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "public_rsa", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "access_token", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_start_time", type = LocalTime.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "office_end_time", type = LocalTime.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "user", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.IN, name = "operation", type = String.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_id", type = Long.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_code", type = Integer.class),
                @StoredProcedureParameter(mode = ParameterMode.OUT, name = "out_message_description", type = String.class)
        }
)
public class UsersEnrollment {
    @Id
    @GeneratedValue(strategy= GenerationType.IDENTITY)
    private Long id;

    @Column(name="employee_id")
    private String employeeId;

    @ManyToOne
    @JoinColumn(name="geofance_id")
    private Geofance geofance;

    @Column(name="public_rsa")
    private String publicRsa;

    @Column(name="access_token")
    private String accessToken;

    @Column(name="office_start_time")
    private LocalTime officeStartTime;

    @Column(name="office_end_time")
    private LocalTime officeEndTime;

    @Column(name="active")
    private Boolean active;

    @Column(name="created_at")
    private LocalDateTime createdAt;

    @Column(name="created_by")
    private String createdBy;

    @Column(name="updated_at")
    private LocalDateTime updatedAt;

    @Column(name="updated_by")
    private String updatedBy;

}
