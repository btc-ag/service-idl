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
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.BasicCppGenerator
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.generator.cpp.ProjectGeneratorBase
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import java.util.Collection
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static com.btc.serviceidl.generator.cpp.Util.*

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*

@Accessors
class OdbProjectGenerator extends ProjectGeneratorBase {
    new(IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSetFactory projectSetFactory,IProjectSet vsSolution,
        IModuleStructureStrategy moduleStructureStrategy, ITargetVersionProvider targetVersionProvider,
        Map<IProjectReference, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map,  ModuleDeclaration module)
    {
        super(file_system_access, qualified_name_provider, scope_provider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, protobuf_project_references, smart_pointer_map,
            ProjectType.EXTERNAL_DB_IMPL, module, new OdbSourceGenerationStrategy)
    }
    
   override void generate()
   {
      val all_elements = module.moduleComponents
         .filter[e | Util.isStruct(e)]
         .map(e | Util.getUltimateType(e) as StructDeclaration)
         .filter[!members.empty]
         .filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
         .resolveAllDependencies
         .map[type]
         .filter(StructDeclaration)
      
      // all structs, for which ODB files will be generated; characteristic: 
      // they have a member called "ID" with type UUID
      val id_structs = all_elements.filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty ]
      
      // nothing to do...
      if (id_structs.empty)
      { return }
                  
      // paths
      val odb_path = projectPath + Constants.SEPARATOR_FILE + "odb" + Constants.SEPARATOR_FILE
      
      // collect all commonly used types to include them in an centralized header
      val common_types = all_elements
         .filter[members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
      if (!common_types.empty)
      {
         val basic_file_name = Constants.FILE_NAME_ODB_COMMON
         file_system_access.generateFile(odb_path + basic_file_name.hxx, ArtifactNature.CPP.label, generateCommonHxx(common_types))
         projectFileSet.addToGroup(OdbConstants.ODB_FILE_GROUP, basic_file_name)
      }
      for ( struct : id_structs )
      {
         val basic_file_name = struct.name.toLowerCase
         file_system_access.generateFile(odb_path + basic_file_name.hxx, ArtifactNature.CPP.label, generateHxx(struct))
         projectFileSet.addToGroup(OdbConstants.ODB_FILE_GROUP, basic_file_name)
      }
      file_system_access.generateFile(odb_path + Constants.FILE_NAME_ODB_TRAITS.hxx, ArtifactNature.CPP.label, generateODBTraits)
      
      super.generate()
      
      for ( interface_declaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val basic_file_name = GeneratorUtil.getClassName(ArtifactNature.CPP, param_bundle.projectType, interface_declaration.name)
         projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, basic_file_name.h)
         projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, basic_file_name.cpp)
      }
      
      generateProjectFiles(ProjectType.EXTERNAL_DB_IMPL, projectPath, vsSolution.getVcxprojName(param_bundle), projectFileSet)
   }

   private def String generateCommonHxx(Iterable<StructDeclaration> common_types)
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val file_content = new OdbGenerator(basicCppGenerator.typeResolver).generateCommonHxx(common_types).toString      
      makeHxx(basicCppGenerator, file_content, false)
   }
   
   private def String generateHxx(StructDeclaration struct)
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val file_content = new OdbGenerator(basicCppGenerator.typeResolver).generateHxx(struct).toString
      var underlying_types = getUnderlyingTypes(struct)
      makeHxx(basicCppGenerator, file_content, !underlying_types.empty)
   }
   
   private def String generateODBTraits()
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val file_content = new OdbGenerator(basicCppGenerator.typeResolver).generateODBTraitsBody()
      
      makeHxx(basicCppGenerator, file_content.toString, false)
   }
   
   private def String makeHxx(BasicCppGenerator basicCppGenerator, String file_content, boolean use_common_types)
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
   
   private static class OdbSourceGenerationStrategy implements ISourceGenerationStrategy
    {
        override String generateProjectSource(BasicCppGenerator basicCppGenerator, InterfaceDeclaration interface_declaration)
        {
            val file_content = generateCppImpl(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider, 
                basicCppGenerator.paramBundle, interface_declaration
            )

            generateSource(basicCppGenerator, file_content.toString, Optional.empty)
        }

        override String generateProjectHeader(BasicCppGenerator basicCppGenerator, IModuleStructureStrategy moduleStructureStrategy, 
            InterfaceDeclaration interface_declaration, String export_header)
        {
            val file_content = generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider, 
                basicCppGenerator.paramBundle, interface_declaration
            )

            generateHeader(basicCppGenerator, moduleStructureStrategy, file_content.toString, Optional.of(export_header))
        }
    }
}
