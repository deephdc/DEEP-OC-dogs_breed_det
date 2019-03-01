#!/usr/bin/groovy

@Library(['github.com/indigo-dc/jenkins-pipeline-library@1.2.3']) _

pipeline {
    agent {
        label 'docker-build'
    }

    environment {
        dockerhub_repo = "deephdc/deep-oc-dogs_breed_det"
        tf_ver = "1.10.0"
    }

    stages {
        stage('Docker image building (DEEP-OC)') {
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

                    if (env.BRANCH_NAME == 'master') {
                       // CPU + python2 (aka default now)
                       DockerBuild(id,
                                   tag: ['latest', 'cpu'], 
                                   build_args: ["tag=${env.tf_ver}",
                                                "pyVer=python"])

                       // GPU + python2
                       DockerBuild(id,
                                   tag: ['gpu'], 
                                   build_args: ["tag=${env.tf_ver}-gpu",
                                                "pyVer=python"])
                    }

                    if (env.BRANCH_NAME == 'test') {
                       // CPU + python2 (aka default now)
                       DockerBuild(id,
                                   tag: ['test', 'cpu-test'], 
                                   build_args: ["tag=${env.tf_ver}",
                                                "pyVer=python"])

                       // GPU + python2
                       DockerBuild(id,
                                   tag: ['gpu-test'], 
                                   build_args: ["tag=${env.tf_ver}-gpu",
                                                "pyVer=python"])
                    }

                }
            }
            post {
                failure {
                    DockerClean()
                }
            }
        }



        stage('Docker Hub delivery') {
            when {
                anyOf {
                   branch 'master'
                   branch 'test'
                   buildingTag()
               }
            }
            steps{
                script {
                    DockerPush(dockerhub_repo) // should push all tags
                }
            }
            post {
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
