#!groovy
@Library(['github.com/cloudogu/ces-build-lib@1.48.0', 'github.com/cloudogu/dogu-build-lib@v1.6.0'])
import com.cloudogu.ces.cesbuildlib.*
import com.cloudogu.ces.dogubuildlib.*

node('vagrant'){
    properties([
      // Keep only the last 10 build to preserve space
      buildDiscarder(logRotator(numToKeepStr: '10')),
      // Don't run concurrent builds for a branch, because they use the same workspace directory
      disableConcurrentBuilds(),
      // Parameter to activate dogu upgrade test on demand
      parameters([
        booleanParam(defaultValue: false, description: 'Test dogu upgrade from latest release or optionally from defined version below', name: 'TestDoguUpgrade'),
        string(defaultValue: '', description: 'Old Dogu version for the upgrade test (optional; e.g. 2.222.1-1)', name: 'OldDoguVersionForUpgradeTest')
      ])
    ])
    doguName = 'ldap'
    branch = "${env.BRANCH_NAME}"
    Git git = new Git(this, "cesmarvin")
    git.committerName = 'cesmarvin'
    git.committerEmail = 'cesmarvin@cloudogu.com'
    GitFlow gitflow = new GitFlow(this, git)
    GitHub github = new GitHub(this, git)
    Changelog changelog = new Changelog(this)
    EcoSystem ecoSystem = new EcoSystem(this, "gcloud-ces-operations-internal-packer", "jenkins-gcloud-ces-operations-internal")

    timestamps{
      stage('Checkout') {
          checkout scm
      }

      stage('Lint') {
          lintDockerfile()
      }

      stage('Shellcheck'){
         shellCheck()
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
          ecoSystem.verify("/dogu")
        }

        stage('Integration Tests') {
          echo "No integration test exists."
        }

        if (params.TestDoguUpgrade != null && params.TestDoguUpgrade){
          stage('Upgrade dogu') {
            // Remove new dogu that has been built and tested above
            ecoSystem.purgeDogu(doguName)

            if (params.OldDoguVersionForUpgradeTest != '' && !params.OldDoguVersionForUpgradeTest.contains('v')){
              println "Installing user defined version of dogu: " + params.OldDoguVersionForUpgradeTest
              ecoSystem.installDogu("official/" + doguName + " " + params.OldDoguVersionForUpgradeTest)
            } else {
              println "Installing latest released version of dogu..."
              ecoSystem.installDogu("official/" + doguName)
            }
            ecoSystem.startDogu(doguName)
            ecoSystem.waitForDogu(doguName)
            ecoSystem.upgradeDogu(ecoSystem)

            // Wait for upgraded dogu to get healthy
            ecoSystem.waitForDogu(doguName)
          }

          stage('Integration Tests - After Upgrade') {
            echo "No integration test exists."
          }
        }

        if (gitflow.isReleaseBranch()) {
          String releaseVersion = git.getSimpleBranchName();

          stage('Finish Release') {
            gitflow.finishRelease(releaseVersion)
          }

          stage('Push Dogu to registry') {
            ecoSystem.push("/dogu")
          }

          stage ('Add Github-Release'){
            github.createReleaseWithChangelog(releaseVersion, changelog)
          }
        }

      } finally {
        stage('Clean') {
          ecoSystem.destroy()
        }
      }
    }
}


