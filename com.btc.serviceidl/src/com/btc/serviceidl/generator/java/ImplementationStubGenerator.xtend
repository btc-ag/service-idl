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

import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*

import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ImplementationStubGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateImplementationStubBody(String implName, InterfaceDeclaration interfaceDeclaration)
    {
        val apiName = typeResolver.resolve(interfaceDeclaration)
        '''
        public class «implName» implements «apiName» {
           
           «FOR function : interfaceDeclaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
               /**
                  @see «apiName.fullyQualifiedName»#«function.name.toFirstLower»
               */
               @Override
               public «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)» {
                  «makeDefaultMethodStub»
               }
           «ENDFOR»
           
           «FOR event : interfaceDeclaration.namedEvents»
               «val observableName = basicJavaSourceGenerator.toText(event)»
               /**
                  @see «apiName»#get«observableName»
               */
               @Override
               public «observableName» get«observableName»() {
                  «makeDefaultMethodStub»
               }
           «ENDFOR»
        }
        '''
    }

}
