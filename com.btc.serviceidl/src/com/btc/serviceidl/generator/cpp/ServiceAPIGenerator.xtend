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
   def String generateHeaderFileBody(InterfaceDeclaration interfaceDeclaration)
   {
      // TODO this file should only contain the service API functionality, generic functionality should be extracted, 
      // and functionality specific to other project types should be moved elsewhere
      
      // API requires some specific conditions (GUID, pure virtual functions, etc.)
      // non-API also (e.g. override keyword etc.)
      val isApi = paramBundle.projectType == ProjectType.SERVICE_API
      val isProxy = paramBundle.projectType == ProjectType.PROXY
      val isImpl = paramBundle.projectType == ProjectType.IMPL
      val anonymousEvent = interfaceDeclaration.anonymousEvent
      val exportMacro = makeExportMacro
      
      val sortedTypes = interfaceDeclaration.topologicallySortedTypes
      val forwardDeclarations = resolveForwardDeclarations(sortedTypes)
            
      '''
      «IF isApi»
         «FOR type : forwardDeclarations»
            struct «Names.plain(type)»;
         «ENDFOR»

         «FOR wrapper : sortedTypes»
            «toText(wrapper.type, interfaceDeclaration)»
            
         «ENDFOR»
      «ENDIF»
      «IF isProxy»
         // anonymous namespace for internally used typedef
         namespace
         {
            typedef «resolveSymbol("BTC::ServiceComm::ProtobufBase::AProtobufServiceProxyBaseTemplate")»<
               «typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.REQUEST)»
               ,«typeResolver.resolveProtobuf(interfaceDeclaration, ProtobufType.RESPONSE)» > «interfaceDeclaration.asBaseName»;
         }
      «ENDIF»
      «IF !interfaceDeclaration.docComments.empty»
      /**
         «FOR comment : interfaceDeclaration.docComments»«toText(comment, interfaceDeclaration)»«ENDFOR»
      */
      «ENDIF»
      class «exportMacro»
      «generateHClassSignature(interfaceDeclaration)»
      {
      public:
         «IF isApi»
            /** \return {«GuidMapper.get(interfaceDeclaration)»} */
            static «resolveSymbol("BTC::Commons::CoreExtras::UUID")» TYPE_GUID();
         «ELSE»
            «generateHConstructor(interfaceDeclaration)»
            
            «generateHDestructor(interfaceDeclaration)»
         «ENDIF»
         «FOR function : interfaceDeclaration.functions»
         
         /**
            «IF isApi»
               «FOR comment : function.docComments»«toText(comment, interfaceDeclaration)»«ENDFOR»
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
               \see «resolve(interfaceDeclaration, ProjectType.SERVICE_API)»::«function.name»
            «ENDIF»
         */
         virtual «IF !function.isSync»«resolveSymbol("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interfaceDeclaration)»«IF !function.isSync»>«ENDIF» «function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»«IF isApi» = 0«ELSE» override«ENDIF»;
         «ENDFOR»
         «IF isProxy»
            
            using «interfaceDeclaration.asBaseName»::InitiateShutdown;
            
            using «interfaceDeclaration.asBaseName»::Wait;
            
         «ENDIF»
         
         «IF !isApi»
             «FOR event : interfaceDeclaration.events.filter[name !== null]»
                «val eventType = toText(event.data, event)»
                /**
                   \brief Subscribe for event of type «eventType»
                */
                «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«eventType»> &observer) override;
             «ENDFOR»
             «IF anonymousEvent !== null»
               /**
                  \see BTC::Commons::CoreExtras::IObservableRegistration::Subscribe
               */
                «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Disposable")»> Subscribe( «resolveSymbol("BTC::Commons::CoreExtras::IObserver")»<«toText(anonymousEvent.data, anonymousEvent)»> &observer ) override;
             «ENDIF»
            
            private:
               «resolveSymbol("BTC::Commons::Core::Context")» &m_context;
            «IF isProxy»
               «FOR event : interfaceDeclaration.events»
                  «val eventParamsName = event.eventParamsName»
                  struct «eventParamsName»
                  {
                     typedef «resolve(event.data)» EventDataType;
                     
                     static «resolveSymbol("BTC::Commons::CoreExtras::UUID")» GetEventTypeGuid();
                     static «resolveSymbol("BTC::ServiceComm::API::EventKind")» GetEventKind();
                     static «resolveSymbol("BTC::Commons::Core::String")» GetEventTypeDescription();
                     static «resolveSymbol("std::function")»<EventDataType const ( «resolveSymbol("BTC::ServiceComm::API::IEventSubscriberManager::ObserverType::OnNextParamType")» )> GetUnmarshalFunction();
                  };
                  «resolveSymbol("BTC::ServiceComm::Util::CDefaultObservableRegistrationProxy")»<«eventParamsName»> «event.observableRegistrationName»;
               «ENDFOR»
            «ENDIF»
            «IF isImpl»
               «FOR event : interfaceDeclaration.events»
                  «resolveSymbol("BTC::Commons::CoreExtras::CDefaultObservable")»<«resolve(event.data)»> «event.observableName»;
               «ENDFOR»
            «ENDIF»
         «ENDIF»
      };
      «IF isApi»
         void «exportMacro»
         «getRegisterServerFaults(interfaceDeclaration, Optional.empty)»(«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager);
      «ENDIF»
      '''
   }
   
   private def String generateHClassSignature(InterfaceDeclaration interfaceDeclaration)
   {
      val anonymousEvent = interfaceDeclaration.anonymousEvent
      val eventTypes = #[interfaceDeclaration.events.filter[name !== null].map[toText(it.data, it)],
                if (anonymousEvent !== null) #[toText(anonymousEvent.data, anonymousEvent)] else #[]].flatten      
      
      '''«GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType, interfaceDeclaration.name)» : 
      «IF paramBundle.projectType == ProjectType.SERVICE_API»
         virtual public «resolveSymbol("BTC::Commons::Core::Object")»
         «FOR eventType : eventTypes BEFORE "," SEPARATOR ",\n"»
            public virtual «resolveSymbol("BTC::Commons::CoreExtras::IObservableRegistration")»<«eventType»>
         «ENDFOR»
         
         «IF anonymousEvent !== null», public «resolveSymbol("BTC::Commons::CoreExtras::IObservableRegistration")»<«resolve(anonymousEvent.data)»>«ENDIF»
      «ELSE»
         virtual public «resolve(interfaceDeclaration, ProjectType.SERVICE_API)»
         , private «resolveSymbol("BTC::Logging::API::LoggerAware")»
      «ENDIF»
      «IF paramBundle.projectType == ProjectType.PROXY»
         , private «interfaceDeclaration.asBaseName»
      «ENDIF»
      '''
   }
    
    def generateImplFileBody(InterfaceDeclaration interfaceDeclaration) {
      val className = resolve(interfaceDeclaration, paramBundle.projectType)
      
      // prepare for re-use
      val registerServiceFault = resolveSymbol("BTC::ServiceComm::Base::RegisterServiceFault")
      val cabString = resolveSymbol("BTC::Commons::Core::String")
      
      // collect exceptions thrown by interface methods
      val thrownExceptions = new HashSet<AbstractException>
      interfaceDeclaration
         .functions
         .filter[!raisedExceptions.empty]
         .map[raisedExceptions]
         .flatten
         .forEach[ thrownExceptions.add(it) ]
      
      // for optional element, include the impl file!
      if
      (
         !interfaceDeclaration.eAllContents.filter(MemberElement).filter[optional].empty
         || !interfaceDeclaration.eAllContents.filter(SequenceDeclaration).filter[failable].empty
      )
      {
         resolveSymbolWithImplementation("BTC::Commons::CoreExtras::Optional")
      }
      
      '''
      «FOR exception : interfaceDeclaration.contains.filter(ExceptionDeclaration).sortBy[name]»
         «makeExceptionImplementation(exception)»
      «ENDFOR»
      
      // {«GuidMapper.get(interfaceDeclaration)»}
      static const «resolveSymbol("BTC::Commons::CoreExtras::UUID")» s«interfaceDeclaration.name»TypeGuid = 
         «resolveSymbol("BTC::Commons::CoreExtras::UUID")»::ParseString("«GuidMapper.get(interfaceDeclaration)»");

      «resolveSymbol("BTC::Commons::CoreExtras::UUID")» «className.shortName»::TYPE_GUID()
      {
         return s«interfaceDeclaration.name»TypeGuid;
      }

      «makeEventGUIDImplementations(typeResolver, interfaceDeclaration.contains.filter(StructDeclaration))»
      
      void «getRegisterServerFaults(interfaceDeclaration, Optional.empty)»(«resolveSymbol("BTC::ServiceComm::API::IServiceFaultHandlerManager")»& serviceFaultHandlerManager)
      {
         «IF !thrownExceptions.empty»// register exceptions thrown by service methods«ENDIF»
         «FOR exception : thrownExceptions.sortBy[name]»
            «val resolveExcName = resolve(exception)»
            «registerServiceFault»<«resolveExcName»>(
               serviceFaultHandlerManager, «cabString»("«exception.getCommonExceptionName(qualifiedNameProvider)»"));
         «ENDFOR»
         
         // most commonly used exception types
         «val defaultExceptions = typeResolver.defaultExceptionRegistration»
         «FOR exception : defaultExceptions.keySet.sort»
            «registerServiceFault»<«defaultExceptions.get(exception)»>(
               serviceFaultHandlerManager, «cabString»("«exception»"));
         «ENDFOR»
      }
      '''
    }
               
}
