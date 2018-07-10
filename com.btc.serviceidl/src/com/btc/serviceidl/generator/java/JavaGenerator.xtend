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

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.util.Extensions.*

class JavaGenerator
{
    // parameters
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val Map<EObject, String> protobufArtifacts
    val IGenerationSettings generationSettings
    val IDLSpecification idl
    val String groupId
    val MavenResolver mavenResolver

    new(IDLSpecification idl, IFileSystemAccess fileSystemAccess, IQualifiedNameProvider qualifiedNameProvider,
        IGenerationSettings generationSettings, Map<EObject, String> protobufArtifacts)
    {
        this.idl = idl
        this.fileSystemAccess = fileSystemAccess
        this.qualifiedNameProvider = qualifiedNameProvider
        this.protobufArtifacts = protobufArtifacts
        this.generationSettings = generationSettings
        this.groupId = this.idl.eResource.URI.lastSegment // TODO this must be customizable
        mavenResolver = new MavenResolver(groupId)
    }

    def void doGenerate()
    {
        // iterate module by module and generate included content
        for (module : idl.modules)
        {
            processModule(module)
        }

        generateParentPOM
    }

    private def void generateParentPOM()
    {
        new ParentPOMGenerator(fileSystemAccess, mavenResolver, groupId).generate
    }

    private def void processModule(ModuleDeclaration module)
    {
        if (!module.virtual)
        {
            // generate common data types and exceptions, if available
            if (module.containsTypes)
                generateModuleContents(module)

            // generate proxy/dispatcher projects for all contained interfaces
            generateInterfaceProjects(module)
        }

        // process nested modules
        for (nestedModule : module.nestedModules)
            processModule(nestedModule)
    }

    private def void generateModuleContents(ModuleDeclaration module)
    {
        new ModuleProjectGenerator(fileSystemAccess, qualifiedNameProvider, generationSettings, protobufArtifacts, idl,
            mavenResolver, module).generate
    }

    private def void generateInterfaceProjects(ModuleDeclaration module)
    {
        for (interfaceDeclaration : module.moduleComponents.filter(InterfaceDeclaration))
        {
            new InterfaceProjectGenerator(fileSystemAccess, qualifiedNameProvider, generationSettings,
                protobufArtifacts, idl, mavenResolver, interfaceDeclaration).generate
        }
    }

}
