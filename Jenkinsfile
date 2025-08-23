pipeline {
  agent any

  environment {
    DOCKERHUB_REPO = 'vitalybelos112/quakewatch'
    CHART_DIR      = 'charts/quakewatch'
    RELEASE        = 'quakewatch'         // <-- Helm release name (consistent!)
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Compute Tag') {
      steps {
        script {
          // Read current image tag from the running Deployment (named quakewatch-helm by the chart)
          def current = sh(
            script: "kubectl get deploy quakewatch-helm -o jsonpath='{.spec.template.spec.containers[0].image}' || true",
            returnStdout: true
          ).trim()

          def curTag = '0.1.0'
          if (current) {
            def parts = current.tokenize(':')
            if (parts.size() == 2) curTag = parts[1]
          }

          // Simple bump rule: x.y.z -> x.y.(z+1); if z >= 9 then x.(y+1).0
          def nums = curTag.tokenize('.').collect { it as int }
          while (nums.size() < 3) { nums << 0 }
          if (nums[2] >= 9) { nums[1] = nums[1] + 1; nums[2] = 0 } else { nums[2] = nums[2] + 1 }
          env.IMAGE_TAG = "${nums[0]}.${nums[1]}.${nums[2]}"

          echo "Next IMAGE_TAG = ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build') {
      steps {
        sh """
          set -eux
          docker build -t ${DOCKERHUB_REPO}:${IMAGE_TAG} .
          docker image inspect ${DOCKERHUB_REPO}:${IMAGE_TAG}
        """
      }
    }

    stage('Test') {
      steps {
        sh """
          set -eux
          helm lint ${CHART_DIR}
          # Server-side dry-run using the SAME Helm release name
          helm template ${RELEASE} ${CHART_DIR} \\
            --set image.repository=${DOCKERHUB_REPO} \\
            --set image.tag=${IMAGE_TAG} \\
          | kubectl apply -f - --dry-run=server
        """
      }
    }

    stage('Publish') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                          usernameVariable: 'DOCKERHUB_USER',
                                          passwordVariable: 'DOCKERHUB_PASS')]) {
          sh """
            set -eux
            echo "\$DOCKERHUB_PASS" | docker login -u "\$DOCKERHUB_USER" --password-stdin
            docker push ${DOCKERHUB_REPO}:${IMAGE_TAG}
          """
        }
      }
    }

    stage('Deploy') {
      steps {
        sh """
          set -eux
          helm upgrade --install ${RELEASE} ${CHART_DIR} \\
            --set image.repository=${DOCKERHUB_REPO} \\
            --set image.tag=${IMAGE_TAG} \\
            --wait
        """
      }
    }

    stage('Verify (smoke)') {
      steps {
        sh """
          set -eux
          kubectl run curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- -fsS http://quakewatch-helm/ | grep -qi Hello
        """
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
    }
  }
}
