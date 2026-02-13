#!groovy
@Library([
  'pipe-build-lib',
  'ces-build-lib',
  'dogu-build-lib'
]) _

def pipe = new com.cloudogu.sos.pipebuildlib.DoguPipe(this, [
    doguName           : 'ldap',
    shellScripts       : ['''
                            resources/scheduled_jobs.sh
                            resources/send-mail-after-changed-password.sh
                            resources/startup.sh
                            resources/srv/openldap/create-sa.sh
                            resources/srv/openldap/remove-sa.sh
                          '''],
    doBatsTests        : true,
    defaultBranch      : "master"
])

pipe.setBuildProperties()
pipe.addDefaultStages()
pipe.overrideStage('Bats Tests') {
    def bats_base_image = "bats/bats"
    def bats_custom_image = "cloudogu/bats"
    def bats_tag = "1.2.1"

    def batsImage = docker.build("${bats_custom_image}:${bats_tag}", "--build-arg=BATS_BASE_IMAGE=${bats_base_image} --build-arg=BATS_TAG=${bats_tag} ./unitTests")
    try {
        sh "mkdir -p target"

        batsContainer = batsImage.inside("--entrypoint='' -v ${WORKSPACE}:/workspace") {
            sh "make unit-test-shell-ci"
        }
    } finally {
        junit allowEmptyResults: true, testResults: 'target/shell_test_reports/*.xml'
    }
}

pipe.run()
