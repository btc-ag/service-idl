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
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.Map
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

@Accessors(PROTECTED_GETTER)
class CommonProjectGenerator extends ProjectGeneratorBaseBase
{

    new(IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IDLSpecification idl, IProjectSetFactory projectSetFactory,
        IProjectSet vsSolution, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider,
        Map<AbstractTypeReference, Collection<AbstractTypeReference>> smartPointerMap, ModuleDeclaration module)
    {
        super(fileSystemAccess, qualifiedNameProvider, scopeProvider, idl, projectSetFactory, vsSolution,
            moduleStructureStrategy, targetVersionProvider, smartPointerMap,
            ProjectType.COMMON, module)
    }

    // TODO this is largely a clone of ProjectGeneratorBase.generateProjectStructure
    def generate()
    {
        // paths
        val includePath = projectPath.append("include")
        val sourcePath = projectPath.append(moduleStructureStrategy.sourceFileDir)

        // file names
        val exportHeaderFileName = (GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase
        val headerFile = Constants.FILE_NAME_TYPES.h
        val cppFile = Constants.FILE_NAME_TYPES.cpp

        // include sub-folder
        fileSystemAccess.generateFile(includePath.append(exportHeaderFileName).toString, ArtifactNature.CPP.label,
            generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, exportHeaderFileName)

        fileSystemAccess.generateFile(includePath.append(headerFile).toString, ArtifactNature.CPP.label,
            generateHFileCommons(module, exportHeaderFileName))
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, headerFile)

        // source sub-folder
        fileSystemAccess.generateFile(sourcePath.append(cppFile).toString, ArtifactNature.CPP.label,
            generateCppCommons(module, exportHeaderFileName))
        projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, cppFile)

        generateProjectFiles(ProjectType.COMMON, projectPath, vsSolution.getVcxprojName(paramBundle), projectFileSet)
    }

    private def String generateHFileCommons(ModuleDeclaration module, String exportHeader)
    {
        val basicCppGenerator = createBasicCppGenerator
        val fileContent = new CommonsGenerator(basicCppGenerator.typeResolver, targetVersionProvider, paramBundle).
            generateHeaderFileBody(module, exportHeader)
        generateHeader(basicCppGenerator, moduleStructureStrategy, fileContent.toString, Optional.of(exportHeader))
    }

    private def String generateCppCommons(ModuleDeclaration module, String exportHeader)
    {
        val basicCppGenerator = createBasicCppGenerator
        val fileContent = new CommonsGenerator(basicCppGenerator.typeResolver, targetVersionProvider, paramBundle).
            generateImplFileBody(module, exportHeader)
        generateSource(basicCppGenerator, fileContent.toString, Optional.empty)
    }

}
