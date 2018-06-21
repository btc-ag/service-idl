/*
 * generated by Xtext
 */
package com.btc.serviceidl.generator

import org.eclipse.emf.ecore.resource.Resource
import com.google.inject.Inject
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.idl.EventDeclaration
import org.eclipse.emf.ecore.EObject
import java.util.UUID
import java.util.Map
import java.util.Collections
import com.btc.serviceidl.generator.common.ArtifactNature
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import com.btc.serviceidl.generator.protobuf.ProtobufGenerator
import com.btc.serviceidl.generator.cpp.CppGenerator
import com.btc.serviceidl.generator.java.JavaGenerator
import com.btc.serviceidl.generator.dotnet.DotNetGenerator
import com.btc.serviceidl.generator.common.ProjectType
import org.eclipse.xtext.generator.AbstractFileSystemAccess

/**
 * Generates code from your model files on save.
 * 
 * see http://www.eclipse.org/Xtext/documentation.html#TutorialCodeGeneration
 */
class IdlGenerator implements IGenerator2
{

    @Inject extension IQualifiedNameProvider qualified_name_provider
    @Inject extension IScopeProvider scope_provider
    @Inject IGenerationSettingsProvider generation_settings_provider

    override doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext gc)
    {
        // generate GUIDs: common among C++, Java and .NET!
        var boolean resourceChanged = false;
        for (interface_declaration : resource.allContents.toIterable.filter(InterfaceDeclaration))
        {
            if (interface_declaration.guid === null)
            {
                val uuid = UUID.randomUUID.toString.toUpperCase
                GuidMapper.put(interface_declaration, uuid)
                interface_declaration.guid = uuid
                resourceChanged = true
            }
            else
                GuidMapper.put(interface_declaration, interface_declaration.guid.toUpperCase)
        }
        for (event : resource.allContents.toIterable.filter(EventDeclaration))
        {
            if (event.guid === null)
            {
                val uuid = UUID.randomUUID.toString.toUpperCase
                GuidMapper.put(event.data, uuid)
                event.guid = uuid
                resourceChanged = true
            }
            else
                GuidMapper.put(event.data, event.guid.toUpperCase)
        }
        if (resourceChanged)
        {
            resource.save(Collections.EMPTY_MAP)
        }

        val projectTypes = generation_settings_provider.projectTypes
        val languages = generation_settings_provider.languages

// TODO REFACTOR invert these dependencies
        var ProtobufGenerator protobuf_generator
        var Map<EObject, String> protobuf_artifacts
        if (projectTypes.contains(ProjectType.PROTOBUF))
        {
            protobuf_generator = new ProtobufGenerator
            protobuf_generator.doGenerate(resource, fsa, qualified_name_provider, scope_provider, languages)
            protobuf_artifacts = protobuf_generator.generatedArtifacts
        }

        // TODO workaround for generation from within editor, for a proper solution see https://stackoverflow.com/a/10396957
        if (fsa instanceof AbstractFileSystemAccess)
        {
            for (artifactNature : languages)
            {
                try
                {
                    fsa.getURI("", artifactNature.label)
                }
                catch (IllegalArgumentException e)
                {
                    fsa.setOutputPath(
                        artifactNature.label,
                        fsa.getURI("").appendSegment(artifactNature.label).toFileString
                    )
                }
            }
        }

        if (languages.contains(ArtifactNature.CPP))
        {
            val cpp_generator = new CppGenerator(resource, fsa, qualified_name_provider, scope_provider,
                generation_settings_provider,
                if (protobuf_generator !== null) protobuf_generator.getProjectReferences(ArtifactNature.CPP) else null)
            cpp_generator.doGenerate
        }

        if (languages.contains(ArtifactNature.JAVA))
        {
            val java_generator = new JavaGenerator(resource, fsa, qualified_name_provider, scope_provider,
                generation_settings_provider, protobuf_artifacts)
            java_generator.doGenerate
        }

        if (languages.contains(ArtifactNature.DOTNET))
        {
            val dotnet_generator = new DotNetGenerator
            dotnet_generator.doGenerate(resource, fsa, qualified_name_provider, scope_provider, projectTypes,
                if (protobuf_generator !== null)
                    protobuf_generator.getProjectReferences(ArtifactNature.DOTNET)
                else
                    null)
        }
    }

    override afterGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context)
    {
    }

    override beforeGenerate(Resource input, IFileSystemAccess2 fsa, IGeneratorContext context)
    {
    }

}
