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

import com.btc.serviceidl.generator.Main
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class ProxyGenerator extends BasicCppGenerator {
        
    def generateImplementationFileBody(InterfaceDeclaration interfaceDeclaration) {
      val className = resolve(interfaceDeclaration, paramBundle.projectType)
      val apiClassName = resolve(interfaceDeclaration, ProjectType.SERVICE_API)
      
      // the class name is not used explicitly in the following code, but
      // we need to include this *.impl.h file to avoid linker errors
      resolveSymbolWithImplementation("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")
      
      '''
      «className.shortName»::«className.shortName»
      (
         «resolveSymbol("BTC::Commons::Core::Context")» &context
         ,«resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
         ,«resolveSymbol("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
         ,«resolveSymbolWithImplementation("BTC::Commons::CoreExtras::Optional")»<«resolveSymbol("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid
      ) :
      m_context(context)
      , «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
      , «interfaceDeclaration.asBaseName»(context, localEndpoint, «apiClassName»::TYPE_GUID(), serverServiceInstanceGuid
      «IF generationSettings.hasGeneratorOption(Main.OPTION_GENERATOR_OPTION_CPP_PROXY_TIMEOUT_SECONDS)»
        «val proxyTimeoutSeconds = Integer.parseInt(generationSettings.getGeneratorOption(Main.OPTION_GENERATOR_OPTION_CPP_PROXY_TIMEOUT_SECONDS))»
        ,
        «IF targetVersion == ServiceCommVersion.V0_10 || targetVersion == ServiceCommVersion.V0_11»
          «resolveSymbol("BTC::Commons::Core::TimeSpan")»::Seconds(«proxyTimeoutSeconds»)
        «ELSE»
          «resolveSymbol("std::chrono::seconds")»(«proxyTimeoutSeconds»)
        «ENDIF»
      «ENDIF»
      )
      «FOR event : interfaceDeclaration.events»
      , «event.observableRegistrationName»(context, localEndpoint.GetEventRegistry(), «event.eventParamsName»())
      «ENDFOR»
      { «getRegisterServiceFaults(interfaceDeclaration, Optional.of(GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP, TransformType.NAMESPACE)))»( GetClientServiceReference().GetServiceFaultHandlerManager() ); }
      
      «generateCppDestructor(interfaceDeclaration)»
      
      «generateInheritedInterfaceMethods(interfaceDeclaration)»
      
      «FOR event : interfaceDeclaration.events AFTER System.lineSeparator»
         «val eventType = resolve(event.data)»
         «val eventName = eventType.shortName»
         «val eventParamsName = event.eventParamsName»
         
         namespace // anonymous namespace to avoid naming collisions
         {
            «eventType» const Unmarshal«eventName»( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager")»::ObserverType::OnNextParamType event )
            {
               «/* TODO remove ProtobufType argument */»
               «typeResolver.resolveProtobuf(event.data, ProtobufType.REQUEST)» eventProtobuf;
               «IF targetVersion == ServiceCommVersion.V0_10»
               if (!(event->GetNumElements() == 1))
                  «resolveSymbol("CABTHROW_V2")»(«resolveSymbol("BTC::ServiceComm::API::InvalidMessageReceivedException")»("Event message has not exactly one part"));
               «ENDIF»
               «resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ParseMessageOrThrow<«resolveSymbol("BTC::ServiceComm::API::InvalidMessageReceivedException")»>(eventProtobuf, «IF targetVersion == ServiceCommVersion.V0_10»(*event)[0]«ELSE»*event«ENDIF»);

               return «typeResolver.resolveCodecNS(paramBundle, event.data)»::Decode( eventProtobuf );
            }
         }
         
         «resolveSymbol("BTC::Commons::CoreExtras::UUID")» «className.shortName»::«eventParamsName»::GetEventTypeGuid()
         {
           /** this uses a global event type, i.e. if there are multiple instances of the service (dispatcher), these will all be subscribed;
           *  alternatively, an instance-specific type guid must be registered by the dispatcher and queried by the proxy */
           return «eventType»::EVENT_TYPE_GUID();
         }
         
         «resolveSymbol("BTC::ServiceComm::API::EventKind")» «className.shortName»::«eventParamsName»::GetEventKind()
         {
           return «resolveSymbol("BTC::ServiceComm::API::EventKind")»::EventKind_PublishSubscribe;
         }
         
         «resolveSymbol("BTC::Commons::Core::String")» «className.shortName»::«eventParamsName»::GetEventTypeDescription()
         {
           return «resolveSymbol("CABTYPENAME")»(«eventType»);
         }
         
         «resolveSymbol("std::function")»<«className.shortName»::«eventParamsName»::EventDataType const ( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager::ObserverType::OnNextParamType")»)> «className»::«eventParamsName»::GetUnmarshalFunction( )
         {
           return &Unmarshal«eventName»;
         }
         
         «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> «className.shortName»::Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«eventType»> &observer )
         {
           return «event.observableRegistrationName».Subscribe(observer);
         }
      «ENDFOR»
      '''
    }
    
    override generateFunctionBody(InterfaceDeclaration interfaceDeclaration, FunctionDeclaration function)
    {
        val protobufRequestMessage = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.REQUEST)
        val protobufResponseMessage= typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.RESPONSE)
        
        '''
           «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «protobufRequestMessage» > request( BorrowRequestMessage() );

           // encode request -->
           auto * const concreteRequest( request->mutable_«function.name.asRequest.asCppProtobufName»() );
           «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
              «IF GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.CPP) && !(param.paramType.isByte || param.paramType.isInt16 || param.paramType.isChar)»
                 «IF param.paramType.isSequenceType»
                    «val ulimateType = param.paramType.ultimateType»
                    «val isFailable = param.paramType.isFailable»
                    «val protobufType = typeResolver.resolveProtobuf(ulimateType, ProtobufType.RESPONSE).fullyQualifiedName»
                    «typeResolver.resolveCodecNS(paramBundle, ulimateType, isFailable, Optional.of(interfaceDeclaration))»::Encode«IF isFailable»Failable«ENDIF»< «resolve(ulimateType)», «IF isFailable»«typeResolver.resolveFailableProtobufType(param.paramType.actualType, interfaceDeclaration)»«ELSE»«protobufType»«ENDIF» >
                       ( «resolveSymbol("std::move")»(«param.paramName»), concreteRequest->mutable_«param.paramName.asCppProtobufName»() );
                 «ELSEIF param.paramType.isEnumType»
                    concreteRequest->set_«param.paramName.asCppProtobufName»( «typeResolver.resolveCodecNS(paramBundle, param.paramType.actualType)»::Encode(«param.paramName») );
                 «ELSE»
                    «typeResolver.resolveCodecNS(paramBundle, param.paramType.actualType)»::Encode( «param.paramName», concreteRequest->mutable_«param.paramName.asCppProtobufName»() );
                 «ENDIF»
              «ELSE»
                 concreteRequest->set_«param.paramName.asCppProtobufName»(«param.paramName»);
              «ENDIF»
           «ENDFOR»
           // encode request <--
           
           «IF function.returnedType instanceof VoidType»
              return Request«IF function.isSync»Sync«ELSE»Async«ENDIF»UnmarshalVoid( *request );
           «ELSE»
              return RequestAsyncUnmarshal< «toText(function.returnedType, interfaceDeclaration)» >( *request, [&]( «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «protobufResponseMessage» > response )
              {
                 // decode response -->
                 auto const& concreteResponse( response->«function.name.asResponse.asCppProtobufName»() );
                 «val outputParameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                 «IF !outputParameters.empty»
                    // handle [out] parameters
                    «FOR param : outputParameters»
                       «IF param.paramType.isSequenceType»
                          «typeResolver.resolveDecode(paramBundle, param.paramType.actualType, interfaceDeclaration)»( concreteResponse.«param.paramName.asCppProtobufName»(), «param.paramName» );
                       «ELSE»
                          «param.paramName» = «makeDecodeResponse(param.paramType.actualType, interfaceDeclaration, param.paramName.asCppProtobufName)»
                       «ENDIF»
                    «ENDFOR»
                 «ENDIF»
                 return «makeDecodeResponse(function.returnedType.actualType, interfaceDeclaration, function.name.asCppProtobufName)»
                 // decode response <--
              } )«IF function.isSync».Get()«ENDIF»;
           «ENDIF»
        '''
    }

   private def String makeDecodeResponse(AbstractTypeReference type, AbstractContainerDeclaration container, String protobufName)
   {
      val useCodec = GeneratorUtil.useCodec(type, ArtifactNature.CPP)
      '''«IF useCodec»«typeResolver.resolveDecode(paramBundle, type, container)»( «ENDIF»concreteResponse.«protobufName»()«IF useCodec» )«ENDIF»;'''
   }
   
    
}
