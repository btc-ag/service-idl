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
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*

@Accessors(NONE)
class AppConfigGenerator {
  val extension BasicCSharpSourceGenerator basicCSharpSourceGenerator
  
  private def getTypeResolver()
  {
      basicCSharpSourceGenerator.typeResolver
  } 

  private def getParameterBundle()
  {
      basicCSharpSourceGenerator.typeResolver.parameterBundle
  } 
    
  // TODO for some reason, the return type must be specified here, otherwise we get compile errors
  // on Jenkins (but not on travis-ci)
  def CharSequence generateAppConfig(ModuleDeclaration module)
  {
      val scv_V0_6 = getTargetVersion() == ServiceCommVersion.V0_6
      
      '''
      <?xml version="1.0"?>
      <configuration>
        <configSections>
          <section name="log4net" type="«typeResolver.resolve("log4net.Config.Log4NetConfigurationSectionHandler").fullyQualifiedName», log4net" requirePermission="false"/>
          <sectionGroup name="spring">
            <section name="context" type="«typeResolver.resolve("Spring.Context.Support.ContextHandler").fullyQualifiedName», Spring.Core" />
            <section name="objects" type="«typeResolver.resolve("Spring.Context.Support.DefaultSectionHandler").fullyQualifiedName», Spring.Core" />
          </sectionGroup>
        </configSections>
      
        <log4net configSource="«parameterBundle.log4NetConfigFile»" />
      
        <spring>
          <context>
            <resource uri="config://spring/objects" />
          </context>
          <objects xmlns="http://www.springframework.net">
            <object id="BTC.CAB.Logging.API.NET.LoggerFactory" type="«typeResolver.resolve("BTC.CAB.Logging.Log4NET.Log4NETLoggerFactory").fullyQualifiedName», BTC.CAB.Logging.Log4NET"/>
            «IF !scv_V0_6»
               <object id="BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManagerFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManagerFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.FaultHandling"/>
            «ENDIF»
            
            «IF parameterBundle.projectType == ProjectType.SERVER_RUNNER»
               «val protobufServerHelper = typeResolver.resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper").fullyQualifiedName»
               «val serviceDescriptor = '''«typeResolver.resolve("BTC.CAB.ServiceComm.NET.API.DTO.ServiceDescriptor").fullyQualifiedName»'''»
               «val serviceDispatcher = typeResolver.resolve("BTC.CAB.ServiceComm.NET.API.IServiceDispatcher").fullyQualifiedName»
               <!--ZeroMQ server factory-->
               <object id="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ">
                 <constructor-arg name="connectionOptions" expression="T(BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory, BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ).DefaultServerConnectionOptions" />
                 <constructor-arg name="loggerFactory" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
               </object>
               <object id="BTC.CAB.ServiceComm.NET.ServerRunner.ServerFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.ServerFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.Core">
                 <constructor-arg index="0" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
                 <constructor-arg index="1" ref="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" />
                 <constructor-arg index="2" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
                 «IF !scv_V0_6»
                    <constructor-arg index="3" ref="BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManagerFactory"/>
                 «ENDIF»
               </object>

               <object id="«protobufServerHelper»" type="«protobufServerHelper», BTC.CAB.ServiceComm.NET.ProtobufUtil"/>

               «FOR interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration)»
                  «val api = typeResolver.resolve(interfaceDeclaration)»
                  «val impl = typeResolver.resolve(interfaceDeclaration, ProjectType.IMPL)»
                  «val dispatcher = typeResolver.resolve(interfaceDeclaration, ProjectType.DISPATCHER)»
                  <!-- «interfaceDeclaration.name» Service -->
                  <object id="«dispatcher».ServiceDescriptor" type="«serviceDescriptor», BTC.CAB.ServiceComm.NET.API">
                    <constructor-arg name="typeGuid" expression="T(«api.namespace».«getConstName(interfaceDeclaration)», «api.namespace»).«typeGuidProperty»"/>
                    <constructor-arg name="typeName" expression="T(«api.namespace».«getConstName(interfaceDeclaration)», «api.namespace»).«typeNameProperty»"/>
                    <constructor-arg name="instanceGuid" expression="T(System.Guid, mscorlib).NewGuid()"/>
                    <constructor-arg name="instanceName" value="PerformanceTestService"/>
                    <constructor-arg name="instanceDescription" value="«api» instance for performance tests"/>
                  </object>
                  <object id="«impl»" type="«impl», «impl.namespace»"/>
                  <object id="«dispatcher»" type="«dispatcher», «dispatcher.namespace»">
                    <constructor-arg index="0" ref="«impl»" />
                    <constructor-arg index="1" ref="«protobufServerHelper»" />
                  </object>
               «ENDFOR»
               
               <!-- Service Dictionary -->
               <object id="BTC.CAB.ServiceComm.NET.ServerRunner.SpringServerRunner.Services" type="«typeResolver.resolve("System.Collections.Generic.Dictionary").fullyQualifiedName»&lt;«serviceDescriptor», «serviceDispatcher»>">
                 <constructor-arg>
                   <dictionary key-type="«serviceDescriptor»" value-type="«serviceDispatcher»">
                     «FOR interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration)»
                        «val dispatcher = typeResolver.resolve(interfaceDeclaration, ProjectType.DISPATCHER)»
                        <entry key-ref="«dispatcher».ServiceDescriptor" value-ref="«dispatcher»" />
                     «ENDFOR»
                   </dictionary>
                 </constructor-arg>
               </object>
            «ELSEIF parameterBundle.projectType == ProjectType.CLIENT_CONSOLE»
               <!--ZeroMQ client factory-->
               <object id="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ">
                 <constructor-arg name="connectionOptions" expression="T(BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory, BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ).DefaultClientConnectionOptions" />
                 <constructor-arg name="loggerFactory" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
               </object>
               <object id="BTC.CAB.ServiceComm.NET.API.ClientFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.ClientFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.Core">
                 <constructor-arg index="0" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
                 <constructor-arg index="1" ref="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" />
                 <constructor-arg index="2" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
                 «IF !scv_V0_6»
                    <constructor-arg index="3" ref="BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManagerFactory"/>
                 «ENDIF»
               </object>
            «ENDIF»
            
          </objects>
        </spring>
        
        <startup>
          <supportedRuntime version="v4.0" sku=".NETFramework,Version=v«DotNetGenerator.DOTNET_FRAMEWORK_VERSION.toString»"/>
        </startup>
      </configuration>
      '''      
  }    
}
