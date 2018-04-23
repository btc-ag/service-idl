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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import java.util.Optional
import org.eclipse.emf.ecore.EObject

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

class ProtobufUtil
{
    def static ResolvedName resolveProtobuf(extension TypeResolver typeResolver, EObject object,
        ProtobufType protobuf_type)
    {
        if (com.btc.serviceidl.util.Util.isUUIDType(object))
            return new ResolvedName(resolveSTL("std::string"), TransformType.NAMESPACE)
        else if (com.btc.serviceidl.util.Util.isInt16(object) || com.btc.serviceidl.util.Util.isByte(object) ||
            com.btc.serviceidl.util.Util.isChar(object))
            return new ResolvedName("::google::protobuf::int32", TransformType.NAMESPACE)
        else if (object instanceof PrimitiveType)
            return new ResolvedName(getPrimitiveTypeName(object), TransformType.NAMESPACE)
        else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
            return resolveProtobuf(typeResolver, (object as AbstractType).primitiveType, protobuf_type)

        val is_function = (object instanceof FunctionDeclaration)
        val is_interface = (object instanceof InterfaceDeclaration)
        val scope_determinant = com.btc.serviceidl.util.Util.getScopeDeterminant(object)

        val builder = ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(scope_determinant))
        builder.reset(ProjectType.PROTOBUF)

        var result = GeneratorUtil.transform(builder.build, TransformType.NAMESPACE)
        result += Constants.SEPARATOR_NAMESPACE
        if (is_interface)
            result += Names.plain(object) + "_" + protobuf_type.getName
        else if (is_function)
            result += Names.plain(scope_determinant) + "_" + protobuf_type.getName + "_" + Names.plain(object) + "_" +
                protobuf_type.getName
        else
            result += Names.plain(object)

        var header_path = GeneratorUtil.transform(builder.build, TransformType.FILE_SYSTEM)
        var header_file = GeneratorUtil.getPbFileName(object)
        modules_includes.add("modules/" + header_path + "/gen/" + header_file.pb.h)
        object.resolveProjectFilePath(ProjectType.PROTOBUF)
        return new ResolvedName(result, TransformType.NAMESPACE)
    }

    def static String resolveDecode(extension TypeResolver typeResolver, EObject element, EObject container)
    {
        resolveDecode(typeResolver, element, container, true)
    }

    def static String resolveDecode(extension TypeResolver typeResolver, EObject element, EObject container,
        boolean use_codec_ns)
    {
        // handle sequence first, because it may include UUIDs and other types from below
        if (com.btc.serviceidl.util.Util.isSequenceType(element))
        {
            val is_failable = com.btc.serviceidl.util.Util.isFailable(element)
            val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(element)

            var protobuf_type = resolve(ultimate_type, ProjectType.PROTOBUF).fullyQualifiedName
            if (is_failable)
                protobuf_type = typeResolver.resolveFailableProtobufType(element, container)
            else if (com.btc.serviceidl.util.Util.isByte(ultimate_type) ||
                com.btc.serviceidl.util.Util.isInt16(ultimate_type) ||
                com.btc.serviceidl.util.Util.isChar(ultimate_type))
                protobuf_type = "google::protobuf::int32"

            var decodeMethodName = ""
            if (is_failable)
            {
                if (element.eContainer instanceof MemberElement)
                    decodeMethodName = '''DecodeFailableToVector'''
                else
                    decodeMethodName = '''DecodeFailable'''
            }
            else
            {
                if (element.eContainer instanceof MemberElement)
                {
                    if (com.btc.serviceidl.util.Util.isUUIDType(ultimate_type))
                        decodeMethodName = "DecodeUUIDToVector"
                    else
                        decodeMethodName = "DecodeToVector"
                }
                else
                {
                    if (com.btc.serviceidl.util.Util.isUUIDType(ultimate_type))
                        decodeMethodName = "DecodeUUID"
                    else
                        decodeMethodName = "Decode"
                }
            }

            return '''«IF use_codec_ns»«typeResolver.resolveCodecNS(ultimate_type, is_failable, Optional.of(container))»::«ENDIF»«decodeMethodName»«IF is_failable || !com.btc.serviceidl.util.Util.isUUIDType(ultimate_type)»< «protobuf_type», «resolve(ultimate_type)» >«ENDIF»'''
        }

        if (com.btc.serviceidl.util.Util.isUUIDType(element))
            return '''«typeResolver.resolveCodecNS(element)»::DecodeUUID'''

        if (com.btc.serviceidl.util.Util.isByte(element))
            return '''static_cast<«resolveSTL("int8_t")»>'''

        if (com.btc.serviceidl.util.Util.isInt16(element))
            return '''static_cast<«resolveSTL("int16_t")»>'''

        if (com.btc.serviceidl.util.Util.isChar(element))
            return '''static_cast<char>'''

        return '''«typeResolver.resolveCodecNS(element)»::Decode'''
    }

    def static String resolveCodecNS(extension TypeResolver typeResolver, EObject object)
    {
        resolveCodecNS(typeResolver, object, false, Optional.empty)
    }

    def static String resolveCodecNS(extension TypeResolver typeResolver, EObject object, boolean is_failable,
        Optional<EObject> container)
    {
        val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(object)

        val temp_param = new ParameterBundle.Builder
        temp_param.reset(param_bundle.artifactNature)
        temp_param.reset(
            if (is_failable) param_bundle.moduleStack else com.btc.serviceidl.util.Util.getModuleStack(ultimate_type)) // failable wrappers always local!
        temp_param.reset(ProjectType.PROTOBUF)

        val codec_name = if (is_failable)
                GeneratorUtil.getCodecName(container.get)
            else
                GeneratorUtil.getCodecName(ultimate_type)

        var header_path = GeneratorUtil.transform(temp_param.build, TransformType.FILE_SYSTEM)
        modules_includes.add("modules/" + header_path + "/include/" + codec_name.h)
        resolveProjectFilePath(ultimate_type, ProjectType.PROTOBUF)

        GeneratorUtil.transform(temp_param.build, TransformType.NAMESPACE) + TransformType.NAMESPACE.separator +
            codec_name
    }

    def static String resolveFailableProtobufType(extension TypeResolver typeResolver, EObject element,
        EObject container)
    {
        // explicitly include some essential dependencies
        cab_libs.add("BTC.CAB.ServiceComm.Default.lib")

        var namespace = GeneratorUtil.transform(
            ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(
                com.btc.serviceidl.util.Util.getScopeDeterminant(container))).with(ProjectType.PROTOBUF).build,
            TransformType.NAMESPACE
        )
        return namespace + Constants.SEPARATOR_NAMESPACE +
            GeneratorUtil.asFailable(element, container, qualified_name_provider)
    }

}
