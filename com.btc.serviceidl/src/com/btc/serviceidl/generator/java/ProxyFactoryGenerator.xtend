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
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors(NONE)
class ProxyFactoryGenerator
{
    private val BasicJavaSourceGenerator basicJavaSourceGenerator

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def public generateProxyFactory(String class_name, InterfaceDeclaration interface_declaration)
    {
        val api_type = typeResolver.resolve(interface_declaration)

        '''
        public class «class_name» {
           
           public static «api_type» createDirectProtobufProxy(«typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» endpoint) throws Exception
           {
              return new «GeneratorUtil.getClassName(ArtifactNature.JAVA, ProjectType.PROXY, interface_declaration.name)»(endpoint);
           }
        }
        '''
    }

}
