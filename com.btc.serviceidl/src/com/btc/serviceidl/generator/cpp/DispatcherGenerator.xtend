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
    def generateImplementationFileBody(InterfaceDeclaration interfaceDeclaration)
    {
        val className = resolve(interfaceDeclaration, paramBundle.projectType)
        val apiClassName = resolve(interfaceDeclaration, ProjectType.SERVICE_API)
        val protobufRequestMessage = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.REQUEST)
        val protobufResponseMessage = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.RESPONSE)
        val moduleNamespace = Optional.of(
            GeneratorUtil.getTransformedModuleName(
                new ParameterBundle.Builder(paramBundle).with(ProjectType.SERVICE_API).build, ArtifactNature.CPP,
                TransformType.NAMESPACE))

        '''
            «className.shortName»::«className.shortName»
            (
               «resolveSymbol("BTC::Commons::Core::Context")»& context
               ,«resolveSymbol("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
               ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «apiClassName» > dispatchee
            ) :
            «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interfaceDeclaration.asBaseName»( serviceEndpoint.GetServiceFaultHandlerManagerFactory(), «resolveSymbol("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interfaceDeclaration, moduleNamespace)»( GetServiceFaultHandlerManager() ); }
            
            «className.shortName»::«className.shortName»
            (
               «resolveSymbol("BTC::Logging::API::LoggerFactory")»& loggerFactory
               ,«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
               ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «apiClassName» > dispatchee
            ) :
            «resolveSymbol("BTC_CAB_LOGGING_API_INIT_LOGGERAWARE")»(loggerFactory)
            , «interfaceDeclaration.asBaseName»( serviceFaultHandlerManagerFactory, «resolveSymbol("std::move")»(dispatchee) )
            { «getRegisterServerFaults(interfaceDeclaration, moduleNamespace)»( GetServiceFaultHandlerManager() ); }
            
            «generateCppDestructor(interfaceDeclaration)»
            
            «messagePtrType» «className.shortName»::ProcessRequest
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
               «resolveSymbol("BTC::Commons::Core::AutoPtr")»< «protobufRequestMessage» > protoBufRequest( BorrowRequestMessage() );
               ParseRequestOrLogAndThrow( «className.shortName»::GetLogger(), *protoBufRequest, «IF targetVersion == ServiceCommVersion.V0_10»(*request)[0]«ELSE»*request«ENDIF» );
               
               «FOR function : interfaceDeclaration.functions»
                  «generateFunctionHandler(function, interfaceDeclaration)»                  
               «ENDFOR»
               
               «resolveSymbol("CABLOG_ERROR")»("Invalid request: " << protoBufRequest->DebugString().c_str());
               «resolveSymbol("CABTHROW_V2")»( «resolveSymbol("BTC::ServiceComm::API::InvalidRequestReceivedException")»(«resolveSymbol("BTC::Commons::Core::String")»("«interfaceDeclaration.name»_Request is invalid, unknown request type")));
            }
            
            void «className.shortName»::AttachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
            {
               «interfaceDeclaration.asBaseName»::AttachEndpoint( endpoint );
               
               /** Publisher/Subscriber could be attached here to the endpoint
               */
            }
            
            void «className.shortName»::DetachEndpoint(BTC::ServiceComm::API::IServerEndpoint &endpoint)
            {
               /** Publisher/Subscriber could be detached here
               */
            
               «interfaceDeclaration.asBaseName»::DetachEndpoint(endpoint);
            }
            
            void «className.shortName»::RegisterMessageTypes(«resolveSymbol("BTC::ServiceComm::ProtobufUtil::ProtobufMessageDecoder")» &decoder)
            {
               «resolveSymbol("BTC::ServiceComm::Commons::CMessagePartPool")» pool;
               «resolveSymbol("BTC::ServiceComm::Commons::CMessage")» buffer;
               «resolveSymbol("BTC::ServiceComm::ProtobufUtil::ExportDescriptors")»< «protobufRequestMessage» >(buffer, pool);
               decoder.RegisterMessageTypes( 
                  «apiClassName»::TYPE_GUID()
                 ,buffer
                 ,"«GeneratorUtil.switchSeparator(protobufRequestMessage.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»"
                 ,"«GeneratorUtil.switchSeparator(protobufResponseMessage.toString, TransformType.NAMESPACE, TransformType.PACKAGE)»" );
            }
            
            «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::ServiceComm::Util::IDispatcherAutoRegistrationFactory")»> «className.shortName»::CreateDispatcherAutoRegistrationFactory
            (
               «resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
               , «resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")» &serverEndpoint
               , «resolveSymbol("BTC::Commons::CoreExtras::UUID")» const &instanceGuid /*= Commons::CoreExtras::UUID()*/
               , «resolveSymbol("BTC::Commons::Core::String")» const &instanceName /*= BTC::Commons::Core::String ()*/
            )
            {
               using «resolveSymbol("BTC::ServiceComm::Util::CDispatcherAutoRegistrationFactory")»;
               using «resolveSymbol("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContext")»;
            
               return «resolveSymbol("BTC::Commons::Core::CreateUnique")»<CDispatcherAutoRegistrationFactory<«apiClassName», «className.shortName»>>
               (
               loggerFactory
               «IF targetVersion == ServiceCommVersion.V0_10»
                   , serverEndpoint
               «ENDIF»
               , instanceGuid
               , «resolveSymbol("CABTYPENAME")»(«apiClassName»)
               , instanceName.IsNotEmpty() ? instanceName : («resolveSymbol("CABTYPENAME")»(«apiClassName») + " default instance")
               );
            }
        '''
    }
    
    def generateFunctionHandler(FunctionDeclaration function, InterfaceDeclaration interfaceDeclaration)
    {
        val protobufRequestMethod = function.name.asRequest.asCppProtobufName
        val isSync = function.isSync
        val isVoid = function.returnedType instanceof VoidType
        val protobufResponseMethod = function.name.asResponse.asCppProtobufName
        val outputParameters = function.parameters.filter[direction == ParameterDirection.PARAM_OUT]
        val protobufResponseMessage = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.RESPONSE)
        '''
            if ( protoBufRequest->has_«protobufRequestMethod»() )
            {
           // decode request -->
           auto const& concreteRequest( protoBufRequest->«protobufRequestMethod»() );
           «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF GeneratorUtil.useCodec(param.paramType.actualType, ArtifactNature.CPP)»
                   «IF param.paramType.isSequenceType»
                       «val ulimateType = param.paramType.ultimateType»
                       «val isUuid = ulimateType.isUUIDType»
                       «val isFailable = param.paramType.isFailable»
                       auto «param.paramName»( «typeResolver.resolveCodecNS(paramBundle, ulimateType, isFailable, Optional.of(interfaceDeclaration))»::Decode«IF isFailable»Failable«ELSEIF isUuid»UUID«ENDIF»
                          «IF !isUuid || isFailable»
                              «val protobufType = typeResolver.resolveProtobuf(ulimateType, ProtobufType.REQUEST).fullyQualifiedName»
                              < «IF isFailable»«typeResolver.resolveFailableProtobufType(param.paramType.actualType, interfaceDeclaration)»«ELSE»«protobufType»«ENDIF», «resolve(ulimateType)» >
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
           
           «IF !outputParameters.empty»
               // prepare [out] parameters
               «FOR param : outputParameters»
                   «IF param.paramType.isSequenceType»
                       «val typeName = resolve(param.paramType.ultimateType)»
                       «val isFailable = param.paramType.isFailable»
                       «if (isFailable) addCabInclude(new Path("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h")).alias("") /* necessary to use InsertableTraits with FailableHandle */»
                       «val effectiveTypename = if (isFailable) '''«resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")»< «typeName» >''' else typeName»
                       «resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «effectiveTypename» >::AutoPtrType «param.paramName»(
                          «resolveSymbol("BTC::Commons::FutureUtil::GetOrCreateDefaultInsertable")»(«resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «effectiveTypename» >::MakeEmptyInsertablePtr()) );
                       auto «param.paramName»Future = «param.paramName»->GetFuture();
                   «ELSE»
                       «toText(param.paramType, param)» «param.paramName»;
                   «ENDIF»
               «ENDFOR»
           «ENDIF»
           
           // call actual method
        «IF !isVoid»auto result( «ENDIF»GetDispatchee().«function.name»(
                 «FOR p : function.parameters SEPARATOR ", "»
                     «val isSequenceType = p.paramType.isSequenceType»
                     «IF p.direction == ParameterDirection.PARAM_OUT && isSequenceType»*«ENDIF»
                     «IF p.direction == ParameterDirection.PARAM_IN && isSequenceType»«resolveSymbol("std::move")»(«ENDIF»
                     «p.paramName»
                     «IF p.direction == ParameterDirection.PARAM_IN && isSequenceType»)«ENDIF»
                 «ENDFOR»)«IF !isSync».Get()«ENDIF»«IF !isVoid» )«ENDIF»;
        
        // prepare response
        «resolveSymbol("BTC::Commons::Core::AutoPtr")»< «protobufResponseMessage» > response( BorrowReplyMessage() );
        
        «IF !isVoid || !outputParameters.empty»
            // encode response -->
            auto * const concreteResponse( response->mutable_«protobufResponseMethod»() );
            «IF !isVoid»«makeEncodeResponse(function.returnedType.actualType, interfaceDeclaration, function.name.asCppProtobufName, Optional.empty)»«ENDIF»
            «IF !outputParameters.empty»
                // handle [out] parameters
                «FOR param : outputParameters»
                    «makeEncodeResponse(param.paramType.actualType, interfaceDeclaration, param.paramName.asCppProtobufName, Optional.of(param.paramName))»
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

    private def String makeEncodeResponse(AbstractTypeReference type, AbstractContainerDeclaration container, String protobufName,
        Optional<String> outputParam)
    {
        val apiInput = if (outputParam.present) outputParam.get else "result"
        '''
            «IF GeneratorUtil.useCodec(type, ArtifactNature.CPP) && !(type.isByte || type.isInt16 || type.isChar)»
                «IF type.isSequenceType»
                    «val ulimateType = type.ultimateType»
                    «val isFailable = type.isFailable»
                    «val protobufType = typeResolver.resolveProtobuf(ulimateType, ProtobufType.RESPONSE).fullyQualifiedName»
                    «typeResolver.resolveCodecNS(paramBundle, ulimateType, isFailable, Optional.of(container))»::Encode«IF isFailable»Failable«ENDIF»< «resolve(ulimateType)», «IF isFailable»«typeResolver.resolveFailableProtobufType(type, container)»«ELSE»«protobufType»«ENDIF» >
                       ( «resolveSymbol("std::move")»(«apiInput»«IF outputParam.present»Future.Get()«ENDIF»), concreteResponse->mutable_«protobufName»() );
                «ELSEIF type.isEnumType»
                    concreteResponse->set_«protobufName»( «typeResolver.resolveCodecNS(paramBundle, type)»::Encode(«apiInput») );
                «ELSE»
                    «typeResolver.resolveCodecNS(paramBundle, type)»::Encode( «apiInput», concreteResponse->mutable_«protobufName»() );
                «ENDIF»
            «ELSE»
                concreteResponse->set_«protobufName»(«apiInput»);
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

    def generateHeaderFileBody(InterfaceDeclaration interfaceDeclaration)
    {
        val className = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType,
            interfaceDeclaration.name)

        '''
            «makeDispatcherBaseTemplate(interfaceDeclaration)»
            
            class «makeExportMacro()» «className» :
            virtual private «resolveSymbol("BTC::Logging::API::LoggerAware")»
            , public «interfaceDeclaration.asBaseName»
            {
            public:
               «generateHConstructor(interfaceDeclaration)»
               
               «className»
               (
                  «resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
                  ,«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManagerFactory")» &serviceFaultHandlerManagerFactory
                  ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «resolve(interfaceDeclaration)» > dispatchee
               );
               
               «generateHDestructor(interfaceDeclaration)»
               
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
                  ,«resolveSymbol("BTC::Commons::CoreExtras::UUID")» const &instanceGuid = BTC::Commons::CoreExtras::UUID::Null()
                  ,«resolveSymbol("BTC::Commons::Core::String")» const &instanceName = BTC::Commons::Core::String()
               );
            };
        '''
    }

    private def String makeDispatcherBaseTemplate(InterfaceDeclaration interfaceDeclaration)
    {
        val apiClassName = resolve(interfaceDeclaration, ProjectType.SERVICE_API)
        val protobufRequest = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.REQUEST)
        val protobuf_response = typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.RESPONSE)

        '''
            typedef «resolveSymbol("BTC::ServiceComm::ProtobufBase::AProtobufServiceDispatcherBaseTemplate")»<
               «apiClassName»
               , «protobufRequest»
               , «protobuf_response» > «interfaceDeclaration.asBaseName»;
        '''
    }

}
