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

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.StructDeclaration
import org.eclipse.core.runtime.Path
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class TestGenerator extends BasicCppGenerator
{

    def generateCppTest(InterfaceDeclaration interfaceDeclaration)
    {
        val apiType = resolve(interfaceDeclaration, ProjectType.SERVICE_API)
        val subjectName = interfaceDeclaration.name.toFirstLower
        val loggerFactory = resolveSymbol("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")
        val containerName = interfaceDeclaration.name + "TestContainer"

        // explicitly resolve some necessary includes, because they are needed
        // for the linker due to some classes we use, but not directly referenced
        resolveSymbolWithImplementation("BTC::Commons::CoreExtras::Optional")

        '''
            typedef «resolveSymbol("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContextAndEndpoint")»<
                «apiType»
               ,«resolve(interfaceDeclaration, ProjectType.DISPATCHER)» > CreateDispatcherFunctorBaseType;
            
            struct CreateDispatcherFunctor : public CreateDispatcherFunctorBaseType
            {  CreateDispatcherFunctor( «resolveSymbol("BTC::Commons::Core::Context")»& context ) : CreateDispatcherFunctorBaseType( context ) {} };
            
            typedef «resolveSymbol("BTC::ServiceComm::Util::DispatcherAutoRegistration")»<
                «apiType»
               ,«resolve(interfaceDeclaration, ProjectType.DISPATCHER)»
               ,CreateDispatcherFunctor> DispatcherAutoRegistrationType;
            
            // enable commented lines for ZeroMQ encryption!
            const auto serverConnectionOptionsBuilder =
               «resolveSymbol("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
               //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
               //.WithServerAcceptAnyClientKey(true)
               //.WithServerSecretKey("d{pnP/0xVmQY}DCV2BS)8Y9fw9kB/jq^id4Qp}la")
               //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
               ;
            
            // enable commented lines for ZeroMQ encryption!
            const auto clientConnectionOptionsBuilder =
               «resolveSymbol("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
               //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
               //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
               //.WithClientSecretKey("9L9K[bCFp7a]/:gJL2x{PoV}wnaAb.Zt}[qj)z/!")
               //.WithClientPublicKey("=ayKwMDx1YB]TK9hj4:II%8W2p4:Ue((iEkh30:@")
               ;
            
            struct «containerName»
            {
               «containerName»( «resolveSymbol("BTC::Commons::Core::Context")»& context ) :
               m_connection(
               «IF targetVersion == ServiceCommVersion.V0_12»
                  «resolveSymbol("BTC::ServiceComm::SQ::ZeroMQTestSupport::ZeroMQTestConnectionBuilder")»{context, «loggerFactory»()}
                   .WithClientServerConnectionOptionsBuilders(clientConnectionOptionsBuilder, serverConnectionOptionsBuilder)
                   .Create()
                «ELSE»
                  «resolveSymbol("BTC::Commons::Core::CreateUnique")»<«resolveSymbol("BTC::ServiceComm::SQ::ZeroMQTestSupport::ZeroMQTestConnection")»>(
                   context
                  ,«loggerFactory»(), 1, true
                  ,«resolveSymbol("BTC::ServiceComm::SQ::ZeroMQTestSupport::ConnectionDirection")»::Regular
                  ,clientConnectionOptionsBuilder
                  ,serverConnectionOptionsBuilder
               )
               «ENDIF»
               )
               ,m_dispatcher( new DispatcherAutoRegistrationType(
                   «apiType»::TYPE_GUID()
                  ,"«apiType.shortName»"
                  ,"«apiType.shortName»"
                  ,«loggerFactory»()
                  ,m_connection->GetServerEndpoint()
                  ,«resolveSymbol("BTC::Commons::Core::CreateAuto")»<«resolve(interfaceDeclaration, ProjectType.IMPL)»>(
                      context
                     ,«loggerFactory»()
                     )
                  ,CreateDispatcherFunctor( context ) ) )
               ,m_proxy(«resolveSymbol("BTC::Commons::Core::CreateUnique")»<«resolve(interfaceDeclaration, ProjectType.PROXY)»>(
                   context
                  ,«loggerFactory»()
                  ,m_connection->GetClientEndpoint()
                  ))
               {}
            
               ~«containerName»()
               {
               m_connection->GetClientEndpoint().InitiateShutdown();
               m_connection->GetClientEndpoint().Wait();
               }
            
               «apiType»& GetSubject()
               {  return *m_proxy; }
            
            private:
               «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «resolveSymbol("BTC::ServiceComm::TestBase::ITestConnection")» > m_connection;
               «resolveSymbol("BTC::Commons::Core::UniquePtr")»< DispatcherAutoRegistrationType > m_dispatcher;
               «resolveSymbol("BTC::Commons::Core::UniquePtr")»< «apiType» > m_proxy;
            };
            
            «FOR func : interfaceDeclaration.functions»
                «resolveSymbol("TEST")»( «interfaceDeclaration.name»_«func.name» )
                {
                   «containerName» container( *GetContext() );
                   «apiType»& «subjectName»( container.GetSubject() );
                   
                   «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                       «IF param.paramType.isSequenceType»
                           «val isFailable = param.paramType.isFailable»
                           «resolveSymbol("BTC::Commons::CoreStd::Collection")»< «IF isFailable»«resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")»<«ENDIF»«toText(param.paramType.ultimateType, param)»«IF isFailable»>«ENDIF» > «param.paramName.asParameter»;
                       «ELSE»
                           «val typeName = toText(param.paramType, param)»
                           «typeName» «param.paramName.asParameter»«IF param.paramType.isEnumType» = «typeName»::«(param.paramType.ultimateType as EnumDeclaration).containedIdentifiers.head»«ELSEIF param.paramType.isStruct» = {}«ENDIF»;
                       «ENDIF»
                   «ENDFOR»
                   «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                       «IF param.paramType.isSequenceType»
                           «val ulimateType = toText(param.paramType.ultimateType, param)»
                           «val isFailable = param.paramType.isFailable»
                           «val innerType = if (isFailable) '''«addCabInclude(new Path("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h")).alias(resolveSymbol("BTC::Commons::CoreExtras::FailableHandle"))»< «ulimateType» >''' else ulimateType»
                           «resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «innerType» >::AutoPtrType «param.paramName.asParameter»( «resolveSymbol("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")»< «innerType» >() );
                       «ELSE»
                           «val typeName = toText(param.paramType, param)»
                           «typeName» «param.paramName.asParameter»«IF param.paramType.isEnumType» = «typeName»::«(param.paramType.ultimateType as EnumDeclaration).containedIdentifiers.head»«ENDIF»;
                       «ENDIF»
                   «ENDFOR»
                   «FOR param : func.parameters»
                       «val paramType = param.paramType.ultimateType»
                       «IF paramType instanceof StructDeclaration»
                           «FOR member : paramType.allMembers.filter[!optional].filter[type.isEnumType]»
                               «val enumType = member.type.ultimateType»
                               «param.paramName.asParameter».«member.name.asMember» = «toText(enumType, enumType)»::«(enumType as EnumDeclaration).containedIdentifiers.head»;
                           «ENDFOR»
                       «ENDIF»
                   «ENDFOR»
                   «resolveSymbol("UTTHROWS")»( «resolveSymbol("BTC::Commons::Core::UnsupportedOperationException")», «subjectName».«func.name»(«func.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT && paramType.isSequenceType) "*" else "") + paramName.asParameter + if (direction == ParameterDirection.PARAM_IN && paramType.isSequenceType) ".GetBeginForward()" else ""].join(", ")»)«IF !func.isSync».Get()«ENDIF» );
                }
            «ENDFOR»
            
        '''
    }

}
