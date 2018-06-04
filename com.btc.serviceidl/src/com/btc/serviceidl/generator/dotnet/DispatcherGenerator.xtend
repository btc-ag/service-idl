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
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(NONE)
class DispatcherGenerator extends ProxyDispatcherGeneratorBase {
    
    def generate(String dispatcher_class_name, InterfaceDeclaration interface_declaration) {
      val api_class_name = resolve(interface_declaration).shortName
            
      val events = interface_declaration.events
      
      val protobuf_request = getProtobufRequestClassName(interface_declaration)
      val protobuf_response = getProtobufResponseClassName(interface_declaration)
      val service_fault_handler = "serviceFaultHandler"
      
      // special case: the ServiceComm type InvalidRequestReceivedException has
      // the namespace BTC.CAB.ServiceComm.NET.API.Exceptions, but is included
      // in the assembly BTC.CAB.ServiceComm.NET.API; if we use the resolve()
      // method, a non-existing assembly is referenced, so we do it manually
      namespace_references.add("BTC.CAB.ServiceComm.NET.API.Exceptions")
      
     '''
     public class «dispatcher_class_name» : «resolve("BTC.CAB.ServiceComm.NET.Base.AServiceDispatcherBase")»
     {
        private readonly «api_class_name» _dispatchee;
        
        private readonly «resolve("BTC.CAB.ServiceComm.NET.ProtobufUtil.ProtoBufServerHelper")» _protoBufHelper;
        
        private readonly «resolve("BTC.CAB.ServiceComm.NET.API.IServiceFaultHandlerManager")» _faultHandlerManager;
        
        «FOR event : events»
        private «resolve("System.Collections.Generic.List")»<«resolve("BTC.CAB.ServiceComm.NET.API.IEventPublisherRegistration")»> _remote«event.data.name»Publishers;
        private «resolve("System.Collections.Generic.List")»<«resolve("System.IDisposable")»> _local«event.data.name»Subscriptions;
        «ENDFOR»
        
        public «dispatcher_class_name»(«api_class_name» dispatchee, ProtoBufServerHelper protoBufHelper)
        {
           _dispatchee = dispatchee;
           _protoBufHelper = protoBufHelper;

           «FOR event : events»
           _remote«event.data.name»Publishers = new List<IEventPublisherRegistration>();
           _local«event.data.name»Subscriptions = new List<IDisposable>();
           «ENDFOR»

           _faultHandlerManager = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.ServiceFaultHandlerManager")»();

           var «service_fault_handler» = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.MultipleExceptionTypesServiceFaultHandler")»();

           «makeExceptionRegistration(service_fault_handler, com.btc.serviceidl.util.Util.getRaisedExceptions(interface_declaration))»

           _faultHandlerManager.RegisterHandler(«service_fault_handler»);
        }
        
        «FOR event : events»
           «val event_type = event.data»
           «val protobuf_class_name = resolve(event_type, ProjectType.PROTOBUF)»
           private «protobuf_class_name» Marshal«event_type.name»(«resolve(event_type)» arg)
           {
              return («protobuf_class_name») «resolveCodec(typeResolver, param_bundle, event_type)».encode(arg);
           }
        «ENDFOR»
        
        /// <see cref="BTC.CAB.ServiceComm.NET.API.IServiceDispatcher.ProcessRequest"/>
        public override «resolve("BTC.CAB.ServiceComm.NET.Common.IMessageBuffer")» ProcessRequest(IMessageBuffer requestBuffer, «resolve("BTC.CAB.ServiceComm.NET.Common.IPeerIdentity")» peerIdentity)
        {
           var request = «protobuf_request».ParseFrom(requestBuffer.PopFront());
           
           «FOR func : interface_declaration.functions»
           «val request_name = func.name.toLowerCase.toFirstUpper + Constants.PROTOBUF_REQUEST»
           «val is_void = func.returnedType.isVoid»
           «IF func != interface_declaration.functions.head»else «ENDIF»if (request.Has«request_name»)
           {
              «val out_params = func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
              «IF !out_params.empty»
                 // prepare [out] parameters
                 «FOR param : out_params»
                    var «param.paramName.asParameter» = «basicCSharpSourceGenerator.makeDefaultValue(param.paramType)»;
                 «ENDFOR»
                 
              «ENDIF»
              // call actual method
              «IF !is_void»var result = «ENDIF»_dispatchee.«func.name»
                 (
                    «FOR param : func.parameters SEPARATOR ","»
                       «val is_input = (param.direction == ParameterDirection.PARAM_IN)»
                       «val use_codec = GeneratorUtil.useCodec(param, ArtifactNature.DOTNET)»
                       «val decodeMethod = getDecodeMethod(param.paramType)»
                       «IF is_input»
                          «IF use_codec»(«resolveDecode(param.paramType)») «resolveCodec(typeResolver, param_bundle, param.paramType)».«decodeMethod»(«ENDIF»«IF use_codec»«resolve(param.paramType, ProjectType.PROTOBUF).alias("request")»«ELSE»request«ENDIF».«request_name».«param.paramName.toLowerCase.toFirstUpper»«IF (com.btc.serviceidl.util.Util.isSequenceType(param.paramType))»List«ENDIF»«IF use_codec»)«ENDIF»
                       «ELSE»
                          out «param.paramName.asParameter»
                       «ENDIF»
                    «ENDFOR»
                 )«IF !func.sync».«IF is_void»Wait()«ELSE»Result«ENDIF»«ENDIF»;«IF !func.sync» // «IF is_void»await«ELSE»retrieve«ENDIF» the result in order to trigger exceptions«ENDIF»

              // deliver response
              var responseBuilder = «protobuf_response».Types.«com.btc.serviceidl.util.Util.asResponse(func.name)».CreateBuilder()
                 «val use_codec = GeneratorUtil.useCodec(func.returnedType, ArtifactNature.DOTNET)»
                 «val method_name = if (com.btc.serviceidl.util.Util.isSequenceType(func.returnedType)) "AddRange" + func.name.toLowerCase.toFirstUpper else "Set" + func.name.toLowerCase.toFirstUpper»
                 «val encodeMethod = getEncodeMethod(func.returnedType)»
                 «IF !is_void».«method_name»(«IF use_codec»(«resolveEncode(func.returnedType)») «resolveCodec(typeResolver, param_bundle, func.returnedType)».«encodeMethod»(«ENDIF»«IF use_codec»«resolve(func.returnedType).alias("result")»«ELSE»result«ENDIF»«IF use_codec»)«ENDIF»)«ENDIF»
                 «FOR param : out_params»
                    «val param_name = param.paramName.asParameter»
                    «val use_codec_param = GeneratorUtil.useCodec(param.paramType, ArtifactNature.DOTNET)»
                    «val method_name_param = if (com.btc.serviceidl.util.Util.isSequenceType(param.paramType)) "AddRange" + param.paramName.toLowerCase.toFirstUpper else "Set" + param.paramName.toLowerCase.toFirstUpper»
                    «val encode_method_param = getEncodeMethod(param.paramType)»
                    .«method_name_param»(«IF use_codec_param»(«resolveEncode(param.paramType)») «resolveCodec(typeResolver, param_bundle, param.paramType)».«encode_method_param»(«ENDIF»«IF use_codec_param»«resolve(param.paramType).alias(param_name)»«ELSE»«param_name»«ENDIF»«IF use_codec_param»)«ENDIF»)
                 «ENDFOR»
                 ;
              
              var response = «protobuf_response».CreateBuilder().Set«func.name.toLowerCase.toFirstUpper»Response(responseBuilder).Build();
              return new «resolve("BTC.CAB.ServiceComm.NET.Common.MessageBuffer")»(response.ToByteArray());
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
              «val event_type = event.data»
              «val event_api_class_name = resolve(event_type)»
              // registration for «event_type.name»
              endpoint.EventRegistry.CreateEventRegistration(«event_api_class_name».«eventTypeGuidProperty»,
                 «resolve("BTC.CAB.ServiceComm.NET.API.EventKind")».EventKindPublishSubscribe, «event_api_class_name».«eventTypeGuidProperty».ToString());
              var remote«event_type.name»Publisher = endpoint.EventRegistry.PublisherManager.RegisterPublisher(
                          «event_api_class_name».«eventTypeGuidProperty»);
              _remote«event_type.name»Publishers.Add(remote«event_type.name»Publisher);
              var local«event_type.name»Subscription = _dispatchee«IF event.name !== null».Get«getObservableName(event)»()«ENDIF».Subscribe(
              new «event_type.name»Observer(remote«event_type.name»Publisher));
              _local«event_type.name»Subscriptions.Add(local«event_type.name»Subscription);
           «ENDFOR»
        }
        
        «FOR event : events»
        «val event_type = event.data»
        «val event_api_class_name = resolve(event_type)»
        «val event_protobuf_class_name = resolve(event_type, ProjectType.PROTOBUF)»
        class «event_type.name»Observer : IObserver<«event_api_class_name»>
        {
            private readonly IObserver<IMessageBuffer> _messageBufferObserver;

            public «event_type.name»Observer(IObserver<IMessageBuffer> messageBufferObserver)
            {
                _messageBufferObserver = messageBufferObserver;
            }

            public void OnNext(«event_api_class_name» value)
            {
                «event_protobuf_class_name» protobufEvent = «resolveCodec(typeResolver, param_bundle, event.data)».encode(value) as «event_protobuf_class_name»;
                byte[] serializedEvent = protobufEvent.ToByteArray();
                _messageBufferObserver.OnNext(new MessageBuffer(serializedEvent));
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
           «val event_type = event.data»
           foreach (var eventSubscription in _local«event_type.name»Subscriptions)
           {
              eventSubscription.Dispose();
           }
           
           foreach (var eventPublisher in _remote«event_type.name»Publishers)
           {
              eventPublisher.Dispose();
           }
           «ENDFOR»
        }
     }
     '''
    }
    
}
