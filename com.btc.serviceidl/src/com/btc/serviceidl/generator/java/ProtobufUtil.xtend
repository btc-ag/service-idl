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

        val scopeDeterminant = object.scopeDeterminant

        var result = MavenResolver.resolvePackage(object, Optional.of(ProjectType.PROTOBUF))
        result += Constants.SEPARATOR_PACKAGE
        if (object instanceof InterfaceDeclaration && Util.ensurePresentOrThrow(optProtobufType))
            result += Names.plain(object) + "." + Names.plain(object) + "_" + optProtobufType.get.getName
        else if (object instanceof FunctionDeclaration && Util.ensurePresentOrThrow(optProtobufType))
            result +=
                Names.plain(scopeDeterminant) + "_" + optProtobufType.get.getName + "_" + Names.plain(object) + "_" +
                    optProtobufType.get.getName
        else if (scopeDeterminant instanceof ModuleDeclaration)
            result += Constants.FILE_NAME_TYPES + "." + Names.plain(object)
        else
            result += Names.plain(scopeDeterminant) + "." + Names.plain(object)

        typeResolver.addDependency(MavenResolver.resolveDependency(object))
        return new ResolvedName(result, TransformType.PACKAGE)
    }

    def public static String asProtobufName(String name)
    {
        name.toLowerCase.toFirstUpper
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

    private def static String getContainerName(EObject container)
    {
        if (container instanceof InterfaceDeclaration)
            '''«container.name».'''
        else
            ""
    }
}
