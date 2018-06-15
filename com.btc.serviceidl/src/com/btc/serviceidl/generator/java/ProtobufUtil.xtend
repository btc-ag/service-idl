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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import com.google.common.base.CaseFormat
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.util.Util.*

class ProtobufUtil
{
    def public static ResolvedName resolveProtobuf(TypeResolver typeResolver, EObject object,
        Optional<ProtobufType> optProtobufType)
    {
        if (object.isUUIDType)
            return typeResolver.resolve(object, ProjectType.PROTOBUF)
        else if (object.isAlias)
            return resolveProtobuf(typeResolver, object.ultimateType, optProtobufType)
        else if (object instanceof PrimitiveType)
            return new ResolvedName(typeResolver.resolve(object).toString, TransformType.PACKAGE)
        else if (object instanceof AbstractType)
        {
            if (object.primitiveType !== null)
                return resolveProtobuf(typeResolver, object.primitiveType, optProtobufType)
            else if (object.referenceType !== null)
                return resolveProtobuf(typeResolver, object.referenceType, optProtobufType)
        }

        typeResolver.addDependency(MavenResolver.resolveDependency(object))
        return new ResolvedName(
            MavenResolver.resolvePackage(object, Optional.of(ProjectType.PROTOBUF)) + Constants.SEPARATOR_PACKAGE +
                getLocalName(object, optProtobufType), TransformType.PACKAGE)
    }

    private static def String getLocalName(EObject object, Optional<ProtobufType> optProtobufType)
    {
        val scopeDeterminant = object.scopeDeterminant

        if (object instanceof InterfaceDeclaration && Util.ensurePresentOrThrow(optProtobufType))
            getOuterClassName(object) + "." + Names.plain(object) + optProtobufType.get.getName
        else if (object instanceof FunctionDeclaration && Util.ensurePresentOrThrow(optProtobufType))
            Names.plain(scopeDeterminant) + "_" + optProtobufType.get.getName + "_" + Names.plain(object) +
                optProtobufType.get.getName
        else if (scopeDeterminant instanceof ModuleDeclaration)
            Constants.FILE_NAME_TYPES + "." + Names.plain(object)
        else
            getOuterClassName(scopeDeterminant) + "." + Names.plain(object)
    }

    private static def String getOuterClassName(EObject scopeDeterminant)
    {
        Names.plain(scopeDeterminant) + (if (scopeDeterminant.interfaceWithElementWithSameName) "OuterClass" else "")
    }

    def public static boolean interfaceWithElementWithSameName(EObject scopeDeterminant)
    {
        if (scopeDeterminant instanceof InterfaceDeclaration)
        {
            val name = Names.plain(scopeDeterminant)
            // TODO Not sure if this can really be true, while still producing valid generated code
            // this might lead to other naming conflicts
            return scopeDeterminant.contains.exists[Names.plain(it) == name]
        }
        else
            false
    }

    public static def String asProtobufName(String name)
    {
        // TODO change this function to accept a model construct rather than a bare name
        asProtobufName(name, CaseFormat.UPPER_CAMEL)
    }

    // TODO reconsider placement of this method
    def public static String resolveCodec(EObject object)
    {
        val ultimateType = object.ultimateType

        MavenResolver.resolvePackage(ultimateType, Optional.of(ProjectType.PROTOBUF)) +
            TransformType.PACKAGE.separator + ultimateType.codecName
    }

    def public static String resolveFailableProtobufType(IQualifiedNameProvider qualifiedNameProvider, EObject element,
        EObject container)
    {
        return MavenResolver.resolvePackage(container, Optional.of(ProjectType.PROTOBUF)) +
            TransformType.PACKAGE.separator + ( if (container instanceof ModuleDeclaration)
                '''«Constants.FILE_NAME_TYPES».'''
            else
                "" ) + container.containerName + GeneratorUtil.asFailable(element, container, qualifiedNameProvider)
    }

    private static def String getContainerName(EObject container)
    {
        if (container instanceof InterfaceDeclaration)
            '''«container.name».'''
        else
            ""
    }
}
