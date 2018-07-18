/*********************************************************************
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ArtifactNature
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess

@Accessors(NONE)
class ParentPOMGenerator
{
    val IFileSystemAccess fileSystemAccess
    val MavenResolver mavenResolver
    val String groupId    

    def generate()
    {
        this.fileSystemAccess.generateFile("pom.xml", ArtifactNature.JAVA.label, generateContents)
    }

    def CharSequence generateContents()
    {
        '''
            <project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
                <modelVersion>4.0.0</modelVersion>
                <groupId>«groupId»</groupId>
                <artifactId>«groupId».parent</artifactId>
                <version>1.0.0-SNAPSHOT</version>
                <packaging>pom</packaging>
            
                <properties>
                    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
                    <maven.compiler.source>1.8</maven.compiler.source>
                    <maven.compiler.target>1.8</maven.compiler.target>
                </properties>
                <modules>
                «FOR packageId : mavenResolver.registeredPackages»
                    <module>«packageId»</module>
                «ENDFOR»
                </modules>
            
                <dependencies>
                </dependencies>
                
                <distributionManagement>
                    <repository>
                        <id>cab-maven</id>
                        <name>CAB Main Maven Repository</name>
                        <url>https://artifactory.bop-dev.de/artifactory/cab-maven/</url>
                    </repository>
                </distributionManagement>
            </project>
        '''
    }

}
