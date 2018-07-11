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

import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ImplementationStubGenerator extends GeneratorBase
{

    private def makeImplementatonStub(FunctionDeclaration function)
    {
        val is_void = function.returnedType instanceof VoidType

        '''
            «IF !function.sync»
                // TODO Auto-generated method stub
                «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                    «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                «ENDFOR»
                return «resolve("System.Threading.Tasks.Task")»«IF !is_void»<«toText(function.returnedType, function)»>«ENDIF».Factory.StartNew(() => { throw new «resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»"); });
            «ELSE»
                «makeDefaultMethodStub(typeResolver)»
            «ENDIF»
        '''
    }

    def generate(InterfaceDeclaration interface_declaration, String impl_class_name)
    {
        val api_fully_qualified_name = resolve(interface_declaration)

        val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)
        '''
            public class «impl_class_name» : «IF anonymous_event !== null»«resolve("BTC.CAB.ServiceComm.NET.Base.ABasicObservable")»<«resolve(anonymous_event.data)»>, «ENDIF»«api_fully_qualified_name.shortName»
            {
               «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
                   /// <see cref="«api_fully_qualified_name».«function.name»"/>
                   public «typeResolver.makeReturnType(function)» «function.name»(
                      «FOR param : function.parameters SEPARATOR ","»
                          «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function).asParameter»
                      «ENDFOR»
                   )
                   {
                      «makeImplementatonStub(function)»
                   }
               «ENDFOR»
               
               «FOR event : interface_declaration.events.filter[name !== null]»
                   «val event_name = toText(event, interface_declaration)»
                   /// <see cref="«api_fully_qualified_name».Get«event_name»"/>
                   public «event_name» Get«event_name»()
                   {
                      «makeDefaultMethodStub(typeResolver)»
                   }
               «ENDFOR»
            }
        '''

    }

}
