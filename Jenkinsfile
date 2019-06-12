#!groovy
@Library(['github.com/cloudogu/ces-build-lib@c622273', 'github.com/cloudogu/dogu-build-lib@f8cca7c9b101ed0bcdde8df556c13711d4cfd5a5'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*

node('docker'){
        stage('Checkout') {
            checkout scm
        }

        stage('Lint') {
            lintDockerfile()
        }

        stage('Shellcheck'){
           shellCheck()
    }
}
node('vagrant') {

    timestamps{
        properties([
                // Keep only the last x builds to preserve space
                buildDiscarder(logRotator(numToKeepStr: '10')),
                // Don't run concurrent builds for a branch, because they use the same workspace directory
                disableConcurrentBuilds()
        ])

        EcoSystem ecoSystem = new EcoSystem(this, "gcloud-ces-operations-internal-packer", "jenkins-gcloud-ces-operations-internal")


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
                ecoSystem.verify("/dogu")
            }

        } finally {
            stage('Clean') {
                ecoSystem.destroy()
            }
        }
    }
}



