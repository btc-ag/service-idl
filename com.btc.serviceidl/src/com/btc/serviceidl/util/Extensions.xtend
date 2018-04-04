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
 * \file       Extensions.xtend
 * 
 * \brief      Diverse useful extension methods
 */

package com.btc.serviceidl.util

import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.StructDeclaration
import java.util.ArrayList
import java.util.Collection
import java.util.HashSet
import org.eclipse.emf.ecore.EObject

class Extensions
{
   def static boolean isByte(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("byte"))
   }
   
   def static boolean isInt16(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("int16"))
   }
   
   def static boolean isInt32(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("int32"))
   }
   
   def static boolean isInt64(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("int64"))
   }
   
   def static boolean isChar(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.charType !== null)
   }
   
   def static boolean isString(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.stringType !== null)
   }
   
   def static boolean isUUID(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.uuidType !== null)
   }
   
   def static boolean isBoolean(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.booleanType !== null)
   }
   
   def static boolean isDouble(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.floatingPointType !== null && primitive_type.floatingPointType.equals("double"))
   }
   
   def static boolean isFloat(PrimitiveType primitive_type)
   {
      (primitive_type !== null && primitive_type.floatingPointType !== null && primitive_type.floatingPointType.equals("float"))
   }
   
   def static boolean containsTypes(ModuleDeclaration module)
   {
      module.moduleComponents.exists[o | !(o instanceof ModuleDeclaration)
         && !(o instanceof InterfaceDeclaration)]
   }
   
   def static boolean containsInterfaces(ModuleDeclaration module)
   {
      module.moduleComponents.exists[o | o instanceof InterfaceDeclaration]
   }

// TODO MODULE move this somewhere else   
//   def static ProjectType getMainProjectType(EObject item)
//   {
//      val scope_determinant = Util.getScopeDeterminant(item)
//      if (scope_determinant instanceof InterfaceDeclaration)
//         return ProjectType.SERVICE_API
//      
//      if (scope_determinant instanceof ModuleDeclaration)
//         return ProjectType.COMMON
//      
//      throw new IllegalArgumentException("Cannot determine main project type for " + item.toString)
//   }
   
   /**
    * For a given object, check in the container hierarchy whether it belongs
    * to a function parameter marked as "out".
    * 
    * \return true, if yes, false otherwise (also e.g. if such an owner could not be found at all)
    */
   def static boolean isOutputParameter(EObject element)
   {
      var container = element.eContainer
      
      while (container !== null)
      {
         if (container instanceof ParameterElement)
         {
            return (container.direction == ParameterDirection.PARAM_OUT)
         }
         container = container.eContainer
      }
      
      return false
   }
   
   /**
    * For a given interface, return all function it offers, i.e. own functions
    * as well as functions from all super classes.
    */
   def static Iterable<FunctionDeclaration> functions(InterfaceDeclaration interface_declaration)
   {
      val function_collection = new HashSet<FunctionDeclaration>
      
      function_collection.addAll(interface_declaration.contains.filter(FunctionDeclaration))
      for (parent : interface_declaration.derivesFrom)
      {
         function_collection.addAll(parent.functions)
      }
      
      return function_collection.sortBy[name]
   }
   
   /**
    * For a given interface, return all function it offers, i.e. own functions
    * as well as functions from all super classes.
    */
   def static Iterable<EventDeclaration> events(InterfaceDeclaration interface_declaration)
   {
      val event_collection = new HashSet<EventDeclaration>
      
      event_collection.addAll(interface_declaration.contains.filter(EventDeclaration))
      for (parent : interface_declaration.derivesFrom)
      {
         event_collection.addAll(parent.events)
      }
      
      return event_collection.sortBy[data.name]
   }
   
   /**
    * Allows to print the given text for any object: useful, when we need
    * to resolve a type, but do not want/may not print the resulting string.
    */
   def static String alias(Object object, String text)
   {
      text
   }
   
   /**
    * Requirements are all elements, which are essentially needed by the given
    * element, no matter if defined externally or internally.
    */
   def static dispatch Collection<EObject> requirements(StructDeclaration element)
   {
      val result = new HashSet<EObject>(element.members.size)
      for (member : element.members)
      {
         if (Util.isStruct(member.type))
            result.add(Util.getUltimateType(member.type) as StructDeclaration)
      }
      return result
   }
   
   def static dispatch Collection<EObject> requirements(ExceptionDeclaration element)
   {
      val result = new HashSet<EObject>(element.members.size)
      for (member : element.members)
      {
         if (Util.isException(member.type))
            result.add(Util.getUltimateType(member.type) as ExceptionDeclaration)
      }
      return result
   }
   
   def static dispatch Collection<EObject> requirements(EObject element)
   {
      return #[] // default: none
   }
   
   def private static dispatch void getUnderlyingTypes(StructDeclaration element, HashSet<EObject> all_types)
   {
      for ( type : element.members )
      {
         if (!all_types.contains(type))
            getUnderlyingTypes( type, all_types )
      }
   }
   
   def private static dispatch void getUnderlyingTypes(AliasDeclaration element, HashSet<EObject> all_types)
   {
      val type = Util.getUltimateType(element)

      if (!all_types.contains(type))
         getUnderlyingTypes( type, all_types )
      
      if (!Util.isPrimitive(type))
         all_types.add(type)
   }
   
   def private static dispatch void getUnderlyingTypes(ExceptionDeclaration element, HashSet<EObject> all_types)
   {
      for ( type : element.members )
      {
         if (!all_types.contains(type))
            getUnderlyingTypes( type, all_types )
      }
   }
   
   def private static dispatch void getUnderlyingTypes(EObject element, HashSet<EObject> all_types)
   {
      // do nothing by default
   }
   
   def static boolean isAllUpperCase(String text)
   {
      return text.chars.allMatch(c | Character.isUpperCase(c))
   }
   
   def static dispatch Collection<StructDeclaration> getBaseTypes(StructDeclaration element)
   {
      val base_types = new HashSet<StructDeclaration>
      var current_type = element.supertype
      while (current_type !== null && !(base_types.contains(current_type)))
      {
         base_types.add(current_type)
         current_type = current_type.supertype
      }
      return base_types
   }
   
   def static dispatch Collection<InterfaceDeclaration> getBaseTypes(InterfaceDeclaration element)
   {
      val base_types = new HashSet<InterfaceDeclaration>
      collectBaseTypes(element, base_types)
      return base_types
   }
   
   def private static void collectBaseTypes(InterfaceDeclaration element, HashSet<InterfaceDeclaration> base_types)
   {
      for (base_type : element.derivesFrom)
      {
         if (!base_types.contains(base_type))
         {
            base_types.add(base_type)
            collectBaseTypes(base_type, base_types)
         }
      }
   }
   
   def static dispatch Collection<AbstractException> getBaseTypes(ExceptionDeclaration element)
   {
      val base_types = new HashSet<AbstractException>
      var current_type = element.supertype
      while (current_type !== null && !(base_types.contains(current_type)))
      {
         base_types.add(current_type)
         if (current_type instanceof ExceptionDeclaration)
            current_type = current_type.supertype
         else
            current_type = null
      }
      return base_types
   }
   
   /**
    * For a given element, return all members it offers, i.e. own members
    * as well as members from all super classes.
    */
   def static dispatch Iterable<MemberElementWrapper> allMembers(StructDeclaration element)
   {
      if (element.supertype !== null)
      {
         val base_types = element.baseTypes as Collection<StructDeclaration>
         val all_members = base_types.map[effectiveMembers].flatten.toList
         all_members.addAll(element.effectiveMembers)
         return all_members
      }
      else
      {
         return element.effectiveMembers
      }
   }

   def static dispatch Iterable<MemberElementWrapper> allMembers(ExceptionDeclaration element)
   {
      if (element.supertype !== null)
      {
         val base_types = element.baseTypes.filter(ExceptionDeclaration)
         val all_members = base_types.map[members].flatten.map[e | e.wrapMember].toList
         all_members.addAll(element.members.map[e | e.wrapMember])
         return all_members
      }
      else
      {
         return element.members.map[e | e.wrapMember]
      }
   }
   
   /**
    * For a given element, return its effective members. Effective members are
    * all OWN (!) members + type declarations with an identifier. Example:
    * 
    * struct S1
    * {
    *     string mem1;
    *    
    *    struct S2
    *    {
    *        //...
    *    } mem2;
    * }
    * 
    * The result will be [mem1, mem2].
    * 
    */
   def static dispatch Iterable<MemberElementWrapper> effectiveMembers(StructDeclaration element)
   {
      val result = new ArrayList<MemberElementWrapper>
      result.addAll(element.members.map[e | e.wrapMember])
      element.typeDecls.filter(EnumDeclaration).filter[declarator !== null].forEach[ e | result.add(e.wrapMember) ]
      element.typeDecls.filter(StructDeclaration).filter[declarator !== null].forEach[ e | result.add(e.wrapMember) ]
      return result
   }
   
   def static dispatch Iterable<MemberElementWrapper> effectiveMembers(ExceptionDeclaration element)
   {
      return element.members.map[e | e.wrapMember]
   }
   
   def static dispatch Iterable<MemberElementWrapper> effectiveMembers(EObject element)
   {
      return #[] // default case: no members
   }
   
   def private static dispatch MemberElementWrapper wrapMember(MemberElement member)
   {
      return new MemberElementWrapper(member)
   }
   
   def private static dispatch MemberElementWrapper wrapMember(StructDeclaration struct)
   {
      return new MemberElementWrapper(struct)
   }
   
   def private static dispatch MemberElementWrapper wrapMember(EnumDeclaration enum_declaration)
   {
      return new MemberElementWrapper(enum_declaration)
   }
}
