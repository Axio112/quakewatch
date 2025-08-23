pipeline {
  agent any

  environment {
    REGISTRY   = 'docker.io'
    IMAGE_REPO = 'vitalybelos112/quakewatch'
    RELEASE    = 'quakewatch'
    CHART_DIR  = 'charts/quakewatch'
    BUCKET     = '10' // builds per minor (0.1.0..0.1.9 then 0.2.0..)
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Compute Tag') {
      steps {
        script {
          def buildNum = env.BUILD_NUMBER as Integer
          def bucket   = env.BUCKET as Integer
          def minor    = ((buildNum - 1) / bucket) + 1       // 1,2,3...
          def patch    = (buildNum - 1) % bucket             // 0..9
          env.IMAGE_TAG = "0.${minor}.${patch}"
          env.IMAGE_URI = "${env.IMAGE_REPO}:${env.IMAGE_TAG}"
        }
        sh 'echo "Computed IMAGE_TAG=${IMAGE_TAG}  IMAGE_URI=${IMAGE_URI}"'
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -eux
          docker build -t "${IMAGE_URI}" .
          docker image inspect "${IMAGE_URI}"
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eux
          helm lint "${CHART_DIR}"
          helm template "${RELEASE}" "${CHART_DIR}" \
            --set image.repository="${IMAGE_REPO}" \
            --set image.tag="${IMAGE_TAG}" \
          | kubectl apply -f - --dry-run=server
        '''
      }
    }

    stage('Publish') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKERHUB_USER',
          passwordVariable: 'DOCKERHUB_PASS'
        )]) {
          sh '''
            set -eux
            echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
            docker push "${IMAGE_URI}"
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -eux
          kubectl config current-context
          helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
            --set image.repository="${IMAGE_REPO}" \
            --set image.tag="${IMAGE_TAG}" \
            --wait
        '''
      }
    }

    stage('Verify (smoke)') {
      steps {
        sh '''
          set -eux
          kubectl run curl --rm -i --restart=Never \
            --image=curlimages/curl:8.10.1 -- -fsS http://quakewatch-helm/ \
          | grep -qi Hello
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
  }
}
