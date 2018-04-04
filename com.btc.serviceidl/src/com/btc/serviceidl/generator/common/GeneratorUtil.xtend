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
	
}