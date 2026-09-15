# JOB Portal

### by Daffodil Internation University

## Docker Instruction
### build docker image
```shell
sudo docker build -f Dockerfile -t job-portal .
```

### run docker container in Dev Server
```shell
### sudo docker run -d --name job-portal -v /home/storage:/home/storage -d -p 6000:6000 job-portal
```

### tagging a docker image
```shell
sudo docker tag job-portal:latest daffodilsoftwaresection/job-portal:1.0.4
```

### upload docker image to docker hub
```shell
sudo docker push daffodilsoftwaresection/job-portal:1.0.4
```

### run docker container Prod Server
```shell
sudo docker run -d --name job-portal -v /home/storage:/home/storage -p 6000:6000 daffodilsoftwaresection/job-portal:1.0.4
```

### To delete all containers including its volumes use,

sudo docker rm -vf $(sudo docker ps -aq)

### To delete all the images,

sudo docker rmi -f $(sudo docker images -aq)


