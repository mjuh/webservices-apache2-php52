@Library('mj-shared-library') _

def dockerImage = null

pipeline {
    agent { label 'nixbld' }
    options {
        gitLabConnection(Constants.gitLabConnection)
        gitlabBuilds(builds: ['Build Docker image', 'Push Docker image'])
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
    }
    environment {
        PROJECT_NAME = gitRemoteOrigin.getProject()
        GROUP_NAME = gitRemoteOrigin.getGroup()
    }
    stages {
        stage('Build Docker image') {
            steps {
                gitlabCommitStatus(STAGE_NAME) {
                    script { dockerImage = nixBuildDocker namespace: GROUP_NAME, name: PROJECT_NAME }
                }
            }
        }
        stage('Test Docker image') {
            steps {
                script {
                    if(PROJECT_NAME.contains('php')) {
                        nixSh cmd: 'nix-build test.nix --out-link test-result --show-trace'

                        publishHTML (target: [
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'test-result/coverage-data/vm-state-docker',
                                reportFiles: 'phpinfo.html, bitrix_server_test.html',
                                reportName: "coverage-data"
                            ])

                        publishHTML (target: [
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'test-result',
                                reportFiles: 'log.html',
                                reportName: "result"
                            ])
                    }
                }
            }
        }
        stage('Push Docker image') {
            steps {
                gitlabCommitStatus(STAGE_NAME) {
                    pushDocker image: dockerImage
                }
            }
        }
    }
    post {
        success { cleanWs() }
        failure { notifySlack "Build failled: ${JOB_NAME} [<${RUN_DISPLAY_URL}|${BUILD_NUMBER}>]", "red" }
    }
}
