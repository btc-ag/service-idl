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
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.util.Constants
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class DispatcherGenerator extends BasicCppGenerator
{
    def generateImplementationFileBody(InterfaceDeclaration interface_declaration)
    {
        val class_name = resolve(interface_declaration, paramBundle.projectType)
        val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
        val protobuf_request_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
        val protobuf_response_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)

        val cab_message_ptr = resolveCAB("BTC::ServiceComm::Commons::MessagePtr")

        '''
            «class_name.shortName»::«class_name.shortName»
            (
               «resolveCAB("BTC::Commons::Core::Context")»& context
               ,«resolveCAB("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
               ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
            ) :
            «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interface_declaration.asBaseName»( serviceEndpoint.GetServiceFaultHandlerManagerFactory(), «resolveSTL("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP, TransformType.NAMESPACE)))»( GetServiceFaultHandlerManager() ); }
            
            «class_name.shortName»::«class_name.shortName»
            (
               «resolveCAB("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
               ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
            ) :
            «resolveCAB("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interface_declaration.asBaseName»( serviceFaultHandlerManagerFactory, «resolveSTL("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interface_declaration, Optional.of(GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP, TransformType.NAMESPACE)))»( GetServiceFaultHandlerManager() ); }
            
            «generateCppDestructor(interface_declaration)»
            
            «cab_message_ptr» «class_name.shortName»::ProcessRequest
            (
               «cab_message_ptr» requestBuffer
               , «resolveCAB("BTC::ServiceComm::Commons::CMessage")» const& clientIdentity
            )
            {
               // check whether request has exactly one part (other dispatchers could use more than one part)
               if (requestBuffer->GetNumElements() != 1) 
               {
                  «resolveCAB("CABLOG_ERROR")»("Received invalid request (wrong message part count): " << requestBuffer->ToString());
                  «resolveCAB("CABTHROW_V2")»( «resolveCAB("BTC::ServiceComm::API::InvalidRequestReceivedException")»( «resolveCAB("BTC::Commons::CoreExtras::StringBuilder")»() 
                     << "Expected exactly 1 message part, but received " << requestBuffer->GetNumElements() ) );
               }
               
               // parse raw message into Protocol Buffers message object
               «resolveCAB("BTC::Commons::Core::AutoPtr")»< «protobuf_request_message» > request( BorrowRequestMessage() );
               ParseRequestOrLogAndThrow( «class_name.shortName»::GetLogger(), *request, (*requestBuffer)[0] );
               
               «FOR function : interface_declaration.functions»
                   «val protobuf_request_method = com.btc.serviceidl.util.Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_REQUEST)»
                   «val is_sync = function.isSync»
                   «val is_void = function.returnedType.isVoid»
                   «val protobuf_response_method = com.btc.serviceidl.util.Util.makeProtobufMethodName(function.name, Constants.PROTOBUF_RESPONSE)»
                   «val output_parameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                   if ( request->has_«protobuf_request_method»() )
                   {
                      // decode request -->
                      auto const& concreteRequest( request->«protobuf_request_method»() );
                      «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                          «IF GeneratorUtil.useCodec(param.paramType, ArtifactNature.CPP)»
                              «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                                  «val ulimate_type = com.btc.serviceidl.util.Util.getUltimateType(param.paramType)»
                                  «val is_uuid = com.btc.serviceidl.util.Util.isUUIDType(ulimate_type)»
                                  «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                                  auto «param.paramName»( «typeResolver.resolveCodecNS(ulimate_type, is_failable, Optional.of(interface_declaration))»::Decode«IF is_failable»Failable«ELSEIF is_uuid»UUID«ENDIF»
                                     «IF !is_uuid || is_failable»
                                         «val protobuf_type = typeResolver.resolveProtobuf(ulimate_type, ProtobufType.REQUEST).fullyQualifiedName»
                                         < «IF is_failable»«typeResolver.resolveFailableProtobufType(param.paramType, interface_declaration)»«ELSE»«protobuf_type»«ENDIF», «resolve(ulimate_type)» >
                                     «ENDIF»
                                     (concreteRequest.«param.paramName.toLowerCase»()) );
                              «ELSE»
                                  auto «param.paramName»( «typeResolver.resolveCodecNS(param.paramType)»::Decode«IF com.btc.serviceidl.util.Util.isUUIDType(param.paramType)»UUID«ENDIF»(concreteRequest.«param.paramName.toLowerCase»()) );
                              «ENDIF»
                          «ELSE»
                              auto «param.paramName»( concreteRequest.«param.paramName.toLowerCase»() );
                          «ENDIF»
                      «ENDFOR»
                      // decode request <--
                      
                      «IF !output_parameters.empty»
                          // prepare [out] parameters
                          «FOR param : output_parameters»
                              «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                                  «val type_name = resolve(com.btc.serviceidl.util.Util.getUltimateType(param.paramType))»
                                  «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                                  «if (is_failable) cab_includes.add("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h").alias("") /* necessary to use InsertableTraits with FailableHandle */»
                                  «val effective_typename = if (is_failable) '''«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»< «type_name» >''' else type_name»
                                  «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::AutoPtrType «param.paramName»(
                                     «resolveCAB("BTC::Commons::FutureUtil::GetOrCreateDefaultInsertable")»(«resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::MakeEmptyInsertablePtr()) );
                                  auto «param.paramName»Future = «param.paramName»->GetFuture();
                              «ELSE»
                                  «toText(param.paramType, param)» «param.paramName»;
                              «ENDIF»
                          «ENDFOR»
                      «ENDIF»
                      
                      // call actual method
               «IF !is_void»auto result( «ENDIF»GetDispatchee().«function.name»(«FOR p : function.parameters SEPARATOR ", "»«IF p.direction == ParameterDirection.PARAM_OUT && com.btc.serviceidl.util.Util.isSequenceType(p.paramType)»*«ENDIF»«IF p.direction == ParameterDirection.PARAM_IN && com.btc.serviceidl.util.Util.isSequenceType(p.paramType)»«resolveSTL("std::move")»(«ENDIF»«p.paramName»«IF p.direction == ParameterDirection.PARAM_IN && com.btc.serviceidl.util.Util.isSequenceType(p.paramType)»)«ENDIF»«ENDFOR»)«IF !is_sync».Get()«ENDIF»«IF !is_void» )«ENDIF»;
               
               // prepare response
               «resolveCAB("BTC::Commons::Core::AutoPtr")»< «protobuf_response_message» > response( BorrowReplyMessage() );
               
               «IF !is_void || !output_parameters.empty»
                   // encode response -->
                   auto * const concreteResponse( response->mutable_«protobuf_response_method»() );
                   «IF !is_void»«makeEncodeResponse(function.returnedType, interface_declaration, function.name.toLowerCase, Optional.empty)»«ENDIF»
                   «IF !output_parameters.empty»
                       // handle [out] parameters
                       «FOR param : output_parameters»
                           «makeEncodeResponse(param.paramType, interface_declaration, param.paramName.toLowerCase, Optional.of(param.paramName))»
                       «ENDFOR»
                   «ENDIF»
                   // encode response <--
               «ENDIF»
               
               // send return message
               return «resolveCAB("BTC::ServiceComm::CommonsUtil::MakeSinglePartMessage")»(
                   GetMessagePool(), «resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ProtobufToMessagePart(
                     GetMessagePartPool()
                    ,*response ) );
                   }
               «ENDFOR»
               
               «resolveCAB("CABLOG_ERROR")»("Invalid request: " << request->DebugString().c_str());
               «resolveCAB("CABTHROW_V2")»( «resolveCAB("BTC::ServiceComm::API::InvalidRequestReceivedException")»(«resolveCAB("BTC::Commons::Core::String")»("«interface_declaration.name»_Request is invalid, unknown request type")));
            }
            
            void «class_name.shortName»::AttachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
            {
               «interface_declaration.asBaseName»::AttachEndpoint( endpoint );
               
               /** Publisher/Subscriber could be attached here to the endpoint
               */
            }
            
            void «class_name.shortName»::DetachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
            {
               /** Publisher/Subscriber could be detached here
               */
            
               «interface_declaration.asBaseName»::DetachEndpoint(endpoint);
            }
            
            void «class_name.shortName»::RegisterMessageTypes(«resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder)
            {
               «resolveCAB("BTC::ServiceComm::Commons::CMessagePartPool")» pool;
               «resolveCAB("BTC::ServiceComm::Commons::CMessage")» buffer;
               «resolveCAB("BTC::ServiceComm::ProtobufUtil::ExportDescriptors")»< «protobuf_request_message» >(buffer, pool);
               decoder.RegisterMessageTypes( 
                  «api_class_name»::TYPE_GUID()
                 ,buffer
                 ,"«GeneratorUtil.switchSeparator(protobuf_request_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»"
                 ,"«GeneratorUtil.switchSeparator(protobuf_response_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»" );
            }
            
            «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> «class_name.shortName»::CreateDispatcherAutoRegistrationFactory
            (
               «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
               , «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
               , «resolveCAB("BTC::Commons::CoreExtras::UUID")» const &instanceGuid /*= Commons::CoreExtras::UUID()*/
               , «resolveCAB("BTC::Commons::Core::String")» const &instanceName /*= BTC::Commons::Core::String ()*/
            )
            {
               using «resolveCAB("BTC::ServiceComm::Util::CDispatcherAutoRegistrationFactory")»;
               using «resolveCAB("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContext")»;
            
               return «resolveCAB("BTC::Commons::Core::CreateUnique")»<CDispatcherAutoRegistrationFactory<«api_class_name», «class_name.shortName»>>
               (
               loggerFactory
               , serverEndpoint
               , instanceGuid
               , «resolveCAB("CABTYPENAME")»(«api_class_name»)
               , instanceName.IsNotEmpty() ? instanceName : («resolveCAB("CABTYPENAME")»(«api_class_name») + " default instance")
               );
            }
        '''
    }

    def private String makeEncodeResponse(EObject type, EObject container, String protobuf_name,
        Optional<String> output_param)
    {
        val api_input = if (output_param.present) output_param.get else "result"
        '''
            «IF GeneratorUtil.useCodec(type, ArtifactNature.CPP) && !(com.btc.serviceidl.util.Util.isByte(type) || com.btc.serviceidl.util.Util.isInt16(type) || com.btc.serviceidl.util.Util.isChar(type))»
                «IF com.btc.serviceidl.util.Util.isSequenceType(type)»
                    «val ulimate_type = com.btc.serviceidl.util.Util.getUltimateType(type)»
                    «val is_failable = com.btc.serviceidl.util.Util.isFailable(type)»
                    «val protobuf_type = typeResolver.resolveProtobuf(ulimate_type, ProtobufType.RESPONSE).fullyQualifiedName»
                    «typeResolver.resolveCodecNS(ulimate_type, is_failable, Optional.of(container))»::Encode«IF is_failable»Failable«ENDIF»< «resolve(ulimate_type)», «IF is_failable»«typeResolver.resolveFailableProtobufType(type, container)»«ELSE»«protobuf_type»«ENDIF» >
                       ( «resolveSTL("std::move")»(«api_input»«IF output_param.present»Future.Get()«ENDIF»), concreteResponse->mutable_«protobuf_name»() );
                «ELSEIF com.btc.serviceidl.util.Util.isEnumType(type)»
                    concreteResponse->set_«protobuf_name»( «typeResolver.resolveCodecNS(type)»::Encode(«api_input») );
                «ELSE»
                    «typeResolver.resolveCodecNS(type)»::Encode( «api_input», concreteResponse->mutable_«protobuf_name»() );
                «ENDIF»
            «ELSE»
                concreteResponse->set_«protobuf_name»(«api_input»);
            «ENDIF»
        '''
    }

    def generateHeaderFileBody(InterfaceDeclaration interface_declaration)
    {
        val class_name = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType, interface_declaration.name)

        val cab_message_ptr = resolveCAB("BTC::ServiceComm::Commons::MessagePtr")
        
        // TODO do not use anonymous namespaces in a header file!
        '''
            // anonymous namespace for internally used typedef
            namespace
            {
               «makeDispatcherBaseTemplate(interface_declaration)»
            }
            
            class «makeExportMacro()» «class_name» :
            virtual private «resolveCAB("BTC::Logging::API::LoggerAware")»
            , public «interface_declaration.asBaseName»
            {
            public:
               «generateHConstructor(interface_declaration)»
               
               «class_name»
               (
                  «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
                  ,«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
                  ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «resolve(interface_declaration)» > dispatchee
               );
               
               «generateHDestructor(interface_declaration)»
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::ProcessRequest
               */
               virtual «cab_message_ptr» ProcessRequest
               (
                  «cab_message_ptr» request,
                  «resolveCAB("BTC::ServiceComm::Commons::CMessage")» const& clientIdentity
               ) override;
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::AttachEndpoint
               */
               virtual void AttachEndpoint( «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::DetachEndpoint
               */
               virtual void DetachEndpoint( «resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
               
               static void RegisterMessageTypes( «resolveCAB("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder );
               
               // for server runner
               static «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> CreateDispatcherAutoRegistrationFactory
               (
                  «resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
                  ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
                  ,«resolveCAB("BTC::Commons::CoreExtras::UUID")» const &instanceGuid = BTC::Commons::CoreExtras::UUID()
                  ,«resolveCAB("BTC::Commons::Core::String")» const &instanceName = BTC::Commons::Core::String()
               );
            };
        '''
    }

    def private String makeDispatcherBaseTemplate(InterfaceDeclaration interface_declaration)
    {
        val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
        val protobuf_request = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
        val protobuf_response = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)

        '''
            typedef «resolveCAB("BTC::ServiceComm::ProtobufBase::AProtobufServiceDispatcherBaseTemplate")»<
               «api_class_name»
               , «protobuf_request»
               , «protobuf_response» > «interface_declaration.asBaseName»;
        '''
    }

}
