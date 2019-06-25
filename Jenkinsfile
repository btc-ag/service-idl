@Library("cab") _

nodeWs("linux")
{
	withMaven(jdk: 'Java11', maven: 'maven-default', publisherStrategy: 'EXPLICIT', options: [artifactsPublisher()])
	{
	    checkout scm
	    def mvHelper = new jvm.MavenHelper(this)
	    def config = mvHelper.extractProxyFromEnv()
	    config['file'] = "maven.settings.xml"
	    mvHelper.writeMavenSettingsFile(config)
		sh "mvn -X -e package -U -s maven.settings.xml"
		build job: '/cab/BF/serviceidl-integrationtests/master', 
		      parameters: [string(name: 'build_project', value: env.JOB_NAME), string(name: 'build_id', value: env.BUILD_NUMBER), string(name: 'version', value: '')], 
			  wait: false
	}
}
