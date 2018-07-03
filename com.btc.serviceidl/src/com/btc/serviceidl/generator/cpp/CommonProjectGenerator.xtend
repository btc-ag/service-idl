/**
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors(PROTECTED_GETTER)
class CommonProjectGenerator extends ProjectGeneratorBaseBase
{

    new(IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSetFactory projectSetFactory,
        IProjectSet vsSolution, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider, Map<String, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ModuleDeclaration module)
    {
        super(file_system_access, qualified_name_provider, scope_provider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, protobuf_project_references, smart_pointer_map,
            ProjectType.COMMON, module)
    }

    // TODO this is largely a clone of ProjectGeneratorBase.generateProjectStructure
    def generate()
    {
        // paths
        val include_path = projectPath.append("include")
        val source_path = projectPath.append("source")

        // file names
        val export_header_file_name = (GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase
        val header_file = Constants.FILE_NAME_TYPES.h
        val cpp_file = Constants.FILE_NAME_TYPES.cpp

        // sub-folder "./include"
        file_system_access.generateFile(include_path.append(export_header_file_name).toString, ArtifactNature.CPP.label,
            generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, export_header_file_name)

        file_system_access.generateFile(include_path.append(header_file).toString, ArtifactNature.CPP.label,
            generateHFileCommons(module, export_header_file_name))
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, header_file)

        // sub-folder "./source"
        file_system_access.generateFile(source_path.append(cpp_file).toString, ArtifactNature.CPP.label,
            generateCppCommons(module, export_header_file_name))
        projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, cpp_file)

        generateProjectFiles(ProjectType.COMMON, projectPath, vsSolution.getVcxprojName(param_bundle), projectFileSet)
    }

    private def String generateHFileCommons(ModuleDeclaration module, String export_header)
    {
        val basicCppGenerator = createBasicCppGenerator
        val file_content = new CommonsGenerator(basicCppGenerator.typeResolver, targetVersionProvider, param_bundle).
            generateHeaderFileBody(module, export_header)
        generateHeader(basicCppGenerator, moduleStructureStrategy, file_content.toString, Optional.of(export_header))
    }

    private def String generateCppCommons(ModuleDeclaration module, String export_header)
    {
        val basicCppGenerator = createBasicCppGenerator
        val file_content = new CommonsGenerator(basicCppGenerator.typeResolver, targetVersionProvider, param_bundle).
            generateImplFileBody(module, export_header)
        generateSource(basicCppGenerator, file_content.toString, Optional.empty)
    }

}
