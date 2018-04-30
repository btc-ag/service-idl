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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.generator.common.ArtifactNature

@Accessors(NONE)
class ProxyDispatcherGeneratorBase extends GeneratorBase
{
    def protected String getProtobufRequestClassName(InterfaceDeclaration interface_declaration)
    {
        resolve(interface_declaration, ProjectType.PROTOBUF)
        return GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(param_bundle).with(ProjectType.PROTOBUF).build,
            ArtifactNature.DOTNET, TransformType.PACKAGE) + Constants.SEPARATOR_PACKAGE +
            com.btc.serviceidl.util.Util.asRequest(interface_declaration.name)
    }

    def protected String getProtobufResponseClassName(InterfaceDeclaration interface_declaration)
    {
        resolve(interface_declaration, ProjectType.PROTOBUF)
        return GeneratorUtil.getTransformedModuleName(new ParameterBundle.Builder(param_bundle).with(ProjectType.PROTOBUF).build,
            ArtifactNature.DOTNET, TransformType.PACKAGE) + Constants.SEPARATOR_PACKAGE +
            com.btc.serviceidl.util.Util.asResponse(interface_declaration.name)
    }

    def protected String getEncodeMethod(EObject type)
    {
        val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(type)
        val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(type)
        if (is_sequence)
            "encodeEnumerable<" + resolveEncode(ultimate_type) + ", " + toText(ultimate_type, null) + ">"
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

    def protected String resolveEncode(EObject element)
    {
        if (element.isUUIDType)
            resolve("Google.ProtocolBuffers.ByteString").toString
        else if (element.isByte || element.isInt16 || element.isChar)
            "int"
        else if (element.isSequenceType)
            resolve("System.Collections.Generic.IEnumerable") +
                '''<«resolveEncode(com.btc.serviceidl.util.Util.getUltimateType(element))»>'''
        else
            resolve(element, ProjectType.PROTOBUF).toString
    }

    def protected String getDecodeMethod(EObject type)
    {
        val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(type)
        if (is_sequence)
        {
            val ultimateType = com.btc.serviceidl.util.Util.getUltimateType(type)
            if (ultimateType instanceof PrimitiveType && (ultimateType as PrimitiveType).integerType !== null)
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

    def protected String resolveDecode(EObject element)
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

    def protected ResolvedName resolveProtobuf(EObject element)
    {
        resolve(element, ProjectType.PROTOBUF)
    }

    def protected String makeExceptionRegistration(String service_fault_handler_name,
        Iterable<AbstractException> exceptions)
    {
        '''
            «FOR exception : exceptions.sortBy[name] SEPARATOR System.lineSeparator»
                «service_fault_handler_name».RegisterException("«com.btc.serviceidl.util.Util.getCommonExceptionName(exception, qualified_name_provider)»", typeof («resolve(exception)»));
            «ENDFOR»
                  
            // most commonly used exception types
            «service_fault_handler_name».RegisterException("«Constants.INVALID_ARGUMENT_EXCEPTION_FAULT_HANDLER»", typeof(«"System.ArgumentException"»));
            
            «service_fault_handler_name».RegisterException("«Constants.UNSUPPORTED_OPERATION_EXCEPTION_FAULT_HANDLER»", typeof(«"System.NotSupportedException"»));
        '''
    }

}
