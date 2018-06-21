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
 * \file       JavaGenerator.xtend
 * 
 * \brief      Xtend generator for Java artifacts from an IDL
 */
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.util.Extensions.*

class JavaGenerator
{
    // parameters
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val Map<EObject, String> protobufArtifacts
    val IGenerationSettingsProvider generationSettingsProvider
    val IDLSpecification idl

    new(Resource resource, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IGenerationSettingsProvider generationSettingsProvider, Map<EObject, String> protobufArtifacts)
    {
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.protobufArtifacts = protobufArtifacts
        this.generationSettingsProvider = generationSettingsProvider

        this.idl = resource.contents.filter(IDLSpecification).head // only one IDL root module possible
    }

    def void doGenerate()
    {
        // iterate module by module and generate included content
        for (module : idl.modules)
        {
            processModule(module, generationSettingsProvider.projectTypes)
        }
    }

    private def void processModule(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        if (!module.virtual)
        {
            // generate common data types and exceptions, if available
            if (module.containsTypes)
                generateModuleContents(module, projectTypes)

            // generate proxy/dispatcher projects for all contained interfaces
            if (module.containsInterfaces)
                generateInterfaceProjects(module, projectTypes)
        }

        // process nested modules
        for (nested_module : module.nestedModules)
            processModule(nested_module, projectTypes)
    }

    private def void generateModuleContents(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        new ModuleProjectGenerator(fileSystemAccess, qualifiedNameProvider, generationSettingsProvider,
            protobufArtifacts, idl, module).generate
    }

    private def void generateInterfaceProjects(ModuleDeclaration module, Set<ProjectType> projectTypes)
    {
        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            new InterfaceProjectGenerator(fileSystemAccess, qualifiedNameProvider, generationSettingsProvider,
                protobufArtifacts, idl, interfaceDeclaration).generate
        }
    }

}
