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
 * \file       ProtobufGenerator.xtend
 * 
 * \brief      Xtend generator for Google Protocol Buffers artifacts from an IDL
 */

package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*

@Accessors(NONE)
class ProtobufGenerator
{
   val Resource resource
   val IFileSystemAccess file_system_access
   val IQualifiedNameProvider qualified_name_provider
   val IModuleStructureStrategy moduleStructureStrategy
      
   val generated_artifacts = new HashMap<EObject, String>
   val typedef_table = new HashMap<String, String>
   val allProjectReferences = new HashMap<ArtifactNature, Map<ParameterBundle, Set<ParameterBundle>>>
   
   def Map<ParameterBundle, Set<ParameterBundle>> getProjectReferences(ArtifactNature artifactNature)
    {
        allProjectReferences.computeIfAbsent(artifactNature, [new HashMap<ParameterBundle, Set<ParameterBundle>>])
    }
   
   def Map<EObject, String> getGeneratedArtifacts()
   {
      return generated_artifacts
   }
   
    def void doGenerate(Iterable<ArtifactNature> languages) 
    {  
      // handle all interfaces
      for (interface_declaration : resource.allContents.filter(InterfaceDeclaration).toIterable)
      {
         val artifact_name = interface_declaration.name

         // TODO why is the proto file generated for each language?
         for (language : languages)
             generateProtobufFile(language, interface_declaration, artifact_name,
                 new InterfaceProtobufFileGenerator(qualified_name_provider, moduleStructureStrategy,
                     getProjectReferences(language), typedef_table, language).generateInterface(
                     interface_declaration))
         
         generated_artifacts.put(interface_declaration, artifact_name)
      }
      
      // handle all module contents (excluding interfaces)
      for (module : resource.allContents.filter(ModuleDeclaration).filter[!isVirtual].toIterable)
      {
         val module_contents = module.eContents.filter( [e | !(e instanceof ModuleDeclaration || e instanceof InterfaceDeclaration)])
         if ( !module_contents.empty )
         {
            val artifact_name = Constants.FILE_NAME_TYPES
            
            for (language : languages)
                    generateProtobufFile(language, module, artifact_name,
                        new ModuleProtobufFileGenerator(qualified_name_provider, moduleStructureStrategy,
                            getProjectReferences(language), typedef_table, language).generateModuleContent(module,
                            module_contents))
            
            generated_artifacts.put(module, artifact_name)
         }
      }
   }
   
   private def void generateProtobufFile(ArtifactNature an, EObject container, String artifact_name,
        String file_content)
    {
        file_system_access.generateFile(
            makeProtobufPath(container, artifact_name, an, moduleStructureStrategy).toPortableString, an.label,
            file_content)
    }
}
