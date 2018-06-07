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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ProxyProtocolGenerator extends ProxyDispatcherGeneratorBase
{
    def generate(String class_name, InterfaceDeclaration interface_declaration)
    {
        val protobuf_request = getProtobufRequestClassName(interface_declaration)
        val protobuf_response = getProtobufResponseClassName(interface_declaration)
        val service_fault_handler = "serviceFaultHandler"

        '''
            internal static class «class_name»
            {
               public static void RegisterServiceFaults(«resolve("BTC.CAB.ServiceComm.NET.API.IServiceFaultHandlerManager")» serviceFaultHandlerManager)
               {
                  var «service_fault_handler» = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.MultipleExceptionTypesServiceFaultHandler")»();
            
                  «makeExceptionRegistration(service_fault_handler, com.btc.serviceidl.util.Util.getRaisedExceptions(interface_declaration))»
                  
                  serviceFaultHandlerManager.RegisterHandler(«service_fault_handler»);
               }
               
               «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
                   «val request_name = com.btc.serviceidl.util.Util.asRequest(function.name)»
                   «val data_contract_name = getDataContractName(interface_declaration, function, ProtobufType.REQUEST)»
                   public static «protobuf_request» Encode_«request_name»(«data_contract_name» arg)
                   {
                      var resultBuilder = «protobuf_request».Types.«request_name»
                         .CreateBuilder()
                         «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                             «val codec = resolveCodec(typeResolver, param_bundle, param.paramType)»
                             «val use_codec = GeneratorUtil.useCodec(param, ArtifactNature.DOTNET)»
                             «val encodeMethod = getEncodeMethod(param.paramType)»
                             .«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»AddRange«ELSE»Set«ENDIF»«param.paramName.toLowerCase.toFirstUpper»(«IF use_codec»(«resolveEncode(param.paramType)») «codec».«encodeMethod»(«ENDIF»arg.«param.paramName.asProperty»«IF use_codec»)«ENDIF»)
                         «ENDFOR»
                         ;
                         
                      return new «protobuf_request»
                         .Builder { «function.name.toLowerCase.toFirstUpper»Request = resultBuilder.Build() }
                         .Build();
                   }
               «ENDFOR»
               
               «FOR function : interface_declaration.functions.filter[!returnedType.isVoid] SEPARATOR System.lineSeparator»
                   «val response_name = getDataContractName(interface_declaration, function, ProtobufType.RESPONSE)»
                   «val protobuf_message = function.name.toLowerCase.toFirstUpper»
                   «val use_codec = GeneratorUtil.useCodec(function.returnedType, ArtifactNature.DOTNET)»
                   «val decodeMethod = getDecodeMethod(function.returnedType)»
                   «val return_type = toText(function.returnedType, function)»
                   «val codec = resolveCodec(typeResolver, param_bundle, function.returnedType)»
                   public static «response_name» Decode_«response_name»(«protobuf_response» arg)
                   {
                      var response = new «response_name»();
                      response.«returnValueProperty» = «IF use_codec»(«return_type») «codec».«decodeMethod»(«ENDIF»arg.«protobuf_message»Response.«protobuf_message»«IF com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)»List«ENDIF»«IF use_codec»)«ENDIF»;
                      return response;
                   }
               «ENDFOR»
            }
        '''
    }
}
