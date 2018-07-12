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
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

// TODO reorganize this according to logical aspects
class Util
{
    def static String hasField(MemberElementWrapper member)
    {
        return '''Has«member.name.toLowerCase.toFirstUpper»'''
    }

    /**
     * For optional struct members, this generates an "?" to produce a C# Nullable
     * type; if the type if already Nullable (e.g. string), an empty string is returned.
     */
    def static String maybeOptional(MemberElementWrapper member)
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
    def static boolean isValueType(AbstractTypeReference element)
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
            return isValueType(element.type.actualType)
        }

        return false
    }

    /**
     * Make a C# property name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def static String asProperty(String name)
    {
        name.toFirstUpper
    }

    /**
     * Make a C# member variable name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def static String asMember(String name)
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
    def static String asParameter(String name)
    {
        asMember(name) // currently the same convention
    }

    def static getEventTypeGuidProperty()
    {
        "EventTypeGuid".asMember
    }

    def static getTypeGuidProperty()
    {
        "TypeGuid".asMember
    }

    def static getTypeNameProperty()
    {
        "TypeName".asMember
    }

    def static boolean isExecutable(ProjectType pt)
    {
        return (pt == ProjectType.SERVER_RUNNER || pt == ProjectType.CLIENT_CONSOLE)
    }

    def static String getObservableName(EventDeclaration event)
    {
        if (event.name === null)
            throw new IllegalArgumentException("No named observable for anonymous events!")

        event.name.toFirstUpper + "Observable"
    }

    def static String getDeserializingObserverName(EventDeclaration event)
    {
        (event.name ?: "") + "DeserializingObserver"
    }

    def static String getTestClassName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "Test"
    }

    def static String getProxyFactoryName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "ProxyFactory"
    }

    def static String getServerRegistrationName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "ServerRegistration"
    }

    def static String getConstName(InterfaceDeclaration interface_declaration)
    {
        interface_declaration.name + "Const"
    }

    def static dispatch boolean isNullable(AbstractTypeReference element)
    {
        false
    }

    def static dispatch boolean isNullable(PrimitiveType element)
    {
        element.booleanType !== null || element.integerType !== null || element.charType !== null ||
            element.floatingPointType !== null || element.uuidType !== null
    }

    def static dispatch boolean isNullable(AliasDeclaration element)
    {
        isNullable(element.type)
    }

    def static dispatch boolean isNullable(AbstractType element)
    {
        element.primitiveType !== null && isNullable(element.primitiveType)
    }

    static def String getLog4NetConfigFile(ParameterBundle param_bundle)
    {
        GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.DOTNET, TransformType.PACKAGE).toLowerCase +
            ".log4net".config

    }

    static def String makeDefaultValue(BasicCSharpSourceGenerator basicCSharpSourceGenerator, AbstractType element)
    {
        makeDefaultValue(basicCSharpSourceGenerator, element.actualType)
    }

    static def String makeDefaultValue(BasicCSharpSourceGenerator basicCSharpSourceGenerator,
        AbstractTypeReference element)
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
        else if (element instanceof SequenceDeclaration)
        {
            var type = basicCSharpSourceGenerator.toText(element.type, element)
            if (element.failable)
            {
                type = typeResolver.resolveFailableType(type)
            }
            return '''new «typeResolver.resolve("System.Collections.Generic.List")»<«type»>()«typeResolver.asEnumerable»'''
        }
        else if (element instanceof StructDeclaration)
        {
            return '''new «typeResolver.resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«member.name.asParameter»: «IF member.optional»null«ELSE»«makeDefaultValue(basicCSharpSourceGenerator, member.type)»«ENDIF»«ENDFOR»)'''
        }

        return '''default(«basicCSharpSourceGenerator.toText(element, element)»)'''
    }

    static def String makeReturnType(TypeResolver typeResolver, FunctionDeclaration function)
    {
        val is_void = function.returnedType instanceof VoidType
        val is_sync = function.isSync

        if (is_void)
            '''«IF !is_sync»«typeResolver.resolve("System.Threading.Tasks.Task")»«ELSE»void«ENDIF»'''
        else
        {
            val isSequence = com.btc.serviceidl.util.Util.isSequenceType(function.returnedType)
            val isFailable = isSequence && com.btc.serviceidl.util.Util.isFailable(function.returnedType)
            val basicType = typeResolver.resolve(
                com.btc.serviceidl.util.Util.getUltimateType(function.returnedType.actualType))
            var effectiveType = if (isSequence)
                {
                    '''«typeResolver.resolve("System.Collections.Generic.IEnumerable")»<«IF isFailable»«typeResolver.resolveFailableType(basicType.fullyQualifiedName)»«ELSE»«basicType»«ENDIF»>'''
                }
                else
                    basicType.toString

            '''«IF !is_sync»«typeResolver.resolve("System.Threading.Tasks.Task")»<«ENDIF»«effectiveType»«IF !is_sync»>«ENDIF»'''
        }
    }

    static def String resolveCodec(TypeResolver typeResolver, ParameterBundle param_bundle,
        AbstractTypeReference object)
    {
        val ultimate_type = object.ultimateType

        val codec_name = GeneratorUtil.getCodecName(ultimate_type.scopeDeterminant)

        typeResolver.resolveProjectFilePath(ultimate_type.scopeDeterminant, ProjectType.PROTOBUF)

        GeneratorUtil.getTransformedModuleName(
            new ParameterBundle.Builder().with(ultimate_type.scopeDeterminant.moduleStack).with(
                ProjectType.PROTOBUF).build, ArtifactNature.DOTNET, TransformType.PACKAGE) +
            TransformType.PACKAGE.separator + codec_name
    }

    def static String makeDefaultMethodStub(TypeResolver typeResolver)
    {
        '''
            // TODO Auto-generated method stub
            throw new «typeResolver.resolve("System.NotSupportedException")»("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
        '''
    }

    static def getPrefix(AbstractContainerDeclaration container)
    {
        if (container instanceof InterfaceDeclaration) container.name else ""
    }

    static def ResolvedName resolveServiceFaultHandling(TypeResolver typeResolver, AbstractContainerDeclaration owner)
    {
        val namespace = typeResolver.resolveNamedDeclaration(owner, ProjectType.PROTOBUF).namespace
        return new ResolvedName('''«namespace».«owner.prefix»ServiceFaultHandling''', TransformType.PACKAGE)
    }

    static def String asEnumerable(TypeResolver typeResolver)
    {
        typeResolver.resolve("System.Linq.Enumerable")
        '''.AsEnumerable()'''
    }

    def static getProxyProtocolName(InterfaceDeclaration interfaceDeclaration)
    {
        interfaceDeclaration.name + "Protocol"
    }

    def static getProxyDataName(InterfaceDeclaration interfaceDeclaration)
    {
        interfaceDeclaration.name + "Data"
    }
}
