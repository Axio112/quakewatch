pipeline {
  agent any

  environment {
    IMAGE_REPO = 'vitalybelos112/quakewatch'
    IMAGE_TAG  = "0.1.${BUILD_NUMBER}"
    HELM_EXTRA = "--set fullnameOverride=quakewatch-helm"
  }

    stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    

    stage('Build') {
      steps {
        sh '''
          set -eux
          docker build -t ${IMAGE_REPO}:${IMAGE_TAG} .
          docker image inspect ${IMAGE_REPO}:${IMAGE_TAG}
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eux
          helm lint charts/quakewatch
          helm template quakewatch charts/quakewatch \
            ${HELM_EXTRA} \
            --set image.repository=${IMAGE_REPO} \
            --set image.tag=${IMAGE_TAG} \
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
            docker push ${IMAGE_REPO}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          set -eux
          kubectl config current-context
          helm upgrade --install quakewatch charts/quakewatch \
            ${HELM_EXTRA} \
            --set image.repository=${IMAGE_REPO} \
            --set image.tag=${IMAGE_TAG} \
            --wait --atomic --timeout 10m
        '''
      }
    }

    stage('Verify (smoke)') {
      steps {
        sh '''
          set -eux
          kubectl run curl --rm -i --restart=Never \
            --image=curlimages/curl:8.10.1 -- -fsS http://quakewatch-helm/ | grep -qi "Hello"
        '''
      }
    }
  }

  post {
    always { sh 'docker logout || true' }
  }
}
