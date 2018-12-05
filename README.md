DEEP-OC-dogs_breed_det
============================================

![DEEP-Hybrid-DataCloud logo](https://deep-hybrid-datacloud.eu/wp-content/uploads/2018/01/logo.png)

This is a container that will simply run the DEEP as a Service API component,
with a toy example to identify Dog's breed, "Dogs breed detector" (src: [indigo-dc/dogs_breed_det](https://github.com/indigo-dc/dogs_breed_det)).

    
# Running the container

## Directly from Docker Hub

To run the Docker container directly from Docker Hub and start using the API
simply run the following command:

```bash
$ docker run -ti -p 5000:5000 deephdc/deep-oc-dogs_breed_det deepaas-run --listen-ip=0.0.0.0
```

This command will pull the Docker container from the Docker Hub
[`deephdc`](https://hub.docker.com/u/deephdc/) organization.

## Building the container

If you want to build the container directly in your machine (because you want
to modify the `Dockerfile` for instance) follow the following instructions:

Building the container:

1. Get the `DEEP-OC-dogs_breed_det` repository (this repo):

    ```bash
    $ git clone https://github.com/indigo-dc/DEEP-OC-dogs_breed_det
    ```

2. Build the container:

    ```bash
    $ cd DEEP-OC-dogs_breed_det
    $ docker build -t deephdc/deep-oc-dogs_breed_det .
    ```

These two steps will download the repository from GitHub and will build the
Docker container locally on your machine. You can inspect and modify the
`Dockerfile` in order to check what is going on. For instance, you can pass the
`--debug=True` flag to the `deepaas-run` command, in order to enable the debug
mode.

# Connect to the API

Once the container is up and running, browse to `http://localhost:5000` to get
the [OpenAPI (Swagger)](https://www.openapis.org/) documentation page.


## Expected data location

The [indigo-dc/dogs_breed_det](https://github.com/indigo-dc/dogs_breed_det) application expects 
data for training, validation, and test located in the following directories _inside the container_:
/srv/dogs_breed_det/data/dogImages/train
/srv/dogs_breed_det/data/dogImages/valid
/srv/dogs_breed_det/data/dogImages/test

Original dataset with dog images for training can be found at [udacity-aind/dogImages.zip](https://s3-us-west-1.amazonaws.com/udacity-aind/dog-project/dogImages.zip)

Trained model is stored inside the container in
/srv/dogs_breed_det/models

## Running the container
In the following example we suppose that dog images are located in $HOME/dogImages directory at your host machine. Then to run the Docker container for training execute:

```bash
$ docker run -ti -p 5000:5000 -v $HOME/dogImages:/srv/dogs_breed_det/data/dogImages deephdc/deep-oc-dogs_breed_det deepaas-run --listen-ip=0.0.0.0
```

Once the model is trained, you can use it for classifying dog's breeds.



