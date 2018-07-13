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
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.VoidType
import java.util.HashSet
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.TypeResolverExtensions.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class ServiceAPIGenerator extends BasicCppGenerator {
   def String generateHeaderFileBody(InterfaceDeclaration interface_declaration)
   {
      // TODO this file should only contain the service API functionality, generic functionality should be extracted, 
      // and functionality specific to other project types should be moved elsewhere
      
      // API requires some specific conditions (GUID, pure virtual functions, etc.)
      // non-API also (e.g. override keyword etc.)
      val is_api = paramBundle.projectType == ProjectType.SERVICE_API
      val is_proxy = paramBundle.projectType == ProjectType.PROXY
      val is_impl = paramBundle.projectType == ProjectType.IMPL
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
            typedef «resolveSymbol("BTC::ServiceComm::ProtobufBase::AProtobufServiceProxyBaseTemplate")»<
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
            static «resolveSymbol("BTC::Commons::CoreExtras::UUID")» TYPE_GUID();
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
               «IF !(function.returnedType instanceof VoidType)»\return «ENDIF»
            «ELSE»
               \see «resolve(interface_declaration, ProjectType.SERVICE_API)»::«function.name»
            «ENDIF»
         */
         virtual «IF !function.isSync»«resolveSymbol("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interface_declaration)»«IF !function.isSync»>«ENDIF» «function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»«IF is_api» = 0«ELSE» override«ENDIF»;
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
            virtual «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«event_type»> &observer )«IF is_api» = 0«ENDIF»;
         «ENDFOR»
         
         «IF !is_api»
            «IF anonymous_event !== null»
               /**
                  \see BTC::Commons::CoreExtras::IObservableRegistration::Subscribe
               */
               virtual «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«toText(anonymous_event.data, anonymous_event)»> &observer ) override;
            «ENDIF»
            private:
               «resolveSymbol("BTC::Commons::Core::Context")» &m_context;
            «IF is_proxy»
               «FOR event : interface_declaration.events»
                  «val event_params_name = event.eventParamsName»
                  struct «event_params_name»
                  {
                     typedef «resolve(event.data)» EventDataType;
                     
                     static «resolveSymbol("BTC::Commons::CoreExtras::UUID")» GetEventTypeGuid();
                     static «resolveSymbol("BTC::ServiceComm::API::EventKind")» GetEventKind();
                     static «resolveSymbol("BTC::Commons::Core::String")» GetEventTypeDescription();
                     static «resolveSymbol("std::function")»<EventDataType const ( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager::ObserverType::OnNextParamType")» )> GetUnmarshalFunction();
                  };
                  «resolveSymbol("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")»<«event_params_name»> «event.observableRegistrationName»;
               «ENDFOR»
            «ENDIF»
            «IF is_impl»
               «FOR event : interface_declaration.events»
                  «resolveSymbol("BTC::Commons::CoreExtras::CDefaultObservable")»<«resolve(event.data)»> «event.observableName»;
               «ENDFOR»
            «ENDIF»
         «ENDIF»
      };
      «IF is_api»
         void «export_macro»
         «getRegisterServerFaults(interface_declaration, Optional.empty)»(«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager);
      «ENDIF»
      '''
   }
   
   private def String generateHClassSignature(InterfaceDeclaration interface_declaration)
   {
      val anonymous_event = interface_declaration.anonymousEvent
      
      '''«GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType, interface_declaration.name)» : 
      «IF paramBundle.projectType == ProjectType.SERVICE_API»
         virtual public «resolveSymbol("BTC::Commons::Core::Object")»
         «IF anonymous_event !== null», public «resolveSymbol("BTC::Commons::CoreExtras::IObservableRegistration")»<«resolve(anonymous_event.data)»>«ENDIF»
      «ELSE»
         virtual public «resolve(interface_declaration, ProjectType.SERVICE_API)»
         , private «resolveSymbol("BTC::Logging::API::LoggerAware")»
      «ENDIF»
      «IF paramBundle.projectType == ProjectType.PROXY»
         , private «interface_declaration.asBaseName»
      «ENDIF»
      '''
   }
    
    def generateImplFileBody(InterfaceDeclaration interface_declaration) {
      val class_name = resolve(interface_declaration, paramBundle.projectType)
      
      // prepare for re-use
      val register_service_fault = resolveSymbol("BTC::ServiceComm::Base::RegisterServiceFault")
      val cab_string = resolveSymbol("BTC::Commons::Core::String")
      
      // collect exceptions thrown by interface methods
      val thrown_exceptions = new HashSet<AbstractException>
      interface_declaration
         .functions
         .filter[!raisedExceptions.empty]
         .map[raisedExceptions]
         .flatten
         .forEach[ thrown_exceptions.add(it) ]
      
      // for optional element, include the impl file!
      if
      (
         !interface_declaration.eAllContents.filter(MemberElement).filter[optional].empty
         || !interface_declaration.eAllContents.filter(SequenceDeclaration).filter[failable].empty
      )
      {
         resolveSymbolWithImplementation("BTC::Commons::CoreExtras::Optional")
      }
      
      '''
      «FOR exception : interface_declaration.contains.filter(ExceptionDeclaration).sortBy[name]»
         «makeExceptionImplementation(exception)»
      «ENDFOR»
      
      // {«GuidMapper.get(interface_declaration)»}
      static const «resolveSymbol("BTC::Commons::CoreExtras::UUID")» s«interface_declaration.name»TypeGuid = 
         «resolveSymbol("BTC::Commons::CoreExtras::UUID")»::ParseString("«GuidMapper.get(interface_declaration)»");

      «resolveSymbol("BTC::Commons::CoreExtras::UUID")» «class_name.shortName»::TYPE_GUID()
      {
         return s«interface_declaration.name»TypeGuid;
      }

      «makeEventGUIDImplementations(typeResolver, interface_declaration.contains.filter(StructDeclaration))»
      
      void «getRegisterServerFaults(interface_declaration, Optional.empty)»(«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager)
      {
         «IF !thrown_exceptions.empty»// register exceptions thrown by service methods«ENDIF»
         «FOR exception : thrown_exceptions.sortBy[name]»
            «val resolve_exc_name = resolve(exception)»
            «register_service_fault»<«resolve_exc_name»>(
               serviceFaultHandlerManager, «cab_string»("«exception.getCommonExceptionName(qualified_name_provider)»"));
         «ENDFOR»
         
         // most commonly used exception types
         «val default_exceptions = typeResolver.defaultExceptionRegistration»
         «FOR exception : default_exceptions.keySet.sort»
            «register_service_fault»<«default_exceptions.get(exception)»>(
               serviceFaultHandlerManager, «cab_string»("«exception»"));
         «ENDFOR»
      }
      '''
    }
               
}
