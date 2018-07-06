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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import java.util.HashSet
import java.util.Set
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class TypeResolver
{
    // TODO the idea of collecting types to import them is problematic, while it might improve 
    // readability, it might also lead to conflicting non-qualified names. Since the generated 
    // code is not intended to be read, at least user-defined types could never be imported, 
    // which avoids problems with conflicts. Apart from that, this seems like a recurring 
    // problem when generating Java code using Xtext. Perhaps there is some reusable solution? 
    @Accessors(PUBLIC_GETTER) val referenced_types = new HashSet<String>

    val IQualifiedNameProvider qualified_name_provider
    val Set<MavenDependency> dependencies

    val MavenResolver mavenResolver

    val fully_qualified = false // we want the toString method show short names by default!

    def addDependency(MavenDependency dependency)
    {
        dependencies.add(dependency)
    }

    def ResolvedName resolve(String name)
    {
        val fully_qualified_name = QualifiedName.create(name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))
        referenced_types.add(name)
        val dependency = MavenResolver.resolveExternalDependency(name)
        if (dependency.present) dependencies.add(dependency.get)
        return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, false)
    }

    def ResolvedName resolve(PrimitiveType element)
    {
        if (element.isUUID)
            return resolve(JavaClassNames.UUID)
        else
            return new ResolvedName(getPrimitiveTypeName(element), TransformType.PACKAGE)
    }

    def getPrimitiveTypeName(PrimitiveType element)
    {
        if (element.isInt64)
            return "Long"
        else if (element.isInt32)
            return "Integer"
        else if (element.isInt16)
            return "Short"
        else if (element.isByte)
            return "Byte"
        else if (element.isString)
            return "String"
        else if (element.isFloat)
            return "Float"
        else if (element.isDouble)
            return "Double"
        else if (element.isBoolean)
            return "Boolean"
        else if (element.isChar)
            return "Character"

        throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
    }

    def ResolvedName resolve(EObject element)
    {
        return resolve(element, element.mainProjectType)
    }

    def ResolvedName resolve(EObject element, ProjectType project_type)
    {
        var name = qualified_name_provider.getFullyQualifiedName(element)

        // try to resolve CAB-related pseudo-exceptions
        if (element.isException)
        {
            val exception_name = resolveException(name.toString)
            if (exception_name !== null)
                return new ResolvedName(exception_name, TransformType.PACKAGE, fully_qualified)
        }

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
                    return resolve(element.referenceType.ultimateType, if (project_type != ProjectType.PROTOBUF)
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
                        return resolve("com.google.protobuf.ByteString")
                    else
                        return resolve(JavaClassNames.UUID)
                }
                else
                    return resolve(element as PrimitiveType)
            }
            return new ResolvedName(Names.plain(element), TransformType.PACKAGE, fully_qualified)
        }

        val effective_name = resolvePackage(element, project_type) + TransformType.PACKAGE.separator +
            if (element instanceof InterfaceDeclaration)
                project_type.getClassName(ArtifactNature.JAVA, name.lastSegment)
            else if (element instanceof EventDeclaration) getObservableName(element) else name.lastSegment
        val fully_qualified_name = QualifiedName.create(
            effective_name.split(Pattern.quote(Constants.SEPARATOR_PACKAGE)))

        referenced_types.add(fully_qualified_name.toString)

        return new ResolvedName(fully_qualified_name, TransformType.PACKAGE, fully_qualified)
    }

    def String resolveException(String name)
    {
        // temporarily some special handling for exceptions, because not all
        // C++ CAB exceptions are supported by the Java CAB
        switch (name)
        {
            case "BTC.Commons.Core.InvalidArgumentException":
                // TODO shouldn't this use resolve("java.util.IllegalArgumentException")?
                "IllegalArgumentException"
            default:
                null
        }
    }

    private static def String getObservableName(EventDeclaration event)
    {
        if (event.name === null)
            throw new IllegalArgumentException("No named observable for anonymous events!")

        event.name.toFirstUpper + "Observable"
    }

    def resolvePackage(EObject container, ProjectType projectType)
    {
        val dependency = mavenResolver.resolveDependency(container, projectType)
        addDependency(dependency)
        dependency.artifactId
    }

}
