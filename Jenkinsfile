#!/usr/bin/groovy

@Library(['github.com/indigo-dc/jenkins-pipeline-library']) _

pipeline {
    agent {
        label 'docker-build'
    }

    environment {
        dockerhub_repo = "deephdc/deep-oc-dogs_breed_det"
        tf_ver = "1.10.0"
    }

    stages {
        stage('DockerHub delivery') {
            when {
                anyOf {
                   branch 'master'
                   buildingTag()
               }
            }
            steps{
                checkout scm
                script {
                    // build different tags
                    id = "${env.dockerhub_repo}"
                    //image_id = DockerBuild(dockerhub_repo, env.BRANCH_NAME)

                    // CPU + python2 (aka default now)
                    sh "docker build --no-cache --force-rm -t ${id} -t ${id}:py2 \
                        --build-arg tag=${env.tf_ver} \
                        --build-arg pyVer=python ."

                    // GPU + python2
                    sh "docker build --no-cache --force-rm -t ${id}:tf-gpu-py2 \
                        --build-arg tag=${env.tf_ver}-gpu \
                        --build-arg pyVer=python ."
                }
            }
            post {
                success {
                    DockerPush(dockerhub_repo)  // should push all tags
                }
                failure {
                    DockerClean()
                }
                always {
                    cleanWs()
                }
            }
        }
    }
}
