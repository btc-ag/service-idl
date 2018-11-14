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
import com.btc.serviceidl.generator.common.PackageInfo
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.BasicCppGenerator
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.generator.cpp.ProjectGeneratorBase
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import java.util.Collection
import java.util.Map
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static com.btc.serviceidl.generator.cpp.Util.*

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class OdbProjectGenerator extends ProjectGeneratorBase {

    val boolean usePrinsEncapsulationHeaders

    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider, IScopeProvider scopeProvider,
        IDLSpecification idl, IProjectSetFactory projectSetFactory, IProjectSet vsSolution,
        IModuleStructureStrategy moduleStructureStrategy, ITargetVersionProvider targetVersionProvider,
        Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap, ModuleDeclaration module,
        Iterable<PackageInfo> importedDependencies, boolean usePrinsEncapsulationHeaders)
    {
        super(fileSystemAccess, qualifiedNameProvider, scopeProvider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, smartPointerMap, ProjectType.EXTERNAL_DB_IMPL, module,
            importedDependencies, new OdbSourceGenerationStrategy)

        this.usePrinsEncapsulationHeaders = usePrinsEncapsulationHeaders
    }

   override void generate()
   {
      val allElements = module.moduleComponents
         .filter[e | e.isStruct]
         .map(e | e.structType.ultimateType as StructDeclaration)
         .filter[!members.empty]
         .filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
         .map[val AbstractTypeReference res = it ; res]
         .resolveAllDependencies
         .map[type]
         .filter(StructDeclaration)
      
      // all structs, for which ODB files will be generated; characteristic: 
      // they have a member called "ID" with type UUID
      val id_structs = allElements.filter[!members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty ]
      
      // nothing to do...
      if (id_structs.empty)
      { return }
                  
      // paths
      val odbPath = projectPath + Constants.SEPARATOR_FILE + "odb" + Constants.SEPARATOR_FILE
      
      // collect all commonly used types to include them in an centralized header
      val commonTypes = allElements
         .filter[members.filter[m | m.name.toUpperCase == "ID" && Util.isUUIDType(m.type)].empty]
      if (!commonTypes.empty)
      {
         val basicFileName = Constants.FILE_NAME_ODB_COMMON
         fileSystemAccess.generateFile(odbPath + basicFileName.hxx, ArtifactNature.CPP.label, generateCommonHxx(commonTypes))
         projectFileSet.addToGroup(OdbConstants.ODB_FILE_GROUP, basicFileName)
      }
      for ( struct : id_structs )
      {
         val basicFileName = struct.name.toLowerCase
         fileSystemAccess.generateFile(odbPath + basicFileName.hxx, ArtifactNature.CPP.label, generateHxx(struct))
         projectFileSet.addToGroup(OdbConstants.ODB_FILE_GROUP, basicFileName)
      }
      fileSystemAccess.generateFile(odbPath + Constants.FILE_NAME_ODB_TRAITS.hxx, ArtifactNature.CPP.label, generateODBTraits)
      
      super.generate()
      
      for ( interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
      {
         val basicFileName = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType, interfaceDeclaration.name)
         projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, basicFileName.h)
         projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, basicFileName.cpp)
      }
      
      generateProjectFiles(ProjectType.EXTERNAL_DB_IMPL, projectPath, vsSolution.getVcxprojName(paramBundle), projectFileSet)
   }

   private def String generateCommonHxx(Iterable<StructDeclaration> commonTypes)
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val fileContent = new OdbGenerator(basicCppGenerator.typeResolver).generateCommonHxx(commonTypes).toString      
      makeHxx(basicCppGenerator, fileContent, false)
   }
   
   private def String generateHxx(StructDeclaration struct)
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val fileContent = new OdbGenerator(basicCppGenerator.typeResolver).generateHxx(struct).toString
      var underlyingTypes = getUnderlyingTypes(struct)
      makeHxx(basicCppGenerator, fileContent, !underlyingTypes.empty)
   }
   
   private def String generateODBTraits()
   {
      val basicCppGenerator = createBasicCppGenerator
      
      val fileContent = new OdbGenerator(basicCppGenerator.typeResolver).generateODBTraitsBody()
      
      makeHxx(basicCppGenerator, fileContent.toString, false)
   }
   
   private def String makeHxx(BasicCppGenerator basicCppGenerator, String fileContent, boolean useCommonTypes)
   {
      '''
      #pragma once

      «IF usePrinsEncapsulationHeaders»
      #include "modules/Commons/include/BeginPrinsModulesInclude.h"
      «ENDIF»

      «IF useCommonTypes»#include "«Constants.FILE_NAME_ODB_COMMON.hxx»"«ENDIF»
      «basicCppGenerator.generateIncludes(true)»
      «fileContent»

      «IF usePrinsEncapsulationHeaders»
      #include "modules/Commons/include/EndPrinsModulesInclude.h"
      «ENDIF»
      '''
   }

   private static class OdbSourceGenerationStrategy implements ISourceGenerationStrategy
    {
        override String generateProjectSource(BasicCppGenerator basicCppGenerator, InterfaceDeclaration interfaceDeclaration)
        {
            val fileContent = generateCppImpl(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider, 
                basicCppGenerator.paramBundle, interfaceDeclaration
            )

            generateSource(basicCppGenerator, fileContent.toString, Optional.empty)
        }

        override String generateProjectHeader(BasicCppGenerator basicCppGenerator, IModuleStructureStrategy moduleStructureStrategy, 
            InterfaceDeclaration interfaceDeclaration, String exportHeader)
        {
            val fileContent = generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.targetVersionProvider, 
                basicCppGenerator.paramBundle, interfaceDeclaration
            )

            generateHeader(basicCppGenerator, moduleStructureStrategy, fileContent.toString, Optional.of(exportHeader))
        }
    }
}
