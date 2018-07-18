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
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.dotnet.Util.*

import static extension com.btc.serviceidl.generator.common.Extensions.*

@Accessors(NONE)
class ServerRegistrationGenerator extends GeneratorBase
{

    def generate(InterfaceDeclaration interfaceDeclaration, String className)
    {
        val basicName = interfaceDeclaration.name
        val constClass = resolve(interfaceDeclaration).alias(getConstName(interfaceDeclaration))

        '''
            internal class «className» : «resolve("System.IDisposable")»
            {
               private readonly «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")» _serverRegistration;
               private «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")».ServerServiceRegistration _serverServiceRegistration;
            
               public «className»(«resolve("BTC.CAB.ServiceComm.NET.API.IServer")» server)
               {
               _serverRegistration = new «resolve("BTC.CAB.ServiceComm.NET.Util.ServerRegistration")»(server);
               }
            
               public void RegisterService()
               {
               // create ServiceDescriptor for «basicName»
               var serviceDescriptor = new «resolve("BTC.CAB.ServiceComm.NET.API.DTO.ServiceDescriptor")»()
               {
                  ServiceTypeGuid = «constClass».«typeGuidProperty»,
                  ServiceTypeName = «constClass».«typeNameProperty»,
                  ServiceInstanceName = "«basicName»TestService",
                  ServiceInstanceDescription = "«resolve(interfaceDeclaration)» instance for integration tests",
                  ServiceInstanceGuid = «resolve("System.Guid")».NewGuid()
               };
            
                  // create «basicName» instance and dispatcher
                  var protoBufServerHelper = new «resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper")»();
                  var dispatchee = new «resolve(interfaceDeclaration, ProjectType.IMPL)»();
                  var dispatcher = new «resolve(interfaceDeclaration, ProjectType.DISPATCHER)»(dispatchee, protoBufServerHelper);
            
                  // register dispatcher
                  _serverServiceRegistration = _serverRegistration.RegisterService(serviceDescriptor, dispatcher);
               }
            
               public void Dispose()
               {
               _serverServiceRegistration.Dispose();
               }
            }
        '''

    }

}
