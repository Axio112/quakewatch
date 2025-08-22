pipeline {
  agent any

  options {
    // avoid the automatic extra "Declarative: Checkout SCM" stage
    skipDefaultCheckout(true)
  }

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

    stage('Build') {
      steps {
        sh '''
          set -eux
          docker build -t "$IMAGE:$TAG" .
          docker image inspect "$IMAGE:$TAG" >/dev/null
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eux
          # 1) Static chart checks
          helm lint "$CHART_DIR"

          # 2) Server-side schema validation (no changes applied)
          helm template "$RELEASE" "$CHART_DIR" \
            --set image.repository="$IMAGE" \
            --set image.tag="$TAG" \
          | kubectl apply -f - --dry-run=server
        '''
      }
    }

    stage('Publish') {
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

    stage('Deploy') {
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

    stage('Verify (smoke)') {
      steps {
        sh '''
          set -eux
          # Call the ClusterIP Service from inside the cluster and look for "Hello"
          kubectl run curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
            -fsS "http://${RELEASE}-helm/" | grep -qi "Hello"
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
