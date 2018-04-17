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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.generator.common.ResolvedName

@Accessors(NONE)
class ProxyGenerator
{
    private val BasicJavaSourceGenerator basicJavaSourceGenerator
    private val ParameterBundle.Builder param_bundle

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def public String generateProxyImplementation(String class_name, InterfaceDeclaration interface_declaration)
    {
        val anonymous_event = interface_declaration.anonymousEvent
        val api_name = typeResolver.resolve(interface_declaration)

        '''
            public class «class_name» implements «api_name» {
               
               private final «typeResolver.resolve(JavaClassNames.CLIENT_ENDPOINT)» _endpoint;
               private final «typeResolver.resolve("com.btc.cab.servicecomm.api.IServiceReference")» _serviceReference;
               private final «typeResolver.resolve("com.btc.cab.servicecomm.serialization.IMessageBufferSerializer")» _serializer;
               
               public «class_name»(IClientEndpoint endpoint) throws Exception {
                  _endpoint = endpoint;
            
                  _serviceReference = _endpoint
               .connectService(«api_name».TypeGuid);
            
                  _serializer = new «typeResolver.resolve("com.btc.cab.servicecomm.serialization.SinglePartMessageBufferSerializer")»(new «typeResolver.resolve("com.btc.cab.servicecomm.protobuf.ProtobufSerializer")»());
            
                  // ServiceFaultHandler
                  _serviceReference
               .getServiceFaultHandlerManager()
               .registerHandler(«typeResolver.resolve(MavenResolver.resolvePackage(interface_declaration, Optional.of(ProjectType.SERVICE_API)) + '''.«interface_declaration.asServiceFaultHandlerFactory»''')».createServiceFaultHandler());
               }
               
               «FOR function : interface_declaration.functions SEPARATOR BasicJavaSourceGenerator.newLine»
                   «generateFunction(function, api_name, interface_declaration)»
               «ENDFOR»
               
               «IF anonymous_event !== null»
                   «outputAnonymousEvent(anonymous_event)»
               «ENDIF»
               «FOR event : interface_declaration.contains.filter(EventDeclaration).filter[name !== null]»
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

    private def generateFunction(FunctionDeclaration function, ResolvedName api_name,
        InterfaceDeclaration interface_declaration)
    {
        val protobuf_request = resolveProtobuf(basicJavaSourceGenerator, interface_declaration,
            Optional.of(ProtobufType.REQUEST))
        val protobuf_response = resolveProtobuf(basicJavaSourceGenerator, interface_declaration,
            Optional.of(ProtobufType.RESPONSE))
        val is_void = function.returnedType.isVoid
        val is_sync = function.sync
        val return_type = (if (is_void) "Void" else basicJavaSourceGenerator.toText(function.returnedType) )
        val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]

        '''
            /**
               @see «api_name.fullyQualifiedName»#«function.name.toFirstLower»
            */
            @Override
            public «basicJavaSourceGenerator.makeInterfaceMethodSignature(function)» {
               «val request_message = protobuf_request + Constants.SEPARATOR_PACKAGE + function.name.asRequest»
               «val response_message = protobuf_response + Constants.SEPARATOR_PACKAGE + function.name.asResponse»
               «val response_name = '''response«function.name»'''»
               «val protobuf_function_name = function.name.asProtobufName»
               «request_message» request«function.name» = 
                  «request_message».newBuilder()
                  «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                      «val use_codec = GeneratorUtil.useCodec(param.paramType, param_bundle.artifactNature)»
                      «var codec = resolveCodec(param.paramType)»
                      «val is_sequence = param.paramType.isSequenceType»
                      «val is_failable = is_sequence && param.paramType.isFailable»
                      «val method_name = '''«IF is_sequence»addAll«ELSE»set«ENDIF»«param.paramName.asProtobufName»'''»
                  .«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(basicJavaSourceGenerator, param.paramType, Optional.empty)») «ENDIF»«codec».encode«IF is_failable»Failable«ENDIF»(«ENDIF»«param.paramName»«IF is_failable», «resolveFailableProtobufType(basicJavaSourceGenerator.qualified_name_provider, param.paramType, interface_declaration)».class«ENDIF»«IF use_codec»)«ENDIF»)
               «ENDFOR»
               .build();
               
               «protobuf_request» request = «protobuf_request».newBuilder()
                 .set«protobuf_function_name»«Constants.PROTOBUF_REQUEST»(request«function.name»)
                 .build();
               
               «typeResolver.resolve("java.util.concurrent.Future")»<byte[]> requestFuture = «typeResolver.resolve("com.btc.cab.servicecomm.util.ClientEndpointExtensions")».RequestAsync(_endpoint, _serviceReference, _serializer, request);
               «typeResolver.resolve("java.util.concurrent.Callable")»<«return_type»> returnCallable = () -> {
                   byte[] bytes = requestFuture.get();
                   «protobuf_response» response = «protobuf_response».parseFrom(bytes);
                     «IF !is_void || !out_params.empty»«response_message» «response_name» = «ENDIF»response.get«protobuf_function_name»«Constants.PROTOBUF_RESPONSE»();
                     «IF !out_params.empty»
                         
                         // handle [out] parameters
                         «FOR out_param : out_params»
                             «val codec = resolveCodec(out_param.paramType)»
                             «val temp_param_name = '''_«out_param.paramName.toFirstLower»'''»
                             «val param_name = out_param.paramName.asParameter»
                             «IF !out_param.paramType.isSequenceType»
                                 «val out_param_type = basicJavaSourceGenerator.toText(out_param.paramType)»
                                 «out_param_type» «temp_param_name» = («out_param_type») «codec».decode( «response_name».get«out_param.paramName.asProtobufName»() );
                                 «handleOutputParameter(out_param, temp_param_name, param_name)»
                             «ELSE»
                                 «val is_failable = out_param.paramType.isFailable»
                                 «typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«basicJavaSourceGenerator.toText(out_param.paramType.ultimateType)»«IF is_failable»>«ENDIF»> «temp_param_name» = «codec».decode«IF is_failable»Failable«ENDIF»( «response_name».get«out_param.paramName.asProtobufName»List() );
                                 «param_name».addAll( «temp_param_name» );
                             «ENDIF»
                             
                         «ENDFOR»
                     «ENDIF»
                     «val codec = resolveCodec(function.returnedType)»
                     «val is_byte = function.returnedType.isByte»
                     «val is_short = function.returnedType.isInt16»
                     «val is_char = function.returnedType.isChar»
                     «val use_codec = GeneratorUtil.useCodec(function.returnedType, param_bundle.artifactNature)»
                     «val is_sequence = function.returnedType.isSequenceType»
                     «val is_failable = is_sequence && function.returnedType.isFailable»
                     «IF is_sequence»
                         «return_type» result = «codec».decode«IF is_failable»Failable«ENDIF»(«response_name».get«protobuf_function_name»List());
                     «ELSEIF is_void»
                         return null; // it's a Void!
                     «ELSE»
                     «return_type» result = «IF use_codec»(«return_type») «codec».decode(«ENDIF»«IF is_byte || is_short || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»«response_name».get«protobuf_function_name»()«IF use_codec»)«ENDIF»;
                   «ENDIF»
                   «IF !is_void»return result;«ENDIF»
                  };
            
               «IF !is_void || !is_sync»return «ENDIF»«typeResolver.resolve("com.btc.cab.commons.helper.AsyncHelper")».createAndRunFutureTask(returnCallable)«IF is_sync».get()«ENDIF»;
            }
        '''
    }

    private def outputAnonymousEvent(EventDeclaration anonymous_event)
    '''«IF anonymous_event.keys.empty»
       «val event_type_name = typeResolver.resolve(anonymous_event.data)»
       /**
          @see com.btc.cab.commons.IObservable#subscribe
       */
       @Override
       public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymous_event.data)»> observer) throws Exception {
          _endpoint.getEventRegistry().createEventRegistration(
                «event_type_name».EventTypeGuid,
                «typeResolver.resolve("com.btc.cab.servicecomm.api.EventKind")».EVENTKINDPUBLISHSUBSCRIBE,
                «event_type_name».EventTypeGuid.toString());
          return «typeResolver.resolve("com.btc.cab.servicecomm.util.EventRegistryExtensions")».subscribe(_endpoint.getEventRegistry()
                .getSubscriberManager(), _serializerDeserializer,
                «event_type_name».EventTypeGuid,
                EventKind.EVENTKINDPUBLISHSUBSCRIBE, observer);
       }
     «ELSE»
       /**
          @see ???
       */
       public «typeResolver.resolve(JavaClassNames.CLOSEABLE)» subscribe(«typeResolver.resolve(JavaClassNames.OBSERVER)»<«typeResolver.resolve(anonymous_event.data)»> observer, Iterable<KeyType> keys) throws Exception {
          «makeDefaultMethodStub»
       }
    «ENDIF»'''

    def private String handleOutputParameter(ParameterElement element, String source_name, String target_name)
    {
        val ultimate_type = element.paramType.ultimateType
        if (!(ultimate_type instanceof StructDeclaration))
            throw new IllegalArgumentException("In Java generator, only structs are supported as output parameters!")

        '''
            «FOR member : (ultimate_type as StructDeclaration).allMembers»
                «val member_name = member.name.toFirstUpper»
                «target_name».set«member_name»( «source_name».get«member_name»() );
            «ENDFOR»
        '''
    }

}
