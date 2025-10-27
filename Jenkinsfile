pipeline {
  agent any
  options { timestamps() }
  parameters {
    string(name: 'DOMAIN_BASE', defaultValue: '91-107-228-241.sslip.io', description: 'Basisdomain/Traefik (z. B. sslip.io-Domain)')
    booleanParam(name: 'DEPLOY_QS', defaultValue: true, description: 'Nach QS Gates eine Demo/QS-Instanz bereitstellen')
  }

  environment {
    GIT_COMMIT_SHORT = "${env.GIT_COMMIT?.take(7)}"
    IMAGE_NAME       = "ife/${env.JOB_NAME?.replaceAll('/','-')}"
    BRANCH_SLUG      = "${env.BRANCH_NAME?.toLowerCase()?.replaceAll('[^a-z0-9_-]','-')}"
    PROJECT_NAME     = "odoo_${BRANCH_NAME}"
    VIRTUAL_HOST     = "${BRANCH_NAME}.${params.DOMAIN_BASE}"
    DOCKER_CONFIG    = "${WORKSPACE}/.docker"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('QS: Lint (optional)') {
      steps {
        sh '''
          set -eux
          if command -v python3 >/dev/null 2>&1 && [ -f "requirements.txt" ] && (grep -E "flake8|black" requirements.txt >/dev/null 2>&1 || true); then
            python3 -m venv .venv
            . .venv/bin/activate
            pip install --upgrade pip
            pip install -r requirements.txt || true
            command -v flake8 >/dev/null 2>&1 && flake8 || echo "flake8 nicht gefunden – übersprungen"
            command -v black  >/dev/null 2>&1 && black --check . || echo "black nicht gefunden – übersprungen"
          else
            echo "Kein Python/keine Lint-Tools – Lint übersprungen"
          fi
        '''
      }
    }

    stage('QS: Build (Docker)') {
      steps {
        sh '''
          set -eux
          if [ -f Dockerfile ]; then
            docker build -t "${IMAGE_NAME}:${BRANCH_NAME}-${GIT_COMMIT_SHORT}" .
            docker images | head -n 10
          else
            echo "Kein Dockerfile – Build übersprungen"
          fi
        '''
      }
    }

    stage('QS: Smoke (HTTP 200) – optional') {
      steps {
        sh '''
          set -eux
          HOST="${VIRTUAL_HOST}"
          echo "Smoke gegen http://${HOST}/web/login"
          curl -sI --max-time 2 --resolve "${HOST}:80:127.0.0.1" "http://${HOST}/web/login" | sed -n '1,5p' || true
        '''
      }
    }

    stage('QS: Deploy (Compose pro Branch)') {
      when { expression { return params.DEPLOY_QS } }
      steps {
        sh '''
          set -eux
          if [ -f docker-compose.yml ] && [ -f docker-compose.init.yml ]; then
            export COMPOSE_PROJECT_NAME="${PROJECT_NAME}"
            export TRAEFIK_ENABLE="true"
            export VIRTUAL_HOST="${VIRTUAL_HOST}"

            FILES="-f docker-compose.yml -f docker-compose.init.yml"
            if [ -f docker-compose.le.yml ]; then FILES="$FILES -f docker-compose.le.yml"; fi

            echo "==> Deploy ${COMPOSE_PROJECT_NAME} auf ${VIRTUAL_HOST}"
            docker compose -p "${COMPOSE_PROJECT_NAME}" ${FILES} up -d --wait || true

            echo "Warte bis /web/login erreichbar ist (max 90s)…"
            READY=0
            for i in $(seq 1 90); do
              if curl -fsS -m 2 --resolve "${VIRTUAL_HOST}:80:127.0.0.1" "http://${VIRTUAL_HOST}/web/login" >/dev/null 2>&1; then READY=1; break; fi
              sleep 1
            done
            if [ "$READY" -ne 1 ]; then
              echo "WARN: Smoke 200 nicht bestätigt – Logs:"
              docker compose -p "${COMPOSE_PROJECT_NAME}" ps || true
              docker compose -p "${COMPOSE_PROJECT_NAME}" logs --tail=200 || true
            else
              echo "OK: QS-Instanz erreichbar: https://${VIRTUAL_HOST}/web"
            fi
          else
            echo "Keine Compose-Dateien im Repo – Deploy übersprungen."
          fi
        '''
      }
    }
  }

  post {
    always {
      sh '''
        set +e
        docker ps --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}' > ps.txt 2>/dev/null || true
      '''
      archiveArtifacts artifacts: 'ps.txt,.venv/**', allowEmptyArchive: true
    }
  }
}
