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
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class DispatcherGenerator extends ProxyDispatcherGeneratorBase {
    
    def generate(String dispatcherClassName, InterfaceDeclaration interfaceDeclaration) {
      val apiClassName = resolve(interfaceDeclaration).shortName
            
      val events = interfaceDeclaration.events
      
      val protobufRequest = getProtobufRequestClassName(interfaceDeclaration)
      val protobuf_response = getProtobufResponseClassName(interfaceDeclaration)
      val serviceFaultHandler = "serviceFaultHandler"
      val serviceCommVersion_V0_6 = getTargetVersion() == ServiceCommVersion.V0_6
      
      // special case: the ServiceComm type InvalidRequestReceivedException has
      // the namespace BTC.CAB.ServiceComm.NET.API.Exceptions, but is included
      // in the assembly BTC.CAB.ServiceComm.NET.API; if we use the resolve()
      // method, a non-existing assembly is referenced, so we do it manually
      namespaceReferences.add("BTC.CAB.ServiceComm.NET.API.Exceptions")
      
     '''
     public class «dispatcherClassName» : «resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")»
     {
        private readonly «apiClassName» _dispatchee;
        
        private readonly «resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper")» _protoBufHelper;
        
        private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IServiceFaultHandlerManager")» _faultHandlerManager;
        
        «FOR event : events»
        private «resolve("System.Collections.Generic.List")»<«resolve("BTC.CAB.ServiceComm.NET.API.IEventPublisherRegistration")»> _remote«event.data.name»Publishers;
        private «resolve("System.Collections.Generic.List")»<«resolve("System.IDisposable")»> _local«event.data.name»Subscriptions;
        «ENDFOR»
        
        public «dispatcherClassName»(«apiClassName» dispatchee, ProtoBufServerHelper protoBufHelper)
        {
           _dispatchee = dispatchee;
           _protoBufHelper = protoBufHelper;

           «FOR event : events»
           _remote«event.data.name»Publishers = new List<IEventPublisherRegistration>();
           _local«event.data.name»Subscriptions = new List<IDisposable>();
           «ENDFOR»

           _faultHandlerManager = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManager")»();

           «makeExceptionRegistration(serviceFaultHandler, interfaceDeclaration)»

           _faultHandlerManager.RegisterHandler(«serviceFaultHandler»);
        }
        
        «FOR event : events»
           «val eventType = event.data»
           «val protobufClassName = resolve(eventType, ProjectType.PROTOBUF)»
           private «protobufClassName» Marshal«eventType.name»(«resolve(eventType)» arg)
           {
              return («protobufClassName») «resolveCodec(typeResolver, parameterBundle, eventType)».encode(arg);
           }
        «ENDFOR»
        
        /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.ProcessRequest"/>
        «IF serviceCommVersion_V0_6»
            public override «resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» ProcessRequest(IMessageBuffer requestBuffer, «resolve("BTC.CAB.ServiceComm.NET.Common.IPeerIdentity")» peerIdentity)
        «ELSE»
            public override «resolve("System.Byte[]")» ProcessRequest(byte[] requestBuffer, «resolve("BTC.CAB.ServiceComm.NET.Common.IPeerIdentity")» peerIdentity)
        «ENDIF»
        {
           «IF serviceCommVersion_V0_6»
               var request = «protobufRequest».ParseFrom(requestBuffer.PopFront());
           «ELSE»
               var request = «protobufRequest».ParseFrom(requestBuffer);
           «ENDIF»
           
           «FOR func : interfaceDeclaration.functions»
           «val requestName = func.name.asDotNetProtobufName + Constants.PROTOBUF_REQUEST»
           «val isVoid = func.returnedType instanceof VoidType»
           «IF func != interfaceDeclaration.functions.head»else «ENDIF»if (request.Has«requestName»)
           {
              «val outParams = func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
              «IF !outParams.empty»
                 // prepare [out] parameters
                 «FOR param : outParams»
                    var «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                 «ENDFOR»
                 
              «ENDIF»
              // call actual method
              «IF !isVoid»var result = «ENDIF»_dispatchee.«func.name»
                 (
                    «FOR param : func.parameters SEPARATOR ","»
                       «val isInput = (param.direction == ParameterDirection.PARAM_IN)»
                       «val isFailable = com.btc.serviceidl.util.Util.isFailable(param)»
                       «val useCodec = isFailable || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                       «val decodeMethod = getDecodeMethod(param.paramType.actualType, interfaceDeclaration)»
                       «val useCast = useCodec && !isFailable»
                       «IF isInput»
                          «IF useCodec»«IF useCast»(«resolveDecode(param.paramType.actualType)») «ENDIF»«resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)».«decodeMethod»(«ENDIF»«IF useCodec»«resolve(param.paramType, ProjectType.PROTOBUF).alias("request")»«ELSE»request«ENDIF».«requestName».«param.paramName.asDotNetProtobufName»«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»List«ENDIF»«IF useCodec»)«ENDIF»
                       «ELSE»
                          out «param.paramName.asParameter»
                       «ENDIF»
                    «ENDFOR»
                 )«IF !func.sync».«IF isVoid»Wait()«ELSE»Result«ENDIF»«ENDIF»;«IF !func.sync» // «IF isVoid»await«ELSE»retrieve«ENDIF» the result in order to trigger exceptions«ENDIF»

              // deliver response
              var responseBuilder = «protobuf_response».Types.«com.btc.serviceidl.util.Util.asResponse(func.name)».CreateBuilder()
                 «val isSequence = com.btc.serviceidl.util.Util.isSequenceType(func.returnedType)»
                 «val useCodec = isSequence || GeneratorUtil.useCodec(func.returnedType.actualType, ArtifactNature.DOTNET)»
                 «val methodName = if (isSequence) "AddRange" + func.name.asDotNetProtobufName else "Set" + func.name.asDotNetProtobufName»
                 «val encodeMethod = getEncodeMethod(func.returnedType.actualType, interfaceDeclaration)»
                 «val isFailable = com.btc.serviceidl.util.Util.isFailable(func.returnedType)»
                 «val useCast = useCodec && !isFailable»
                 «IF !isVoid».«methodName»(«IF useCodec»«IF useCast»(«resolveEncode(func.returnedType.actualType)») «ENDIF»«resolveCodec(typeResolver, parameterBundle, func.returnedType.actualType)».«encodeMethod»(«ENDIF»«IF useCodec»«resolve(func.returnedType).alias("result")»«ELSE»result«ENDIF»«IF useCodec»)«ENDIF»)«ENDIF»
                 «FOR param : outParams»
                    «val paramName = param.paramName.asParameter»
                    «val isFailableParam = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                    «val useCodecParam = isFailableParam || GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.DOTNET)»
                    «val methodNameParam = if (com.btc.serviceidl.util.Util.isSequenceType(param.paramType)) "AddRange" + param.paramName.asDotNetProtobufName else "Set" + param.paramName.asDotNetProtobufName»
                    «val encodeMethodParam = getEncodeMethod(param.paramType.actualType, interfaceDeclaration)»
                    «val useCastParam = useCodecParam && !isFailableParam»
                    .«methodNameParam»(«IF useCodecParam»«IF useCastParam»(«resolveEncode(param.paramType.actualType)») «ENDIF»«resolveCodec(typeResolver, parameterBundle, param.paramType.actualType)».«encodeMethodParam»(«ENDIF»«IF useCodecParam»«resolve(param.paramType).alias(paramName)»«ELSE»«paramName»«ENDIF»«IF useCodecParam»)«ENDIF»)
                 «ENDFOR»
                 ;
              
              var response = «protobuf_response».CreateBuilder().Set«func.name.asDotNetProtobufName»Response(responseBuilder).Build();
              «IF serviceCommVersion_V0_6»
                  return new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(response.ToByteArray());
              «ELSE»
                  return response.ToByteArray();
              «ENDIF»
           }
           «ENDFOR»

           throw new InvalidRequestReceivedException("Unknown or invalid request");
        }
        
        /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.ServiceFaultHandlerManager"/>
        public override IServiceFaultHandlerManager ServiceFaultHandlerManager
        {
           get { return _faultHandlerManager; }
        }
        
        /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.AttachEndpoint"/>
        public override void AttachEndpoint(IServerEndpoint endpoint)
        {
           base.AttachEndpoint(endpoint);
           
           «FOR event : events»
              «val eventType = event.data»
              «val eventApiClassName = resolve(eventType)»
              // registration for «eventType.name»
              endpoint.EventRegistry.CreateEventRegistration(«eventApiClassName».«eventTypeGuidProperty»,
                 «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «eventApiClassName».«eventTypeGuidProperty».ToString());
              var remote«eventType.name»Publisher = endpoint.EventRegistry.PublisherManager.RegisterPublisher(
                          «eventApiClassName».«eventTypeGuidProperty»);
              _remote«eventType.name»Publishers.Add(remote«eventType.name»Publisher);
              var local«eventType.name»Subscription = _dispatchee«IF event.name !== null».Get«getObservableName(event)»()«ENDIF».Subscribe(
              new «eventType.name»Observer(remote«eventType.name»Publisher));
              _local«eventType.name»Subscriptions.Add(local«eventType.name»Subscription);
           «ENDFOR»
        }
        
        «FOR event : events»
        «val eventType = event.data»
        «val eventApiClassName = resolve(eventType)»
        «val eventProtobufClassName = resolve(eventType, ProjectType.PROTOBUF)»
        class «eventType.name»Observer : IObserver<«eventApiClassName»>
        {
            «IF serviceCommVersion_V0_6»
                private readonly IObserver<IMessageBuffer> _messageBufferObserver;

                public «eventType.name»Observer(IObserver<IMessageBuffer> messageBufferObserver)
            «ELSE»
                private readonly IObserver<byte[]> _messageBufferObserver;

                public «eventType.name»Observer(IObserver<byte[]> messageBufferObserver)
            «ENDIF»
            {
                _messageBufferObserver = messageBufferObserver;
            }

            public void OnNext(«eventApiClassName» value)
            {
                «eventProtobufClassName» protobufEvent = «resolveCodec(typeResolver, parameterBundle, event.data)».encode(value) as «eventProtobufClassName»;
                byte[] serializedEvent = protobufEvent.ToByteArray();
                «IF serviceCommVersion_V0_6»
                    _messageBufferObserver.OnNext(new MessageBuffer(serializedEvent));
                «ELSE»
                    _messageBufferObserver.OnNext(serializedEvent);
                «ENDIF»
            }

            public void OnError(Exception error)
            {
                throw new NotSupportedException();
            }

            public void OnCompleted()
            {
                throw new NotSupportedException();
            }
        }
        «ENDFOR»
        
        /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.DetachEndpoint"/>
        public override void DetachEndpoint(IServerEndpoint endpoint)
        {
           base.DetachEndpoint(endpoint);
           
           «FOR event : events»
           «val eventType = event.data»
           foreach (var eventSubscription in _local«eventType.name»Subscriptions)
           {
              eventSubscription.Dispose();
           }
           
           foreach (var eventPublisher in _remote«eventType.name»Publishers)
           {
              eventPublisher.Dispose();
           }
           «ENDFOR»
        }
     }
     '''
    }
    
}
