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

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.core.runtime.IPath
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PROTECTED_GETTER)
abstract class ProjectGeneratorBase extends ProjectGeneratorBaseBase
{
    // TODO align the method signatures: either both should be passed a BasicCppGenerator or none, the order of parameters should also be aligned
    interface ISourceGenerationStrategy
    {
        def String generateProjectSource(BasicCppGenerator basicCppGenerator,
            InterfaceDeclaration interfaceDeclaration)

        def String generateProjectHeader(BasicCppGenerator basicCppGenerator,
            IModuleStructureStrategy moduleStructureStrategy, InterfaceDeclaration interfaceDeclaration,
            String exportHeader)
    }

    val ISourceGenerationStrategy sourceGenerationStrategy

    protected def void generate()
    {
        // TODO check how to reflect this special handling of EXTERNAL_DB_IMPL
//        if (projectType != ProjectType.EXTERNAL_DB_IMPL) // for ExternalDBImpl, keep both C++ and ODB artifacts
//            reinitializeProject(projectType)
        val exportHeaderFileName = (GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP,
            TransformType.EXPORT_HEADER) + "_export".h).toLowerCase
        fileSystemAccess.generateFile(projectPath.append("include").append(exportHeaderFileName).toString,
            ArtifactNature.CPP.label, generateExportHeader())
        projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, exportHeaderFileName)

        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            generateProject(paramBundle.projectType, interfaceDeclaration, projectPath, exportHeaderFileName)
        }

        if (paramBundle.projectType != ProjectType.EXTERNAL_DB_IMPL) // done separately for ExternalDBImpl to include ODB files also
        {
            generateProjectFiles(paramBundle.projectType, projectPath, vsSolution.getVcxprojName(paramBundle),
                projectFileSet)
        }
    }

    private def void generateProject(ProjectType pt, InterfaceDeclaration interfaceDeclaration, IPath projectPath,
        String exportHeaderFileName)
    {
        val builder = new ParameterBundle.Builder(paramBundle)
        builder.with(interfaceDeclaration.moduleStack)
        val localParamBundle = builder.build

        // paths
        val includePath = projectPath.append("include")
        val sourcePath = projectPath.append("source")

        // file names
        val mainHeaderFileName = GeneratorUtil.getClassName(ArtifactNature.CPP, localParamBundle.projectType,
            interfaceDeclaration.name).h
        val mainCppFileName = GeneratorUtil.getClassName(ArtifactNature.CPP, localParamBundle.projectType,
            interfaceDeclaration.name).cpp

        // sub-folder "./include"
        if (pt != ProjectType.TEST)
        {
            fileSystemAccess.generateFile(includePath.append(mainHeaderFileName).toString,
                ArtifactNature.CPP.label,
                sourceGenerationStrategy.generateProjectHeader(createBasicCppGenerator(localParamBundle),
                    moduleStructureStrategy, interfaceDeclaration, exportHeaderFileName))
            projectFileSet.addToGroup(ProjectFileSet.HEADER_FILE_GROUP, mainHeaderFileName)
        }

        // sub-folder "./source"
        fileSystemAccess.generateFile(sourcePath.append(mainCppFileName).toString, ArtifactNature.CPP.label,
            sourceGenerationStrategy.generateProjectSource(createBasicCppGenerator(localParamBundle),
                interfaceDeclaration))
        projectFileSet.addToGroup(ProjectFileSet.CPP_FILE_GROUP, mainCppFileName)
    }

    // TODO move this somewhere else
    protected static def generateCppImpl(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
        ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
    {
        new ImplementationStubGenerator(typeResolver, targetVersionProvider, paramBundle).generateCppImpl(
            interfaceDeclaration)
    }

    // TODO move this somewhere else
    protected static def generateInterface(TypeResolver typeResolver, ITargetVersionProvider targetVersionProvider,
        ParameterBundle paramBundle, InterfaceDeclaration interfaceDeclaration)
    {
        new ServiceAPIGenerator(typeResolver, targetVersionProvider, paramBundle).
            generateHeaderFileBody(interfaceDeclaration)
    }

}
