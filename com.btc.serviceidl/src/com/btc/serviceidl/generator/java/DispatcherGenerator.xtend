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
import com.btc.serviceidl.idl.VoidType
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

    def generateDispatcherBody(String dispatcherClassName, InterfaceDeclaration interfaceDeclaration)
    {
        val apiClassName = typeResolver.resolve(interfaceDeclaration)
        val protobufRequest = resolveProtobuf(typeResolver,
            interfaceDeclaration, Optional.of(ProtobufType.REQUEST))
        val protobuf_response = resolveProtobuf(typeResolver,
            interfaceDeclaration, Optional.of(ProtobufType.RESPONSE))

        val serializerType = typeResolver.resolve("com.btc.cab.servicecomm.serialization.ISerializer")
        val messageType = if (basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3)
                typeResolver.resolve("com.btc.cab.servicecomm.common.IMessageBuffer").toString
            else
                "byte[]"

        '''
            public class «dispatcherClassName» implements «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceDispatcher")» {
               
               private final «apiClassName» _dispatchee;
            
               «IF basicJavaSourceGenerator.targetVersion == ServiceCommVersion.V0_3»
                   private final «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtoBufServerHelper")» _protoBufHelper;
               «ELSE»
                   private final «serializerType» _serializer;
               «ENDIF»
            
               private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceFaultHandlerManager")» _faultHandlerManager;
               
               public «dispatcherClassName»(«apiClassName» dispatchee, 
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
                  _faultHandlerManager.registerHandler(«typeResolver.resolve(basicJavaSourceGenerator.typeResolver.resolvePackage(interfaceDeclaration, ProjectType.SERVICE_API) + '''.«interfaceDeclaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
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
                  «protobufRequest» request
                     = «protobufRequest».parseFrom(requestByte);
                  
                  «FOR function : interfaceDeclaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
                      «val isSync = function.isSync»
                      «val isVoid = function.returnedType instanceof VoidType»
                      «val resultType = typeResolver.resolve(function.returnedType)»
                      «val resultIsSequence = function.returnedType.isSequenceType»
                      «val resultIsFailable = resultIsSequence && function.returnedType.isFailable»
                      «val resultUseCodec = GeneratorUtil.useCodec(function.returnedType.actualType, ArtifactNature.JAVA) || resultIsFailable»
                      «var resultCodec = if (resultUseCodec) resolveCodec(function.returnedType.actualType, typeResolver) else null»
                      «val requestMethodName = function.name.asJavaProtobufName + "Request"»
                      «val responseMethodName = '''«protobuf_response».«function.name.asResponse»'''»
                      if (request.has«requestMethodName»()) {
                         «val outParams = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                         «IF !outParams.empty»
                             // prepare [out] parameters
                             «FOR param : outParams»
                                 «val isSequence = param.paramType.isSequenceType»
                                 «val isFailable = isSequence && param.paramType.isFailable»
                             «IF isSequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF isFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(param.paramType.ultimateType)»«IF isFailable»>«ENDIF»>«ELSE»«typeResolver.resolve(param.paramType)»«ENDIF» «param.paramName.asParameter» = «basicJavaSourceGenerator.makeDefaultValue(param.paramType)»;
                         «ENDFOR»
                  «ENDIF»
                  
                  // call actual method
               «IF !isVoid»«IF resultIsSequence»«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF resultIsFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«typeResolver.resolve(function.returnedType.actualType.ultimateType)»«IF resultIsFailable»>«ENDIF»>«ELSE»«resultType»«ENDIF» result = «ENDIF»_dispatchee.«function.name.asMethod»
               (
               «FOR param : function.parameters SEPARATOR ","»
                «val plainType = typeResolver.resolve(param.paramType)»
                «val isByte = param.paramType.isByte»
                «val isShort = param.paramType.isInt16»
                «val isChar = param.paramType.isChar»
                «val isInput = (param.direction == ParameterDirection.PARAM_IN)»
                «val useCodec = GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.JAVA)»
                «var codec = resolveCodec(param.paramType.actualType, typeResolver)»
                «val isSequence = param.paramType.isSequenceType»
               «IF isInput»«IF useCodec»«IF !isSequence»(«plainType») «ENDIF»«codec».decode(«ENDIF»«IF isByte || isShort || isChar»(«IF isByte»byte«ELSEIF isChar»char«ELSE»short«ENDIF») «ENDIF»request.get«requestMethodName»().get«param.paramName.asJavaProtobufName»«IF isSequence»List«ENDIF»()«IF useCodec»)«ENDIF»«ELSE»«param.paramName.asParameter»«ENDIF»
               «ENDFOR»
                  )«IF !isSync».get();«IF isVoid» // retrieve the result in order to trigger exceptions«ENDIF»«ELSE»;«ENDIF»
                  
                  // deliver response
                  «responseMethodName» methodResponse
               = «responseMethodName».newBuilder()
               «IF !isVoid».«IF resultIsSequence»addAll«function.name.asJavaProtobufName»«ELSE»set«function.name.asJavaProtobufName»«ENDIF»(«IF resultUseCodec»«IF !resultIsSequence»(«resolveProtobuf(typeResolver, function.returnedType.actualType, Optional.empty)»)«ENDIF»«resultCodec».encode«IF resultIsFailable»Failable«ENDIF»(«ENDIF»result«IF resultIsFailable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualifiedNameProvider, function.returnedType.actualType, interfaceDeclaration)».class«ENDIF»«IF resultUseCodec»)«ENDIF»)«ENDIF»
               «FOR outParam : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                «val isSequence = outParam.paramType.isSequenceType»
                «val isFailable = isSequence && outParam.paramType.isFailable»
                «val useCodec = GeneratorUtil.useCodec(outParam.paramType.actualType, ArtifactNature.JAVA) || isFailable»
                «val codec = resolveCodec(outParam.paramType.actualType, typeResolver)»
                .«IF isSequence»addAll«outParam.paramName.asJavaProtobufName»«ELSE»set«outParam.paramName.asJavaProtobufName»«ENDIF»(«IF useCodec»«IF !isSequence»(«resolveProtobuf(typeResolver, outParam.paramType.actualType, Optional.empty)») «ENDIF»«codec».encode«IF isFailable»Failable«ENDIF»(«ENDIF»«outParam.paramName.asParameter»«IF isFailable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualifiedNameProvider, outParam.paramType.actualType, interfaceDeclaration)».class«ENDIF»«IF useCodec»)«ENDIF»)
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
