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

package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.util.Util
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
final class InterfaceProtobufFileGenerator extends ProtobufFileGeneratorBase
{
    def String generateInterface(InterfaceDeclaration interfaceDeclaration)
    {
        var requestPartId = 1
        var responsePartId = 1

        var fileBody = '''
            «generateFailable(interfaceDeclaration)»
            «generateTypes(interfaceDeclaration, interfaceDeclaration.contains.toList)»
            
            message «interfaceDeclaration.name.asRequest»
            {
               «FOR function : interfaceDeclaration.functions SEPARATOR System.lineSeparator»
                   message «function.name.asRequest»
                   {
                      «val fieldId = new Counter»
                      «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                          «IF Util.isSequenceType(param.paramType)»
                              «makeSequence(Util.getUltimateType(param.paramType), Util.isFailable(param.paramType), param, interfaceDeclaration, param.protoFileAttributeName, fieldId)»
                          «ELSE»
                              required «resolve(param.paramType, interfaceDeclaration, interfaceDeclaration)» «param.protoFileAttributeName» = «fieldId.incrementAndGet»;
                          «ENDIF»
                      «ENDFOR»
                   }
               «ENDFOR»
            
               «FOR function : interfaceDeclaration.functions»
                   «val messagePart = function.name.asRequest»
                   optional «messagePart» «messagePart.asProtoFileAttributeName» = «requestPartId++»;
               «ENDFOR»
            }
            
            message «interfaceDeclaration.name.asResponse»
            {
               «FOR function : interfaceDeclaration.functions SEPARATOR System.lineSeparator»
                   message «function.name.asResponse»
                   {
                      «val fieldId = new Counter»
                      «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                          «IF Util.isSequenceType(param.paramType)»
                              «val sequence = Util.tryGetSequence(param.paramType).get»
                              «toText(sequence, param, interfaceDeclaration, fieldId)»
                          «ELSE»
                              required «resolve(param.paramType, interfaceDeclaration, interfaceDeclaration)» «param.protoFileAttributeName» = «fieldId.incrementAndGet»;
                          «ENDIF»
                      «ENDFOR»
                      «generateReturnType(function, interfaceDeclaration, interfaceDeclaration, fieldId)»
                   }
               «ENDFOR»
            
               «FOR function : interfaceDeclaration.functions»
                   «val messagePart = function.name.asResponse»
                   optional «messagePart» «messagePart.asProtoFileAttributeName» = «responsePartId++»;
               «ENDFOR»
            }
        '''

        var file_header = '''
            «generatePackageName(interfaceDeclaration)»
            «generateImports(interfaceDeclaration)»
        '''

        return file_header + fileBody
    }

    private def String generateReturnType(FunctionDeclaration function, EObject context, EObject container,
        Counter id)
    {
        val element = function.returnedType
        '''
            «IF !element.isVoid»
                «IF requiresNewMessageType(element)»
                    «toText(element, function, container, id)»
                «ELSE»
                    «IF Util.isSequenceType(element)»
                        «toText(element, function, container, id)»
                    «ELSE»
                        required «resolve(element, context, container)» «function.protoFileAttributeName» = «id.incrementAndGet»;
                    «ENDIF»
                «ENDIF»
            «ENDIF»
        '''
    }

}
