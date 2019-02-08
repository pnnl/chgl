#!/bin/bash

# This script uses a builds a PNNL-based Docker image based on the current Chapel master branch in GitHub.

mkdir docker-tmp
cd docker-tmp
wget https://raw.githubusercontent.com/chapel-lang/chapel/master/util/dockerfiles/master/Dockerfile


# login with user that has permissions to push to https://hub.docker.com/r/pnnl/chapel/
sudo docker login

# clean up all old docker images (be careful!)
sudo docker system prune -a

# build the image and push it to Docker Hub
sudo docker build -t chapelmaster .
sudo docker tag chapelmaster pnnl/chapel:master
sudo docker push pnnl/chapel:master

cd ..
rm -rf docker-tmp


