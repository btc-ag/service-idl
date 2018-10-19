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
 * \file       CppGenerator.xtend
 * 
 * \brief      Xtend generator for C++ artifacts from an IDL
 */
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet.ProjectReference
import com.btc.serviceidl.generator.cpp.cmake.CMakeTopLevelProjectFileGenerator
import com.btc.serviceidl.generator.cpp.prins.OdbProjectGenerator
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.google.common.collect.Sets
import java.util.Collection
import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class CppGenerator
{
    // parameters
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val IScopeProvider scopeProvider
    val IDLSpecification idl
    val IGenerationSettings generationSettings
    val Map<IProjectReference, Set<IProjectReference>> protobufProjectReferences

    val IProjectSet projectSet
    val IModuleStructureStrategy moduleStructureStrategy
    val smartPointerMap = new HashMap<AbstractTypeReference, Collection<AbstractTypeReference>>

    new(IDLSpecification idl, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IGenerationSettings generationSettings,
        Map<ParameterBundle, Set<ParameterBundle>> protobufProjectReferences)
    {
        this.idl = idl
        this.fileSystemAccess = fileSystemAccess
    this.qualifiedNameProvider = qualifiedNameProvider
    this.scopeProvider = scopeProvider

    this.projectSet = generationSettings.projectSetFactory.create
    this.protobufProjectReferences = protobufProjectReferences?.entrySet?.toMap([projectSet.resolve(it.key)], [
        value.map[projectSet.resolve(it)].toSet
    ])
    this.moduleStructureStrategy = generationSettings.moduleStructureStrategy
    this.generationSettings = generationSettings
}

    def void doGenerate()
    {
        // iterate module by module and generate included content
        for (module : this.idl.modules)
        {
            processModule(module, generationSettings.projectTypes)

            // only for the top-level modules, produce a parent project file
            if (projectSet instanceof CMakeProjectSet)
            {
                new CMakeTopLevelProjectFileGenerator(fileSystemAccess, generationSettings,
                    projectSet, module).generate()
            }
        }
    }

    private def void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        if (!module.virtual)
        {
            // generate common data types and exceptions, if available
            if (projectTypes.contains(ProjectType.COMMON) && module.containsTypes)
            {
                new CommonProjectGenerator(
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    generationSettings.projectSetFactory,
                    projectSet,
                    moduleStructureStrategy,
                    generationSettings,
                    smartPointerMap,
                    module,
                    generationSettings.dependencies
                ).generate()

            }

            // generate proxy/dispatcher projects for all contained interfaces
            if (module.containsInterfaces)
            {
                for (projectType : Sets.intersection(projectTypes, #{
                    ProjectType.SERVICE_API,
                    ProjectType.IMPL,
                    ProjectType.PROXY,
                    ProjectType.DISPATCHER,
                    ProjectType.TEST
                }))
                {
                    new LegacyProjectGenerator(
                        fileSystemAccess,
                        qualifiedNameProvider,
                        scopeProvider,
                        idl,
                        generationSettings.projectSetFactory,
                        projectSet,
                        moduleStructureStrategy,
                        generationSettings,
                        smartPointerMap,
                        projectType,
                        module
                    ).generate()
                }

                if (projectTypes.contains(ProjectType.SERVER_RUNNER))
                {
                    new ServerRunnerProjectGenerator(
                        fileSystemAccess,
                        qualifiedNameProvider,
                        scopeProvider,
                        idl,
                        generationSettings.projectSetFactory,
                        projectSet,
                        moduleStructureStrategy,
                        generationSettings,
                        smartPointerMap,
                        module,
                        generationSettings.dependencies
                    ).generate()
                }
            }

            // generate Protobuf project, if necessary
            // TODO what does this mean?
            if (projectTypes.contains(ProjectType.PROTOBUF) && (module.containsTypes || module.containsInterfaces))
            {
                val currentProjectReference = new ProjectReference(
                    GeneratorUtil.getTransformedModuleName(
                        new ParameterBundle.Builder().with(module.moduleStack).with(ProjectType.PROTOBUF).build,
                        ArtifactNature.CPP, TransformType.PACKAGE), module.eResource.URI)

                new ProtobufProjectGenerator(
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    generationSettings.projectSetFactory,
                    projectSet,
                    moduleStructureStrategy,
                    generationSettings,
                    protobufProjectReferences.get(currentProjectReference),
                    smartPointerMap,
                    module,
                    generationSettings.dependencies
                ).generate()
            }

            if (projectTypes.contains(ProjectType.EXTERNAL_DB_IMPL) && module.containsTypes &&
                module.containsInterfaces)
            {
                new OdbProjectGenerator(
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    generationSettings.projectSetFactory,
                    projectSet,
                    moduleStructureStrategy,
                    generationSettings,
                    smartPointerMap,
                    module,
                    generationSettings.dependencies
                ).generate()
            }
        }

        // process nested modules
        for (nestedModule : module.nestedModules)
            processModule(nestedModule, projectTypes)
    }

}
