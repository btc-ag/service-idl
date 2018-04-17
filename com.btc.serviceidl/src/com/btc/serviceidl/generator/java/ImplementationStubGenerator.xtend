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

import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*

import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ImplementationStubGenerator
{
    private val BasicJavaSourceGenerator basicJavaSourceGenerator

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateImplementationStubBody(String impl_name, InterfaceDeclaration interface_declaration)
    {
        val api_name = typeResolver.resolve(interface_declaration)
        '''
        public class «impl_name» implements «api_name» {
           
           «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
               /**
                  @see «api_name.fullyQualifiedName»#«function.name.toFirstLower»
               */
               @Override
               public «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)» {
                  «makeDefaultMethodStub»
               }
           «ENDFOR»
           
           «FOR event : interface_declaration.namedEvents»
               «val observable_name = basicJavaSourceGenerator.toText(event)»
               /**
                  @see «api_name»#get«observable_name»
               */
               @Override
               public «observable_name» get«observable_name»() {
                  «makeDefaultMethodStub»
               }
           «ENDFOR»
        }
        '''
    }

}
