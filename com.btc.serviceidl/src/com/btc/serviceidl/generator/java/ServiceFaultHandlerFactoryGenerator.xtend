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

import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import java.util.HashSet
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ServiceFaultHandlerFactoryGenerator
{
    private val BasicJavaSourceGenerator basicJavaSourceGenerator

    def private getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def public generateServiceFaultHandlerFactory(String class_name, EObject container)
    {
        val service_fault_handler = typeResolver.resolve(JavaClassNames.DEFAULT_SERVICE_FAULT_HANDLER)
        val i_error = typeResolver.resolve(JavaClassNames.ERROR)
        val optional = typeResolver.resolve(JavaClassNames.OPTIONAL)
        val raised_exceptions = container.raisedExceptions
        val failable_exceptions = container.failableExceptions

        // merge both collections to avoid duplicate entries
        val exceptions = new HashSet<AbstractException>
        exceptions.addAll(raised_exceptions)
        exceptions.addAll(failable_exceptions)

        // TODO except for the static initializer, this can be extracted into a reusable class, which can be provided 
        // from com.btc.cab.servicecomm
        // TODO InvalidArgumentException and UnsupportedOperationException should not be added to the error map, only 
        // service-specific subtypes 
        '''
        public class «class_name»
        {
           private static final «typeResolver.resolve("org.apache.commons.collections4.BidiMap")»<String, Exception> errorMap = new «typeResolver.resolve("org.apache.commons.collections4.bidimap.DualHashBidiMap")»<>();
           
           static
           {
              «FOR exception : exceptions.sortBy[name]»
                  errorMap.put("«Util.getCommonExceptionName(exception, basicJavaSourceGenerator.qualified_name_provider)»", new «typeResolver.resolve(exception)»());
              «ENDFOR»
              
              // most commonly used exception types
              errorMap.put("«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»", new IllegalArgumentException());
              errorMap.put("«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»", new UnsupportedOperationException());
           }
           
           public static final «typeResolver.resolve(JavaClassNames.SERVICE_FAULT_HANDLER)» createServiceFaultHandler()
           {
              «service_fault_handler» serviceFaultHandler = new «service_fault_handler»();
              errorMap.forEach( (key, value) -> serviceFaultHandler.registerException(key, value) );
              return serviceFaultHandler;
              
           }
           
           public static final Exception createException(String errorType, String message, String stackTrace)
           {
              if (errorMap.containsKey(errorType))
              {
                 Exception exception = errorMap.get(errorType);
                 try
                 {
                    «typeResolver.resolve("java.lang.reflect.Constructor")»<?> constructor = exception.getClass().getConstructor(String.class);
                    return (Exception) constructor.newInstance( new Object[] {message} );
                 } catch (Exception ex)
                 {
                    return exception;
                 }
              }
              
              return new Exception(message); // default exception
           }
           
           public static final «i_error» createError(Exception exception)
           {
              «optional»<String> errorType = «optional».empty();
              for (Exception e : errorMap.values())
              {
                 if (e.getClass().equals(exception.getClass()))
                 {
                    errorType = «optional».of(errorMap.inverseBidiMap().get(e));
                    break;
                 }
              }
              «i_error» error = new «typeResolver.resolve("com.btc.cab.servicecomm.faulthandling.ErrorMessage")»(
                  exception.getMessage(),
                  errorType.isPresent() ? errorType.get() : exception.getClass().getName(),
                  «typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getStackTrace(exception));
              return error;
           }
        }
        '''
    }
}
