package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Map

class TypeResolverExtensions {
    static def String makeEventGUIDImplementations(extension TypeResolver typeResolver,
        Iterable<StructDeclaration> structs)
    {        
      '''
      «FOR eventData : structs»
         «val relatedEvent = com.btc.serviceidl.util.Util.getRelatedEvent(eventData)»
         «IF relatedEvent !== null»
            «val eventUuid = GuidMapper.get(relatedEvent)»
            // {«eventUuid»}
            static const «resolveSymbol("BTC::Commons::CoreExtras::UUID")» s«eventData.name»TypeGuid = 
               «resolveSymbol("BTC::Commons::CoreExtras::UUID")»::ParseString("«eventUuid»");

            «resolveSymbol("BTC::Commons::CoreExtras::UUID")» «resolve(eventData)»::EVENT_TYPE_GUID()
            {
               return s«eventData.name»TypeGuid;
            }
         «ENDIF»
      «ENDFOR»
      '''
    }

   static def Map<String, String> getDefaultExceptionRegistration(extension TypeResolver typeResolver)
   {
      // TODO these must not be registered, the default must be empty
      #{
          Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER         -> resolveSymbol("BTC::Commons::Core::InvalidArgumentException")
         ,Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER    -> resolveSymbol("BTC::Commons::Core::UnsupportedOperationException")
      }
   }
      
    
}