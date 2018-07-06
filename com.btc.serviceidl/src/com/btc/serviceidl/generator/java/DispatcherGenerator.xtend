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
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class DispatcherGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateDispatcherBody(String dispatcher_class_name, InterfaceDeclaration interface_declaration)
    {
        val api_class_name = typeResolver.resolve(interface_declaration)
        val protobuf_request = resolveProtobuf(typeResolver,
            interface_declaration, Optional.of(ProtobufType.REQUEST))
        val protobuf_response = resolveProtobuf(typeResolver,
            interface_declaration, Optional.of(ProtobufType.RESPONSE))

        val serializerType = typeResolver.resolve("com.btc.cab.servicecomm.serialization.ISerializer")
        val messageType = if (basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3)
                typeResolver.resolve("com.btc.cab.servicecomm.common.IMessageBuffer").toString
            else
                "byte[]"

        '''
            public class «dispatcher_class_name» implements «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceDispatcher")» {
               
               private final «api_class_name» _dispatchee;
            
               «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                   private final «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» _protoBufHelper;
               «ELSE»
                   private final «serializerType» _serializer;
               «ENDIF»
            
               private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceFaultHandlerManager")» _faultHandlerManager;
               
               public «dispatcher_class_name»(«api_class_name» dispatchee, 
               «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                   ProtoBufServerHelper protoBufHelper
               «ELSE»
                   «serializerType» serializer
               «ENDIF»
               ) {
               _dispatchee = dispatchee;
               «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                   _protoBufHelper = protoBufHelper;
               «ELSE»
                   _serializer = serializer;
               «ENDIF»
            
                  // ServiceFaultHandlerManager
                  _faultHandlerManager = new «typeResolver.resolve("com.btc.cab.servicecomm.faulthandling.ServiceFaultHandlerManager")»();
            
                  // ServiceFaultHandler
                  _faultHandlerManager.registerHandler(«typeResolver.resolve(basicJavaSourceGenerator.mavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
               }
               
               /**
                  @see com.btc.cab.servicecomm.api.IServiceDispatcher#processRequest
               */
               @Override
               public «messageType» processRequest(
                  «messageType» requestBuffer, «typeResolver.resolve("com.btc.cab.servicecomm.common.IPeerIdentity")» peerIdentity, «typeResolver.resolve(JavaClassNames.SERVER_ENDPOINT)» serverEndpoint) throws Exception {
                  
                  byte[] requestByte = 
                  «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                      _protoBufHelper.deserializeRequest(requestBuffer)
                  «ELSE»
                      requestBuffer
                  «ENDIF»;
                  «protobuf_request» request
                     = «protobuf_request».parseFrom(requestByte);
                  
                  «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
                      «val is_sync = function.isSync»
                      «val is_void = function.returnedType.isVoid»
                      «val result_type = typeResolver.resolve(function.returnedType)»
                      «val result_is_sequence = function.returnedType.isSequenceType»
                      «val result_is_failable = result_is_sequence && function.returnedType.isFailable»
                      «val result_use_codec = GeneratorUtil.useCodec(function.returnedType, ArtifactNature.JAVA) || result_is_failable»
                      «var result_codec = resolveCodec(function.returnedType, basicJavaSourceGenerator.mavenResolver)»
                      «val request_method_name = function.name.asJavaProtobufName + "Request"»
                      «val response_method_name = '''«protobuf_response».«function.name.asResponse»'''»
                      if (request.has«request_method_name»()) {
                         «val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                         «IF !out_params.empty»
                             // prepare [out] parameters
                             «FOR param : out_params»
                                 «val is_sequence = param.paramType.isSequenceType»
                                 «val is_failable = is_sequence && param.paramType.isFailable»
                             «IF is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(param.paramType.ultimateType)»«IF is_failable»>«ENDIF»>«ELSE»«typeResolver.resolve(param.paramType)»«ENDIF» «param.paramName.asParameter» = «basicJavaSourceGenerator.makeDefaultValue(param.paramType)»;
                         «ENDFOR»
                  «ENDIF»
                  
                  // call actual method
               «IF !is_void»«IF result_is_sequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF result_is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(function.returnedType.ultimateType)»«IF result_is_failable»>«ENDIF»>«ELSE»«result_type»«ENDIF» result = «ENDIF»_dispatchee.«function.name.asMethod»
               (
               «FOR param : function.parameters SEPARATOR ","»
                «val plain_type = typeResolver.resolve(param.paramType)»
                «val is_byte = param.paramType.isByte»
                «val is_short = param.paramType.isInt16»
                «val is_char = param.paramType.isChar»
                «val is_input = (param.direction == ParameterDirection.PARAM_IN)»
                «val use_codec = GeneratorUtil.useCodec(param.paramType, ArtifactNature.JAVA)»
                «var codec = resolveCodec(param.paramType, basicJavaSourceGenerator.mavenResolver)»
                «val is_sequence = param.paramType.isSequenceType»
               «IF is_input»«IF use_codec»«IF !is_sequence»(«plain_type») «ENDIF»«codec».decode(«ENDIF»«IF is_byte || is_short || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»request.get«request_method_name»().get«param.paramName.asJavaProtobufName»«IF is_sequence»List«ENDIF»()«IF use_codec»)«ENDIF»«ELSE»«param.paramName.asParameter»«ENDIF»
               «ENDFOR»
                  )«IF !is_sync».get();«IF is_void» // retrieve the result in order to trigger exceptions«ENDIF»«ELSE»;«ENDIF»
                  
                  // deliver response
                  «response_method_name» methodResponse
               = «response_method_name».newBuilder()
               «IF !is_void».«IF result_is_sequence»addAll«function.name.asJavaProtobufName»«ELSE»set«function.name.asJavaProtobufName»«ENDIF»(«IF result_use_codec»«IF !result_is_sequence»(«resolveProtobuf(typeResolver, function.returnedType, Optional.empty)»)«ENDIF»«result_codec».encode«IF result_is_failable»Failable«ENDIF»(«ENDIF»result«IF result_is_failable», «resolveFailableProtobufType(basicJavaSourceGenerator.mavenResolver, basicJavaSourceGenerator.qualified_name_provider, function.returnedType, interface_declaration)».class«ENDIF»«IF result_use_codec»)«ENDIF»)«ENDIF»
               «FOR out_param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                «val is_sequence = out_param.paramType.isSequenceType»
                «val is_failable = is_sequence && out_param.paramType.isFailable»
                «val use_codec = GeneratorUtil.useCodec(out_param.paramType, ArtifactNature.JAVA) || is_failable»
                «val codec = resolveCodec(out_param.paramType, basicJavaSourceGenerator.mavenResolver)»
                .«IF is_sequence»addAll«out_param.paramName.asJavaProtobufName»«ELSE»set«out_param.paramName.asJavaProtobufName»«ENDIF»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(typeResolver, out_param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«out_param.paramName.asParameter»«IF is_failable», «resolveFailableProtobufType(basicJavaSourceGenerator.mavenResolver, basicJavaSourceGenerator.qualified_name_provider, out_param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
               «ENDFOR»
               .build();
               
               «protobuf_response» response
               = «protobuf_response».newBuilder()
               .set«function.name.asJavaProtobufName»Response(methodResponse)
               .build();
               
               «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                return _protoBufHelper.serializeResponse(response);
               «ELSE»
                return _serializer.serialize(response);
               «ENDIF»
               }
               «ENDFOR»
               
               // request could not be processed
               throw new «typeResolver.resolve("com.btc.cab.servicecomm.api.exceptions.InvalidMessageReceivedException")»("Unknown or invalid request");
               }
            
               /**
               @see com.btc.cab.servicecomm.api.IServiceDispatcher#getServiceFaultHandlerManager
               */
               @Override
               public IServiceFaultHandlerManager getServiceFaultHandlerManager() {
                  return _faultHandlerManager;
               }
            }
        '''
    }

}
