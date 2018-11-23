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

3. Run the container:

    ```bash
    $ docker run -ti -p 5000:5000 deephdc/deep-oc-dogs_breed_det deepaas-run --listen-ip=0.0.0.0
    ```

These three steps will download the repository from GitHub and will build the
Docker container locally on your machine. You can inspect and modify the
`Dockerfile` in order to check what is going on. For instance, you can pass the
`--debug=True` flag to the `deepaas-run` command, in order to enable the debug
mode.

# Connect to the API

Once the container is up and running, browse to `http://localhost:5000` to get
the [OpenAPI (Swagger)](https://www.openapis.org/) documentation page.


