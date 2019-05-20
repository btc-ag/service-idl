@Library("cab") _

nodeWs("azure-linux")
{
	withMaven(jdk: 'Java11', maven: 'maven-default', publisherStrategy: 'EXPLICIT', options: [artifactsPublisher()])
	{
	    checkout scm
		sh "mvn -X -e package -U"
		build job: '/cab/BF/serviceidl-integrationtests/master', 
		      parameters: [string(name: 'build_project', value: env.JOB_NAME), string(name: 'build_id', value: env.BUILD_NUMBER), string(name: 'version', value: '')], 
			  wait: false
	}
}
