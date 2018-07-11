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
import com.btc.serviceidl.generator.common.FeatureProfile
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class ProxyGenerator extends ProxyDispatcherGeneratorBase {

    def generate(String class_name, InterfaceDeclaration interface_declaration)
    {
      val api_fully_qualified_name = resolve(interface_declaration)
      val feature_profile = new FeatureProfile(interface_declaration)
      if (feature_profile.uses_futures)
         resolve("BTC.CAB.ServiceComm.NET.Util.ClientEndpointExtensions")
      if (feature_profile.uses_events)
         resolve("BTC.CAB.ServiceComm.NET.Util.EventRegistryExtensions")
      val serviceFaultHandler = "serviceFaultHandler"
      
      '''
      public class «class_name» : «api_fully_qualified_name.shortName»
      {
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» _endpoint;
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientServiceReference")» _serviceReference;
         
         public «class_name»(IClientEndpoint endpoint)
         {
            _endpoint = endpoint;

            _serviceReference = _endpoint.ConnectService(«interface_declaration.name»Const.«typeGuidProperty»);
            
            «makeExceptionRegistration(serviceFaultHandler, interface_declaration)»
            
            _serviceReference.ServiceFaultHandlerManager.RegisterHandler(«serviceFaultHandler»);
         }
         
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
            «val api_request_name = getProtobufRequestClassName(interface_declaration)»
            «val api_response_name = getProtobufResponseClassName(interface_declaration)»
            «val out_params = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
            «val is_void = function.returnedType instanceof VoidType»
            «val return_type = if (is_void) null else resolveDecode(function.returnedType.actualType)»
            «val is_sync = function.isSync»
            /// <see cref="«api_fully_qualified_name».«function.name»"/>
            public «typeResolver.makeReturnType(function)» «function.name»(
               «FOR param : function.parameters SEPARATOR ","»
                  «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function)»
               «ENDFOR»
            )
            {
               var methodRequestBuilder = «api_request_name».Types.«com.btc.serviceidl.util.Util.asRequest(function.name)».CreateBuilder();
               «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                  «val isSequence = com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                  «val isFailable = isSequence && com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                  «val use_codec = isFailable || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                  «val encodeMethod = getEncodeMethod(param.paramType.actualType, interface_declaration)»
                  «val codec = resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)»
                  «val useCast = use_codec && !isFailable»
                  methodRequestBuilder.«IF isSequence»AddRange«ELSE»Set«ENDIF»«param.paramName.asDotNetProtobufName»(«IF use_codec»«IF useCast»(«resolveEncode(param.paramType.actualType)») «ENDIF»«codec».«encodeMethod»(«ENDIF»«toText(param, function)»«IF use_codec»)«ENDIF»);
               «ENDFOR»
               var requestBuilder = «api_request_name».CreateBuilder();
               requestBuilder.Set«function.name.asDotNetProtobufName»Request(methodRequestBuilder.BuildPartial());
               var protobufRequest = requestBuilder.BuildPartial();
               
               «IF !out_params.empty»
                  // prepare placeholders for [out] parameters
                  «FOR param : out_params»
                     var «param.paramName.asParameter»Placeholder = «makeDefaultValue(basicCSharpSourceGenerator, param.paramType)»;
                  «ENDFOR»
                  
               «ENDIF»
               var result =_serviceReference.RequestAsync(new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(protobufRequest.ToByteArray())).ContinueWith(task =>
               {
                  «api_response_name» response = «api_response_name».ParseFrom(task.Result.PopFront());
                  «val isFailable = com.btc.serviceidl.util.Util.isFailable(function.returnedType)»
                  «val use_codec = isFailable || GeneratorUtil.useCodec(function.returnedType.actualType, ArtifactNature.DOTNET)»
                  «val useCast = use_codec && !isFailable»
                  «val decodeMethod = getDecodeMethod(function.returnedType.actualType, interface_declaration)»
                  «val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)»
                  «val codec = if (use_codec) resolveCodec(typeResolver, parameterBundle, function.returnedType.actualType) else null»
                  «IF !out_params.empty»
                     // handle [out] parameters
                  «ENDIF»
                  «FOR param : out_params»
                     «val basic_name = param.paramName.asParameter»
                     «val isFailableParam = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                     «val is_sequence_param = com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                     «val use_codec_param = isFailableParam || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                     «val decode_method_param = getDecodeMethod(param.paramType.actualType, interface_declaration)»
                     «val codec_param = resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)»
                     «val useCastParam = use_codec_param && !isFailableParam»
                     «basic_name»Placeholder = «IF use_codec_param»«IF useCastParam»(«resolveDecode(param.paramType.actualType)») «ENDIF»«codec_param».«decode_method_param»(«ENDIF»response.«function.name.asDotNetProtobufName»Response.«basic_name.asDotNetProtobufName»«IF is_sequence_param»List«ENDIF»«IF use_codec_param»)«ENDIF»;
                  «ENDFOR»
                  «IF !is_void»return «IF use_codec»«IF useCast»(«return_type») «ENDIF»«codec».«decodeMethod»(«ENDIF»response.«function.name.asDotNetProtobufName»Response.«function.name.asDotNetProtobufName»«IF is_sequence»List«ENDIF»«IF use_codec»)«ELSEIF is_sequence»«typeResolver.asEnumerable»«ENDIF»;«ENDIF»
               });
               «IF out_params.empty»
                  «IF is_sync»«IF is_void»result.Wait();«ELSE»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ELSE»
                  
                  result.Wait();
                  // assign [out] parameters
                  «FOR param : out_params»
                     «val basic_name = param.paramName.asParameter»
                     «basic_name» = «basic_name»Placeholder;
                  «ENDFOR»
                  «IF is_sync»«IF !is_void»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ENDIF»
            }
         «ENDFOR»
         
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val event_name = toText(event, interface_declaration)»
            /// <see cref="«api_fully_qualified_name».Get«event_name»"/>
            public «event_name» Get«event_name»()
            {
               return new «event_name»Impl(_endpoint);
            }
         «ENDFOR»
         «val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)»
         «IF anonymous_event !== null»
            «val event_type_name = toText(anonymous_event.data, anonymous_event)»
            «val deserializing_observer = getDeserializingObserverName(anonymous_event)»
            
            /// <see cref="System.IObservable.Subscribe"/>
            public «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«event_type_name»> observer)
            {
               _endpoint.EventRegistry.CreateEventRegistration(«event_type_name».«eventTypeGuidProperty», «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «event_type_name».«eventTypeGuidProperty».ToString());
               return _endpoint.EventRegistry.SubscriberManager.Subscribe(«resolve(anonymous_event.data)».«eventTypeGuidProperty», new «deserializing_observer»(observer));
            }
            
            class «deserializing_observer» : «resolve("System.IObserver")»<«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")»>
            {
                private readonly «resolve("System.IObserver")»<«toText(anonymous_event.data, anonymous_event)»> _subscriber;

                public «deserializing_observer»(«resolve("System.IObserver")»<«toText(anonymous_event.data, anonymous_event)»> subscriber)
                {
                    _subscriber = subscriber;
                }

                public void OnNext(«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» value)
                {
                    var protobufEvent = «resolveProtobuf(anonymous_event.data)».ParseFrom(value.PopFront());
                    _subscriber.OnNext((«toText(anonymous_event.data, anonymous_event)»)«resolveCodec(typeResolver, parameterBundle, interface_declaration)».decode(protobufEvent));
                }

                public void OnError(Exception error)
                {
                    _subscriber.OnError(error);
                }

                public void OnCompleted()
                {
                    _subscriber.OnCompleted();
                }
            }
         «ENDIF»
      }
      '''       
    }    
}