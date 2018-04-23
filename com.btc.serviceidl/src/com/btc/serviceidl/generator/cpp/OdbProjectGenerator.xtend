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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashMap
import java.util.Map
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static com.btc.serviceidl.generator.cpp.Util.*

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*

@Accessors
class OdbProjectGenerator extends ProjectGeneratorBase {
     
    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, VSSolution vsSolution,
        Map<String, HashMap<String, String>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map,  ModuleDeclaration module)
    {
        super(resource, file_system_access, qualified_name_provider, scope_provider, idl, vsSolution,
            protobuf_project_references, smart_pointer_map, ProjectType.EXTERNAL_DB_IMPL, module)
    }
    
   override void generate()
   {
      val all_elements = module.moduleComponents
         .filter[e | com.btc.serviceidl.util.Util.isStruct(e)]
         .map(e | com.btc.serviceidl.util.Util.getUltimateType(e) as StructDeclaration)
         .filter[!members.empty]
         .filter[!members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty]
         .resolveAllDependencies
         .map[type]
         .filter(StructDeclaration)
      
      // all structs, for which ODB files will be generated; characteristic: 
      // they have a member called "ID" with type UUID
      val id_structs = all_elements.filter[!members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty ]
      
      // nothing to do...
      if (id_structs.empty)
      { return }
                  
      // paths
      val odb_path = projectPath + "odb" + Constants.SEPARATOR_FILE
      
      // collect all commonly used types to include them in an centralized header
      val common_types = all_elements
         .filter[members.filter[m | m.name.toUpperCase == "ID" && com.btc.serviceidl.util.Util.isUUIDType(m.type)].empty]
      if (!common_types.empty)
      {
         val basic_file_name = Constants.FILE_NAME_ODB_COMMON
         file_system_access.generateFile(odb_path + basic_file_name.hxx, generateCommonHxx(common_types))
         odb_files.add(basic_file_name);
      }
      for ( struct : id_structs )
      {
         val basic_file_name = struct.name.toLowerCase
         file_system_access.generateFile(odb_path + basic_file_name.hxx, generateHxx(struct))
         odb_files.add(basic_file_name);
      }
      file_system_access.generateFile(odb_path + Constants.FILE_NAME_ODB_TRAITS.hxx, generateODBTraits)
      
      super.generate()
      
      for ( interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val basic_file_name = GeneratorUtil.getClassName(param_bundle, interface_declaration.name)
         header_files.add(basic_file_name.h)
         cpp_files.add(basic_file_name.cpp)
      }
      
      generateVSProjectFiles(ProjectType.EXTERNAL_DB_IMPL, projectPath, vsSolution.getVcxprojName(param_bundle, Optional.empty))
   }

   def private String generateCommonHxx(Iterable<StructDeclaration> common_types)
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateCommonHxx(common_types).toString      
      makeHxx(file_content, false)
   }
   
   def private String generateHxx(StructDeclaration struct)
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateHxx(struct).toString
      var underlying_types = getUnderlyingTypes(struct)
      makeHxx(file_content, !underlying_types.empty)
   }
   
   def private String generateODBTraits()
   {
      reinitializeFile
      
      val file_content = new OdbGenerator(typeResolver).generateODBTraitsBody()
      
      makeHxx(file_content.toString, false)
   }
   
   def private String makeHxx(String file_content, boolean use_common_types)
   {
      '''
      #pragma once
      
      #include "modules/Commons/include/BeginPrinsModulesInclude.h"
      
      «IF use_common_types»#include "«Constants.FILE_NAME_ODB_COMMON.hxx»"«ENDIF»
      «basicCppGenerator.generateIncludes(true)»
      «file_content»
      
      #include "modules/Commons/include/EndPrinsModulesInclude.h"
      '''
   }
   
   def override String generateProjectSource(InterfaceDeclaration interface_declaration)
   {
        reinitializeFile
        
        val file_content = generateCppImpl(interface_declaration)
        
        generateSource(file_content.toString, Optional.empty)
    }
 
     def override String generateProjectHeader(String export_header, InterfaceDeclaration interface_declaration)
    {
        reinitializeFile

        val file_content = generateInterface(interface_declaration)

        generateHeader(file_content.toString, Optional.of(export_header))
    }
    
}
