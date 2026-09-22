package org.jobportal.repository;

import org.jobportal.dto.BasicInfoProjection;
import org.jobportal.entity.EmployeeGeofance;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;


public interface EmployeeGeofanceRepository extends JpaRepository<EmployeeGeofance, Long> {

    @Procedure(name = "employee_geofance_save")
    Map<String, Object> spEmployeeGeofanceSave(
        @Param("geofance_id") Long geofanceId,
        @Param("faculty_id") Long facultyId,
        @Param("department_id") Long departmentId,
        @Param("employee_ids") String employeeIds,
        @Param("office_latitude") Double officeLatitude,
        @Param("office_longitude") Double officeLongitude,
        @Param("office_radius") Double officeRadius,
        @Param("office_name") String officeName,
        @Param("user") String user,
        @Param("operation") String operation
    );

    EmployeeGeofance findByEmployeeId(String userId);

    @Query(value = "select egf.id as id, " +
            " ei.employee_id as employeeId , " +
            " ei.id as employeeInfoId , " +
            " ei.full_name as fullName , " +
            " gf.name as officeName , " +
            " gf.longitude as officeLongitude , " +
            " gf.latitude as officeLatitude , " +
            " gf.radius as officeRadius , " +
            " dp.name as department , " +
            " fac.name as faculty , " +
            " dg.name as designation" +
            " from UM_HR_Employee_Info ei   " +
            " left join UM_HR_DM_Employee_Geofance egf on ei.employee_id=egf.employee_id " +
            " left join UM_HR_DM_Geofance gf on egf.geofance_id = gf.id " +
            " left join UM_AS_Departments dp on dp.id=ei.department_id " +
            " left join UM_AS_Faculties fac on ei.faculty_id = fac.id " +
            " left join UM_HR_Designations dg on ei.designation_id = dg.id  " +
            " where ei.active=1 and ( :employeeIds is null or concat(',',:employeeIds,',') like concat('%,',ei.employee_id,',%')  )  " +
            "  and ( :departmentId is null or dp.id=:departmentId ) " +
            "  and ( :facultyId is null or fac.id=:facultyId ) " +
            "  AND (  " +
            "     :isAssigned is null   " +
            "     or ( :isAssigned=true and egf.employee_id IS NOT NULL )  " +
            "     or ( :isAssigned=false and egf.employee_id IS  NULL ) "+
            ")",nativeQuery = true)
    Page<Map<String, Object>> employeeGeofanc(@Param("facultyId") Long facultyId,
                                              @Param("departmentId") Long departmentId,
                                              @Param("employeeIds") String employeeIds,
                                              @Param("isAssigned") Boolean isAssigned,
                                              Pageable pageable);

    @Query(value = "select ei.employee_id as employeeId , " +
            " ei.full_name as fullName ," +
            " dg.name as designation ,  " +
            " dp.name as department , " +
            " ei.join_date as joiningDate , " +
            " dtl.check_in  as startTime , " +
            " dtl.check_out  as endTime ," +
            " ( select top 1 in_out_datetime from dbo.UM_HR_Employee_Attendance_In_Out where " +
            "  employee_info_id=(select id from UM_HR_Employee_Info where employee_id=:userId ) " +
            "  and cast(in_out_datetime as date)= cast(:today as date) " +
            "  order by in_out_datetime asc ) as firstPunch  ," +
            " CASE WHEN dtl.day_of_week IN (6, 7) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END as weekend ," +
            " CASE WHEN EXISTS (" +
            "   SELECT 1 FROM UM_HR_Holiday_Calendar hc " +
            "   WHERE hc.holiday_date = :today AND hc.active = 1 " +
            " ) THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END as holiday  " +
            " from UM_HR_Employee_Attendance_Schedule eas " +
            " inner join UM_HR_Employee_Info ei on eas.employee_info_id = ei.id  " +
            " left join UM_HR_Designations dg on ei.designation_id = dg.id  " +
            " left join UM_AS_Departments dp on ei.department_id = dp.id  " +
            " inner join UM_HR_Attendance_Schedule_Template st on eas.attendance_schedule_template_id = st.id" +
            " inner join UM_HR_Attendance_Template_Detail dtl on st.id = dtl.attendance_schedule_template_id " +
            " where dtl.day_of_week = :dow and ei.employee_id=:userId and eas.active=1  ",nativeQuery = true)
    List<BasicInfoProjection> geBasicInfo(@Param("userId") String userId, @Param("dow") Integer dow,@Param("today") LocalDate today);
}
}