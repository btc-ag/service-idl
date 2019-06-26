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
package com.btc.serviceidl.tests.generator.java

import com.btc.serviceidl.generator.DefaultGenerationSettings
import com.btc.serviceidl.generator.java.MavenResolver
import com.btc.serviceidl.generator.java.ParentPOMGenerator
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.google.inject.Inject
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static com.btc.serviceidl.tests.TestExtensions.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class ParentPOMGeneratorTest
{
    @Inject extension ParseHelper<IDLSpecification>

    @Test
    def void testWithVersion()
    {
        val idl = '''version 1.2.3; module foo { interface Bar {}; }'''.parse
        val fsa = new InMemoryFileSystemAccess
        val groupId = 'foo'
        val mavenResolver = new MavenResolver(groupId)
        val generationSettings = new DefaultGenerationSettings()
        val generator = new ParentPOMGenerator(generationSettings, fsa, idl, mavenResolver, groupId)
        generator.generate

        checkFile(fsa, "java" + "pom.xml", '''<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
            <modelVersion>4.0.0</modelVersion>
            <groupId>foo</groupId>
            <artifactId>foo.parent</artifactId>
            <version>1.2.3-SNAPSHOT</version>
            <packaging>pom</packaging>
        
            <properties>
                <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
                <maven.compiler.source>1.8</maven.compiler.source>
                <maven.compiler.target>1.8</maven.compiler.target>
            </properties>
            <modules>
            </modules>
        
            <dependencies>
            </dependencies>
            
            <distributionManagement>
                <repository>
                    <id>cab-maven</id>
                    <name>CAB Main Maven Repository</name>
                    <url>https://artifactory.psi.de/artifactory/cab-maven/</url>
                </repository>
            </distributionManagement>
        </project>
        
        ''')
    }
}
