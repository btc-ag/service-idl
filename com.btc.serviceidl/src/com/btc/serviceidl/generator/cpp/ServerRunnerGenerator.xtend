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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class ServerRunnerGenerator extends BasicCppGenerator
{
    def generateImplFileBody(InterfaceDeclaration interface_declaration)
    {
        // explicitly resolve some *.lib dependencies
        resolveClass("BTC::Commons::CoreExtras::IObserver") // IObserverBase used indirectly in dispatcher
        val dispatcher = resolve(interface_declaration, ProjectType.DISPATCHER)

        '''
            «resolveClass("BTC::Commons::Core::UniquePtr")»<«resolveClass("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")»> RegisterMessageTypes()
            {
               auto decoder(«resolveClass("BTC::Commons::Core::CreateUnique")»<«resolveClass("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")»>());
               «resolveClass("BTC::ServiceComm::Default::RegisterBaseMessageTypes")»(*decoder);
               «dispatcher»::RegisterMessageTypes(*decoder);
               return «resolveClass("std::move")»(decoder);
            }
            
            BOOL WINAPI MyCtrlHandler(_In_  DWORD dwCtrlType)
            {
               ExitProcess(0);
            }
            
            int main(int argc, char *argv[])
            {
            
               SetConsoleCtrlHandler(&MyCtrlHandler, true);
            
               «resolveClass("BTC::Commons::CoreYacl::Context")» context;
               «resolveClass("BTC::Commons::Core::BlockStackTraceSettings")» settings(BTC::Commons::Core::BlockStackTraceSettings::BlockStackTraceSettings_OnDefault, BTC::Commons::Core::ConcurrencyScope_Process);
            
               try
               {
                  «resolveClass("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")»().GetLogger("")->SetLevel(«resolveClass("BTC::Logging::API::Logger")»::LWarning);
                  «resolveClass("BTC::ServiceComm::PerformanceBase::PerformanceTestServer")» server(context,
                     «resolveClass("BTC::Commons::Core::CreateAuto")»<«resolve(interface_declaration, ProjectType.IMPL)»>(context, «resolveClass("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")»()),
                     &RegisterMessageTypes,
                     «resolveClass("std::bind")»(&«dispatcher»::CreateDispatcherAutoRegistrationFactory,
                     std::placeholders::_1, std::placeholders::_2,
                     «resolveClass("BTC::ServiceComm::PerformanceBase::PerformanceTestServerBase")»::PERFORMANCE_INSTANCE_GUID(),
                     «resolveClass("BTC::Commons::Core::String")»()));
                  return server.Run(argc, argv);
               }
               catch («resolveClass("BTC::Commons::Core::Exception")» const *e)
               {
                  «resolveClass("BTC::Commons::Core::DelException")» _(e);
                  context.GetStdOut() << e->ToString();
                  return 1;
               }
            }
        '''
    }

    def generateIoC()
    {
        '''
            <?xml version="1.0" encoding="utf-8"?>
            <objects BTC.CAB.IoC.Version="1.2">
               <argument-default argument="loggerFactory" type="BTC.CAB.Logging.Default.AdvancedFileLoggerFactory"/>
               <argument-default argument="connectionString" value="tcp://127.0.0.1:«Constants.DEFAULT_PORT»"/>
               <argument-default argument="threadCount" value="4"/>
               
               <object id="connectionOptions" type="BTC.CAB.ServiceComm.SQ.ZeroMQ.ConnectionOptions">
                  <constructor-arg name="remoteSocketType" value="Router"/>
                  <!-- ENABLE THIS SECTION FOR ZEROMQ ENCRYPTION -->
                  <!--
                  <constructor-arg name="authenticationMode" value="Curve"/>
                  <constructor-arg name="serverSecretKey" value="«Constants.ZMQ_SERVER_PRIVATE_KEY»" />
                  <constructor-arg name="serverPublicKey" value="«Constants.ZMQ_SERVER_PUBLIC_KEY»" />
                  <constructor-arg name="serverAcceptAnyClientKey" value="true"/>
                  -->
               </object>
               
               <object id="taskProcessorParameters" type="BTC.CAB.ServiceComm.SQ.API.TaskProcessorParameters">
                  <constructor-arg name="threadCount" arg-ref="threadCount"/>
               </object>
               
               <object id="connectionFactory" type="BTC.CAB.ServiceComm.SQ.ZeroMQ.CZeroMQConnectionFactory">
                  <constructor-arg name="loggerFactory" arg-ref="loggerFactory"/>
                  <constructor-arg name="connectionOptions" ref="connectionOptions"/>
               </object>
               
               <object id="serverEndpointFactory" type="BTC.CAB.ServiceComm.SQ.Default.CServerEndpointFactory">
                  <constructor-arg name="loggerFactory" arg-ref="loggerFactory"/>
                  <constructor-arg name="serverConnectionFactory" ref="connectionFactory"/>
                  <constructor-arg name="connectionString" arg-ref="connectionString"/>
                  <constructor-arg name="taskProcessorParameters" ref="taskProcessorParameters"/>
               </object>
               
            </objects>
        '''

    }

}
