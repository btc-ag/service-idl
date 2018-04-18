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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ReturnTypeElement
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class InterfaceGenerator extends BasicCppGenerator {
   def String generateInterface(InterfaceDeclaration interface_declaration)
   {
      // API requires some specific conditions (GUID, pure virtual functions, etc.)
      // non-API also (e.g. override keyword etc.)
      val is_api = param_bundle.projectType == ProjectType.SERVICE_API
      val is_proxy = param_bundle.projectType == ProjectType.PROXY
      val is_impl = param_bundle.projectType == ProjectType.IMPL
      val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)
      val export_macro = makeExportMacro
      
      val sorted_types = interface_declaration.topologicallySortedTypes
      val forward_declarations = resolveForwardDeclarations(sorted_types)
      
      '''
      «IF is_api»
         «FOR type : forward_declarations»
            struct «Names.plain(type)»;
         «ENDFOR»

         «FOR wrapper : sorted_types»
            «toText(wrapper.type, interface_declaration)»
            
         «ENDFOR»
      «ENDIF»
      «IF is_proxy»
         // anonymous namespace for internally used typedef
         namespace
         {
            typedef «resolveCAB("BTC::ServiceComm::ProtobufBase::AProtobufServiceProxyBaseTemplate")»<
               «typeResolver.resolveProtobuf(interface_declaration, ProtobufType.REQUEST)»
               ,«typeResolver.resolveProtobuf(interface_declaration, ProtobufType.RESPONSE)» > «interface_declaration.asBaseName»;
         }
      «ENDIF»
      «IF !interface_declaration.docComments.empty»
      /**
         «FOR comment : interface_declaration.docComments»«toText(comment, interface_declaration)»«ENDFOR»
      */
      «ENDIF»
      class «export_macro»
      «generateHClassSignature(interface_declaration)»
      {
      public:
         «IF is_api»
            /** \return {«GuidMapper.get(interface_declaration)»} */
            static «resolveCAB("BTC::Commons::CoreExtras::UUID")» TYPE_GUID();
         «ELSE»
            «generateHConstructor(interface_declaration)»
            
            «generateHDestructor(interface_declaration)»
         «ENDIF»
         «FOR function : interface_declaration.functions»
         
         /**
            «IF is_api»
               «FOR comment : function.docComments»«toText(comment, interface_declaration)»«ENDFOR»
               «com.btc.serviceidl.util.Util.addNewLine(!function.docComments.empty)»
               «FOR parameter : function.parameters»
               \param[«parameter.direction»] «parameter.paramName» 
               «ENDFOR»
               «com.btc.serviceidl.util.Util.addNewLine(!function.parameters.empty)»
               «FOR exception : function.raisedExceptions»
               \throw «toText(exception, function)»
               «ENDFOR»
               «com.btc.serviceidl.util.Util.addNewLine(!function.raisedExceptions.empty)»
               «IF !(function.returnedType as ReturnTypeElement).isVoid»\return «ENDIF»
            «ELSE»
               \see «resolve(interface_declaration, ProjectType.SERVICE_API)»::«function.name»
            «ENDIF»
         */
         virtual «IF !function.isSync»«resolveCAB("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interface_declaration)»«IF !function.isSync»>«ENDIF» «function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»«IF is_api» = 0«ELSE» override«ENDIF»;
         «ENDFOR»
         «IF is_proxy»
            
            using «interface_declaration.asBaseName»::InitiateShutdown;
            
            using «interface_declaration.asBaseName»::Wait;
            
         «ENDIF»
         «FOR event : interface_declaration.events.filter[name !== null]»
            «val event_type = toText(event.data, event)»
            /**
               \brief Subscribe for event of type «event_type»
            */
            virtual «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«event_type»> &observer )«IF is_api» = 0«ENDIF»;
         «ENDFOR»
         
         «IF !is_api»
            «IF anonymous_event !== null»
               /**
                  \see BTC::Commons::CoreExtras::IObservableRegistration::Subscribe
               */
               virtual «resolveCAB("BTC::Commons::Core::UniquePtr")»<«resolveCAB("BTC::Commons::Core::Disposable")»> Subscribe( «resolveCAB("BTC::Commons::CoreExtras::IObserver")»<«toText(anonymous_event.data, anonymous_event)»> &observer ) override;
            «ENDIF»
            private:
               «resolveCAB("BTC::Commons::Core::Context")» &m_context;
            «IF is_proxy»
               «FOR event : interface_declaration.events»
                  «var event_params_name = event.eventParamsName»
                  struct «event_params_name»
                  {
                     typedef «resolve(event.data)» EventDataType;
                     
                     static «resolveCAB("BTC::Commons::CoreExtras::UUID")» GetEventTypeGuid();
                     static «resolveCAB("BTC::ServiceComm::API::EventKind")» GetEventKind();
                     static «resolveCAB("BTC::Commons::Core::String")» GetEventTypeDescription();
                     static «resolveSTL("std::function")»<EventDataType const ( «resolveCAB("BTC::ServiceComm::Commons::ConstSharedMessageSharedPtr")» const & )> GetUnmarshalFunction();
                  };
                  «resolveCAB("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")»<«event_params_name»> «event.observableRegistrationName»;
               «ENDFOR»
            «ENDIF»
            «IF is_impl»
               «FOR event : interface_declaration.events»
                  «resolveCAB("BTC::Commons::CoreExtras::CDefaultObservable")»<«resolve(event.data)»> «event.observableName»;
               «ENDFOR»
            «ENDIF»
         «ENDIF»
      };
      «IF is_api»
         void «export_macro»
         «getRegisterServerFaults(interface_declaration, Optional.empty)»(«resolveCAB("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager);
      «ENDIF»
      '''
   }
   
   def private String generateHClassSignature(InterfaceDeclaration interface_declaration)
   {
      val is_api = param_bundle.projectType == ProjectType.SERVICE_API
      val is_proxy = param_bundle.projectType == ProjectType.PROXY
      val anonymous_event = com.btc.serviceidl.util.Util.getAnonymousEvent(interface_declaration)
      
      '''«GeneratorUtil.getClassName(param_bundle.build, interface_declaration.name)» : 
      «IF is_api»
         virtual public «resolveCAB("BTC::Commons::Core::Object")»
         «IF anonymous_event !== null», public «resolveCAB("BTC::Commons::CoreExtras::IObservableRegistration")»<«resolve(anonymous_event.data)»>«ENDIF»
      «ELSE»
         virtual public «resolve(interface_declaration, ProjectType.SERVICE_API)»
         , private «resolveCAB("BTC::Logging::API::LoggerAware")»
      «ENDIF»
      «IF is_proxy»
         , private «interface_declaration.asBaseName»
      «ENDIF»
      '''
   }
               
}
