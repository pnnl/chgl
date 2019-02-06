#!/bin/bash

# This script uses a Dockerfile based on the master branch in https://github.com/tjstavenger-pnnl/chapel/blob/master/util/dockerfiles/master/
# A pull request has been created to merge this back into Chapel. See https://github.com/chapel-lang/chapel/pull/10570

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


