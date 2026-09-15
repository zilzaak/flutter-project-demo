package org.jobportal.utility;


import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Objects;


@Service
public class CommonService {

    private boolean isEqual(Object oldValue, Object newValue) {

        if (oldValue == null && newValue == null) {
            return true;
        }

        if (oldValue == null || newValue == null) {
            return false;
        }
        // Different types are always different
        if (!oldValue.getClass().equals(newValue.getClass())) {
            return false;
        }

        if (oldValue instanceof BigDecimal) {
            return isBigDecimalEqual((BigDecimal) oldValue, (BigDecimal) newValue);
        }

        if (oldValue instanceof Double) {
            return isDoubleEqual((Double) oldValue, (Double) newValue);
        }

        if (oldValue instanceof Float) {
            return isFloatEqual((Float) oldValue, (Float) newValue);
        }

        if (oldValue instanceof Long) {
            return isLongEqual((Long) oldValue, (Long) newValue);
        }

        if (oldValue instanceof Integer) {
            return isIntegerEqual((Integer) oldValue, (Integer) newValue);
        }

        if (oldValue instanceof Boolean) {
            return isBooleanEqual((Boolean) oldValue, (Boolean) newValue);
        }

        if (oldValue instanceof String) {
            return isStringEqual((String) oldValue, (String) newValue);
        }

        if (oldValue instanceof LocalDate) {
            return isLocalDateEqual((LocalDate) oldValue, (LocalDate) newValue);
        }

        if (oldValue instanceof LocalDateTime) {
            return isLocalDateTimeEqual((LocalDateTime) oldValue, (LocalDateTime) newValue);
        }

        // Default comparison
        return Objects.equals(oldValue, newValue);
    }

    public boolean isBigDecimalEqual(BigDecimal oldVal, BigDecimal newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.compareTo(newVal)==0;
        }
    }


    public boolean isDoubleEqual(Double oldVal, Double newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.compareTo(newVal)==0;
        }
    }


    public boolean isFloatEqual(Float oldVal, Float newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.compareTo(newVal)==0;
        }
    }

    public boolean isLongEqual(Long oldVal, Long newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.equals(newVal);
        }
    }

    public boolean isIntegerEqual(Integer oldVal, Integer newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.equals(newVal);
        }
    }

    public boolean isBooleanEqual(Boolean oldVal, Boolean newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.equals(newVal);
        }
    }

    public boolean isStringEqual(String oldVal, String newVal) {
        String normalizedOld = normalize(oldVal);
        String normalizedNew = normalize(newVal);
        if (normalizedOld == null && normalizedNew == null) {
            return true;
        } else if (normalizedOld == null || normalizedNew == null) {
            return false;
        } else {
            return normalizedOld.equals(normalizedNew);
        }
    }
    private String normalize(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        return value.trim();
    }

    public boolean isStringEqualIgnoreCase(String oldVal, String newVal) {
        String normalizedOld = normalize(oldVal);
        String normalizedNew = normalize(newVal);
        if (normalizedOld == null && normalizedNew == null) {
            return true;
        } else if (normalizedOld == null || normalizedNew == null) {
            return false;
        } else {
            return normalizedOld.equalsIgnoreCase(normalizedNew);
        }
    }

    public boolean isLocalDateEqual(LocalDate oldVal, LocalDate newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.equals(newVal);
        }
    }

    public boolean isLocalDateTimeEqual(LocalDateTime oldVal, LocalDateTime newVal) {
        if (oldVal == null && newVal == null) {
            return true;
        }
        else if (oldVal != null && newVal == null) {
            return false;
        }
        else if (oldVal == null && newVal != null) {
            return false;
        }else{
            return oldVal.equals(newVal);
        }
    }

    private static final double EARTH_RADIUS_METERS = 6371000.0;


    public double distanceBetweenTwoLocation(
            double officeLongitude,
            double officeLatitude,
            double employeeLongitude,
            double employeeLatitude) {

        final double EARTH_RADIUS_METERS = 6_371_000.0;

        // Convert degrees to radians
        double officeLatRad = Math.toRadians(officeLatitude);
        double employeeLatRad = Math.toRadians(employeeLatitude);

        double deltaLat = Math.toRadians(employeeLatitude - officeLatitude);
        double deltaLon = Math.toRadians(employeeLongitude - officeLongitude);

        // Haversine formula
        double a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)
                + Math.cos(officeLatRad)
                * Math.cos(employeeLatRad)
                * Math.sin(deltaLon / 2)
                * Math.sin(deltaLon / 2);

        double c = 2 * Math.atan2(
                Math.sqrt(a),
                Math.sqrt(1 - a)
        );

        double distance = EARTH_RADIUS_METERS * c;

        return BigDecimal.valueOf(distance)
                .setScale(3, RoundingMode.HALF_UP)
                .doubleValue();
    }

}
