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

  private def getParam_bundle()
  {
      basicCSharpSourceGenerator.typeResolver.param_bundle
  } 
    
  def generateAppConfig(ModuleDeclaration module)
  {
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
      
        <log4net configSource="«param_bundle.log4NetConfigFile»" />
      
        <spring>
          <context>
            <resource uri="config://spring/objects" />
          </context>
          <objects xmlns="http://www.springframework.net">
            <object id="BTC.CAB.Logging.API.NET.LoggerFactory" type="«typeResolver.resolve("BTC.CAB.Logging.Log4NET.Log4NETLoggerFactory").fullyQualifiedName», BTC.CAB.Logging.Log4NET"/>
            
            «IF param_bundle.projectType == ProjectType.SERVER_RUNNER»
               «val protobuf_server_helper = typeResolver.resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper").fullyQualifiedName»
               «val service_descriptor = '''«typeResolver.resolve("BTC.CAB.ServiceComm.NET.API.DTO.ServiceDescriptor").fullyQualifiedName»'''»
               «val service_dispatcher = typeResolver.resolve("BTC.CAB.ServiceComm.NET.API.IServiceDispatcher").fullyQualifiedName»
               <!--ZeroMQ server factory-->
               <object id="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ">
                 <constructor-arg name="connectionOptions" expression="T(BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory, BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ).DefaultServerConnectionOptions" />
                 <constructor-arg name="loggerFactory" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
               </object>
               <object id="BTC.CAB.ServiceComm.NET.ServerRunner.ServerFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.ServerFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.Core">
                 <constructor-arg index="0" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
                 <constructor-arg index="1" ref="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" />
                 <constructor-arg index="2" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
               </object>

               <object id="«protobuf_server_helper»" type="«protobuf_server_helper», BTC.CAB.ServiceComm.NET.ProtobufUtil"/>

               «FOR interface_declaration : module.moduleComponents.filter(InterfaceDeclaration)»
                  «val api = typeResolver.resolve(interface_declaration)»
                  «val impl = typeResolver.resolve(interface_declaration, ProjectType.IMPL)»
                  «val dispatcher = typeResolver.resolve(interface_declaration, ProjectType.DISPATCHER)»
                  <!-- «interface_declaration.name» Service -->
                  <object id="«dispatcher».ServiceDescriptor" type="«service_descriptor», BTC.CAB.ServiceComm.NET.API">
                    <constructor-arg name="typeGuid" expression="T(«api.namespace».«getConstName(interface_declaration)», «api.namespace»).«typeGuidProperty»"/>
                    <constructor-arg name="typeName" expression="T(«api.namespace».«getConstName(interface_declaration)», «api.namespace»).«typeNameProperty»"/>
                    <constructor-arg name="instanceGuid" expression="T(System.Guid, mscorlib).NewGuid()"/>
                    <constructor-arg name="instanceName" value="PerformanceTestService"/>
                    <constructor-arg name="instanceDescription" value="«api» instance for performance tests"/>
                  </object>
                  <object id="«impl»" type="«impl», «impl.namespace»"/>
                  <object id="«dispatcher»" type="«dispatcher», «dispatcher.namespace»">
                    <constructor-arg index="0" ref="«impl»" />
                    <constructor-arg index="1" ref="«protobuf_server_helper»" />
                  </object>
               «ENDFOR»
               
               <!-- Service Dictionary -->
               <object id="BTC.CAB.ServiceComm.NET.ServerRunner.SpringServerRunner.Services" type="«typeResolver.resolve("System.Collections.Generic.Dictionary").fullyQualifiedName»&lt;«service_descriptor», «service_dispatcher»>">
                 <constructor-arg>
                   <dictionary key-type="«service_descriptor»" value-type="«service_dispatcher»">
                     «FOR interface_declaration : module.moduleComponents.filter(InterfaceDeclaration)»
                        «val dispatcher = typeResolver.resolve(interface_declaration, ProjectType.DISPATCHER)»
                        <entry key-ref="«dispatcher».ServiceDescriptor" value-ref="«dispatcher»" />
                     «ENDFOR»
                   </dictionary>
                 </constructor-arg>
               </object>
            «ELSEIF param_bundle.projectType == ProjectType.CLIENT_CONSOLE»
               <!--ZeroMQ client factory-->
               <object id="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ">
                 <constructor-arg name="connectionOptions" expression="T(BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ.NetMqConnectionFactory, BTC.CAB.ServiceComm.NET.SingleQueue.ZeroMQ.NetMQ).DefaultClientConnectionOptions" />
                 <constructor-arg name="loggerFactory" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
               </object>
               <object id="BTC.CAB.ServiceComm.NET.API.ClientFactory" type="«typeResolver.resolve("BTC.CAB.ServiceComm.NET.SingleQueue.Core.ClientFactory").fullyQualifiedName», BTC.CAB.ServiceComm.NET.SingleQueue.Core">
                 <constructor-arg index="0" ref="BTC.CAB.Logging.API.NET.LoggerFactory" />
                 <constructor-arg index="1" ref="BTC.CAB.ServiceComm.NET.SingleQueue.API.ConnectionFactory" />
                 <constructor-arg index="2" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
               </object>
            «ENDIF»
            
          </objects>
        </spring>
        
        <startup>
          <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.0"/>
        </startup>
      </configuration>
      '''      
  }    
}
