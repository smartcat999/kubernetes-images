pipeline {
  agent {
    node {
      label 'baseubuntu'
    }
  }

  parameters {
    string(name:'DOCKER_USERNAME',defaultValue: '',description:'')
    string(name:'DOCKER_PASSWORD',defaultValue: '',description:'')
  }


  stages {
    stage('构建alpine基础镜像') {
      steps {
        container('baseubuntu') {
          sh 'echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USERNAME} --password-stdin'
          retry(3) {
            sh 'cd base-image && make build-alpine-edge'
          }
        }
      }
     }
   }
}
