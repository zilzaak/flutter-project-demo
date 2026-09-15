package org.jobportal.repository;


import org.jobportal.entity.Geofance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Map;

public interface GeofanceRepository extends JpaRepository<Geofance, Long> {

    @Query("select id as id , name as name  ,longitude as longitude , latitude as latitude ,radius as radius from Geofance where active=true ")
    List<Map<String,Object>> geofanceList();
}