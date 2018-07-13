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
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProxyDispatcherGeneratorBase extends GeneratorBase
{
    protected def String getProtobufRequestClassName(InterfaceDeclaration interfaceDeclaration)
    {
        resolve(interfaceDeclaration, ProjectType.PROTOBUF)
        return GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(parameterBundle).with(ProjectType.PROTOBUF).build,
            ArtifactNature.DOTNET, TransformType.PACKAGE) + Constants.SEPARATOR_PACKAGE +
            com.btc.serviceidl.util.Util.asRequest(interfaceDeclaration.name)
    }

    protected def String getProtobufResponseClassName(InterfaceDeclaration interfaceDeclaration)
    {
        resolve(interfaceDeclaration, ProjectType.PROTOBUF)
        return GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(parameterBundle).with(ProjectType.PROTOBUF).build,
            ArtifactNature.DOTNET, TransformType.PACKAGE) + Constants.SEPARATOR_PACKAGE +
            com.btc.serviceidl.util.Util.asResponse(interfaceDeclaration.name)
    }

    protected def String getEncodeMethod(AbstractTypeReference type, AbstractContainerDeclaration container)
    {
        val isSequence = com.btc.serviceidl.util.Util.isSequenceType(type)
        val ultimateType = com.btc.serviceidl.util.Util.getUltimateType(type)
        if (isSequence)
        {
            if (type.isFailable)
            {
                '''encodeFailable<«resolveFailableProtobufType(ultimateType, container)», «toText(ultimateType, null)»>'''
            }
            else
                "encodeEnumerable<" + resolveEncode(ultimateType) + ", " + toText(ultimateType, null) + ">"
        }
        else if (com.btc.serviceidl.util.Util.isByte(type))
            "encodeByte"
        else if (com.btc.serviceidl.util.Util.isInt16(type))
            "encodeShort"
        else if (com.btc.serviceidl.util.Util.isChar(type))
            "encodeChar"
        else if (com.btc.serviceidl.util.Util.isUUIDType(type))
            "encodeUUID"
        else
            "encode"
    }

    protected def String resolveEncode(AbstractTypeReference element)
    {
        if (element.isUUIDType)
            resolve(TypeResolver.PROTOBUF_UUID_TYPE).toString
        else if (element.isByte || element.isInt16 || element.isChar)
            "int"
        else if (element.isSequenceType)
            resolve("System.Collections.Generic.IEnumerable") +
                '''<«resolveEncode(com.btc.serviceidl.util.Util.getUltimateType(element))»>'''
        else
            resolve(element, ProjectType.PROTOBUF).toString
    }

    protected def String getDecodeMethod(AbstractTypeReference type, AbstractContainerDeclaration container)
    {
        val isSequence = com.btc.serviceidl.util.Util.isSequenceType(type)
        if (isSequence)
        {
            val ultimateType = com.btc.serviceidl.util.Util.getUltimateType(type)
            if (type.isFailable)
            {
                '''decodeFailable<«toText(ultimateType, type)», «resolveFailableProtobufType(ultimateType, container)»>'''
            }
            else if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).integerType !== null)
            {
                if ((ultimateType as PrimitiveType).isByte)
                    "decodeEnumerableByte"
                else if ((ultimateType as PrimitiveType).isInt16)
                    "decodeEnumerableShort"
            }
            else if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).charType !== null)
                "decodeEnumerableChar"
            else if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).uuidType !== null)
                "decodeEnumerableUUID"
            else
                "decodeEnumerable<" + toText(ultimateType, type) + ", " + resolveProtobuf(ultimateType) + ">"
        }
        else if (com.btc.serviceidl.util.Util.isByte(type))
            "decodeByte"
        else if (com.btc.serviceidl.util.Util.isInt16(type))
            "decodeShort"
        else if (com.btc.serviceidl.util.Util.isChar(type))
            "decodeChar"
        else if (com.btc.serviceidl.util.Util.isUUIDType(type))
            "decodeUUID"
        else
            "decode"
    }

    protected def String resolveDecode(AbstractTypeReference element)
    {
        if (com.btc.serviceidl.util.Util.isUUIDType(element))
            resolve("System.Guid").fullyQualifiedName
        else if (com.btc.serviceidl.util.Util.isByte(element))
            "byte"
        else if (com.btc.serviceidl.util.Util.isInt16(element))
            "short"
        else if (com.btc.serviceidl.util.Util.isInt16(element))
            "char"
        else if (com.btc.serviceidl.util.Util.isSequenceType(element))
            resolve("System.Collections.Generic.IEnumerable") +
                '''<«resolveDecode(com.btc.serviceidl.util.Util.getUltimateType(element))»>'''
        else
            return resolve(element).toString
    }

    protected def ResolvedName resolveProtobuf(AbstractTypeReference element)
    {
        resolve(element, ProjectType.PROTOBUF)
    }

    protected def String makeExceptionRegistration(String serviceFaultHandler, InterfaceDeclaration interfaceDeclaration)
    {
        '''
        // service fault handling
        var «serviceFaultHandler» = new «resolve("BTC.CAB.ServiceComm.NET.FaultHandling.MultipleExceptionTypesServiceFaultHandler")»();
        foreach (var item in «Util.resolveServiceFaultHandling(typeResolver, interfaceDeclaration).fullyQualifiedName».getErrorMappings())
        {
           «serviceFaultHandler».RegisterException(item.Key, item.Value);
        }
        '''
    }

}
