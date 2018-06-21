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
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.cmake.CMakeProjectSet
import com.btc.serviceidl.generator.cpp.cmake.CMakeTopLevelProjectFileGenerator
import com.btc.serviceidl.generator.cpp.prins.OdbProjectGenerator
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.ModuleDeclaration
import com.google.common.collect.Sets
import java.util.Arrays
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.util.Extensions.*
import com.btc.serviceidl.generator.ITargetVersionProvider

class CppGenerator
{
    // parameters
    var Resource resource
    var IFileSystemAccess fileSystemAccess
    var IQualifiedNameProvider qualifiedNameProvider
    var IScopeProvider scopeProvider
    var IDLSpecification idl
    var ITargetVersionProvider targetVersionProvider
    var protobufProjectReferences = new HashMap<String, Set<IProjectReference>>

    var IProjectSet projectSet
    var IModuleStructureStrategy moduleStructureStrategy
    val smartPointerMap = new HashMap<EObject, Collection<EObject>>

    def void doGenerate(Resource resource, IFileSystemAccess fileSystemAccess,
        IQualifiedNameProvider qualifiedNameProvider, IScopeProvider scopeProvider,
        IGenerationSettingsProvider generationSettingsProvider,
        Map<String, HashMap<String, String>> protobufProjectReferences)
    {
        this.resource = resource
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.scopeProvider = scopeProvider
        // TODO the protobuf projects must be added to the vsSolution, and converted into IProjectReference 
        this.protobufProjectReferences = /*if (pr !== null) new HashMap<String, Set<IProjectReference>>(pr) else */ null

        this.idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
        if (this.idl === null)
        {
            return
        }

        this.projectSet = generationSettingsProvider.projectSetFactory.create
        this.moduleStructureStrategy = generationSettingsProvider.moduleStructureStrategy
        this.targetVersionProvider = generationSettingsProvider

        // iterate module by module and generate included content
        for (module : this.idl.modules)
        {
            processModule(module, generationSettingsProvider.projectTypes)

            // only for the top-level modules, produce a parent project file
            if (projectSet instanceof CMakeProjectSet)
            {
                new CMakeTopLevelProjectFileGenerator(fileSystemAccess, generationSettingsProvider, projectSet,
                    module).generate()
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
                    resource,
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    projectSet,
                    moduleStructureStrategy,
                    targetVersionProvider,
                    protobufProjectReferences,
                    smartPointerMap,
                    module
                ).generate()

            }

            // generate proxy/dispatcher projects for all contained interfaces
            if (module.containsInterfaces)
            {
                for (projectType : Sets.intersection(projectTypes, new HashSet<ProjectType>(Arrays.asList(
                    ProjectType.SERVICE_API,
                    ProjectType.IMPL,
                    ProjectType.PROXY,
                    ProjectType.DISPATCHER,
                    ProjectType.TEST
                ))))
                {
                    new LegacyProjectGenerator(
                        resource,
                        fileSystemAccess,
                        qualifiedNameProvider,
                        scopeProvider,
                        idl,
                        projectSet,
                        moduleStructureStrategy,
                        targetVersionProvider,
                        protobufProjectReferences,
                        smartPointerMap,
                        projectType,
                        module
                    ).generate()
                }

                if (projectTypes.contains(ProjectType.SERVER_RUNNER))
                {
                    new ServerRunnerProjectGenerator(
                        resource,
                        fileSystemAccess,
                        qualifiedNameProvider,
                        scopeProvider,
                        idl,
                        projectSet,
                        moduleStructureStrategy,
                        targetVersionProvider,
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
                    resource,
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    projectSet,
                    moduleStructureStrategy,
                    targetVersionProvider,
                    protobufProjectReferences,
                    smartPointerMap,
                    module
                ).generate()
            }

            if (projectTypes.contains(ProjectType.EXTERNAL_DB_IMPL) && module.containsTypes &&
                module.containsInterfaces)
            {
                new OdbProjectGenerator(
                    resource,
                    fileSystemAccess,
                    qualifiedNameProvider,
                    scopeProvider,
                    idl,
                    projectSet,
                    moduleStructureStrategy,
                    targetVersionProvider,
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
