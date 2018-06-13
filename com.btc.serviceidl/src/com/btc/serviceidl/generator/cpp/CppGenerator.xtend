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
    // global variables
    private var Resource resource
    private var IFileSystemAccess file_system_access
    private var IQualifiedNameProvider qualified_name_provider
    private var IScopeProvider scope_provider
    private var IDLSpecification idl

    var extension IProjectSet vsSolution
    var IModuleStructureStrategy moduleStructureStrategy

    private var protobuf_project_references = new HashMap<String, Set<IProjectReference>>

    val smart_pointer_map = new HashMap<EObject, Collection<EObject>>

    var ITargetVersionProvider targetVersionProvider

    def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp,
        IGenerationSettingsProvider generationSettingsProvider, Map<String, HashMap<String, String>> pr)
    {
        resource = res
        file_system_access = fsa
        qualified_name_provider = qnp
        scope_provider = sp
        // TODO the protobuf projects must be added to the vsSolution, and converted into IProjectReference 
        protobuf_project_references = /*if (pr !== null) new HashMap<String, Set<IProjectReference>>(pr) else */ null

        idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
        if (idl === null)
        {
            return
        }

        vsSolution = generationSettingsProvider.projectSetFactory.create
        moduleStructureStrategy = generationSettingsProvider.moduleStructureStrategy
        targetVersionProvider = generationSettingsProvider

        // iterate module by module and generate included content
        for (module : idl.modules)
        {
            processModule(module, generationSettingsProvider.projectTypes)

            // only for the top-level modules, produce a parent project file
            if (vsSolution instanceof CMakeProjectSet)
            {
                new CMakeTopLevelProjectFileGenerator(file_system_access, generationSettingsProvider, vsSolution,
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
                    file_system_access,
                    qualified_name_provider,
                    scope_provider,
                    idl,
                    vsSolution,
                    moduleStructureStrategy,
                    targetVersionProvider,
                    protobuf_project_references,
                    smart_pointer_map,
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
                        file_system_access,
                        qualified_name_provider,
                        scope_provider,
                        idl,
                        vsSolution,
                        moduleStructureStrategy,
                        targetVersionProvider,
                        protobuf_project_references,
                        smart_pointer_map,
                        projectType,
                        module
                    ).generate()
                }

                if (projectTypes.contains(ProjectType.SERVER_RUNNER))
                {
                    new ServerRunnerProjectGenerator(
                        resource,
                        file_system_access,
                        qualified_name_provider,
                        scope_provider,
                        idl,
                        vsSolution,
                        moduleStructureStrategy,
                        targetVersionProvider,
                        protobuf_project_references,
                        smart_pointer_map,
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
                    file_system_access,
                    qualified_name_provider,
                    scope_provider,
                    idl,
                    vsSolution,
                    moduleStructureStrategy,
                    targetVersionProvider,
                    protobuf_project_references,
                    smart_pointer_map,
                    module
                ).generate()
            }

            if (projectTypes.contains(ProjectType.EXTERNAL_DB_IMPL) && module.containsTypes &&
                module.containsInterfaces)
            {
                new OdbProjectGenerator(
                    resource,
                    file_system_access,
                    qualified_name_provider,
                    scope_provider,
                    idl,
                    vsSolution,
                    moduleStructureStrategy,
                    targetVersionProvider,
                    protobuf_project_references,
                    smart_pointer_map,
                    module
                ).generate()
            }
        }

        // process nested modules
        for (nested_module : module.nestedModules)
            processModule(nested_module, projectTypes)
    }

}
