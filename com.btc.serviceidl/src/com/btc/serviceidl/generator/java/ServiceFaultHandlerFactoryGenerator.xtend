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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import java.util.HashSet
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ServiceFaultHandlerFactoryGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateServiceFaultHandlerFactory(String className, AbstractContainerDeclaration container)
    {
        val serviceFaultHandler = typeResolver.resolve(JavaClassNames.DEFAULT_SERVICE_FAULT_HANDLER)
        val iError = typeResolver.resolve(JavaClassNames.ERROR)
        val optional = typeResolver.resolve(JavaClassNames.OPTIONAL)
        val raisedExceptions = container.raisedExceptions
        val failableExceptions = container.failableExceptions

        // merge both collections to avoid duplicate entries
        val exceptions = new HashSet<AbstractException>
        exceptions.addAll(raisedExceptions)
        exceptions.addAll(failableExceptions)
        
        val errorMapValueType = if (basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3) "Exception" else "Class"

        // TODO except for the static initializer, this can be extracted into a reusable class, which can be provided 
        // from com.btc.cab.servicecomm
        '''
        public class «className»
        {
           «// TODO the map should not use exception instances as values, but their types/Classes
           »
           private static final «typeResolver.resolve("org.apache.commons.collections4.BidiMap")»<String, «errorMapValueType»> errorMap = new «typeResolver.resolve("org.apache.commons.collections4.bidimap.DualHashBidiMap")»<>();
           
           static
           {
              «FOR exception : exceptions.sortBy[name]»
                  errorMap.put("«Util.getCommonExceptionName(exception, basicJavaSourceGenerator.qualifiedNameProvider)»", «getClassOrObject(typeResolver.resolve(exception))»);
              «ENDFOR»
           }
           
           public static final «typeResolver.resolve(JavaClassNames.SERVICE_FAULT_HANDLER)» createServiceFaultHandler()
           {
              «serviceFaultHandler» serviceFaultHandler = new «serviceFaultHandler»();
              errorMap.forEach( (key, value) -> serviceFaultHandler.registerException(key, value) );
              return serviceFaultHandler;
              
           }
           
           public static final Exception createException(String errorType, String message, String stackTrace)
           {
              if (errorMap.containsKey(errorType))
              {
                 «errorMapValueType» exception = errorMap.get(errorType);
                 try
                 {
                    «typeResolver.resolve("java.lang.reflect.Constructor")»<?> constructor = exception.«IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»getClass().«ENDIF»getConstructor(String.class);
                    return (Exception) constructor.newInstance( new Object[] {message} );
                 } catch (Exception ex)
                 {
                    «IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»
                    «// TODO this looks strange. What kind of Exception is intended to be caught here? Any exception is swallowed here.
                     // one typical case might be that the exception type has no constructor accepting a String message. In that case
                     // the element from the map is returned. However, this is certainly not thread-safe.
                    »
                    return exception;
                    «ELSE»
                    throw new RuntimeException("Exception when trying to instantiate exception", ex);
                    «ENDIF»
                 }
              }
              
              return new Exception(message); // default exception
           }
           
           public static final «iError» createError(Exception exception)
           {
              «optional»<String> errorType = «optional».empty();
              for («errorMapValueType» e : errorMap.values())
              {
                 if (e.«IF basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3»getClass().«ENDIF»equals(exception.getClass()))
                 {
                    errorType = «optional».of(errorMap.inverseBidiMap().get(e));
                    break;
                 }
              }
              «iError» error = new «typeResolver.resolve("com.btc.cab.servicecomm.faulthandling.ErrorMessage")»(
                  exception.getMessage(),
                  errorType.isPresent() ? errorType.get() : exception.getClass().getName(),
                  «typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getStackTrace(exception));
              return error;
           }
        }
        '''
    }
    
    def getClassOrObject(ResolvedName name) {
        if (basicJavaSourceGenerator.javaTargetVersion == ServiceCommVersion.V0_3)
            '''new «name»()'''
        else
            name + ".class"
    }
    
}
