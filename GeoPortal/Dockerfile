FROM eclipse-temurin:17-jdk

ENV TZ=Asia/Dhaka
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY target/job-portal-1.0.0.jar /app/job-portal-1.0.0.jar
COPY target/../custom.java.security /app/custom.java.security

WORKDIR /app

CMD ["java", "-jar", "-Djava.security.properties=custom.java.security", "job-portal-1.0.0.jar"]


