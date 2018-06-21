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
package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.util.Constants

import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ServiceFaultHandlingGenerator extends GeneratorBase
{
   def String generate(String className, EObject owner)
   {
      val dictionary = resolve("System.Collections.Generic.Dictionary")
      val exception = resolve("System.Exception")
      val string = resolve("System.string")
      val type = resolve("System.Type")
      
      val raisedExceptions = owner.raisedExceptions
      
      '''
      public static class «className»
      {
         // note that this mapping is effectively bi-directional! we could technically
         // use the same runtime exception type for different error IDs coming from the
         // wire, but to translate an arbitrary exception to different error IDs, we
         // would need to know the context of the exception = this is not given here!
         private static «dictionary»<«string», «type»> errorMap = new «dictionary»<«string», «type»>();
         
         static «className»()
         {
            // most commonly used exception types
            errorMap["«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»"] = typeof(«resolve("System.ArgumentException").fullyQualifiedName»);
            errorMap["«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»"] = typeof(«resolve("System.NotSupportedException").fullyQualifiedName»);
            
            «FOR e : raisedExceptions.sortBy[name] SEPARATOR System.lineSeparator»
               errorMap["«e.getCommonExceptionName(qualified_name_provider)»"] = typeof(«resolve(e)»);
            «ENDFOR»
         }
         
         public static «dictionary»<«string», «type»> getErrorMappings()
         {
            return errorMap;
         }
         
         public static «string» resolveError(«exception» e)
         {
            var type = e.GetType();
            foreach (var item in errorMap)
            {
               if (type.Equals(item.Value))
               {
                  return item.Key;
               }
            }
            
            // mapping not found: use the type name itself
            return type.ToString();
         }
         
         public static «exception» resolveError(«string» type, «string» message, «string» stacktrace)
         {
            if (errorMap.ContainsKey(type))
            {
               return «resolve("System.Activator")».CreateInstance(errorMap[type], new «resolve("System.object")»[] { message }) as «exception»;
            }
         
            // mapping not found: create generic exception
            return new «exception»(message);
         }
      }
      '''
   }
}
