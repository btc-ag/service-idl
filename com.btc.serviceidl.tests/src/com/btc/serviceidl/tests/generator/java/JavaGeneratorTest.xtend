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
    def void testAttributeWithUnderscore()
    {
        val fileCount = 3
        val baseDirectory = ArtifactNature.JAVA.label + "foo/"
        val directory = baseDirectory + "src/main/java/com/foo/protobuf/"
        val contents = ImmutableMap.of(directory + "TypesCodec.java", '''
package com.foo.protobuf;

import com.btc.cab.servicecomm.api.IError;
import com.foo.common.ComplexPower;
import com.foo.common.ServiceFaultHandlerFactory;
import com.google.protobuf.ByteString;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.util.Collection;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.stream.Collectors;
import org.apache.commons.lang3.exception.ExceptionUtils;

public class TypesCodec {
   
   private static IError encodeException(Exception e)
   {
      Exception cause = (Exception) ExceptionUtils.getRootCause(e);
      return ServiceFaultHandlerFactory.createError(cause);
   }
   
   private static Exception decodeException(String errorType, String message, String stackTrace)
   {
      return ServiceFaultHandlerFactory.createException(errorType, message, stackTrace);
   }
   
   @SuppressWarnings("unchecked")
   public static<TOut, TIn> Collection<TOut> encode(Collection<TIn> plainData) {
      return
         plainData
         .stream()
         .map(item -> (TOut) encode(item))
         .collect(Collectors.toList());
   }
   
   public static<TOut, TIn> Collection<TOut> encodeFailable(Collection<CompletableFuture<TIn>> plainData, Class<TOut> targetType)
   {
      return
         plainData
         .stream()
         .map(item -> encodeFailableWrapper(item, targetType) )
         .collect(Collectors.toList());
   }
   
   private static<TOut, TIn> TOut encodeFailableWrapper(CompletableFuture<TIn> failableData, Class<TOut> targetType)
   {
      try { return encodeFailable(failableData, targetType); }
      catch (Exception e) { throw new RuntimeException(e); }
   }
   
   @SuppressWarnings("unchecked")
   public static<TOut, TIn> Collection<TOut> decode(Collection<TIn> encodedData) {
      return
         encodedData
         .stream()
         .map(item -> (item instanceof ByteString) ? (TOut) decode( (ByteString) item) : (TOut) decode(item))
         .collect(Collectors.toList());
   }
   
   public static ByteString encode(UUID plainData) {
      
      byte[] rawBytes = ByteBuffer.allocate(16)
         .putLong(plainData.getMostSignificantBits())
         .putLong(plainData.getLeastSignificantBits())
         .array();

      return ByteString.copyFrom( switchByteOrder(rawBytes) );
   }
   
   @SuppressWarnings( {"boxing", "unchecked"} )
   private static<TOut, TIn> TOut encodeFailable(CompletableFuture<TIn> failableData, Class<TOut> targetType) throws Exception
   {
      if (failableData == null)
         throw new NullPointerException();
   
      if (failableData.isCompletedExceptionally())
      {
        try
        {
           failableData.get();
        } catch (Exception e) // retrieve and encode underlying exception
        {
           IError error = encodeException(e);
           Method newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
           Object builder = newBuilderMethod.invoke(null);
           Method setExceptionMethod = builder.getClass().getDeclaredMethod("setException", String.class);
           setExceptionMethod.invoke(builder, error.getServerErrorType());
           Method setMessageMethod = builder.getClass().getDeclaredMethod("setMessage", String.class);
           setMessageMethod.invoke(builder, error.getMessage());
           Method setStacktraceMethod = builder.getClass().getDeclaredMethod("setStacktrace", String.class);
           setStacktraceMethod.invoke(builder, error.getServerContextInformation());
           Method buildMethod = builder.getClass().getDeclaredMethod("build");
           return (TOut) buildMethod.invoke(builder);
        }
      }
      else
      {
        TIn plainData = failableData.get();
        Method newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
        Object builder = newBuilderMethod.invoke(null);
        Method getValueMethod = builder.getClass().getDeclaredMethod("getValue");
        Class<?> paramType = getValueMethod.getReturnType();
        Method setValueMethod = builder.getClass().getDeclaredMethod("setValue", paramType);
        setValueMethod.invoke(builder, encode( plainData ));
        Method buildMethod = builder.getClass().getDeclaredMethod("build");
        return (TOut) buildMethod.invoke(builder);
      }
      
      throw new IllegalArgumentException("Unknown target type for encoding: " + targetType.getCanonicalName());
   }
   
   @SuppressWarnings("unchecked")
   public static<TOut, TIn> Collection<CompletableFuture<TOut>> decodeFailable(Collection<TIn> encodedData)
   {
      return
         encodedData
         .stream()
         .map( item -> (CompletableFuture<TOut>) decodeFailableWrapper(item) )
         .collect(Collectors.toList());
   }
   
   private static<TOut, TIn> CompletableFuture<TOut> decodeFailableWrapper(TIn encodedData)
   {
      try { return decodeFailable(encodedData); }
      catch (Exception e) { throw new RuntimeException(e); }
   }
   
   @SuppressWarnings( {"boxing", "unchecked"} )
   public static<TOut, TIn> CompletableFuture<TOut> decodeFailable(TIn encodedData) throws Exception
   {
      if (encodedData == null)
         throw new NullPointerException();

      CompletableFuture<TOut> result = new CompletableFuture<TOut>();
      
      Method hasValueMethod = encodedData.getClass().getDeclaredMethod("hasValue");
      Boolean hasValue = (Boolean) hasValueMethod.invoke(encodedData);
      if (hasValue)
      {
         Method getValueMethod = encodedData.getClass().getDeclaredMethod("getValue");
         Object value = getValueMethod.invoke(encodedData);
         if (encodedData.getClass().getSimpleName().toLowerCase().endsWith("_uuid")) // it's a failable UUID: explicit handling
            result.complete( (TOut) decode( (ByteString) value) );
         else
            result.complete( (TOut) decode(value) );
         return result;
      }
      else
      {
         Method hasExceptionMethod = encodedData.getClass().getDeclaredMethod("hasException");
         Boolean hasException = (Boolean) hasExceptionMethod.invoke(encodedData);
         if (hasException)
         {
            Method getExceptionMethod = encodedData.getClass().getDeclaredMethod("getException");
            String errorType = getExceptionMethod.invoke(encodedData).toString();
            Method getMessageMethod = encodedData.getClass().getDeclaredMethod("getMessage");
            String message = getMessageMethod.invoke(encodedData).toString();
            Method getStacktraceMethod = encodedData.getClass().getDeclaredMethod("getStacktrace");
            String stackTrace = getStacktraceMethod.invoke(encodedData).toString();
            result.completeExceptionally( decodeException(errorType, message, stackTrace) );
            return result;
         }
      }
      
      throw new IllegalArgumentException("Failed to decode the type: " + encodedData.getClass().getCanonicalName());
   }
   
   public static UUID decode(ByteString encodedData) {
      ByteBuffer byteBuffer = ByteBuffer.wrap(switchByteOrder(encodedData.toByteArray()));
      return new UUID(byteBuffer.getLong(), byteBuffer.getLong());
   }
   
   /**
    * Utility function to change the endianness of the given GUID bytes.
    */
   private static byte[] switchByteOrder(byte[] rawBytes) {
      
      // raw GUID data have this format: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
      byte[] switchedBytes = new byte[16];

      // switch AAAAAAAA bytes
      switchedBytes[0] = rawBytes[3];
      switchedBytes[1] = rawBytes[2];
      switchedBytes[2] = rawBytes[1];
      switchedBytes[3] = rawBytes[0];

      // switch BBBB bytes
      switchedBytes[4] = rawBytes[5];
      switchedBytes[5] = rawBytes[4];

      // switch CCCC bytes
      switchedBytes[6] = rawBytes[7];
      switchedBytes[7] = rawBytes[6];

      // switch EEEEEEEEEEEE bytes
      for (int i = 8; i < 16; i++)
         switchedBytes[i] = rawBytes[i];

      return switchedBytes;
   }
   
   @SuppressWarnings("boxing")
   public static Object encode(Object plainData) {
   
      if (plainData == null)
         throw new NullPointerException();
   
      if (plainData instanceof UUID)
         return encode( (UUID) plainData );

      if (plainData instanceof ComplexPower)
      {
         ComplexPower typedData = (ComplexPower) plainData;
         com.foo.protobuf.Types.ComplexPower.Builder builder
            = com.foo.protobuf.Types.ComplexPower.newBuilder();
         builder.setPMw(typedData.getP_MW());
         return builder.build();
      }
      
      return plainData;
   }
   
   @SuppressWarnings("boxing")
   public static Object decode(Object encodedData) {
   
      if (encodedData == null)
         throw new NullPointerException();
   
      if (encodedData instanceof com.foo.protobuf.Types.ComplexPower)
      {
         com.foo.protobuf.Types.ComplexPower typedData = (com.foo.protobuf.Types.ComplexPower) encodedData;
         Double p_MW = typedData.getPMw();
         
         return new ComplexPower (
            p_MW
         );
      }
      
      return encodedData;
   }
}
        ''')

        checkGenerators('''module foo
        {
            struct ComplexPower
            {
                double p_MW;
            };
        }
        ''', setOf(ProjectType.PROTOBUF), fileCount, contents)
    }

    @Test
    def void testBasicServiceApi()
    {
        val fileCount = 3 // TODO this includes the KeyValueStoreServiceFaultHandlerFactory, which should be generated to a different project, and not with these settings
        val baseDirectory = ArtifactNature.JAVA.label + "btc.prins.infrastructure.servicehost.demo.api.keyvaluestore/"
        val directory = baseDirectory +
            "src/main/java/com/btc/prins/infrastructure/servicehost/demo/api/keyvaluestore/serviceapi/"
        val contents = ImmutableMap.of(directory + "IKeyValueStore.java", '''
            package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
            
            import java.util.UUID;
            
            public interface IKeyValueStore {
                UUID TypeGuid = UUID.fromString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
            }
        ''', directory + "KeyValueStoreServiceFaultHandlerFactory.java", // TODO this should not be placed in this module!
        '''
            package com.btc.prins.infrastructure.servicehost.demo.api.keyvaluestore.serviceapi;
            
            import com.btc.cab.servicecomm.api.IError;
            import com.btc.cab.servicecomm.api.IServiceFaultHandler;
            import com.btc.cab.servicecomm.faulthandling.DefaultServiceFaultHandler;
            import com.btc.cab.servicecomm.faulthandling.ErrorMessage;
            import java.lang.IllegalArgumentException;
            import java.lang.UnsupportedOperationException;
            import java.lang.reflect.Constructor;
            import java.util.Optional;
            import org.apache.commons.collections4.BidiMap;
            import org.apache.commons.collections4.bidimap.DualHashBidiMap;
            import org.apache.commons.lang3.exception.ExceptionUtils;
            
            public class KeyValueStoreServiceFaultHandlerFactory
            {
               private static final BidiMap<String, Class> errorMap = new DualHashBidiMap<>();
               
               static
               {
                  
                  // most commonly used exception types
                  errorMap.put("BTC.Commons.Core.InvalidArgumentException", IllegalArgumentException.class);
                  errorMap.put("BTC.Commons.Core.UnsupportedOperationException", UnsupportedOperationException.class);
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
                     Class exception = errorMap.get(errorType);
                     try
                     {
                        Constructor<?> constructor = exception.getConstructor(String.class);
                        return (Exception) constructor.newInstance( new Object[] {message} );
                     } catch (Exception ex)
                     {
                        throw new RuntimeException("Exception when trying to instantiate exception", ex);
                     }
                  }
                  
                  return new Exception(message); // default exception
               }
               
               public static final IError createError(Exception exception)
               {
                  Optional<String> errorType = Optional.empty();
                  for (Class e : errorMap.values())
                  {
                     if (e.equals(exception.getClass()))
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
        ''', baseDirectory + "pom.xml", '''
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
                  <servicecomm.version>0.5.0</servicecomm.version>
                  
                  <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
                  <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
                  
                  <maven.compiler.source>1.8</maven.compiler.source>
                  <maven.compiler.target>1.8</maven.compiler.target>
                  
                  <!-- directory for files generated by the protoc compiler (default = /src/main/java) -->
                  <protobuf.outputDirectory>${project.build.sourceDirectory}</protobuf.outputDirectory>
                  <!-- *.proto source files (default = /src/main/proto) -->
                  <protobuf.sourceDirectory>${basedir}/src/main/proto</protobuf.sourceDirectory>
            
                  <maven-dependency-plugin.version>2.10</maven-dependency-plugin.version>
                  <os-maven-plugin.version>1.4.1.Final</os-maven-plugin.version>
                  <protobuf.version>3.1.0</protobuf.version>
               </properties>
               
               <repositories>
                  <repository>
                     <id>cab-maven-resolver</id>
                     <url>https://artifactory.bop-dev.de/artifactory/cab-maven-resolver/</url>
                     <releases>
                        <enabled>true</enabled>
                     </releases>
                     <snapshots>
                         <enabled>false</enabled>
                     </snapshots>
                  </repository>
               </repositories>
               
               <pluginRepositories>
                  <pluginRepository>
                     <id>cab-maven-plugin-resolver</id>
                     <url>https://artifactory.bop-dev.de/artifactory/cab-maven-resolver/</url>
                     <releases>
                        <enabled>true</enabled>
                     </releases>
                     <snapshots>
                         <enabled>false</enabled>
                     </snapshots>
                  </pluginRepository>
               </pluginRepositories>
            
               <distributionManagement>
               <repository>
                  <id>cab-maven</id>
                  <name>CAB Main Maven Repository</name>
                  <url>https://artifactory.bop-dev.de/artifactory/cab-maven/</url>
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
                  <extensions>
                    <!-- provides os.detected.classifier (i.e. linux-x86_64, osx-x86_64) property -->
                    <extension>
                        <groupId>kr.motd.maven</groupId>
                        <artifactId>os-maven-plugin</artifactId>
                        <version>${os-maven-plugin.version}</version>
                    </extension>
                  </extensions>
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
                          <artifactId>maven-dependency-plugin</artifactId>
                          <version>${maven-dependency-plugin.version}</version>
                          <executions>
                              <execution>
                                  <id>copy-protoc</id>
                                  <phase>generate-sources</phase>
                                  <goals>
                                      <goal>copy</goal>
                                  </goals>
                                  <configuration>
                                      <artifactItems>
                                          <artifactItem>
                                              <groupId>com.google.protobuf</groupId>
                                              <artifactId>protoc</artifactId>
                                              <version>${protobuf.version}</version>
                                              <classifier>${os.detected.classifier}</classifier>
                                              <type>exe</type>
                                              <overWrite>true</overWrite>
                                              <outputDirectory>${project.build.directory}</outputDirectory>
                                          </artifactItem>
                                      </artifactItems>
                                  </configuration>
                              </execution>
                          </executions>
                     </plugin>
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
                                    <property name="protoc.filename" value="protoc-${protobuf.version}-${os.detected.classifier}.exe"/>
                                    <property name="protoc.filepath" value="${project.build.directory}/${protoc.filename}"/>
                                    <chmod file="${protoc.filepath}" perm="ugo+rx"/>
                                    <mkdir dir="${protobuf.outputDirectory}" />
                                    <exec executable="${protoc.filepath}" failonerror="true">
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
