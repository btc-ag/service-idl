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
import java.util.regex.Pattern

@Accessors(PUBLIC_GETTER, PRIVATE_SETTER)
class FailableAlias implements Comparable<FailableAlias>
{
   val public static PREFIX = "Failable"
   val public static CONTAINER_TYPE = "System.Threading.Tasks.Task"
   
   val String basicTypeName
   
   new (String typeName)
   {
      basicTypeName = typeName
   }
   
   def String getAliasName()
   {
      '''«PREFIX»_«basicTypeName.toFirstUpper.replaceAll(Pattern.quote("."), "_")»'''
   }
   
   override compareTo(FailableAlias o)
   {
      basicTypeName.compareTo(o.basicTypeName)
   }
   
   override equals(Object o)
   {
      if (o instanceof FailableAlias)
      {
         return basicTypeName.equals(o.basicTypeName)
      }
      
      false
   }
   
   override hashCode()
   {
      basicTypeName.hashCode
   }
}
