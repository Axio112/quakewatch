pipeline {
  agent any

  environment {
    // ---- adjust only these if you ever rename things ----
    DOCKERHUB_REPO     = 'vitalybelos112/quakewatch'
    CHART_DIR          = 'charts/quakewatch'
    RELEASE            = 'quakewatch-helm'   // <— Option A: stick with -helm
    DOCKERHUB_CRED_ID  = 'dockerhub'
  }

  options { timestamps() }

  stages {

    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Compute Tag') {
      steps {
        script {
          // Read currently deployed image tag (if any)
          def currentImage = sh(
            script: "kubectl get deploy ${RELEASE} -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true",
            returnStdout: true
          ).trim()

          def tag = '0.1.0'
          if (currentImage) {
            def parts = currentImage.split(':')
            if (parts.size() >= 2) { tag = parts[-1] }
          }

          def nums = tag.tokenize('.').collect { it.isInteger() ? it as Integer : 0 }
          while (nums.size() < 3) { nums << 0 }       // ensure [maj, min, pat]
          def (maj, min, pat) = nums
          pat += 1
          if (pat > 9) { pat = 0; min += 1 }          // 0.1.9 -> 0.2.0

          env.IMAGE_TAG = "${maj}.${min}.${pat}"
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
          # Server-side dry-run of the EXACT resources this release manages
          helm template "${RELEASE}" "${CHART_DIR}" \
            --set image.repository=${DOCKERHUB_REPO} \
            --set image.tag=${IMAGE_TAG} \
          | kubectl apply -f - --dry-run=server
        """
      }
    }

    stage('Publish') {
      steps {
        withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED_ID,
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
          kubectl config current-context
          helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
            --set image.repository=${DOCKERHUB_REPO} \
            --set image.tag=${IMAGE_TAG} \
            --wait --atomic
        """
      }
    }

    stage('Verify (smoke)') {
      steps {
        sh """
          set -eux
          # Hit the in-cluster Service by DNS
          kubectl run curl --rm -i --restart=Never \
            --image=curlimages/curl:8.10.1 -- \
            -fsS http://${RELEASE}/ | grep -qi Hello
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
