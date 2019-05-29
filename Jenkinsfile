#!groovy
@Library(['github.com/cloudogu/dogu-build-lib@1e5e2a6', 'github.com/cloudogu/zalenium-build-lib@3092363']) _

import com.cloudogu.ces.dogubuildlib.*

node('vagrant') {

    timestamps{
        properties([
                // Keep only the last x builds to preserve space
                buildDiscarder(logRotator(numToKeepStr: '10')),
                // Don't run concurrent builds for a branch, because they use the same workspace directory
                disableConcurrentBuilds()
        ])

        EcoSystem ecoSystem = new EcoSystem(this, "gcloud-ces-operations-internal-packer", "jenkins-gcloud-ces-operations-internal")

        stage('Checkout') {
            checkout scm
        }

        stage('Lint') {
            lintDockerfile()
        }

        try {

            stage('Provision') {
                ecoSystem.provision("/dogu");
            }

            stage('Setup') {
                ecoSystem.loginBackend('cesmarvin-setup')
                ecoSystem.setup()
            }

            stage('Build') {
                ecoSystem.build("/dogu")
            }

            stage('Verify') {
                sh 'cesapp start ldap'
                sleep 10
                ecoSystem.verify("/dogu")
            }

        } finally {
            stage('Clean') {
                ecoSystem.destroy()
            }
        }
    }
}

