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
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class TestGenerator extends BasicCppGenerator
{

    def generateCppTest(InterfaceDeclaration interface_declaration)
    {
        val api_type = resolve(interface_declaration, ProjectType.SERVICE_API)
        val subject_name = interface_declaration.name.toFirstLower
        val logger_factory = resolveCAB("BTC::Performance::CommonsTestSupport::GetTestLoggerFactory")
        val container_name = interface_declaration.name + "TestContainer"

        // explicitly resolve some necessary includes, because they are needed
        // for the linker due to some classes we use, but not directly referenced
        resolveCABImpl("BTC::Commons::CoreExtras::Optional")

        '''
            typedef «resolveCAB("BTC::ServiceComm::Util::DefaultCreateDispatcherWithContextAndEndpoint")»<
                «api_type»
               ,«resolve(interface_declaration, ProjectType.DISPATCHER)» > CreateDispatcherFunctorBaseType;
            
            struct CreateDispatcherFunctor : public CreateDispatcherFunctorBaseType
            {  CreateDispatcherFunctor( «resolveCAB("BTC::Commons::Core::Context")»& context ) : CreateDispatcherFunctorBaseType( context ) {} };
            
            typedef «resolveCAB("BTC::ServiceComm::Util::DispatcherAutoRegistration")»<
                «api_type»
               ,«resolve(interface_declaration, ProjectType.DISPATCHER)»
               ,CreateDispatcherFunctor > DispatcherAutoRegistrationType;
            
            // enable commented lines for ZeroMQ encryption!
            const auto serverConnectionOptionsBuilder =
               «resolveCAB("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
               //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
               //.WithServerAcceptAnyClientKey(true)
               //.WithServerSecretKey("d{pnP/0xVmQY}DCV2BS)8Y9fw9kB/jq^id4Qp}la")
               //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
               ;
            
            // enable commented lines for ZeroMQ encryption!
            const auto clientConnectionOptionsBuilder =
               «resolveCAB("BTC::ServiceComm::SQ::ZeroMQ::ConnectionOptionsBuilder")»()
               //.WithAuthenticationMode(BTC::ServiceComm::SQ::ZeroMQ::AuthenticationMode::Curve)
               //.WithServerPublicKey("Qr5^/{Rc{V%ji//usp(^m^{(qxC3*j.vsF+Q{XJt")
               //.WithClientSecretKey("9L9K[bCFp7a]/:gJL2x{PoV}wnaAb.Zt}[qj)z/!")
               //.WithClientPublicKey("=ayKwMDx1YB]TK9hj4:II%8W2p4:Ue((iEkh30:@")
               ;
            
            struct «container_name»
            {
               «container_name»( «resolveCAB("BTC::Commons::Core::Context")»& context ) :
               m_connection( new «resolveCAB("BTC::ServiceComm::SQ::ZeroMQTestSupport::ZeroMQTestConnection")»(
                   context
                  ,«logger_factory»(), 1, true
                  ,«resolveCAB("BTC::ServiceComm::SQ::ZeroMQTestSupport::ConnectionDirection")»::Regular
                  ,clientConnectionOptionsBuilder
                  ,serverConnectionOptionsBuilder
               ) )
               ,m_dispatcher( new DispatcherAutoRegistrationType(
                   «api_type»::TYPE_GUID()
                  ,"«api_type.shortName»"
                  ,"«api_type.shortName»"
                  ,«logger_factory»()
                  ,m_connection->GetServerEndpoint()
                  ,«resolveCAB("BTC::Commons::Core::MakeAuto")»( new «resolve(interface_declaration, ProjectType.IMPL)»(
                      context
                     ,«logger_factory»()
                     ) )
                  ,CreateDispatcherFunctor( context ) ) )
               ,m_proxy( new «resolve(interface_declaration, ProjectType.PROXY)»(
                   context
                  ,«logger_factory»()
                  ,m_connection->GetClientEndpoint() ) )
               {}
            
               ~«container_name»()
               {
               m_connection->GetClientEndpoint().InitiateShutdown();
               m_connection->GetClientEndpoint().Wait();
               }
            
               «api_type»& GetSubject()
               {  return *m_proxy; }
            
            private:
               «resolveSTL("std::unique_ptr")»< «resolveCAB("BTC::ServiceComm::TestBase::ITestConnection")» > m_connection;
               «resolveSTL("std::unique_ptr")»< DispatcherAutoRegistrationType > m_dispatcher;
               «resolveSTL("std::unique_ptr")»< «api_type» > m_proxy;
            };
            
            «FOR func : interface_declaration.functions»
                «resolveCAB("TEST")»( «interface_declaration.name»_«func.name» )
                {
                   «container_name» container( *GetContext() );
                   «api_type»& «subject_name»( container.GetSubject() );
                   
                   «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_IN]»
                       «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                           «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                           «resolveCAB("BTC::Commons::Core::Vector")»< «IF is_failable»«resolveCAB("BTC::Commons::CoreExtras::FailableHandle")»<«ENDIF»«toText(com.btc.serviceidl.util.Util.getUltimateType(param.paramType), param)»«IF is_failable»>«ENDIF» > «param.paramName.asParameter»;
                       «ELSE»
                           «val type_name = toText(param.paramType, param)»
                           «type_name» «param.paramName.asParameter»«IF com.btc.serviceidl.util.Util.isEnumType(param.paramType)» = «type_name»::«(com.btc.serviceidl.util.Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ELSEIF com.btc.serviceidl.util.Util.isStruct(param.paramType)» = {}«ENDIF»;
                       «ENDIF»
                   «ENDFOR»
                   «FOR param : func.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
                       «IF com.btc.serviceidl.util.Util.isSequenceType(param.paramType)»
                           «val ulimate_type = toText(com.btc.serviceidl.util.Util.getUltimateType(param.paramType), param)»
                           «val is_failable = com.btc.serviceidl.util.Util.isFailable(param.paramType)»
                           «val inner_type = if (is_failable) '''«addCabInclude("Commons/FutureUtil/include/FailableHandleAsyncInsertable.h").alias(resolveCAB("BTC::Commons::CoreExtras::FailableHandle"))»< «ulimate_type» >''' else ulimate_type»
                           «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «inner_type» >::AutoPtrType «param.paramName.asParameter»( «resolveCAB("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")»< «inner_type» >() );
                       «ELSE»
                           «val type_name = toText(param.paramType, param)»
                           «type_name» «param.paramName.asParameter»«IF com.btc.serviceidl.util.Util.isEnumType(param.paramType)» = «type_name»::«(com.btc.serviceidl.util.Util.getUltimateType(param.paramType) as EnumDeclaration).containedIdentifiers.head»«ENDIF»;
                       «ENDIF»
                   «ENDFOR»
                   «FOR param : func.parameters»
                       «val param_type = com.btc.serviceidl.util.Util.getUltimateType(param.paramType)»
                       «IF param_type instanceof StructDeclaration»
                           «FOR member : param_type.allMembers.filter[!optional].filter[com.btc.serviceidl.util.Util.isEnumType(it.type)]»
                               «val enum_type = com.btc.serviceidl.util.Util.getUltimateType(member.type)»
                               «param.paramName.asParameter».«member.name.asMember» = «toText(enum_type, enum_type)»::«(enum_type as EnumDeclaration).containedIdentifiers.head»;
                           «ENDFOR»
                       «ENDIF»
                   «ENDFOR»
                   «resolveCAB("UTTHROWS")»( «resolveCAB("BTC::Commons::Core::UnsupportedOperationException")», «subject_name».«func.name»(«func.parameters.map[ (if (direction == ParameterDirection.PARAM_OUT && com.btc.serviceidl.util.Util.isSequenceType(paramType)) "*" else "") + paramName.asParameter + if (direction == ParameterDirection.PARAM_IN && com.btc.serviceidl.util.Util.isSequenceType(paramType)) ".GetBeginForward()" else ""].join(", ")»)«IF !func.isSync».Get()«ENDIF» );
                }
            «ENDFOR»
            
        '''
    }

}
