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

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import java.util.Collection
import java.util.Map
import java.util.Optional
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

class LegacyProjectGenerator extends ProjectGeneratorBase
{
    new(Resource resource, IFileSystemAccess file_system_access, IQualifiedNameProvider qualified_name_provider,
        IScopeProvider scope_provider, IDLSpecification idl, IProjectSet vsSolution,
        Map<String, Set<IProjectReference>> protobuf_project_references,
        Map<EObject, Collection<EObject>> smart_pointer_map, ProjectType type, ModuleDeclaration module)
    {
        super(resource, file_system_access, qualified_name_provider, scope_provider, idl, vsSolution,
            protobuf_project_references, smart_pointer_map, type, module, new SourceGenerationStrategy)
    }

    private static class SourceGenerationStrategy implements ISourceGenerationStrategy
    {

        def override String generateProjectSource(BasicCppGenerator basicCppGenerator,
            InterfaceDeclaration interface_declaration)
        {
            val project_type = basicCppGenerator.paramBundle.projectType

            val file_content = switch (project_type)
            {
                case SERVICE_API:
                    generateCppServiceAPI(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case DISPATCHER:
                    generateCppDispatcher(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case IMPL:
                    generateCppImpl(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case PROXY:
                    generateCppProxy(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case TEST:
                    generateCppTest(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                // TODO check that this is generated otherwise
//            case SERVER_RUNNER:
//                generateCppServerRunner(interface_declaration)
                default:
                    /* nothing to do for other project types */
                    throw new IllegalArgumentException("Inapplicable project type:" + project_type)
            }

            val file_tail = '''
                «IF project_type == ProjectType.PROXY || project_type == ProjectType.DISPATCHER || project_type == ProjectType.IMPL»
                    «generateCppReflection(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle, interface_declaration)»
                «ENDIF»
            '''

            generateSource(basicCppGenerator, file_content.toString,
                if (file_tail.trim.empty) Optional.empty else Optional.of(file_tail))
        }

        def override String generateProjectHeader(BasicCppGenerator basicCppGenerator,
            InterfaceDeclaration interface_declaration, String export_header)
        {
            val file_content = switch (basicCppGenerator.paramBundle.projectType)
            {
                case SERVICE_API:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case DISPATCHER:
                    generateHFileDispatcher(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case IMPL:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                case PROXY:
                    generateInterface(basicCppGenerator.typeResolver, basicCppGenerator.paramBundle,
                        interface_declaration)
                default:
                    /* nothing to do for other project types */
                    throw new IllegalArgumentException("Inapplicable project type:" +
                        basicCppGenerator.paramBundle.projectType)
            }

            generateHeader(basicCppGenerator, file_content.toString, Optional.of(export_header))
        }

        def private generateCppServiceAPI(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new ServiceAPIGenerator(typeResolver, paramBundle).generateImplFileBody(interface_declaration)
        }

        def private generateCppProxy(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new ProxyGenerator(typeResolver, paramBundle).generateImplementationFileBody(interface_declaration)
        }

        def private generateCppTest(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new TestGenerator(typeResolver, paramBundle).generateCppTest(interface_declaration)
        }

        def private generateCppDispatcher(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new DispatcherGenerator(typeResolver, paramBundle).generateImplementationFileBody(interface_declaration)
        }

        def private generateHFileDispatcher(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new DispatcherGenerator(typeResolver, paramBundle).generateHeaderFileBody(interface_declaration)
        }

        def private generateCppReflection(TypeResolver typeResolver, ParameterBundle paramBundle,
            InterfaceDeclaration interface_declaration)
        {
            new ReflectionGenerator(typeResolver, paramBundle).generateImplFileBody(interface_declaration)
        }
    }

}
