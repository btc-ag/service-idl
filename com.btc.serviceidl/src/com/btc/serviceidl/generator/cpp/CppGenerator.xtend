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

import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.generator.cpp.cmake.CMakeTopLevelProjectFileGenerator
import com.btc.serviceidl.generator.cpp.prins.OdbProjectGenerator
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.google.common.collect.Sets
import java.util.Collection
import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.util.Extensions.*

class CppGenerator
{
    // parameters
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val IScopeProvider scopeProvider
    val IDLSpecification idl
    val IGenerationSettingsProvider generationSettingsProvider
    val Map<String, Set<IProjectReference>> protobufProjectReferences

    val IProjectSet projectSet
    val IModuleStructureStrategy moduleStructureStrategy
    val smartPointerMap = new HashMap<EObject, Collection<EObject>>

    new(IDLSpecification idl, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IScopeProvider scopeProvider, IGenerationSettingsProvider generationSettingsProvider,
        Map<String, Set<ParameterBundle>> protobufProjectReferences)
    {
        this.idl = idl
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.scopeProvider = scopeProvider
        // TODO the protobuf projects must be added to the vsSolution, and converted into IProjectReference
        // this.protobufProjectReferences = pr?.immutableCopy  
        this.protobufProjectReferences = null

        this.projectSet = generationSettingsProvider.projectSetFactory.create
        this.moduleStructureStrategy = generationSettingsProvider.moduleStructureStrategy
        this.generationSettingsProvider = generationSettingsProvider
    }

    def void doGenerate()
    {
        // iterate module by module and generate included content
        for (module : this.idl.modules)
        {
            processModule(module, generationSettingsProvider.projectTypes)

            // only for the top-level modules, produce a parent project file
            if (projectSet instanceof CMakeProjectSet)
            {
                new CMakeTopLevelProjectFileGenerator(fileSystemAccess, generationSettingsProvider,
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
                    projectSet,
                    moduleStructureStrategy,
                    generationSettingsProvider,
                    protobufProjectReferences,
                    smartPointerMap,
                    module
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
                        projectSet,
                        moduleStructureStrategy,
                        generationSettingsProvider,
                        protobufProjectReferences,
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
                        projectSet,
                        moduleStructureStrategy,
                        generationSettingsProvider,
                        protobufProjectReferences,
                        smartPointerMap,
                        module
                    ).generate()
                }
            }

            // generate Protobuf project, if necessary
            // TODO what does this mean?
            if (projectTypes.contains(ProjectType.PROTOBUF) && (module.containsTypes || module.containsInterfaces))
            {
                new ProtobufProjectGenerator(
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    projectSet,
                    moduleStructureStrategy,
                    generationSettingsProvider,
                    protobufProjectReferences,
                    smartPointerMap,
                    module
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
                    projectSet,
                    moduleStructureStrategy,
                    generationSettingsProvider,
                    protobufProjectReferences,
                    smartPointerMap,
                    module
                ).generate()
            }
        }

        // process nested modules
        for (nestedModule : module.nestedModules)
            processModule(nestedModule, projectTypes)
    }

}
