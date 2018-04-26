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

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.InterfaceDeclaration
import java.util.Optional
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class LegacyProjectGenerator extends ProjectGeneratorBase
{
    def override String generateProjectSource(InterfaceDeclaration interface_declaration)
    {
        val basicCppGenerator = createBasicCppGenerator
        val project_type = param_bundle.projectType

        val file_content = switch (project_type)
        {
            case SERVICE_API:
                generateCppServiceAPI(basicCppGenerator.typeResolver, interface_declaration)
            case DISPATCHER:
                generateCppDispatcher(basicCppGenerator.typeResolver, interface_declaration)
            case IMPL:
                generateCppImpl(basicCppGenerator.typeResolver, interface_declaration)
            case PROXY:
                generateCppProxy(basicCppGenerator.typeResolver, interface_declaration)
            case TEST:
                generateCppTest(basicCppGenerator.typeResolver, interface_declaration)
            // TODO check that this is generated otherwise
//            case SERVER_RUNNER:
//                generateCppServerRunner(interface_declaration)
            default:
                /* nothing to do for other project types */
                throw new IllegalArgumentException("Inapplicable project type:" + project_type)
        }

        val file_tail = '''
            «IF project_type == ProjectType.PROXY || project_type == ProjectType.DISPATCHER || project_type == ProjectType.IMPL»
                «generateCppReflection(basicCppGenerator.typeResolver, interface_declaration)»
            «ENDIF»
        '''

        generateSource(basicCppGenerator, file_content.toString,
            if (file_tail.trim.empty) Optional.empty else Optional.of(file_tail))
    }

    def override String generateProjectHeader(BasicCppGenerator basicCppGenerator, String export_header,
        InterfaceDeclaration interface_declaration)
    {
        val file_content = switch (param_bundle.projectType)
        {
            case SERVICE_API:
                generateInterface(basicCppGenerator.typeResolver, interface_declaration)
            case DISPATCHER:
                generateHFileDispatcher(basicCppGenerator.typeResolver, interface_declaration)
            case IMPL:
                generateInterface(basicCppGenerator.typeResolver, interface_declaration)
            case PROXY:
                generateInterface(basicCppGenerator.typeResolver, interface_declaration)
            default:
                /* nothing to do for other project types */
                throw new IllegalArgumentException("Inapplicable project type:" + param_bundle.projectType)
        }

        generateHeader(basicCppGenerator, file_content.toString, Optional.of(export_header))
    }

    def private generateCppServiceAPI(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new ServiceAPIGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
    }

    def private generateCppProxy(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new ProxyGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration)
    }

    def private generateCppTest(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new TestGenerator(typeResolver, param_bundle, idl).generateCppTest(interface_declaration)
    }

    def private generateCppDispatcher(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new DispatcherGenerator(typeResolver, param_bundle, idl).generateImplementationFileBody(interface_declaration)
    }

    def private generateHFileDispatcher(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new DispatcherGenerator(typeResolver, param_bundle, idl).generateHeaderFileBody(interface_declaration)
    }

    def private generateCppReflection(TypeResolver typeResolver, InterfaceDeclaration interface_declaration)
    {
        new ReflectionGenerator(typeResolver, param_bundle, idl).generateImplFileBody(interface_declaration)
    }

}
