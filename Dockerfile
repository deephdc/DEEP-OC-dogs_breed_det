# Base image, e.g. tensorflow/tensorflow:1.7.0
FROM tensorflow/tensorflow:1.8.0

LABEL maintainer='Valentin Kozlov'
LABEL version='0.3.0'
# Dogs breed detector


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


# Set the working directory
WORKDIR /srv

# Install user app:
RUN git clone https://github.com/vykozlov/dogs_breed_det && \
    cd  dogs_breed_det && \
    pip install --no-cache-dir -e . && \
    rm -rf /root/.cache/pip/* && \
    rm -rf /tmp/* && \
    cd ..

# Install DEEPaaS:
RUN git clone https://github.com/indigo-dc/deepaas && \
    cd deepaas && \
    pip install -U . && \
    cd ..

# Your code may download data automatically or you force the download during docker build
#ENV Resnet50Data DogResnet50Data.npz
#ENV S3STORAGE https://s3-us-west-1.amazonaws.com/udacity-aind/dog-project/
#RUN curl -o ./dogs_breed_det/models/bottleneck_features/${Resnet50Data} \
#    ${S3STORAGE}${Resnet50Data}

EXPOSE 5000

CMD deepaas-run
