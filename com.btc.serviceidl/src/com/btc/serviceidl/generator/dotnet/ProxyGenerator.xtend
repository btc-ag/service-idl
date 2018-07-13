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

    def generate(String className, InterfaceDeclaration interfaceDeclaration)
    {
      val apiFullyQualifiedName = resolve(interfaceDeclaration)
      val featureProfile = new FeatureProfile(interfaceDeclaration)
      if (featureProfile.usesFutures)
         resolve("BTC.CAB.ServiceComm.NET.Util.ClientEndpointExtensions")
      if (featureProfile.usesEvents)
         resolve("BTC.CAB.ServiceComm.NET.Util.EventRegistryExtensions")
      val serviceFaultHandler = "serviceFaultHandler"
      
      '''
      public class «className» : «apiFullyQualifiedName.shortName»
      {
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientEndpoint")» _endpoint;
         private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IClientServiceReference")» _serviceReference;
         
         public «className»(IClientEndpoint endpoint)
         {
            _endpoint = endpoint;

            _serviceReference = _endpoint.ConnectService(«interfaceDeclaration.name»Const.«typeGuidProperty»);
            
            «makeExceptionRegistration(serviceFaultHandler, interfaceDeclaration)»
            
            _serviceReference.ServiceFaultHandlerManager.RegisterHandler(«serviceFaultHandler»);
         }
         
         «FOR function : interfaceDeclaration.functions SEPARATOR System.lineSeparator»
            «val apiRequestName = getProtobufRequestClassName(interfaceDeclaration)»
            «val apiResponseName = getProtobufResponseClassName(interfaceDeclaration)»
            «val outParams = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
            «val isVoid = function.returnedType instanceof VoidType»
            «val returnType = if (isVoid) null else resolveDecode(function.returnedType.actualType)»
            «val isSync = function.isSync»
            /// <see cref="«apiFullyQualifiedName».«function.name»"/>
            public «typeResolver.makeReturnType(function)» «function.name»(
               «FOR param : function.parameters SEPARATOR ","»
                  «IF param.direction == ParameterDirection.PARAM_OUT»out «ENDIF»«toText(param.paramType, function)» «toText(param, function)»
               «ENDFOR»
            )
            {
               var methodRequestBuilder = «apiRequestName».Types.«com.btc.serviceidl.util.Util.asRequest(function.name)».CreateBuilder();
               «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                  «val isSequence = com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                  «val isFailable = isSequence && com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                  «val useCodec = isFailable || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                  «val encodeMethod = getEncodeMethod(param.paramType.actualType, interfaceDeclaration)»
                  «val codec = resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)»
                  «val useCast = useCodec && !isFailable»
                  methodRequestBuilder.«IF isSequence»AddRange«ELSE»Set«ENDIF»«param.paramName.asDotNetProtobufName»(«IF useCodec»«IF useCast»(«resolveEncode(param.paramType.actualType)») «ENDIF»«codec».«encodeMethod»(«ENDIF»«toText(param, function)»«IF useCodec»)«ENDIF»);
               «ENDFOR»
               var requestBuilder = «apiRequestName».CreateBuilder();
               requestBuilder.Set«function.name.asDotNetProtobufName»Request(methodRequestBuilder.BuildPartial());
               var protobufRequest = requestBuilder.BuildPartial();
               
               «IF !outParams.empty»
                  // prepare placeholders for [out] parameters
                  «FOR param : outParams»
                     var «param.paramName.asParameter»Placeholder = «makeDefaultValue(basicCSharpSourceGenerator, param.paramType)»;
                  «ENDFOR»
                  
               «ENDIF»
               var result =_serviceReference.RequestAsync(new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(protobufRequest.ToByteArray())).ContinueWith(task =>
               {
                  «apiResponseName» response = «apiResponseName».ParseFrom(task.Result.PopFront());
                  «val isFailable = com.btc.serviceidl.util.Util.isFailable(function.returnedType)»
                  «val useCodec = isFailable || GeneratorUtil.useCodec(function.returnedType.actualType, ArtifactNature.DOTNET)»
                  «val useCast = useCodec && !isFailable»
                  «val decodeMethod = getDecodeMethod(function.returnedType.actualType, interfaceDeclaration)»
                  «val isSequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)»
                  «val codec = if (useCodec) resolveCodec(typeResolver, parameterBundle, function.returnedType.actualType) else null»
                  «IF !outParams.empty»
                     // handle [out] parameters
                  «ENDIF»
                  «FOR param : outParams»
                     «val basicName = param.paramName.asParameter»
                     «val isFailableParam = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                     «val isSequenceParam = com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                     «val useCodecParam = isFailableParam || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                     «val decodeMethodParam = getDecodeMethod(param.paramType.actualType, interfaceDeclaration)»
                     «val codecParam = resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)»
                     «val useCastParam = useCodecParam && !isFailableParam»
                     «basicName»Placeholder = «IF useCodecParam»«IF useCastParam»(«resolveDecode(param.paramType.actualType)») «ENDIF»«codecParam».«decodeMethodParam»(«ENDIF»response.«function.name.asDotNetProtobufName»Response.«basicName.asDotNetProtobufName»«IF isSequenceParam»List«ENDIF»«IF useCodecParam»)«ENDIF»;
                  «ENDFOR»
                  «IF !isVoid»return «IF useCodec»«IF useCast»(«returnType») «ENDIF»«codec».«decodeMethod»(«ENDIF»response.«function.name.asDotNetProtobufName»Response.«function.name.asDotNetProtobufName»«IF isSequence»List«ENDIF»«IF useCodec»)«ELSEIF isSequence»«typeResolver.asEnumerable»«ENDIF»;«ENDIF»
               });
               «IF outParams.empty»
                  «IF isSync»«IF isVoid»result.Wait();«ELSE»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ELSE»
                  
                  result.Wait();
                  // assign [out] parameters
                  «FOR param : outParams»
                     «val basicName = param.paramName.asParameter»
                     «basicName» = «basicName»Placeholder;
                  «ENDFOR»
                  «IF isSync»«IF !isVoid»return result.Result;«ENDIF»«ELSE»return result;«ENDIF»
               «ENDIF»
            }
         «ENDFOR»
         
         «FOR event : interfaceDeclaration.events.filter[name !== null]»
            «val eventName = toText(event, interfaceDeclaration)»
            /// <see cref="«apiFullyQualifiedName».Get«eventName»"/>
            public «eventName» Get«eventName»()
            {
               return new «eventName»Impl(_endpoint);
            }
         «ENDFOR»
         «val anonymousEvent = com.btc.serviceidl.util.Util.getAnonymousEvent(interfaceDeclaration)»
         «IF anonymousEvent !== null»
            «val eventTypeName = toText(anonymousEvent.data, anonymousEvent)»
            «val deserializingObserver = getDeserializingObserverName(anonymousEvent)»
            
            /// <see cref="System.IObservable.Subscribe"/>
            public «resolve("System.IDisposable")» Subscribe(«resolve("System.IObserver")»<«eventTypeName»> observer)
            {
               _endpoint.EventRegistry.CreateEventRegistration(«eventTypeName».«eventTypeGuidProperty», «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «eventTypeName».«eventTypeGuidProperty».ToString());
               return _endpoint.EventRegistry.SubscriberManager.Subscribe(«resolve(anonymousEvent.data)».«eventTypeGuidProperty», new «deserializingObserver»(observer));
            }
            
            class «deserializingObserver» : «resolve("System.IObserver")»<«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")»>
            {
                private readonly «resolve("System.IObserver")»<«toText(anonymousEvent.data, anonymousEvent)»> _subscriber;

                public «deserializingObserver»(«resolve("System.IObserver")»<«toText(anonymousEvent.data, anonymousEvent)»> subscriber)
                {
                    _subscriber = subscriber;
                }

                public void OnNext(«resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» value)
                {
                    var protobufEvent = «resolveProtobuf(anonymousEvent.data)».ParseFrom(value.PopFront());
                    _subscriber.OnNext((«toText(anonymousEvent.data, anonymousEvent)»)«resolveCodec(typeResolver, parameterBundle, interfaceDeclaration)».decode(protobufEvent));
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