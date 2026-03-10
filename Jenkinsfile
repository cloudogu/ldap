#!groovy
@Library([
  'pipe-build-lib@test-release',
  'ces-build-lib',
  'dogu-build-lib'
]) _

import com.cloudogu.ces.cesbuildlib.K3d
import com.cloudogu.ces.cesbuildlib.Makefile

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

def componentRegistry = "registry.cloudogu.com"
def componentRegistryNamespace = "k8s"
def componentChartTargetDir = "target/k8s/helm"
def componentBuildImageRepository = "registry.cloudogu.com/k8s/ldap"
def componentReleaseName = "lop-idp-ldap"
def goVersion = "1.26.0"

pipe.setBuildProperties()
pipe.addDefaultStages()

def runMakeInGoContainer = { target ->
    new com.cloudogu.ces.cesbuildlib.Docker(this)
        .image("golang:${goVersion}")
        .mountJenkinsUser()
        .inside("--volume ${WORKSPACE}:/workdir -w /workdir") {
            sh "make ${target}"
        }
}

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

def componentStages = { group ->
    group.stage('Component Checkout') {
        checkout scm
    }

    group.stage('Component Build') {
        docker.withRegistry('https://registry.cloudogu.com/', 'cesmarvin-setup') {
            sh "make component-build"
        }
    }

    group.stage('Component Test') {
        runMakeInGoContainer("component-test")
    }

    group.stage('Component Smoke Test (k3d)') {
        K3d k3d = new K3d(this, "${WORKSPACE}", "${WORKSPACE}/k3d", env.PATH)
        Makefile makefile = new Makefile(this)
        String releaseVersion = makefile.getVersion().trim()

        try {
            echo "[Component k3d] Start cluster"
            k3d.startK3d()

            echo "[Component k3d] Prepare prerequisites"
            k3d.kubectl("delete configmap global-config || true")
            k3d.kubectl("create configmap global-config --from-literal=config.yaml='domain: \"ces.test\"'")
            k3d.kubectl("delete secret ldap-admin-credentials || true")
            k3d.kubectl("create secret generic ldap-admin-credentials --from-literal=password='admin'")

            echo "[Component k3d] Generate helm chart"
            runMakeInGoContainer("component-helm-generate")

            echo "[Component k3d] Retag image for local smoke test"
            sh "docker tag ${componentBuildImageRepository}:${releaseVersion} local-smoke/ldap:${releaseVersion}"

            echo "[Component k3d] Import previously built image"
            sh "sudo ${WORKSPACE}/k3d/.k3d/bin/k3d image import local-smoke/ldap:${releaseVersion} -c ${k3d.registryName}"

            echo "[Component k3d] Deploy component via helm"
            k3d.helm("upgrade --install ${componentReleaseName} ${componentChartTargetDir} --namespace default --set image.registry=local-smoke --set image.repository=ldap --set image.tag=${releaseVersion} --set imagePullPolicy=Never --wait --timeout 5m")

            echo "[Component k3d] Verify component startup"
            k3d.kubectl("rollout status statefulset/${componentReleaseName} --timeout=300s")
            k3d.kubectl("wait --for=condition=ready pod -l app.kubernetes.io/instance=${componentReleaseName} --timeout=300s")
        } catch (Exception e) {
            k3d.collectAndArchiveLogs()
            throw e as java.lang.Throwable
        } finally {
            k3d.deleteK3d()
        }
    }

     if (pipe.gitflow.isReleaseBranch()) {
        group.stage('Push Component Image') {
            Makefile makefile = new Makefile(this)
            String releaseVersion = makefile.getVersion().trim()
            docker.withRegistry('https://registry.cloudogu.com/', 'cesmarvin-setup') {
                sh "docker push ${componentBuildImageRepository}:${releaseVersion}"
            }
        }

        group.stage('Push Component Chart to Harbor') {
            sh "make component-helm-package"

            def componentChartFile = sh(returnStdout: true, script: "ls -1t ${componentChartTargetDir}/*.tgz 2>/dev/null | head -n 1").trim()
            if (!componentChartFile) {
                error("No packaged component chart found in ${componentChartTargetDir}")
            }

            withCredentials([usernamePassword(credentialsId: 'harborhelmchartpush', usernameVariable: 'HARBOR_USERNAME', passwordVariable: 'HARBOR_PASSWORD')]) {
                sh ".bin/helm registry login ${componentRegistry} --username '${HARBOR_USERNAME}' --password '${HARBOR_PASSWORD}'"
                sh ".bin/helm push ${componentChartFile} oci://${componentRegistry}/${componentRegistryNamespace}/"
                sh ".bin/helm registry logout ${componentRegistry}"
            }
        }
    }
}

pipe.addStageGroup('component', pipe.agentMultinode, componentStages)

if (pipe.gitflow.isReleaseBranch()) {
    // Temporary release-artifacts-only mode:
    // keep publishing stages, but skip gitflow merge/tag finalization and notifications.
    pipe.overrideStage('Finish Release') {
        echo "Skipping 'Finish Release' (release-artifacts-only test mode)."
    }
    pipe.overrideStage('Add Github-Release') {
        echo "Skipping 'Add Github-Release' (release-artifacts-only test mode)."
    }
    pipe.overrideStage('Notfiy Webhook - Release') {
        echo "Skipping 'Notfiy Webhook - Release' (release-artifacts-only test mode)."
    }
}

pipe.run()
