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

import org.eclipse.xtend.lib.annotations.Accessors
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ArtifactNature

@Accessors(NONE)
class ProxyFactoryGenerator extends GeneratorBase
{

    def generate(InterfaceDeclaration interfaceDeclaration, String className)
    {
        '''
            public class «className»
            {
               public static «resolve(interfaceDeclaration).shortName» CreateProtobufProxy(«resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» endpoint)
               {
                  return new «GeneratorUtil.getClassName(ArtifactNature.DOTNET, ProjectType.PROXY, interfaceDeclaration.name)»(endpoint);
               }
            }
        '''

    }

}
