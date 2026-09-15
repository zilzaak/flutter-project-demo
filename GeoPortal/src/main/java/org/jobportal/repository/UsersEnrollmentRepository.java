package org.jobportal.repository;


import org.jobportal.entity.UsersEnrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;

import java.time.LocalTime;
import java.util.Map;

public interface UsersEnrollmentRepository extends JpaRepository<UsersEnrollment, Long> {
@Procedure(name = "users_enrollment_save")
Map<String, Object> spUsersEnrollmentSave(
        @Param("id") Long id,
        @Param("employee_id") String employeeId,
        @Param("public_rsa") String publicRsa,
        @Param("access_token") String accessToekn,
        @Param("office_start_time") LocalTime startTime,
        @Param("office_end_time") LocalTime endTime,
        @Param("user") String user,
        @Param("operation") String oepration);

    UsersEnrollment findByEmployeeId(String employeeId);

    UsersEnrollment findByEmployeeIdAndActive(String employeeId, Boolean active);
}