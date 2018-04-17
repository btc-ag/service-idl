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

import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.MemberElementWrapper
import org.eclipse.emf.ecore.EObject

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
        interface_declaration.name + "_" +
            if (protobuf_type == ProtobufType.REQUEST) function_declaration.name.asRequest else function_declaration.
                name.asResponse
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

    def public static boolean isNullable(EObject element)
    {
        if (element instanceof PrimitiveType)
        {
            return (
            element.booleanType !== null || element.integerType !== null || element.charType !== null ||
                element.floatingPointType !== null
         )
        }
        else if (element instanceof AliasDeclaration)
        {
            return isNullable(element.type)
        }
        else if (element instanceof AbstractType)
        {
            if (element.primitiveType !== null)
                return isNullable(element.primitiveType)
            else
                return false
        }

        return false
    }
}
