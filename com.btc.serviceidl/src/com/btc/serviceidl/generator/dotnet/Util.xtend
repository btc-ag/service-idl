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
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import org.eclipse.emf.ecore.EObject

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

// TODO reorganize this according to logical aspects
class Util
{
    def public static String hasField(MemberElementWrapper member)
    {
        return '''Has«member.name.toLowerCase.toFirstUpper»'''
    }

    def public static String getDataContractName(InterfaceDeclaration interface_declaration,
        FunctionDeclaration function_declaration, ProtobufType protobuf_type)
    {
        interface_declaration.name + "_" + if (protobuf_type == ProtobufType.REQUEST)
            function_declaration.name.asRequest
        else
            function_declaration.name.asResponse
    }

    /**
     * For optional struct members, this generates an "?" to produce a C# Nullable
     * type; if the type if already Nullable (e.g. string), an empty string is returned.
     */
    def public static String maybeOptional(MemberElementWrapper member)
    {
        if (member.optional && member.type.isValueType)
        {
            return "?"
        }
        return "" // do nothing, if not optional!
    }

    /**
     * Is the given type a C# value type (suitable for Nullable)?
     */
    def public static boolean isValueType(EObject element)
    {
        if (element instanceof PrimitiveType)
        {
            if (element.stringType !== null)
                return false
            else
                return true
        }
        else if (element instanceof AliasDeclaration)
        {
            return isValueType(element.type)
        }
        else if (element instanceof AbstractType)
        {
            if (element.referenceType !== null)
                return isValueType(element.referenceType)
            else if (element.primitiveType !== null)
                return isValueType(element.primitiveType)
            else if (element.collectionType !== null)
                return isValueType(element.collectionType)
        }

        return false
    }

    /**
     * Make a C# property name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def public static String asProperty(String name)
    {
        name.toFirstUpper
    }

    /**
     * Make a C# member variable name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def public static String asMember(String name)
    {
        if (name.allUpperCase)
            name.toLowerCase // it looks better, if ID --> id and not ID --> iD
        else
            name.toFirstLower
    }

    /**
     * Make a C# parameter name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def public static String asParameter(String name)
    {
        asMember(name) // currently the same convention
    }

    def public static getEventTypeGuidProperty()
    {
        "EventTypeGuid".asMember
    }

    def public static getReturnValueProperty()
    {
        "ReturnValue".asMember
    }

    def public static getTypeGuidProperty()
    {
        "TypeGuid".asMember
    }

    def public static getTypeNameProperty()
    {
        "TypeName".asMember
    }

    def public static boolean isExecutable(ProjectType pt)
    {
        return (pt == ProjectType.SERVER_RUNNER || pt == ProjectType.CLIENT_CONSOLE)
    }

    def public static String getObservableName(EventDeclaration event)
    {
        if (event.name === null)
            throw new IllegalArgumentException("No named observable for anonymous events!")

        event.name.toFirstUpper + "Observable"
    }

    def public static String getDeserializingObserverName(EventDeclaration event)
    {
        (event.name ?: "") + "DeserializingObserver"
    }

    def public static String getTestClassName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "Test"
    }

    def public static String getProxyFactoryName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "ProxyFactory"
    }

    def public static String getServerRegistrationName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "ServerRegistration"
    }

    def public static String getConstName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "Const"
    }

    def public static dispatch boolean isNullable(EObject element)
    {
        false
    }

    def public static dispatch boolean isNullable(PrimitiveType element)
    {
        element.booleanType !== null || element.integerType !== null || element.charType !== null ||
            element.floatingPointType !== null
    }

    def public static dispatch boolean isNullable(AliasDeclaration element)
    {
        isNullable(element.type)
    }

    def public static dispatch boolean isNullable(AbstractType element)
    {
        element.primitiveType !== null && isNullable(element.primitiveType)
    }

    def static String getLog4NetConfigFile(ParameterBundle.Builder param_bundle)
    {
        GeneratorUtil.transform(param_bundle.build, TransformType.PACKAGE).toLowerCase + ".log4net".config

    }

    def static String makeDefaultValue(BasicCSharpSourceGenerator basicCSharpSourceGenerator, EObject element)
    {
        val typeResolver = basicCSharpSourceGenerator.typeResolver
        if (element instanceof PrimitiveType)
        {
            if (element.stringType !== null)
                return '''«typeResolver.resolve("System.string")».Empty'''
        }
        else if (element instanceof AliasDeclaration)
        {
            return makeDefaultValue(basicCSharpSourceGenerator, element.type)
        }
        else if (element instanceof AbstractType)
        {
            if (element.referenceType !== null)
                return makeDefaultValue(basicCSharpSourceGenerator, element.referenceType)
            else if (element.primitiveType !== null)
                return makeDefaultValue(basicCSharpSourceGenerator, element.primitiveType)
            else if (element.collectionType !== null)
                return makeDefaultValue(basicCSharpSourceGenerator, element.collectionType)
        }
        else if (element instanceof SequenceDeclaration)
        {
            val type = basicCSharpSourceGenerator.toText(element.type, element)
            return '''new «typeResolver.resolve("System.Collections.Generic.List")»<«type»>() as «typeResolver.resolve("System.IEnumerable")»<«type»>'''
        }
        else if (element instanceof StructDeclaration)
        {
            return '''new «typeResolver.resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«member.name.asParameter»: «IF member.optional»null«ELSE»«makeDefaultValue(basicCSharpSourceGenerator, member.type)»«ENDIF»«ENDFOR»)'''
        }

        return '''default(«basicCSharpSourceGenerator.toText(element, element)»)'''
    }

    def static String makeReturnType(TypeResolver typeResolver, FunctionDeclaration function)
    {
        val is_void = function.returnedType.isVoid
        val is_sync = function.isSync
        val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)
        val effective_type = '''«IF is_sequence»«typeResolver.resolve("System.Collections.Generic.IEnumerable")»<«typeResolver.resolve(com.btc.serviceidl.util.Util.getUltimateType(function.returnedType))»>«ELSE»«typeResolver.resolve(function.returnedType)»«ENDIF»'''

        '''«IF is_void»«IF !is_sync»«typeResolver.resolve("System.Threading.Tasks.Task")»«ELSE»void«ENDIF»«ELSE»«IF !is_sync»«typeResolver.resolve("System.Threading.Tasks.Task")»<«ENDIF»«effective_type»«IF !is_sync»>«ENDIF»«ENDIF»'''
    }

    def static String resolveCodec(TypeResolver typeResolver, ParameterBundle.Builder param_bundle, EObject object)
    {
        val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(object)

        val temp_param = new ParameterBundle.Builder
        temp_param.reset(ArtifactNature.DOTNET)
        temp_param.reset(com.btc.serviceidl.util.Util.getModuleStack(ultimate_type))
        temp_param.reset(ProjectType.PROTOBUF)

        val codec_name = GeneratorUtil.getCodecName(ultimate_type)

        typeResolver.resolveProjectFilePath(ultimate_type, ProjectType.PROTOBUF)

        GeneratorUtil.transform(temp_param.build, TransformType.PACKAGE) + TransformType.PACKAGE.separator + codec_name
    }

    def public static String makeDefaultMethodStub(TypeResolver typeResolver)
    {
        '''
            // TODO Auto-generated method stub
            throw new «typeResolver.resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
        '''
    }
}
