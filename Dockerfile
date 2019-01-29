# Base image, e.g. tensorflow/tensorflow:1.7.0
FROM tensorflow/tensorflow:1.8.0

LABEL maintainer='V.Kozlov (KIT)'
# Dogs breed detector as example for DEEPaaS API


# Install ubuntu updates and python related stuff
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
         git \
         curl \
         wget \
         python-setuptools \
         python-pip \
         python-wheel && \ 
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*


# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# install rclone
RUN wget https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    touch /srv/.rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*

# Install FLAT (FLask support for handling Access Tokens)
RUN cd /srv && git clone https://github.com/marcvs/flat.git && \
    rm -rf /tmp/* 

ENV PYTHONPATH /srv/flat

# Install user app:
RUN git clone https://github.com/deephdc/dogs_breed_det && \
    cd  dogs_breed_det && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Install DEEPaaS from PyPi:
RUN pip install --no-cache-dir deepaas && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/*


#####
# Your code may download necessary data automatically or 
# you force the download during docker build. Example below is for latter case:
#ENV Resnet50Data DogResnet50Data.npz
#ENV S3STORAGE https://s3-us-west-1.amazonaws.com/udacity-aind/dog-project/
#RUN curl -o ./dogs_breed_det/models/bottleneck_features/${Resnet50Data} \
#    ${S3STORAGE}${Resnet50Data}


# Open DEEPaaS port
EXPOSE 5000

CMD deepaas-run
