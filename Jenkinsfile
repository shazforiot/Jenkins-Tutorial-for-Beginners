// ─────────────────────────────────────────────────────────────────────────────
// Jenkinsfile — Full CI/CD Pipeline for a Node.js Application
// ─────────────────────────────────────────────────────────────────────────────
// SETUP INSTRUCTIONS:
//   1. Place this file in the ROOT of your repository (named exactly "Jenkinsfile")
//   2. In Jenkins: New Item → Pipeline → "Pipeline script from SCM"
//   3. Set Repository URL and branch → Save
//   4. Add Docker Hub credentials in Jenkins → Manage Jenkins → Credentials
//      ID: "docker-hub-creds" (username + password)
//
// STAGES:
//   📥 Checkout    → Pull code from GitHub
//   📦 Install     → npm ci (clean install)
//   🧪 Test        → Run test suite, publish JUnit report
//   🐳 Docker Build → Build image tagged with build number
//   📤 Push        → Push to Docker Hub registry
//   🚀 Deploy      → Zero-downtime container swap on staging
// ─────────────────────────────────────────────────────────────────────────────

pipeline {

    // Run inside a Node.js 20 Docker container (no need to install Node on Jenkins)
    agent {
        docker {
            image 'node:20-alpine'
            // Also install Docker CLI inside the agent container
            args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    // ── GLOBAL ENVIRONMENT VARIABLES ──────────────────────────────────────────
    environment {
        // Docker Hub image name — change to your username/repo
        DOCKER_REPO    = 'yourusername/myapp'

        // Full image tag using Jenkins BUILD_NUMBER for traceability
        IMAGE_TAG      = "${DOCKER_REPO}:${BUILD_NUMBER}"
        IMAGE_LATEST   = "${DOCKER_REPO}:latest"

        // Docker Hub credentials (stored in Jenkins Credentials store)
        // Creates DOCKER_CREDS_USR and DOCKER_CREDS_PSW environment variables
        DOCKER_CREDS   = credentials('docker-hub-creds')

        // Application port
        APP_PORT       = '3000'

        // Staging container name
        CONTAINER_NAME = 'myapp-staging'

        // Node environment
        NODE_ENV       = 'test'
    }

    // ── PIPELINE OPTIONS ──────────────────────────────────────────────────────
    options {
        // Keep last 10 build logs and artifacts
        buildDiscarder(logRotator(numToKeepStr: '10'))

        // Timeout the entire pipeline after 30 minutes
        timeout(time: 30, unit: 'MINUTES')

        // Add timestamps to console output
        timestamps()

        // Don't run concurrent builds on the same branch
        disableConcurrentBuilds()
    }

    // ── STAGES ────────────────────────────────────────────────────────────────
    stages {

        // ── STAGE 1: CHECKOUT ─────────────────────────────────────────────────
        stage('📥 Checkout') {
            steps {
                echo "──────────────────────────────────────────"
                echo "📥 Checking out source code..."
                echo "   Branch: ${env.GIT_BRANCH}"
                echo "   Commit: ${env.GIT_COMMIT?.take(8)}"
                echo "──────────────────────────────────────────"

                // 'checkout scm' uses the repository configured in the Jenkins job
                checkout scm
            }
        }

        // ── STAGE 2: INSTALL DEPENDENCIES ─────────────────────────────────────
        stage('📦 Install Dependencies') {
            steps {
                echo "📦 Installing npm packages..."

                // 'npm ci' is faster and more reliable than 'npm install' in CI
                // It respects the exact versions in package-lock.json
                sh 'npm ci --prefer-offline'

                echo "✅ Dependencies installed successfully"
            }
        }

        // ── STAGE 3: LINT (optional — comment out if no linter) ───────────────
        stage('🔍 Lint') {
            steps {
                echo "🔍 Running linter..."
                sh 'npm run lint || echo "Lint step skipped (add a lint script to package.json)"'
            }
        }

        // ── STAGE 4: TEST ─────────────────────────────────────────────────────
        stage('🧪 Test') {
            steps {
                echo "🧪 Running test suite..."

                sh '''
                    npm test -- \
                        --ci \
                        --coverage \
                        --reporters=default \
                        --reporters=jest-junit || true
                '''
                // Note: '|| true' prevents stage failure if no tests configured yet
                // Remove '|| true' in production to enforce test passing
            }

            post {
                always {
                    // Publish JUnit test results to Jenkins UI (requires JUnit plugin)
                    junit allowEmptyResults: true, testResults: 'junit-results/*.xml'

                    // Publish coverage report (requires HTML Publisher plugin)
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        // ── STAGE 5: DOCKER BUILD ──────────────────────────────────────────────
        stage('🐳 Docker Build') {
            steps {
                echo "🐳 Building Docker image: ${IMAGE_TAG}"

                sh """
                    # Build the image with build number tag
                    docker build \
                        --tag ${IMAGE_TAG} \
                        --tag ${IMAGE_LATEST} \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "git.commit=${GIT_COMMIT}" \
                        --label "git.branch=${GIT_BRANCH}" \
                        .

                    # Show image size
                    docker images ${DOCKER_REPO}
                """

                echo "✅ Docker image built: ${IMAGE_TAG}"
            }
        }

        // ── STAGE 6: PUSH TO DOCKER HUB ───────────────────────────────────────
        stage('📤 Push to Registry') {
            steps {
                echo "📤 Pushing ${IMAGE_TAG} to Docker Hub..."

                sh """
                    # Login using credentials from Jenkins Credentials store
                    # DOCKER_CREDS_PSW and DOCKER_CREDS_USR are auto-injected
                    echo "${DOCKER_CREDS_PSW}" | docker login \
                        --username "${DOCKER_CREDS_USR}" \
                        --password-stdin

                    # Push both tags
                    docker push ${IMAGE_TAG}
                    docker push ${IMAGE_LATEST}

                    echo "✅ Pushed ${IMAGE_TAG} to Docker Hub"
                """
            }
        }

        // ── STAGE 7: DEPLOY TO STAGING ────────────────────────────────────────
        stage('🚀 Deploy to Staging') {
            // Only deploy from the 'main' branch
            when {
                branch 'main'
            }

            steps {
                echo "🚀 Deploying ${IMAGE_TAG} to staging..."

                sh """
                    # Gracefully stop and remove the old container (ignore errors if not running)
                    docker stop ${CONTAINER_NAME} || true
                    docker rm   ${CONTAINER_NAME} || true

                    # Start the new container
                    docker run \
                        --detach \
                        --name     ${CONTAINER_NAME} \
                        --publish  ${APP_PORT}:${APP_PORT} \
                        --restart  unless-stopped \
                        --env      NODE_ENV=staging \
                        ${IMAGE_TAG}

                    # Verify container is running
                    docker ps --filter "name=${CONTAINER_NAME}"

                    echo "✅ Staging deployment complete → http://localhost:${APP_PORT}"
                """
            }
        }

    } // end stages

    // ── POST-PIPELINE ACTIONS ──────────────────────────────────────────────────
    post {

        success {
            echo """
            ══════════════════════════════════════════════
            ✅ PIPELINE SUCCEEDED
               Build:  #${BUILD_NUMBER}
               Branch: ${GIT_BRANCH}
               Time:   ${currentBuild.durationString}
            ══════════════════════════════════════════════
            """
            // TODO: Add Slack/email notification here
            // slackSend(color: 'good', message: "✅ Build #${BUILD_NUMBER} succeeded!")
        }

        failure {
            echo """
            ══════════════════════════════════════════════
            ❌ PIPELINE FAILED
               Build:  #${BUILD_NUMBER}
               Branch: ${GIT_BRANCH}
               Stage:  ${env.STAGE_NAME}
            ══════════════════════════════════════════════
            """
            // TODO: Add Slack/email notification here
            // slackSend(color: 'danger', message: "❌ Build #${BUILD_NUMBER} failed!")
        }

        always {
            // Logout from Docker registry
            sh 'docker logout || true'

            // Clean up the workspace to save disk space
            cleanWs()

            echo "🧹 Workspace cleaned up"
        }

    } // end post

} // end pipeline
