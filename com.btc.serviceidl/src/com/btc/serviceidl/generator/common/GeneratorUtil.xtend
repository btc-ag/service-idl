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
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.util.Constants
import java.util.regex.Pattern
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import org.eclipse.emf.ecore.EObject
import java.util.HashSet
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtext.naming.IQualifiedNameProvider
import com.btc.serviceidl.util.Util
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.StructDeclaration

class GeneratorUtil {
   def public static String transform(ParameterBundle param_bundle)
   {
      var result = ""
      for ( module : param_bundle.module_stack )
      {
         if (!module.virtual)
         {
            result += getEffectiveModuleName(module, param_bundle) + (if (module != param_bundle.module_stack.last) param_bundle.transform_type.getSeparator else "")
         }
         else
         {
            if (param_bundle.transform_type.useVirtual || param_bundle.artifact_nature == ArtifactNature.JAVA)
               result += getEffectiveModuleName(module, param_bundle) + (if (module != param_bundle.module_stack.last) param_bundle.transform_type.getSeparator else "")
         }
      }
      if (param_bundle.project_type.present) result += param_bundle.transform_type.getSeparator + param_bundle.project_type.get.getName
      if (param_bundle.artifact_nature == ArtifactNature.JAVA)
         result = result.toLowerCase
      return result
   }

   def public static String getEffectiveModuleName(ModuleDeclaration module, ParameterBundle param_bundle)
   {
      val artifact_nature = param_bundle.artifact_nature
      
      if (artifact_nature == ArtifactNature.DOTNET)
      {
         if (module.main) return module.name + ".NET" else module.name 
      }
      else if (artifact_nature == ArtifactNature.JAVA)
      {
         if (module.eContainer === null || (module.eContainer instanceof IDLSpecification))
            return "com" + param_bundle.transform_type.separator + module.name
         else
            return module.name
      }
      return module.name
   }
   
   def public static String switchPackageSeperator(String name, TransformType transform_type)
   {
      return name.replaceAll(Pattern.quote(Constants.SEPARATOR_PACKAGE), transform_type.getSeparator)
   }
   
   def static String switchSeparator(String name, TransformType source, TransformType target)
   {
      name.replaceAll(Pattern.quote(source.separator), target.separator)
   }
	
   def static Iterable<EObject> getFailableTypes(EObject container)
   {
      var objects = new HashSet<EObject>

      // interfaces: special handling due to inheritance
      if (container instanceof InterfaceDeclaration)
      {
         // function parameters
         val parameter_types = container
            .functions
            .map[parameters]
            .flatten
            .filter[isFailable(paramType)]
            .toSet

         // function return types
         val return_types = container
            .functions
            .map[returnedType]
            .filter[isFailable]
            .toSet

         objects.addAll(parameter_types)
         objects.addAll(return_types)
      }

      val contents = container.eAllContents.toList
      
      // typedefs
      objects.addAll
      (
         contents
            .filter(AliasDeclaration)
            .filter[isFailable(type)]
            .map[type]
      )
      
      // structs
      objects.addAll
      (
         contents
            .filter(StructDeclaration)
            .map[members]
            .flatten
            .filter[isFailable(type)]
            .map[type]
      )

      // filter out duplicates (especially primitive types) before delivering the result!
      return objects.map[getUltimateType].map[UniqueWrapper.from(it)].toSet.map[type].sortBy[e | Names.plain(e)]
   }
   
   def static String asFailable(EObject element, EObject container, IQualifiedNameProvider name_provider)
   {
      val type = Util.getUltimateType(element)
      var String type_name
      if (type.isPrimitive)
      {
         type_name = Names.plain(type)
      }
      else
      {
         type_name = name_provider.getFullyQualifiedName(type).segments.join("_")
      }
      val container_fqn = name_provider.getFullyQualifiedName(container)
      return '''Failable_«container_fqn.segments.join("_")»_«type_name.toFirstUpper»'''
   }
}