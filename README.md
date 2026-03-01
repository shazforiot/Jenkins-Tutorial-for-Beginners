# Jenkins CI/CD — Demo Project

> Companion code for the **"Jenkins Tutorial for Beginners"** YouTube video.
> Everything you need to run Jenkins locally with Docker and build your first automated pipeline.

---

## 📁 File Overview

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Spins up Jenkins LTS with Docker socket mounted |
| `setup.sh` | One-command setup script — starts Jenkins & prints admin password |
| `Jenkinsfile` | Full 6-stage production pipeline (Node.js app) |
| `Jenkinsfile.simple` | Minimal starter template — adapt to any language |

---

## ⚠️ Common Error — "couldn't find remote ref refs/heads/master"

If you see this error:
```
fatal: couldn't find remote ref refs/heads/master
```

**Cause:** Jenkins defaults to checking out `master`, but GitHub repositories created after 2020 use `main` as the default branch name.

**Fix (30 seconds):**
1. Open your pipeline job → click **Configure**
2. Scroll to **Branches to build**
3. Change `*/master` → `*/main`
4. Click **Save** → **Build Now** ✅

**Fix it globally** so all new jobs default to `main`:
> **Manage Jenkins → System → Git plugin → Default branch name** → type `main` → Save

---

## ⚠️ Common Error — "Invalid agent type docker"

If you see this error when running the pipeline:
```
Invalid agent type "docker" specified. Must be one of [any, label, none]
```

**Cause:** The `agent { docker { ... } }` syntax requires the **Docker Pipeline** plugin, which is **not** included in the default "Install Suggested Plugins" set.

**Fix — choose one:**

**Option A (quickest) — use `agent any`**
The `Jenkinsfile` already defaults to `agent any`. No changes needed — just run the pipeline.

**Option B (recommended for real projects) — install the plugin**
1. Go to **Manage Jenkins → Plugins → Available plugins**
2. Search for **Docker Pipeline**
3. Click **Install** and restart Jenkins
4. In the `Jenkinsfile`, comment out `agent any` and uncomment the `agent { docker { ... } }` block

---

## ✅ Prerequisites

| Requirement | Check |
|-------------|-------|
| [Docker Desktop](https://www.docker.com/get-started) installed | `docker --version` |
| Docker Compose v2+ | `docker compose version` |
| Port **8080** free | Web UI |
| Port **50000** free | Agent communication |
| At least **2 GB RAM** available | — |

---

## 🚀 Quick Start (3 steps)

### Step 1 — Start Jenkins

```bash
docker compose up -d
```

Docker pulls `jenkins/jenkins:lts-jdk17` (~470 MB on first run) and starts the container in the background.

Watch the startup logs with:

```bash
docker compose logs -f jenkins
```

Wait for: `Jenkins is fully up and running`

---

### Step 2 — Get the admin password

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Copy the printed hex string — you'll need it in the next step.

> **Shortcut:** Run `./setup.sh` instead. It does Steps 1 and 2 automatically, waits for Jenkins to be ready, and prints the password for you.

---

### Step 3 — Complete the setup wizard

1. Open **http://localhost:8080** in your browser
2. Paste the admin password
3. Click **Install Suggested Plugins** (takes ~2 minutes)
4. Create your admin user
5. Click **Start using Jenkins** ✅

---

## 🔌 Recommended Plugins to Install

Go to **Manage Jenkins → Plugins → Available** and search for:

| Plugin | Why |
|--------|-----|
| **Blue Ocean** | Beautiful visual pipeline UI |
| **Docker Pipeline** | Build & push Docker images from Jenkinsfile |
| **GitHub Integration** | Auto-trigger builds on `git push` via webhooks |
| **JUnit** | Publish test reports inside Jenkins UI |
| **Slack Notifier** | Build success/failure alerts to Slack |
| **Credentials Binding** | Safely inject secrets into pipelines |

---

## 📝 Creating Your First Pipeline Job

1. Click **New Item** → enter a name → choose **Pipeline** → OK
2. Scroll to the **Pipeline** section
3. Set **Definition** to `Pipeline script from SCM`
4. Set **SCM** to `Git` and enter your repository URL
5. Set **Script Path** to `Jenkinsfile`
6. Click **Save** → **Build Now**

---

## 📄 Jenkinsfile Guide

### `Jenkinsfile.simple` — Start here

Copy this to the root of **any** project and rename it `Jenkinsfile`:

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'npm install'      // Node.js
                // sh 'mvn package'   // Java
                // sh 'go build'      // Go
            }
        }
        stage('Test') {
            steps { sh 'npm test' }
        }
        stage('Deploy') {
            steps { sh 'echo "Add your deploy command here"' }
        }
    }

    post {
        success { echo '✅ Pipeline succeeded!' }
        failure { echo '❌ Pipeline failed — check the logs.' }
        always  { cleanWs() }
    }
}
```

### `Jenkinsfile` — Full production pipeline

The full pipeline covers a complete Node.js CI/CD workflow:

| Stage | What it does |
|-------|-------------|
| 📥 **Checkout** | Pulls code from your Git repository |
| 📦 **Install** | Runs `npm ci` for a clean, reproducible install |
| 🧪 **Test** | Runs the test suite with coverage; publishes JUnit report |
| 🐳 **Docker Build** | Builds and tags the Docker image with the build number |
| 📤 **Push** | Pushes the image to Docker Hub using stored credentials |
| 🚀 **Deploy** | Swaps the running staging container (only on `main` branch) |

**Before using the full Jenkinsfile**, update these values:

```groovy
DOCKER_REPO = 'yourusername/yourapp'   // ← your Docker Hub repo
```

And add a Docker Hub credential in Jenkins:

1. **Manage Jenkins → Credentials → Global → Add Credentials**
2. Kind: `Username with password`
3. Username: your Docker Hub username
4. Password: your Docker Hub password (or access token)
5. ID: `docker-hub-creds`  ← must match the Jenkinsfile exactly

---

## 🐳 Docker Compose Details

The `docker-compose.yml` is configured with:

- **Image:** `jenkins/jenkins:lts-jdk17` — Long Term Support with Java 17
- **User:** `root` — required to manage Docker volumes
- **Ports:** `8080` (UI) and `50000` (agent JNLP)
- **Volume `jenkins_home`:** All Jenkins data persists here (jobs, plugins, credentials, build history). Survives container restarts.
- **Docker socket mount:** `/var/run/docker.sock` — lets Jenkins build and run Docker images from inside the container (Docker-in-Docker)
- **Health check:** Jenkins confirms it's responsive before reporting healthy

---

## 🛠️ Useful Commands

```bash
# Start Jenkins in the background
docker compose up -d

# Watch live logs
docker compose logs -f jenkins

# Stop Jenkins (data is preserved)
docker compose stop

# Start Jenkins again
docker compose start

# Stop and remove container (data preserved in volume)
docker compose down

# ⚠️  Stop AND delete ALL data (jobs, config, history)
docker compose down -v

# Get admin password
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Open a shell inside the Jenkins container
docker exec -it jenkins bash

# Check Jenkins health
curl -sf http://localhost:8080/login && echo "Jenkins is up"
```

---

## ❓ Troubleshooting

**"couldn't find remote ref refs/heads/master"**
```
fatal: couldn't find remote ref refs/heads/master
```
Jenkins is trying to checkout a branch called `master`, but your repository's default branch is `main` (GitHub renamed the default in 2020).

Fix — update the branch name in the Jenkins job:
1. Open the job → click **Configure**
2. Scroll to **Branches to build**
3. Change `*/master` → `*/main`
4. Click **Save** → **Build Now**

> To avoid this for every new job, set the global default:
> **Manage Jenkins → System → Git plugin → Default branch name** → set to `main`

---

**"Invalid agent type docker" error**
```
Invalid agent type "docker" specified. Must be one of [any, label, none]
```
The **Docker Pipeline** plugin is missing. Either:
- Use `agent any` (already the default in the `Jenkinsfile`), **or**
- Install the plugin: **Manage Jenkins → Plugins → Available → "Docker Pipeline" → Install**

---

**Jenkins won't start / port 8080 in use**
```bash
# Find what's using port 8080
lsof -i :8080        # macOS / Linux
netstat -ano | findstr :8080  # Windows
```

**"Permission denied" when building Docker images**
Make sure the Docker socket is mounted correctly in `docker-compose.yml`:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```
On Linux you may also need to add the jenkins user to the docker group.

**Forgot admin password**
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**Pipeline fails at Docker push with "unauthorized"**
Double-check your credential ID in Jenkins matches `docker-hub-creds` in the Jenkinsfile exactly (case-sensitive).

**"ERROR: docker-hub-creds" — pipeline skips all stages**
```
ERROR: docker-hub-creds
```
The `docker-hub-creds` credential doesn't exist yet in this Jenkins instance. The pipeline uses `withCredentials` scoped to the Push stage only, so all earlier stages (Checkout, Install, Test, Docker Build) will still run — the pipeline only fails when it reaches the Push stage.

Fix — add the credential before running the Push stage:
1. **Manage Jenkins → Credentials → Global → Add Credentials**
2. Kind: `Username with password`
3. Username: your Docker Hub username
4. Password: your Docker Hub password or access token
5. ID: `docker-hub-creds` ← must match exactly (case-sensitive)

> **Tip:** If you just want to test the early stages (Checkout, Install, Test), you can simply comment out the entire `📤 Push to Registry` stage — the rest of the pipeline runs fine without it.

---

**"Required context class hudson.FilePath is missing" on cleanWs()**
```
org.jenkinsci.plugins.workflow.steps.MissingContextVariableException:
Required context class hudson.FilePath is missing
```
`cleanWs()` needs an active node/workspace context. This error appears when the pipeline fails *before* an agent is allocated (e.g. a credential binding in the global `environment` block aborts startup). Now that credentials are scoped with `withCredentials` inside the Push stage, the agent is always allocated and `cleanWs()` in `post { always }` works normally. If you see this error, ensure no `credentials()` calls remain in the global `environment` block.

---

**"No such property: GIT_BRANCH" in post block**
```
groovy.lang.MissingPropertyException: No such property: GIT_BRANCH
```
`GIT_BRANCH` is set by the Git plugin during the Checkout stage. If the pipeline fails *before* checkout runs (e.g. a missing credential aborts the `environment` block), the variable is never populated and the `post { failure }` block crashes trying to print it.

The `Jenkinsfile` uses `env.GIT_BRANCH ?: 'unknown'` as a safe fallback. If you see this error you're using an older copy — pull the latest version.

---

**Container exits immediately**
```bash
docker compose logs jenkins   # check for startup errors
```

---

## 📺 Video Timestamps

| Time | Topic |
|------|-------|
| 0:00 | Why manual deployments are painful |
| 1:00 | What is CI/CD? Jenkins architecture |
| 2:30 | Docker setup — step by step |
| 5:30 | Jenkinsfile anatomy explained |
| 7:00 | Full real-world pipeline demo |
| 9:00 | Essential plugins + key takeaways |

---

## 🔗 Resources

- [Jenkins Official Docs](https://www.jenkins.io/doc/)
- [Jenkins Docker Hub Image](https://hub.docker.com/r/jenkins/jenkins)
- [Declarative Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Blue Ocean Plugin](https://plugins.jenkins.io/blueocean/)
- [Jenkins Credentials Binding](https://plugins.jenkins.io/credentials-binding/)
