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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.generator.AbstractGeneratorTest
import com.btc.serviceidl.tests.testdata.TestData
import com.google.common.collect.ImmutableMap
import java.util.Arrays
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.junit.Test
import org.junit.runner.RunWith

import static com.btc.serviceidl.tests.TestExtensions.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class JavaGeneratorTest extends AbstractGeneratorTest
{
    @Test
    def void testBasicServiceApi()
    {
        val fileCount = 3 // TODO this includes the KeyValueStoreServiceFaultHandlerFactory, which should be generated to a different project, and not with these settings
        val baseDirectory = IFileSystemAccess::DEFAULT_OUTPUT +
            "java/btc.prins.infrastructure.servicehost.demo.api.keyvaluestore/"
        val directory = baseDirectory +
            "src/main/java/com/btc/prins/infrastructure/servicehost/demo/api/keyvaluestore/serviceapi/"
        val contents = ImmutableMap.of(directory + "KeyValueStore.java", '''
            package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
            
            import java.util.UUID;
            
            public interface KeyValueStore {
                UUID TypeGuid = UUID.fromString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
            }
        ''', directory + "KeyValueStoreServiceFaultHandlerFactory.java", 
        '''
        package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
        
        import com.btc.cab.servicecomm.api.IError;
        import com.btc.cab.servicecomm.api.IServiceFaultHandler;
        import com.btc.cab.servicecomm.faulthandling.DefaultServiceFaultHandler;
        import com.btc.cab.servicecomm.faulthandling.ErrorMessage;
        import java.lang.reflect.Constructor;
        import java.util.Optional;
        import org.apache.commons.collections4.BidiMap;
        import org.apache.commons.collections4.bidimap.DualHashBidiMap;
        import org.apache.commons.lang3.exception.ExceptionUtils;
        
        public class KeyValueStoreServiceFaultHandlerFactory
        {
           private static final BidiMap<String, Exception> errorMap = new DualHashBidiMap<>();
           
           static
           {
              
              // most commonly used exception types
              errorMap.put("BTC.Commons.Core.InvalidArgumentException", new IllegalArgumentException());
              errorMap.put("BTC.Commons.Core.UnsupportedOperationException", new UnsupportedOperationException());
           }
           
           public static final IServiceFaultHandler createServiceFaultHandler()
           {
              DefaultServiceFaultHandler serviceFaultHandler = new DefaultServiceFaultHandler();
              errorMap.forEach( (key, value) -> serviceFaultHandler.registerException(key, value) );
              return serviceFaultHandler;
              
           }
           
           public static final Exception createException(String errorType, String message, String stackTrace)
           {
              if (errorMap.containsKey(errorType))
              {
                 Exception exception = errorMap.get(errorType);
                 try
                 {
                    Constructor<?> constructor = exception.getClass().getConstructor(String.class);
                    return (Exception) constructor.newInstance( new Object[] {message} );
                 } catch (Exception ex)
                 {
                    return exception;
                 }
              }
              
              return new Exception(message); // default exception
           }
           
           public static final IError createError(Exception exception)
           {
              Optional<String> errorType = Optional.empty();
              for (Exception e : errorMap.values())
              {
                 if (e.getClass().equals(exception.getClass()))
                 {
                    errorType = Optional.of(errorMap.inverseBidiMap().get(e));
                    break;
                 }
              }
              IError error = new ErrorMessage(
                  exception.getMessage(),
                  errorType.isPresent() ? errorType.get() : exception.getClass().getName(),
                  ExceptionUtils.getStackTrace(exception));
              return error;
           }
        }
        ''', baseDirectory + "pom.xml", 
        '''
        <project xmlns="http://maven.apache.org/POM/4.0.0"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
                                     http://maven.apache.org/xsd/maven-4.0.0.xsd">
        
           <modelVersion>4.0.0</modelVersion>
        
           <groupId>com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore</groupId>
           <artifactId>com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore</artifactId>
           <version>1.0.0</version>
        
           <properties>
              <!-- ServiceComm properties -->
              <servicecomm.version>0.3.0</servicecomm.version>
              
              <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
              <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
              
              <maven.compiler.source>1.8</maven.compiler.source>
              <maven.compiler.target>1.8</maven.compiler.target>
              
              <!-- directory for files generated by the protoc compiler (default = /src/main/java) -->
              <protobuf.outputDirectory>${project.build.sourceDirectory}</protobuf.outputDirectory>
              <!-- *.proto source files (default = /src/main/proto) -->
              <protobuf.sourceDirectory>${basedir}/src/main/proto</protobuf.sourceDirectory>
              <!-- directory containing the protoc executable (default = %PROTOC_HOME% environment variable) -->
              <protobuf.binDirectory>${PROTOC_HOME}</protobuf.binDirectory>
           </properties>
           
           <repositories>
              <repository>
                 <id>cab-maven-resolver</id>
                 <url>http://artifactory.bop-dev.de/artifactory/cab-maven-resolver//</url>
                 <releases>
                    <enabled>true</enabled>
                 </releases>
                 <snapshots>
                     <enabled>false</enabled>
                 </snapshots>
              </repository>
           </repositories>
           
           <distributionManagement>
              <repository>
                 <id>cab-maven</id>
                 <name>CAB Main Maven Repository</name>
                 <url>http://artifactory.bop-dev.de/artifactory/cab-maven/</url>
              </repository>
           </distributionManagement>
           
           <dependencies>
              <dependency>
                 <groupId>com.btc.cab.servicecomm</groupId>
                 <artifactId>api</artifactId>
                 <version>${servicecomm.version}</version>
              </dependency>
              <dependency>
                 <groupId>org.apache.commons</groupId>
                 <artifactId>commons-collections4</artifactId>
                 <version>4.0</version>
              </dependency>
              <dependency>
                 <groupId>com.btc.cab.servicecomm</groupId>
                 <artifactId>faulthandling</artifactId>
                 <version>${servicecomm.version}</version>
              </dependency>
              <dependency>
                 <groupId>org.apache.commons</groupId>
                 <artifactId>commons-lang3</artifactId>
                 <version>3.0</version>
              </dependency>
           </dependencies>
        
           <build>
              <pluginManagement>
                 <plugins>
                    <plugin>
                       <groupId>org.eclipse.m2e</groupId>
                       <artifactId>lifecycle-mapping</artifactId>
                       <version>1.0.0</version>
                       <configuration>
                          <lifecycleMappingMetadata>
                             <pluginExecutions>
                                <pluginExecution>
                                   <pluginExecutionFilter>
                                      <groupId>org.apache.maven.plugins</groupId>
                                      <artifactId>maven-antrun-plugin</artifactId>
                                      <versionRange>[1.0.0,)</versionRange>
                                      <goals>
                                         <goal>run</goal>
                                      </goals>
                                   </pluginExecutionFilter>
                                   <action>
                                      <execute />
                                   </action>
                                </pluginExecution>
                             </pluginExecutions>
                          </lifecycleMappingMetadata>
                       </configuration>
                    </plugin>
                 </plugins>
              </pluginManagement>
              <plugins>
                 <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-antrun-plugin</artifactId>
                    <version>1.8</version>
                    <executions>
                       <execution>
                          <id>generate-sources</id>
                          <phase>generate-sources</phase>
                          <configuration>
                             <target>
                                <mkdir dir="${protobuf.outputDirectory}" />
                                <exec executable="${protobuf.binDirectory}/protoc">
                                   <arg value="--java_out=${protobuf.outputDirectory}" />
                                   <arg value="-I=${basedir}\.." />
                                   <arg value="--proto_path=${protobuf.sourceDirectory}" />
                                </exec> 
                             </target>
                          </configuration>
                          <goals>
                             <goal>run</goal>
                          </goals>
                       </execution>
                    </executions>
                 </plugin>
                 <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <version>3.3</version>
                    <configuration>
                       <source>1.8</source>
                       <target>1.8</target>
                    </configuration>
                 </plugin>
              </plugins>
           </build>
        
        </project>
        ''')

        checkGenerators(TestData.basic, setOf(ProjectType.SERVICE_API), fileCount, contents)
    }

    def void checkGenerators(CharSequence input, Set<ProjectType> projectTypes, int fileCount,
        Map<String, String> contents)
    {
        checkGenerators(input, new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.JAVA)), projectTypes, fileCount,
            contents)
    }
}
