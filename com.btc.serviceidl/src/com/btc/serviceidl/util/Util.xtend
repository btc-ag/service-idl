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
 * \file       Util.xtend
 * 
 * \brief      Miscellaneous common utility methods
 */

package com.btc.serviceidl.util

import java.util.Deque
import com.btc.serviceidl.idl.InterfaceDeclaration
//import com.btc.serviceidl.util.TransformType
import java.util.ArrayDeque
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil
import java.util.regex.Pattern
//import com.btc.serviceidl.util.ArtifactNature
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import java.util.HashSet
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.DocCommentElement
import static extension com.btc.serviceidl.util.Extensions.*
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import java.util.Collection
import com.btc.serviceidl.idl.ExceptionDeclaration
import org.eclipse.xtext.naming.IQualifiedNameProvider
import com.btc.serviceidl.idl.AbstractCrossReference
import java.util.Optional
import com.btc.serviceidl.idl.MemberElement

class Util
{
   /**
    * Given a predicate, add a new line or return empty string
    */
   def public static String addNewLine(boolean add_new_line)
   {
      '''
      «IF add_new_line»
      
      «ENDIF»
      '''
   }
   
//   def public static String transform(ParameterBundle param_bundle)
//   {
//      var result = ""
//      for ( module : param_bundle.module_stack )
//      {
//         if (!module.virtual)
//         {
//            result += getEffectiveModuleName(module, param_bundle) + (if (module != param_bundle.module_stack.last) param_bundle.transform_type.getSeparator else "")
//         }
//         else
//         {
//            if (param_bundle.transform_type.useVirtual || param_bundle.artifact_nature == ArtifactNature.JAVA)
//               result += getEffectiveModuleName(module, param_bundle) + (if (module != param_bundle.module_stack.last) param_bundle.transform_type.getSeparator else "")
//         }
//      }
//      if (param_bundle.project_type.present) result += param_bundle.transform_type.getSeparator + param_bundle.project_type.get.getName
//      if (param_bundle.artifact_nature == ArtifactNature.JAVA)
//         result = result.toLowerCase
//      return result
//   }
   
//   def public static String getEffectiveModuleName(ModuleDeclaration module, ParameterBundle param_bundle)
//   {
//      val artifact_nature = param_bundle.artifact_nature
//      
//      if (artifact_nature == ArtifactNature.DOTNET)
//      {
//         if (module.main) return module.name + ".NET" else module.name 
//      }
//      else if (artifact_nature == ArtifactNature.JAVA)
//      {
//         if (module.eContainer === null || (module.eContainer instanceof IDLSpecification))
//            return "com" + param_bundle.transform_type.separator + module.name
//         else
//            return module.name
//      }
//      return module.name
//   }
   
   def public static String makeProtobufMethodName(String method_name, String type)
   {
      return method_name.toLowerCase + "_" + type.toLowerCase
   }
   
   def public static String makeBasicMessageName(String name, String message_type)
   {
      return name + "_" + message_type
   }
   
   /**
    * Converts the given name into Protobuf request name.
    */
   def public static String asRequest(String name)
   {
      return name + "_" + Constants.PROTOBUF_REQUEST
   }
   
   /**
    * Converts given name into Protobuf response name.
    */
   def public static String asResponse(String name)
   {
      return name + "_" + Constants.PROTOBUF_RESPONSE
   }
   
   def public static Deque<ModuleDeclaration> getModuleStack(EObject element)
   {
      var module_stack = new ArrayDeque<ModuleDeclaration>
      var current_container = if (element instanceof ModuleDeclaration) element else element.eContainer
      
      while (current_container !== null && !(current_container instanceof IDLSpecification))
      {
         if (current_container instanceof ModuleDeclaration)
            module_stack.push(current_container)
         current_container = current_container.eContainer
      }
      
      return module_stack
   }

//   /**
//    * Given a module stack, this method will calculate relative paths up to the
//    * solution root directory in form of ../../
//    * 
//    * \details If at least one relative parent path is there, the string ALWAYS
//    * ends with the path separator!
//    */
//   def public static String getRelativePathsUpwards(ParameterBundle param_bundle)
//   {
//      var paths = ""
//      for (module : param_bundle.module_stack)
//      {
//         if (!module.virtual) // = non-virtual
//            paths += ".." + TransformType.FILE_SYSTEM.separator
//      }
//      return paths
//   }

   def public static EObject getScopeDeterminant(EObject element)
   {
      var container = element
      while (container !== null)
      {
         if (container instanceof InterfaceDeclaration || container instanceof ModuleDeclaration)
            return container
         else
            container = container.eContainer
      }
      
      return EcoreUtil.getRootContainer(element)
   }
      
   def public static EventDeclaration getRelatedEvent(StructDeclaration object, IDLSpecification idl)
   {
      return idl.eAllContents.filter(EventDeclaration).findFirst[data === object]
   }
   
   def public static EventDeclaration getAnonymousEvent(InterfaceDeclaration interface_declaration)
   {
      return interface_declaration.contains.filter(EventDeclaration).filter[name === null].head as EventDeclaration
   }
   
   /**
    * Get all structures which act message types in event within the given interface.
    */
   def public static Iterable<StructDeclaration> getEventStructures(IDLSpecification idl, InterfaceDeclaration interface_declaration)
   {
      val event_structs = new HashSet<StructDeclaration>
      for (struct : idl.eAllContents.filter(StructDeclaration).toIterable)
      {
         if (!interface_declaration.contains.filter(EventDeclaration).filter[data === struct].empty)
            event_structs.add(struct)
      }
      return event_structs
   }
   
   def public static Iterable<AbstractException> getRaisedExceptions(EObject container)
   {
      val exceptions = new HashSet<AbstractException>
      for (function : container.eContents.filter(FunctionDeclaration))
      {
         for (exception : function.raisedExceptions)
         {
            exceptions.add(exception)
         }
      }
      
      return exceptions
   }
   
   /**
    * Is the given element a sequence? For example, we then need to call the
    * Google Protobuf method as get...List()
    */
   def public static boolean isSequenceType(EObject element)
   {
      tryGetSequence(element).present
   }
   
   /**
    * Does the given element represents a UUID type? 
    */
   def public static boolean isUUIDType(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof PrimitiveType)
      {
         return (element.uuidType !== null)
      }
      else if (element instanceof AbstractType)
      {
         return isUUIDType(element.primitiveType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isUUIDType(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents an Enum type? 
    */
   def public static boolean isEnumType(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof EnumDeclaration)
         return true
      
      if (element instanceof AbstractType)
      {
         return isEnumType(element.referenceType)
      }
      
      if (element instanceof AliasDeclaration)
      {
         return isEnumType(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents a Byte type? 
    */
   def public static boolean isByte(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof PrimitiveType)
      {
         return element.isByte
      }
      else if (element instanceof AbstractType)
      {
         return isByte(element.primitiveType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isByte(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents a Int16 type? 
    */
   def public static boolean isInt16(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof PrimitiveType)
      {
         return element.isInt16
      }
      else if (element instanceof AbstractType)
      {
         return isInt16(element.primitiveType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isInt16(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents a Char type? 
    */
   def public static boolean isChar(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof PrimitiveType)
      {
         return (element.charType !== null)
      }
      else if (element instanceof AbstractType)
      {
         return isChar(element.primitiveType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isChar(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents a primitive type? 
    */
   def public static boolean isPrimitive(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof PrimitiveType)
      {
         return true
      }
      else if (element instanceof AbstractType)
      {
         return isPrimitive(element.primitiveType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isPrimitive(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents a structure type? 
    */
   def public static boolean isStruct(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof StructDeclaration)
      {
         return true
      }
      else if (element instanceof AbstractType)
      {
         return isStruct(element.referenceType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isStruct(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents an exception type? 
    */
   def public static boolean isException(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof ExceptionDeclaration)
      {
         return true
      }
      else if (element instanceof AbstractType)
      {
         return isException(element.referenceType)
      }
      else if (element instanceof AliasDeclaration)
      {
         return isException(element.type)
      }
      
      return false
   }
   
   /**
    * Does the given element represents an abstract cross reference type? 
    */
   def public static boolean isAbstractCrossReferenceType(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof AbstractCrossReference)
      {
         return true
      }
      else if (element instanceof AbstractType)
      {
         return isAbstractCrossReferenceType(element.referenceType)
      }
      
      return false
   }
   
   /**
    * Does the given element represents an alias type? 
    */
   def public static boolean isAlias(EObject element)
   {
      if (element === null) return false
      
      if (element instanceof AliasDeclaration)
      {
         return true
      }
      else if (element instanceof AbstractType)
      {
         return isAlias(element.referenceType)
      }
      
      return false
   }
   
   /**
    * Return the path to the *.proto file with base type definitions.
    */
   def public static String getProtobufBaseTypesPath()
   {
      return "ServiceComm/ProtobufUtil/gen/BaseTypes.proto"
   }
   
   /**
    * If given element is a sequence (of sequence of sequence... of type T),
    * go deep to retrieve T; otherwise return element immediately. 
    */
   def public static EObject getUltimateType(EObject element)
   {
      return getUltimateType(element, true)
   }
   
   def public static boolean isFailable(EObject element)
   {
      val sequence = tryGetSequence(element)
      return (sequence.present && sequence.get.failable)
   }
   
   def public static Optional<SequenceDeclaration> tryGetSequence(EObject element)
   {
      if (element instanceof SequenceDeclaration)
         return Optional.of(element)
      
      if (element instanceof AbstractType)
         return tryGetSequence(element.collectionType)

      if (element instanceof AliasDeclaration)
         return tryGetSequence(element.type)

      if (element instanceof MemberElement)
         return tryGetSequence(element.type)

      if (element instanceof ParameterElement)
         return tryGetSequence(element.paramType)

      return Optional.empty
   }
   
   /**
    * Core logic for getUltimateType; the flag "decompose_typedef" allows us either
    * to get the basic type defined by this typedef (true) or the typedef itself (false).
    */
   def public static EObject getUltimateType(EObject element, boolean decompose_typedef)
   {
      if (element instanceof SequenceDeclaration)
         return getUltimateType(element.type, decompose_typedef)
      else if (element instanceof AbstractType && ((element as AbstractType).collectionType !== null))
         return getUltimateType((element as AbstractType).collectionType, decompose_typedef)
      else if (element instanceof AbstractType && ((element as AbstractType).referenceType !== null))
         return getUltimateType((element as AbstractType).referenceType, decompose_typedef)
      else if (element instanceof AbstractType && ((element as AbstractType).primitiveType !== null))
         return (element as AbstractType).primitiveType
      else if (element instanceof ParameterElement)
         return getUltimateType(element.paramType, decompose_typedef)
      else if (element instanceof AliasDeclaration)
      {
         if (decompose_typedef)
            return getUltimateType((element as AliasDeclaration).type, decompose_typedef)
         else
            return element
      }
      else
         return element
   }
   
   /**
    * Format a comment element as plain text. Line breaks are preserved at proper places!
    */
   def public static String getPlainText(DocCommentElement comment)
   {
      return comment.text
         .replaceAll("\\p{Blank}+", " ")
         .replaceAll("\\p{Cntrl}\\p{Blank}", "")
         .replaceAll(Pattern.quote("<#"), "")
         .replaceAll(Pattern.quote("#>"), "")
         .replaceFirst("^" + Pattern.quote("#"), "")
         .trim
   }
   
//   def public static String getClassName(ParameterBundle param_bundle, String basic_name)
//   {
//      return getClassName(param_bundle, param_bundle.project_type.get, basic_name)
//   }
//   
//   def static String getClassName(ParameterBundle param_bundle, ProjectType project_type, String basic_name)
//   {
//      return project_type.getClassName(param_bundle.artifact_nature, basic_name)
//   }
//   
//   def static boolean useCodec(EObject element, ArtifactNature artifact_nature)
//   {
//      if (element instanceof PrimitiveType)
//      {
//         return element.isByte || element.isInt16 || element.isChar || element.isUUID
//         // all other primitive types map directly to built-in types!
//      }
//      else if (element instanceof ParameterElement)
//      {
//         return useCodec(element.paramType, artifact_nature)
//      }
//      else if (element instanceof AliasDeclaration)
//      {
//         return useCodec(element.type, artifact_nature)
//      }
//      else if (element instanceof SequenceDeclaration)
//      {
//         if (artifact_nature == ArtifactNature.DOTNET || artifact_nature == ArtifactNature.JAVA)
//            return useCodec(element.type, artifact_nature) // check type of containing elements
//         else
//            return true
//      }
//      else if (element instanceof AbstractType)
//      {
//         if (element.primitiveType !== null)
//            return useCodec(element.primitiveType, artifact_nature)
//         else if (element.collectionType !== null)
//            return useCodec(element.collectionType, artifact_nature)
//         else if (element.referenceType !== null)
//            return useCodec(element.referenceType, artifact_nature)
//      }
//      return true;
//   }
   
//   def static String getCodecName(EObject object)
//   {
//      '''«getPbFileName(object)»«Constants.FILE_NAME_CODEC»'''
//   }
   
//   def static String getPbFileName(EObject object)
//   {
//      if (object instanceof ModuleDeclaration) Constants.FILE_NAME_TYPES
//         else if (object instanceof InterfaceDeclaration) Names.plain(object)
//         else getPbFileName(Util.getScopeDeterminant(object))
//   }
   
   
//   def static Collection<EObject> getEncodableTypes(EObject owner)
//   {
//      val nested_types = new HashSet<EObject>
//      nested_types.addAll(owner.eContents.filter(StructDeclaration))
//      nested_types.addAll(owner.eContents.filter(ExceptionDeclaration))
//      nested_types.addAll(owner.eContents.filter(EnumDeclaration))
//      return nested_types.sortBy[e | Names.plain(e)]
//   }
   
   /**
    * This method generates a consistent name for exceptions used on all sides
    * of the ServiceComm framework in order to correctly resolve the type.
    */
   def static String getCommonExceptionName(AbstractException exception, IQualifiedNameProvider name_provider)
   {
      return name_provider.getFullyQualifiedName(exception).toString
   }
   
   def static<T> boolean ensurePresentOrThrow(Optional<T> optional)
   {
      if (!optional.present)
         throw new IllegalArgumentException("Optional value missing!")
      
      return true
   }

   def static Iterable<AbstractException> getFailableExceptions(EObject container)
   {
      var exceptions = new HashSet<AbstractException>

      // interfaces: special handling due to inheritance
      if (container instanceof InterfaceDeclaration)
      {
         // function parameters
         val from_parameters = container
            .functions
            .map[parameters]
            .flatten
            .map[tryGetSequence]
            .filter[present]
            .map[get]
            .map[raisedExceptions]
            .flatten

         // function return values
         val from_return_values = container
            .functions
            .map[returnedType]
            .map[tryGetSequence]
            .filter[present]
            .map[get]
            .map[raisedExceptions]
            .flatten

         exceptions.addAll(from_parameters)
         exceptions.addAll(from_return_values)
      }

      val contents = container.eAllContents.toList
      
      // typedefs
      exceptions.addAll
      (
         contents
            .filter(AliasDeclaration)
            .map[tryGetSequence]
            .filter[present]
            .map[get]
            .map[raisedExceptions]
            .flatten
      )
      
      // structs
      exceptions.addAll
      (
         contents
            .filter(StructDeclaration)
            .map[members]
            .flatten
            .map[tryGetSequence]
            .filter[present]
            .map[get]
            .map[raisedExceptions]
            .flatten
      )

      return exceptions.sortBy[name]
   }

//   def static Iterable<EObject> getFailableTypes(EObject container)
//   {
//      var objects = new HashSet<EObject>
//
//      // interfaces: special handling due to inheritance
//      if (container instanceof InterfaceDeclaration)
//      {
//         // function parameters
//         val parameter_types = container
//            .functions
//            .map[parameters]
//            .flatten
//            .filter[isFailable(paramType)]
//            .toSet
//
//         // function return types
//         val return_types = container
//            .functions
//            .map[returnedType]
//            .filter[isFailable]
//            .toSet
//
//         objects.addAll(parameter_types)
//         objects.addAll(return_types)
//      }
//
//      val contents = container.eAllContents.toList
//      
//      // typedefs
//      objects.addAll
//      (
//         contents
//            .filter(AliasDeclaration)
//            .filter[isFailable(type)]
//            .map[type]
//      )
//      
//      // structs
//      objects.addAll
//      (
//         contents
//            .filter(StructDeclaration)
//            .map[members]
//            .flatten
//            .filter[isFailable(type)]
//            .map[type]
//      )
//
//      // filter out duplicates (especially primitive types) before delivering the result!
//      return objects.map[getUltimateType].map[UniqueWrapper.from(it)].toSet.map[type].sortBy[e | Names.plain(e)]
//   }
//   
//   def static String asFailable(EObject element, EObject container, IQualifiedNameProvider name_provider)
//   {
//      val type = Util.getUltimateType(element)
//      var String type_name
//      if (type.isPrimitive)
//      {
//         type_name = Names.plain(type)
//      }
//      else
//      {
//         type_name = name_provider.getFullyQualifiedName(type).segments.join("_")
//      }
//      val container_fqn = name_provider.getFullyQualifiedName(container)
//      return '''Failable_«container_fqn.segments.join("_")»_«type_name.toFirstUpper»'''
//   }
}
