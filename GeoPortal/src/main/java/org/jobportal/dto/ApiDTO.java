package org.jobportal.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ApiDTO<T> {
    private Boolean status;
    private String message;
    private T data;
    private Integer totalRecords; //total count with the query without pagination
    private Integer currentPage;
    private Integer totalPages;
    private Integer pageSize;
}