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
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import java.util.Map
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

import static extension com.btc.serviceidl.generator.common.Extensions.*

@Accessors(PACKAGE_GETTER)
class TypeResolver
{
    private val DotNetFrameworkVersion frameworkVersion
    private val IQualifiedNameProvider qualified_name_provider
    private val Set<String> namespace_references
    private val Set<String> referenced_assemblies
    private val Map<String, String> project_references
    private val VSSolution vsSolution
    private val ParameterBundle param_bundle

    def ResolvedName resolve(String name)
    {
        val effective_name = resolveException(name) ?: name
        val fully_qualified_name = QualifiedName.create(
            effective_name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))
        val namespace = fully_qualified_name.skipLast(1).toString

        if (namespace.startsWith("System"))
            referenced_assemblies.add(DotNetAssemblies.getAssemblyForNamespace(namespace, frameworkVersion))
        else
            referenced_assemblies.add(AssemblyResolver.resolveReference(namespace))

        namespace_references.add(namespace)
        return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, false)
    }

    def ResolvedName resolve(EObject element)
    {
        return resolve(element, element.mainProjectType)
    }

    def ResolvedName resolve(EObject element, ProjectType project_type)
    {
        var name = qualified_name_provider.getFullyQualifiedName(element)
        val fully_qualified = true

        if (name === null)
        {
            if (element instanceof AbstractType)
            {
                if (element.primitiveType !== null)
                {
                    return resolve(element.primitiveType, project_type)
                }
                else if (element.referenceType !== null)
                {
                    return resolve(element.referenceType, if (project_type != ProjectType.PROTOBUF)
                        element.referenceType.mainProjectType
                    else
                        project_type)
                }
            }
            else if (element instanceof PrimitiveType)
            {
                if (element.uuidType !== null)
                {
                    if (project_type == ProjectType.PROTOBUF)
                        return resolve("Google.ProtocolBuffers")
                    else
                        return resolve("System.Guid")
                }
                else
                    return new ResolvedName(primitiveTypeName(element), TransformType.PACKAGE, fully_qualified)
            }
            return new ResolvedName(Names.plain(element), TransformType.PACKAGE, fully_qualified)
        }

        var result = GeneratorUtil.transform(
            ParameterBundle.createBuilder(
                com.btc.serviceidl.util.Util.getModuleStack(com.btc.serviceidl.util.Util.getScopeDeterminant(element))).
                with(project_type).build, ArtifactNature.DOTNET, TransformType.PACKAGE)
        result += Constants.SEPARATOR_PACKAGE + if (element instanceof InterfaceDeclaration)
            project_type.getClassName(ArtifactNature.DOTNET, name.lastSegment)
        else
            name.lastSegment

        val package_name = QualifiedName.create(result.split(Pattern.quote(Constants.SEPARATOR_PACKAGE))).skipLast(1)
        if (!isSameProject(package_name))
        {
            // just use namespace, no assembly required - project reference will be used instead!
            namespace_references.add(package_name.toString)
            element.resolveProjectFilePath(project_type)
        }

        return new ResolvedName(result, TransformType.PACKAGE, fully_qualified)
    }

    def private static String resolveException(String name)
    {
        // temporarily some special handling for exceptions, because not all
        // C++ CAB exceptions are supported by the .NET CAB
        switch (name)
        {
            case "BTC.Commons.Core.InvalidArgumentException":
                return "System.ArgumentException"
            default:
                return null
        }
    }

    def private boolean isSameProject(QualifiedName referenced_package)
    {
        GeneratorUtil.transform(param_bundle, ArtifactNature.DOTNET, TransformType.PACKAGE) ==
            referenced_package.toString
    }

    def void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
    {
        val module_stack = com.btc.serviceidl.util.Util.getModuleStack(referenced_object)
        var project_path = ""

        val temp_param = new ParameterBundle.Builder()
        temp_param.reset(module_stack)
        temp_param.reset(project_type)

        val project_name = vsSolution.getCsprojName(temp_param.build)

        if (module_stack.elementsEqual(param_bundle.moduleStack))
        {
            project_path = "../" + project_type.getName + "/" + project_name
        }
        else
        {
            project_path = "../" + GeneratorUtil.getRelativePathsUpwards(param_bundle) +
                GeneratorUtil.transform(temp_param.build, ArtifactNature.DOTNET, TransformType.FILE_SYSTEM) + "/" +
                project_name
        }

        project_references.put(project_name, project_path)
    }

    def primitiveTypeName(PrimitiveType element)
    {
        if (element.integerType !== null)
        {
            switch element.integerType
            {
                case "int64":
                    return "long"
                case "int32":
                    return "int"
                case "int16":
                    return "short"
                case "byte":
                    return "byte"
            }
        }
        else if (element.stringType !== null)
            return "string"
        else if (element.floatingPointType !== null)
        {
            switch element.floatingPointType
            {
                case "double":
                    return "double"
                case "float":
                    return "float"
            }
        }
        else if (element.uuidType !== null)
        {
            return resolve("System.Guid").fullyQualifiedName
        }
        else if (element.booleanType !== null)
            return "bool"
        else if (element.charType !== null)
            return "char"

        throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
    }

}
