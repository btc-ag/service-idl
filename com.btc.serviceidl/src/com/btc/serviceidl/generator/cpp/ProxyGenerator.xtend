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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.util.Constants
import com.google.common.base.CaseFormat
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class ProxyGenerator extends BasicCppGenerator {
        
    def generateImplementationFileBody(InterfaceDeclaration interface_declaration) {
      val class_name = resolve(interface_declaration, paramBundle.projectType)
      val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
      
      // the class name is not used explicitly in the following code, but
      // we need to include this *.impl.h file to avoid linker errors
      resolveSymbolWithImplementation("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")
      
      '''
      «class_name.shortName»::«class_name.shortName»
      (
         «resolveSymbol("BTC::Commons::Core::Context")» &context
         ,«resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
         ,«resolveSymbol("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
         ,«resolveSymbolWithImplementation("BTC::Commons::CoreExtras::Optional")»<«resolveSymbol("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid
      ) :
      m_context(context)
      , «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      , «interface_declaration.asBaseName»(context, localEndpoint, «api_class_name»::TYPE_GUID(), serverServiceInstanceGuid)
      «FOR event : interface_declaration.events»
      , «event.observableRegistrationName»(context, localEndpoint.GetEventRegistry(), «event.eventParamsName»())
      «ENDFOR»
      { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP, TransformType.NAMESPACE)))»( GetClientServiceReference().GetServiceFaultHandlerManager() ); }
      
      «generateCppDestructor(interface_declaration)»
      
      «generateInheritedInterfaceMethods(interface_declaration)»
      
      «FOR event : interface_declaration.events AFTER System.lineSeparator»
         «val event_type = resolve(event.data)»
         «val event_name = event_type.shortName»
         «val event_params_name = event.eventParamsName»
         
         namespace // anonymous namespace to avoid naming collisions
         {
            «event_type» const Unmarshal«event_name»( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager")»::ObserverType::OnNextParamType event )
            {
               «/* TODO remove ProtobufType argument */»
               «typeResolver.resolveProtobuf(event.data, ProtobufType.REQUEST)» eventProtobuf;
               «IF targetVersion == "0.10"»
               if (!(event->GetNumElements() == 1))
                  «resolveSymbol("CABTHROW_V2")»(«resolveSymbol("BTC::ServiceComm::API::InvalidMessageReceivedException")»("Event message has not exactly one part"));
               «ENDIF»
               «resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ParseMessageOrThrow<«resolveSymbol("BTC::ServiceComm::API::InvalidMessageReceivedException")»>(eventProtobuf, «IF targetVersion == "0.10"»(*event)[0]«ELSE»*event«ENDIF»);

               return «typeResolver.resolveCodecNS(paramBundle, event.data)»::Decode( eventProtobuf );
            }
         }
         
         «resolveSymbol("BTC::Commons::CoreExtras::UUID")» «class_name.shortName»::«event_params_name»::GetEventTypeGuid()
         {
           /** this uses a global event type, i.e. if there are multiple instances of the service (dispatcher), these will all be subscribed;
           *  alternatively, an instance-specific type guid must be registered by the dispatcher and queried by the proxy */
           return «event_type»::EVENT_TYPE_GUID();
         }
         
         «resolveSymbol("BTC::ServiceComm::API::EventKind")» «class_name.shortName»::«event_params_name»::GetEventKind()
         {
           return «resolveSymbol("BTC::ServiceComm::API::EventKind")»::EventKind_PublishSubscribe;
         }
         
         «resolveSymbol("BTC::Commons::Core::String")» «class_name.shortName»::«event_params_name»::GetEventTypeDescription()
         {
           return «resolveSymbol("CABTYPENAME")»(«event_type»);
         }
         
         «resolveSymbol("std::function")»<«class_name.shortName»::«event_params_name»::EventDataType const ( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager::ObserverType::OnNextParamType")»)> «class_name»::«event_params_name»::GetUnmarshalFunction( )
         {
           return &Unmarshal«event_name»;
         }
         
         «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> «class_name.shortName»::Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«event_type»> &observer )
         {
           return «event.observableRegistrationName».Subscribe(observer);
         }
      «ENDFOR»
      '''
    }
    
    def override generateFunctionBody(InterfaceDeclaration interface_declaration, FunctionDeclaration function)
    {
        val protobuf_request_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
        val protobuf_response_message= typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
        
        '''
           «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «protobuf_request_message» > request( BorrowRequestMessage() );

           // encode request -->
           auto * const concreteRequest( request->mutable_«function.name.asRequest.asProtobufName(CaseFormat.LOWER_UNDERSCORE)»() );
           «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
              «IF GeneratorUtil.useCodec(param.paramType, ArtifactNature.CPP) && !(com.btc.serviceidl.util.Util.isByte(param.paramType) || com.btc.serviceidl.util.Util.isInt16(param.paramType) || com.btc.serviceidl.util.Util.isChar(param.paramType))»
                 «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                    «val ulimate_type = com.btc.serviceidl.util.Util.getUltimateType(param.paramType)»
                    «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                    «val protobuf_type = typeResolver.resolveProtobuf(ulimate_type, ProtobufType.RESPONSE).fullyQualifiedName»
                    «typeResolver.resolveCodecNS(paramBundle, ulimate_type, is_failable, Optional.of(interface_declaration))»::Encode«IF is_failable»Failable«ENDIF»< «resolve(ulimate_type)», «IF is_failable»«typeResolver.resolveFailableProtobufType(param.paramType, interface_declaration)»«ELSE»«protobuf_type»«ENDIF» >
                       ( «resolveSymbol("std::move")»(«param.paramName»), concreteRequest->mutable_«param.paramName.toLowerCase»() );
                 «ELSEIF com.btc.serviceidl.util.Util.isEnumType(param.paramType)»
                    concreteRequest->set_«param.paramName.toLowerCase»( «typeResolver.resolveCodecNS(paramBundle, param.paramType)»::Encode(«param.paramName») );
                 «ELSE»
                    «typeResolver.resolveCodecNS(paramBundle, param.paramType)»::Encode( «param.paramName», concreteRequest->mutable_«param.paramName.toLowerCase»() );
                 «ENDIF»
              «ELSE»
                 concreteRequest->set_«param.paramName.toLowerCase»(«param.paramName»);
              «ENDIF»
           «ENDFOR»
           // encode request <--
           
           «IF function.returnedType.isVoid»
              return Request«IF function.isSync»Sync«ELSE»Async«ENDIF»UnmarshalVoid( *request );
           «ELSE»
              return RequestAsyncUnmarshal< «toText(function.returnedType, interface_declaration)» >( *request, [&]( «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «protobuf_response_message» > response )
              {
                 // decode response -->
                 auto const& concreteResponse( response->«function.name.asResponse.asProtobufName(CaseFormat.LOWER_UNDERSCORE)»() );
                 «val output_parameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                 «IF !output_parameters.empty»
                    // handle [out] parameters
                    «FOR param : output_parameters»
                       «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                          «typeResolver.resolveDecode(paramBundle, param.paramType, interface_declaration)»( concreteResponse.«param.paramName.toLowerCase»(), «param.paramName» );
                       «ELSE»
                          «param.paramName» = «makeDecodeResponse(param.paramType, interface_declaration, param.paramName.toLowerCase)»
                       «ENDIF»
                    «ENDFOR»
                 «ENDIF»
                 return «makeDecodeResponse(function.returnedType, interface_declaration, function.name.toLowerCase)»
                 // decode response <--
              } )«IF function.isSync».Get()«ENDIF»;
           «ENDIF»
        '''
    }

   private def String makeDecodeResponse(EObject type, EObject container, String protobuf_name)
   {
      val use_codec = GeneratorUtil.useCodec(type, ArtifactNature.CPP)
      '''«IF use_codec»«typeResolver.resolveDecode(paramBundle, type, container)»( «ENDIF»concreteResponse.«protobuf_name»()«IF use_codec» )«ENDIF»;'''
   }
   
    
}
