pipeline {
  agent any

  environment {
    IMAGE     = "vitalybelos112/quakewatch"
    TAG       = "0.1.${env.BUILD_NUMBER}"
    CHART_DIR = "charts/quakewatch"
    RELEASE   = "quakewatch"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Docker Build') {
      steps {
        sh '''
          set -eux
          docker build -t "$IMAGE:$TAG" .
          docker image inspect "$IMAGE:$TAG" >/dev/null
        '''
      }
    }

    stage('Docker Login & Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                          usernameVariable: 'DOCKERHUB_USER',
                                          passwordVariable: 'DOCKERHUB_PASS')]) {
          sh '''
            set -eux
            echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
            docker push "$IMAGE:$TAG"
          '''
        }
      }
    }

    stage('Deploy with Helm') {
      steps {
        sh '''
          set -eux
          kubectl config current-context
          helm upgrade --install "$RELEASE" "$CHART_DIR" \
            --set image.repository="$IMAGE" \
            --set image.tag="$TAG" \
            --wait
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
