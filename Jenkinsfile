pipeline {
    agent any 

    stages {
        stage('Hola Mundo') {
            steps {
                echo '¡Hola! Este es el inicio de mi pipeline en Jenkins.'
            }
        }
        stage('Validar Entorno') {
            steps {
                echo 'Comprobando herramientas...'
                sh 'git --version'
            }
        }
    }
}
