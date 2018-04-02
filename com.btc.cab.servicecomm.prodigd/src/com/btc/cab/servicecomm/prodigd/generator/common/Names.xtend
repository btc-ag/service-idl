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
/**
 * \file       Names.xtend
 * 
 * \brief      Functionality related to model element naming
 */

package com.btc.cab.servicecomm.prodigd.generator.common

import com.btc.cab.servicecomm.prodigd.idl.AliasDeclaration
import com.btc.cab.servicecomm.prodigd.idl.StructDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ModuleDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ExceptionReferenceDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ExceptionDeclaration
import com.btc.cab.servicecomm.prodigd.idl.MemberElement
import com.btc.cab.servicecomm.prodigd.idl.InterfaceDeclaration
import com.btc.cab.servicecomm.prodigd.idl.FunctionDeclaration
import com.btc.cab.servicecomm.prodigd.idl.EventDeclaration
import com.btc.cab.servicecomm.prodigd.idl.EnumDeclaration
import com.btc.cab.servicecomm.prodigd.idl.AbstractType
import com.btc.cab.servicecomm.prodigd.idl.ParameterElement
import com.btc.cab.servicecomm.prodigd.idl.SequenceDeclaration
import com.btc.cab.servicecomm.prodigd.idl.TupleDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ReturnTypeElement
import com.btc.cab.servicecomm.prodigd.idl.PrimitiveType

class Names {
   
   def public static dispatch String plain(ModuleDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(ExceptionReferenceDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(ExceptionDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(StructDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(AliasDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(EnumDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(MemberElement element)
   { return element.name }
   
   def public static dispatch String plain(InterfaceDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(FunctionDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(EventDeclaration element)
   { return element.name }
   
   def public static dispatch String plain(ParameterElement element)
   { return element.paramName }
   
   def public static dispatch String plain(SequenceDeclaration element)
   { return "Sequence" }
   
   def public static dispatch String plain(TupleDeclaration element)
   { return "Tuple" }
   
   def public static dispatch String plain(ReturnTypeElement element)
   { if (element.isVoid) return "void" }
   
   def public static dispatch String plain(AbstractType item)
   {
      if (item.referenceType !== null)
         return plain(item.referenceType)
      else if (item.collectionType !== null)
         return plain(item.collectionType)
      
      throw new IllegalArgumentException("Plain name not supported for " + item)
   }
   
   def public static dispatch String plain(PrimitiveType item)
   {
      if (item.integerType !== null)
      {
         return item.integerType
      }
      else if (item.stringType !== null)
         return item.stringType
      else if (item.floatingPointType !== null)
         return item.floatingPointType
      else if (item.uuidType !== null)
         return item.uuidType
      else if (item.booleanType !== null)
         return item.booleanType
      else if (item.charType !== null)
         return item.charType

      throw new IllegalArgumentException("Unknown PrimitiveType: " + item.class.toString)
   }
}
