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
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProxyGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def String generateProxyImplementation(String className, InterfaceDeclaration interfaceDeclaration)
    {
        val anonymousEvent = interfaceDeclaration.anonymousEvent
        val apiName = typeResolver.resolve(interfaceDeclaration)
        
        val serializerType = if (basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3) typeResolver.resolve(
                "com.btc.cab.servicecomm.serialization.IMessageBufferSerializer") else typeResolver.resolve(
                "com.btc.cab.servicecomm.serialization.ISerializer")
        val deserializerType = if (basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3)
                null
            else
                typeResolver.resolve("com.btc.cab.servicecomm.serialization.IDeserializer")

        '''
            public class «className» implements «apiName» {
               
               private final «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» _endpoint;
               private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceReference")» _serviceReference;
               private final «serializerType» _serializer;
               «IF deserializerType !== null»
               private final «deserializerType» _deserializer;
               «ENDIF»
               
               public «className»(IClientEndpoint endpoint) throws Exception {
                  _endpoint = endpoint;
            
                  _serviceReference = _endpoint
               .connectService(«apiName».TypeGuid);
            
                  _serializer = 
                    «IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»new «typeResolver.resolve("com.btc.cab.servicecomm.serialization.SinglePartMessageBufferSerializer")»(«ENDIF»
                    new «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtobufSerializer")»()
                    «IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»)«ENDIF»
                    ;
                   «IF deserializerType !== null»
                   _deserializer = initializeDeserializer();
                   «ENDIF»
            
                  // ServiceFaultHandler
                  _serviceReference
               .getServiceFaultHandlerManager()
               .registerHandler(«typeResolver.resolve(typeResolver.resolvePackage(interfaceDeclaration, ProjectType.SERVICE_API) + '''.«interfaceDeclaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
               }
               
               «IF deserializerType !== null»
               private «deserializerType» initializeDeserializer() {
                   «deserializerType» dummyDeserializer =
                       new «deserializerType»() {
                         @Override
                         public <T> T deserialize(byte[] inputStream, Class<T> deserializeClass) {
                           return null;
                         }
                       };
                   «typeResolver.resolve("java.util.Map")»<Class<?>, «deserializerType»> deserializerMap = new «typeResolver.resolve("java.util.HashMap")»<>();
                   deserializerMap.put(«resolveProtobuf(typeResolver, interfaceDeclaration, Optional.of(ProtobufType.REQUEST))».class, dummyDeserializer);
                   deserializerMap.put(«resolveProtobuf(typeResolver, interfaceDeclaration, Optional.of(ProtobufType.RESPONSE))».class, dummyDeserializer);
               
                   «IF anonymousEvent !== null»
                       «val eventTypeName = typeResolver.resolve(anonymousEvent.data)»
                       «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.MarshallingDeserializer")»<«eventTypeName», byte[]> netProtoBufStream =
                           new MarshallingDeserializer<>(new UnmarshalProtobufFunction());
                       
                       deserializerMap.put(«eventTypeName».class, netProtoBufStream);
                   «ENDIF»
                              
                   return new «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.CompositeDeserializer")»(deserializerMap);
                 }
               «ENDIF»
               
               «FOR function : interfaceDeclaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
                   «generateFunction(function, apiName, interfaceDeclaration)»
               «ENDFOR»
               
               «IF anonymousEvent !== null»
                   «outputAnonymousEvent(anonymousEvent)»
               «ENDIF»
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

    private def generateFunction(FunctionDeclaration function, ResolvedName apiName,
        InterfaceDeclaration interfaceDeclaration)
    {
        val protobufRequest = resolveProtobuf(typeResolver, interfaceDeclaration, Optional.of(ProtobufType.REQUEST))
        val protobuf_response = resolveProtobuf(typeResolver, interfaceDeclaration, Optional.of(ProtobufType.RESPONSE))
        val isVoid = function.returnedType instanceof VoidType
        val isSync = function.sync
        val returnType = (if (isVoid) "Void" else basicJavaSourceGenerator.toText(function.returnedType) )
        val outParams = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]

        '''
            /**
               @see «apiName.fullyQualifiedName»#«function.name.toFirstLower»
            */
            @Override
            public «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)» {
               «val requestMessage = protobufRequest + Constants.SEPARATOR_PACKAGE + function.name.asRequest»
               «val responseMessage = protobuf_response + Constants.SEPARATOR_PACKAGE + function.name.asResponse»
               «val responseName = '''response«function.name»'''»
               «val protobufFunctionName = function.name.asJavaProtobufName»
               «requestMessage» request«function.name» = 
                  «requestMessage».newBuilder()
                  «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                      «val useCodec = GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.JAVA)»
                      «var codec = resolveCodec(param.paramType.actualType, typeResolver)»
                      «val isSequence = param.paramType.isSequenceType»
                      «val isFailable = isSequence && param.paramType.isFailable»
                      «val methodName = '''«IF isSequence»addAll«ELSE»set«ENDIF»«param.paramName.asJavaProtobufName»'''»
                  .«methodName»(«IF useCodec»«IF !isSequence»(«resolveProtobuf(typeResolver, param.paramType.actualType, Optional.empty)») «ENDIF»«codec».encode«IF isFailable»Failable«ENDIF»(«ENDIF»«param.paramName»«IF isFailable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualifiedNameProvider, param.paramType.actualType, interfaceDeclaration)».class«ENDIF»«IF useCodec»)«ENDIF»)
               «ENDFOR»
               .build();
               
               «protobufRequest» request = «protobufRequest».newBuilder()
              .set«protobufFunctionName»«Constants.PROTOBUF_REQUEST»(request«function.name»)
              .build();
               
               «typeResolver.resolve("java.util.concurrent.Future")»<byte[]> requestFuture 
                 = «typeResolver.resolve("com.btc.cab.servicecomm.util.ClientEndpointExtensions")».
                   «IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»RequestAsync«ELSE»requestAsync«ENDIF»
                   (_endpoint, _serviceReference, _serializer, request);
               «typeResolver.resolve("java.util.concurrent.Callable")»<«returnType»> returnCallable = () -> {
                   byte[] bytes = requestFuture.get();
                   «protobuf_response» response = «protobuf_response».parseFrom(bytes);
                     «IF !isVoid || !outParams.empty»«responseMessage» «responseName» = «ENDIF»response.get«protobufFunctionName»«Constants.PROTOBUF_RESPONSE»();
                     «IF !outParams.empty»
                         
                         // handle [out] parameters
                         «FOR outParam : outParams»
                             «val codec = resolveCodec(outParam.paramType.actualType, typeResolver)»
                             «val tempParamName = '''_«outParam.paramName.toFirstLower»'''»
                             «val paramName = outParam.paramName.asParameter»
                             «IF !outParam.paramType.isSequenceType»
                                 «val outParamType = basicJavaSourceGenerator.toText(outParam.paramType)»
                                 «outParamType» «tempParamName» = («outParamType») «codec».decode( «responseName».get«outParam.paramName.asJavaProtobufName»() );
                                 «handleOutputParameter(outParam, tempParamName, paramName)»
                             «ELSE»
                                 «val isFailable = outParam.paramType.isFailable»
                                 «typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF isFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«basicJavaSourceGenerator.toText(outParam.paramType.ultimateType)»«IF isFailable»>«ENDIF»> «tempParamName» = «codec».decode«IF isFailable»Failable«ENDIF»( «responseName».get«outParam.paramName.asJavaProtobufName»List() );
                                 «paramName».addAll( «tempParamName» );
                             «ENDIF»
                             
                         «ENDFOR»
                     «ENDIF»
                     «val isByte = function.returnedType.isByte»
                     «val isShort = function.returnedType.isInt16»
                     «val isChar = function.returnedType.isChar»
                     «val isSequence = function.returnedType.isSequenceType»
                     «val useCodec = GeneratorUtil.useCodec(function.returnedType.actualType, ArtifactNature.JAVA) || isSequence»
                     «val codec = if (useCodec) resolveCodec(function.returnedType.actualType, typeResolver) else null»
                     «val isFailable = isSequence && function.returnedType.isFailable»
                     «IF isSequence»
                         «returnType» result = «codec».decode«IF isFailable»Failable«ENDIF»(«responseName».get«protobufFunctionName»List());
                     «ELSEIF isVoid»
                         return null; // it's a Void!
                     «ELSE»
                     «returnType» result = «IF useCodec»(«returnType») «codec».decode(«ENDIF»«IF isByte || isShort || isChar»(«IF isByte»byte«ELSEIF isChar»char«ELSE»short«ENDIF») «ENDIF»«responseName».get«protobufFunctionName»()«IF useCodec»)«ENDIF»;
               «ENDIF»
               «IF !isVoid»return result;«ENDIF»
                  };
            
               «IF !isVoid || !isSync»return «ENDIF»«typeResolver.resolve("com.btc.cab.commons.helper.AsyncHelper")».createAndRunFutureTask(returnCallable)«IF isSync».get()«ENDIF»;
            }
        '''
    }

    private def outputAnonymousEvent(EventDeclaration anonymousEvent)
    '''«IF anonymousEvent.keys.empty»
       «val eventTypeName = typeResolver.resolve(anonymousEvent.data)»
       /**
          @see com.btc.cab.commons.IObservable#subscribe
       */
       @Override
       public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymousEvent.data)»> observer) throws Exception {
          _endpoint.getEventRegistry().createEventRegistration(
                «eventTypeName».EventTypeGuid,
                «typeResolver.resolve("com.btc.cab.servicecomm.api.EventKind")».EVENTKINDPUBLISHSUBSCRIBE,
                «eventTypeName».EventTypeGuid.toString());
          return «typeResolver.resolve("com.btc.cab.servicecomm.util.EventRegistryExtensions")».subscribe(_endpoint.getEventRegistry()
                .getSubscriberManager(), «IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»_serializerDeserializer«ELSE»_deserializer«ENDIF»,
                «eventTypeName».EventTypeGuid,
                EventKind.EVENTKINDPUBLISHSUBSCRIBE, observer);
       }
     «ELSE»
       /**
          @see ???
       */
       public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymousEvent.data)»> observer, Iterable<KeyType> keys) throws Exception {
          «makeDefaultMethodStub»
       }
    «ENDIF»'''

    private def String handleOutputParameter(ParameterElement element, String sourceName, String targetName)
    {
        val ultimateType = element.paramType.ultimateType
        if (!(ultimateType instanceof StructDeclaration))
            throw new IllegalArgumentException("In Java generator, only structs are supported as output parameters!")

        '''
            «FOR member : (ultimateType as StructDeclaration).allMembers»
                «val memberName = member.name.toFirstUpper»
                «targetName».set«memberName»( «sourceName».get«memberName»() );
            «ENDFOR»
        '''
    }

}
