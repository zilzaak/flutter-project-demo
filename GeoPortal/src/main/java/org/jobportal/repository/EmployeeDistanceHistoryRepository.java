package org.jobportal.repository;

import org.jobportal.entity.EmployeeDistanceHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;


public interface EmployeeDistanceHistoryRepository extends JpaRepository<EmployeeDistanceHistory, Long> {
    
    @Procedure(name = "employee_distance_history_save")
    Map<String, Object> spEmployeeDistanceHistorySave(
            @Param("id") Long id,
            @Param("employee_id") String employeeId,
            @Param("longitude") String longitude,
            @Param("latitude") String latitude,
            @Param("office_longitude") Double officeLongitude,
            @Param("office_latitude") Double officeLatitude,
            @Param("office_radius") Double officeRadius,
            @Param("distance_from_office") String disTanceFromOffice,
            @Param("outside_of_office") String outsideOfOffice,
            //@Param("date") LocalDate date,
            @Param("user") String user,
            @Param("operation") String operation
    );

    @Query("select edh.latitude as latitude , " +
            " edh.longitude as longitude " +
            " from EmployeeDistanceHistory edh " +
            " where cast(edh.createdAt as date)=cast(:today as date)" +
            " and edh.employeeId=:employeeId  order by edh.id asc ")
    List<Map<String,Double>> myLocationGraph(@Param("employeeId") String employeeId, @Param("today") LocalDate today);
}