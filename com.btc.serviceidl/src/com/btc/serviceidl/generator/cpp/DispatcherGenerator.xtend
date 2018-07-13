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
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.VoidType
import java.util.Optional
import org.eclipse.core.runtime.Path
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class DispatcherGenerator extends BasicCppGenerator
{
    def generateImplementationFileBody(InterfaceDeclaration interface_declaration)
    {
        val class_name = resolve(interface_declaration, paramBundle.projectType)
        val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
        val protobuf_request_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
        val protobuf_response_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
        val moduleNamespace = Optional.of(
            GeneratorUtil.getTransformedModuleName(
                new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP,
                TransformType.NAMESPACE))

        '''
            «class_name.shortName»::«class_name.shortName»
            (
               «resolveSymbol("BTC::Commons::Core::Context")»& context
               ,«resolveSymbol("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
               ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
            ) :
            «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interface_declaration.asBaseName»( serviceEndpoint.GetServiceFaultHandlerManagerFactory(), «resolveSymbol("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interface_declaration, moduleNamespace)»( GetServiceFaultHandlerManager() ); }
            
            «class_name.shortName»::«class_name.shortName»
            (
               «resolveSymbol("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
               ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «api_class_name» > dispatchee
            ) :
            «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interface_declaration.asBaseName»( serviceFaultHandlerManagerFactory, «resolveSymbol("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interface_declaration, moduleNamespace)»( GetServiceFaultHandlerManager() ); }
            
            «generateCppDestructor(interface_declaration)»
            
            «messagePtrType» «class_name.shortName»::ProcessRequest
            (
                  «messagePtrType» request,
                  const «clientIdentityType»& clientIdentity
            )
            {
               «IF targetVersion == ServiceCommVersion.V0_10»
                   // check whether request has exactly one part (other dispatchers could use more than one part)
                   if (request->GetNumElements() != 1) 
                   {
                      «resolveSymbol("CABLOG_ERROR")»("Received invalid request (wrong message part count): " << request->ToString());
                      «resolveSymbol("CABTHROW_V2")»( «resolveSymbol("BTC::ServiceComm::API::InvalidRequestReceivedException")»( «resolveSymbol("BTC::Commons::CoreExtras::StringBuilder")»() 
                         << "Expected exactly 1 message part, but received " << request->GetNumElements() ) );
                   }
               «ENDIF»
               
               // parse raw message into Protocol Buffers message object
               «resolveSymbol("BTC::Commons::Core::AutoPtr")»< «protobuf_request_message» > protoBufRequest( BorrowRequestMessage() );
               ParseRequestOrLogAndThrow( «class_name.shortName»::GetLogger(), *protoBufRequest, «IF targetVersion == ServiceCommVersion.V0_10»(*request)[0]«ELSE»*request«ENDIF» );
               
               «FOR function : interface_declaration.functions»
                  «generateFunctionHandler(function, interface_declaration)»                  
               «ENDFOR»
               
               «resolveSymbol("CABLOG_ERROR")»("Invalid request: " << protoBufRequest->DebugString().c_str());
               «resolveSymbol("CABTHROW_V2")»( «resolveSymbol("BTC::ServiceComm::API::InvalidRequestReceivedException")»(«resolveSymbol("BTC::Commons::Core::String")»("«interface_declaration.name»_Request is invalid, unknown request type")));
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
            
            void «class_name.shortName»::RegisterMessageTypes(«resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder)
            {
               «resolveSymbol("BTC::ServiceComm::Commons::CMessagePartPool")» pool;
               «resolveSymbol("BTC::ServiceComm::Commons::CMessage")» buffer;
               «resolveSymbol("BTC::ServiceComm::ProtobufUtil::ExportDescriptors")»< «protobuf_request_message» >(buffer, pool);
               decoder.RegisterMessageTypes( 
                  «api_class_name»::TYPE_GUID()
                 ,buffer
                 ,"«GeneratorUtil.switchSeparator(protobuf_request_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»"
                 ,"«GeneratorUtil.switchSeparator(protobuf_response_message.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»" );
            }
            
            «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> «class_name.shortName»::CreateDispatcherAutoRegistrationFactory
            (
               «resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
               , «resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
               , «resolveSymbol("BTC::Commons::CoreExtras::UUID")» const &instanceGuid /*= Commons::CoreExtras::UUID()*/
               , «resolveSymbol("BTC::Commons::Core::String")» const &instanceName /*= BTC::Commons::Core::String ()*/
            )
            {
               using «resolveSymbol("BTC::ServiceComm::Util::CDispatcherAutoRegistrationFactory")»;
               using «resolveSymbol("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContext")»;
            
               return «resolveSymbol("BTC::Commons::Core::CreateUnique")»<CDispatcherAutoRegistrationFactory<«api_class_name», «class_name.shortName»>>
               (
               loggerFactory
               «IF targetVersion == ServiceCommVersion.V0_10»
                   , serverEndpoint
               «ENDIF»
               , instanceGuid
               , «resolveSymbol("CABTYPENAME")»(«api_class_name»)
               , instanceName.IsNotEmpty() ? instanceName : («resolveSymbol("CABTYPENAME")»(«api_class_name») + " default instance")
               );
            }
        '''
    }
    
    def generateFunctionHandler(FunctionDeclaration function, InterfaceDeclaration interface_declaration)
    {
        val protobuf_request_method = function.name.asRequest.asCppProtobufName
        val is_sync = function.isSync
        val is_void = function.returnedType instanceof VoidType
        val protobuf_response_method = function.name.asResponse.asCppProtobufName
        val output_parameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]
        val protobuf_response_message = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)
        '''
            if ( protoBufRequest->has_«protobuf_request_method»() )
            {
           // decode request -->
           auto const& concreteRequest( protoBufRequest->«protobuf_request_method»() );
           «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.CPP)»
                   «IF param.paramType.isSequenceType»
                       «val ulimate_type = param.paramType.ultimateType»
                       «val is_uuid = ulimate_type.isUUIDType»
                       «val is_failable = param.paramType.isFailable»
                       auto «param.paramName»( «typeResolver.resolveCodecNS(paramBundle, ulimate_type, is_failable, Optional.of(interface_declaration))»::Decode«IF is_failable»Failable«ELSEIF is_uuid»UUID«ENDIF»
                          «IF !is_uuid || is_failable»
                              «val protobuf_type = typeResolver.resolveProtobuf(ulimate_type, ProtobufType.REQUEST).fullyQualifiedName»
                              < «IF is_failable»«typeResolver.resolveFailableProtobufType(param.paramType.actualType, interface_declaration)»«ELSE»«protobuf_type»«ENDIF», «resolve(ulimate_type)» >
                          «ENDIF»
                          (concreteRequest.«param.paramName.asCppProtobufName»()) );
                   «ELSE»
                       auto «param.paramName»( «typeResolver.resolveCodecNS(paramBundle, param.paramType.actualType)»::Decode«IF param.paramType.isUUIDType»UUID«ENDIF»(concreteRequest.«param.paramName.asCppProtobufName»()) );
                   «ENDIF»
               «ELSE»
                   auto «param.paramName»( concreteRequest.«param.paramName.asCppProtobufName»() );
               «ENDIF»
           «ENDFOR»
           // decode request <--
           
           «IF !output_parameters.empty»
               // prepare [out] parameters
               «FOR param : output_parameters»
                   «IF param.paramType.isSequenceType»
                       «val type_name = resolve(param.paramType.ultimateType)»
                       «val is_failable = param.paramType.isFailable»
                       «if (is_failable) addCabInclude(new Path("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h")).alias("") /* necessary to use InsertableTraits with FailableHandle */»
                       «val effective_typename = if (is_failable) '''«resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")»< «type_name» >''' else type_name»
                       «resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::AutoPtrType «param.paramName»(
                          «resolveSymbol("BTC::Commons::FutureUtil::GetOrCreateDefaultInsertable")»(«resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «effective_typename» >::MakeEmptyInsertablePtr()) );
                       auto «param.paramName»Future = «param.paramName»->GetFuture();
                   «ELSE»
                       «toText(param.paramType, param)» «param.paramName»;
                   «ENDIF»
               «ENDFOR»
           «ENDIF»
           
           // call actual method
        «IF !is_void»auto result( «ENDIF»GetDispatchee().«function.name»(
                 «FOR p : function.parameters SEPARATOR ", "»
                     «val isSequenceType = p.paramType.isSequenceType»
                     «IF p.direction == ParameterDirection.PARAM_OUT && isSequenceType»*«ENDIF»
                     «IF p.direction == ParameterDirection.PARAM_IN && isSequenceType»«resolveSymbol("std::move")»(«ENDIF»
                     «p.paramName»
                     «IF p.direction == ParameterDirection.PARAM_IN && isSequenceType»)«ENDIF»
                 «ENDFOR»)«IF !is_sync».Get()«ENDIF»«IF !is_void» )«ENDIF»;
        
        // prepare response
        «resolveSymbol("BTC::Commons::Core::AutoPtr")»< «protobuf_response_message» > response( BorrowReplyMessage() );
        
        «IF !is_void || !output_parameters.empty»
            // encode response -->
            auto * const concreteResponse( response->mutable_«protobuf_response_method»() );
            «IF !is_void»«makeEncodeResponse(function.returnedType.actualType, interface_declaration, function.name.asCppProtobufName, Optional.empty)»«ENDIF»
            «IF !output_parameters.empty»
                // handle [out] parameters
                «FOR param : output_parameters»
                    «makeEncodeResponse(param.paramType.actualType, interface_declaration, param.paramName.asCppProtobufName, Optional.of(param.paramName))»
                «ENDFOR»
            «ENDIF»
            // encode response <--
        «ENDIF»
        
        // send return message
        return «makeToMessagePtrType('''«resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufSupport")»::ProtobufToMessagePart(
                 GetMessagePartPool()
                ,*response )''')»;
            }
        '''
    }

    def makeToMessagePtrType(String messagePart)
    {
        if (targetVersion == ServiceCommVersion.V0_10)
        {
            '''«resolveSymbol("BTC::ServiceComm::CommonsUtil::MakeSinglePartMessage")»(
                   GetMessagePool(),  «messagePart»)'''
        }
        else
            messagePart
    }

    private def String makeEncodeResponse(AbstractTypeReference type, AbstractContainerDeclaration container, String protobuf_name,
        Optional<String> output_param)
    {
        val api_input = if (output_param.present) output_param.get else "result"
        '''
            «IF GeneratorUtil.useCodec(type, ArtifactNature.CPP) && !(type.isByte || type.isInt16 || type.isChar)»
                «IF type.isSequenceType»
                    «val ulimate_type = type.ultimateType»
                    «val is_failable = type.isFailable»
                    «val protobuf_type = typeResolver.resolveProtobuf(ulimate_type, ProtobufType.RESPONSE).fullyQualifiedName»
                    «typeResolver.resolveCodecNS(paramBundle, ulimate_type, is_failable, Optional.of(container))»::Encode«IF is_failable»Failable«ENDIF»< «resolve(ulimate_type)», «IF is_failable»«typeResolver.resolveFailableProtobufType(type, container)»«ELSE»«protobuf_type»«ENDIF» >
                       ( «resolveSymbol("std::move")»(«api_input»«IF output_param.present»Future.Get()«ENDIF»), concreteResponse->mutable_«protobuf_name»() );
                «ELSEIF type.isEnumType»
                    concreteResponse->set_«protobuf_name»( «typeResolver.resolveCodecNS(paramBundle, type)»::Encode(«api_input») );
                «ELSE»
                    «typeResolver.resolveCodecNS(paramBundle, type)»::Encode( «api_input», concreteResponse->mutable_«protobuf_name»() );
                «ENDIF»
            «ELSE»
                concreteResponse->set_«protobuf_name»(«api_input»);
            «ENDIF»
        '''
    }

    private def getClientIdentityType()
    {
        if (targetVersion.equals(ServiceCommVersion.V0_10))
            resolveSymbol("BTC::ServiceComm::Commons::CMessage")
        else
            resolveSymbol("BTC::ServiceComm::Commons::EndpointIdentity")
    }

    private def getMessagePtrType()
    {
        if (targetVersion.equals(ServiceCommVersion.V0_10))
            resolveSymbol("BTC::ServiceComm::Commons::MessagePtr")
        else
            resolveSymbol("BTC::ServiceComm::Commons::ConstMessagePartPtr")
    }

    def generateHeaderFileBody(InterfaceDeclaration interface_declaration)
    {
        val class_name = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType,
            interface_declaration.name)

        // TODO do not use anonymous namespaces in a header file!
        '''
            // anonymous namespace for internally used typedef
            namespace
            {
               «makeDispatcherBaseTemplate(interface_declaration)»
            }
            
            class «makeExportMacro()» «class_name» :
            virtual private «resolveSymbol("BTC::Logging::API::LoggerAware")»
            , public «interface_declaration.asBaseName»
            {
            public:
               «generateHConstructor(interface_declaration)»
               
               «class_name»
               (
                  «resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
                  ,«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
                  ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «resolve(interface_declaration)» > dispatchee
               );
               
               «generateHDestructor(interface_declaration)»
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::ProcessRequest
               */
               virtual «messagePtrType» ProcessRequest
               (
                  «messagePtrType» request,
                  const «clientIdentityType»& clientIdentity
               ) override;
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::AttachEndpoint
               */
               virtual void AttachEndpoint( «resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
               
               /**
                  \see BTC::ServiceComm::API::IRequestDispatcher::DetachEndpoint
               */
               virtual void DetachEndpoint( «resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» &endpoint ) override;
               
               static void RegisterMessageTypes( «resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder );
               
               // for server runner
               static «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> CreateDispatcherAutoRegistrationFactory
               (
                  «resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
                  ,«resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
                  ,«resolveSymbol("BTC::Commons::CoreExtras::UUID")» const &instanceGuid = BTC::Commons::CoreExtras::UUID()
                  ,«resolveSymbol("BTC::Commons::Core::String")» const &instanceName = BTC::Commons::Core::String()
               );
            };
        '''
    }

    private def String makeDispatcherBaseTemplate(InterfaceDeclaration interface_declaration)
    {
        val api_class_name = resolve(interface_declaration, ProjectType.SERVICE_API)
        val protobuf_request = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)
        val protobuf_response = typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)

        '''
            typedef «resolveSymbol("BTC::ServiceComm::ProtobufBase::AProtobufServiceDispatcherBaseTemplate")»<
               «api_class_name»
               , «protobuf_request»
               , «protobuf_response» > «interface_declaration.asBaseName»;
        '''
    }

}
