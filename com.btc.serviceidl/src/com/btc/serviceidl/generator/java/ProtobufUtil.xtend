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
    def public static ResolvedName resolveProtobuf(BasicJavaSourceGenerator basicJavaSourceGenerator, EObject object,
        Optional<ProtobufType> protobuf_type)
    {
        if (object.isUUIDType)
            return basicJavaSourceGenerator.typeResolver.resolve(object, ProjectType.PROTOBUF)
        else if (object.isAlias)
            return resolveProtobuf(basicJavaSourceGenerator, object.ultimateType, protobuf_type)
        else if (object instanceof PrimitiveType)
            return new ResolvedName(basicJavaSourceGenerator.toText(object), TransformType.PACKAGE)
        else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
            return resolveProtobuf(basicJavaSourceGenerator, (object as AbstractType).primitiveType, protobuf_type)
        else if (object instanceof AbstractType && (object as AbstractType).referenceType !== null)
            return resolveProtobuf(basicJavaSourceGenerator, (object as AbstractType).referenceType, protobuf_type)

        val is_function = (object instanceof FunctionDeclaration)
        val is_interface = (object instanceof InterfaceDeclaration)
        val scope_determinant = object.scopeDeterminant

        var result = MavenResolver.resolvePackage(object, Optional.of(ProjectType.PROTOBUF))
        result += Constants.SEPARATOR_PACKAGE
        if (is_interface && Util.ensurePresentOrThrow(protobuf_type))
            result += Names.plain(object) + "." + Names.plain(object) + "_" + protobuf_type.get.getName
        else if (is_function && Util.ensurePresentOrThrow(protobuf_type))
            result +=
                Names.plain(scope_determinant) + "_" + protobuf_type.get.getName + "_" + Names.plain(object) + "_" +
                    protobuf_type.get.getName
        else if (scope_determinant instanceof ModuleDeclaration)
            result += Constants.FILE_NAME_TYPES + "." + Names.plain(object)
        else
            result += Names.plain(scope_determinant) + "." + Names.plain(object)

        val dependency = MavenResolver.resolveDependency(object)
        basicJavaSourceGenerator.typeResolver.addDependency(dependency)
        return new ResolvedName(result, TransformType.PACKAGE)
    }

    def public static String asProtobufName(String name)
    {
        name.toLowerCase.toFirstUpper
    }

   // TODO reconsider placement of this method
   def public static String resolveCodec(EObject object)
   {
      val ultimate_type = object.ultimateType
      
      val codec_name = ultimate_type.codecName
      MavenResolver.resolvePackage(ultimate_type, Optional.of(ProjectType.PROTOBUF)) + TransformType.PACKAGE.separator + codec_name
   }
      
   def public static String resolveFailableProtobufType(IQualifiedNameProvider qualified_name_provider, EObject element, EObject container)
   {
      val container_name = if (container instanceof InterfaceDeclaration) '''«container.name».''' else "" 
      return MavenResolver.resolvePackage(container, Optional.of(ProjectType.PROTOBUF))
         + TransformType.PACKAGE.separator
         + ( if (container instanceof ModuleDeclaration) '''«Constants.FILE_NAME_TYPES».''' else "" )
         + container_name
         + GeneratorUtil.asFailable(element, container, qualified_name_provider)
   }
}
