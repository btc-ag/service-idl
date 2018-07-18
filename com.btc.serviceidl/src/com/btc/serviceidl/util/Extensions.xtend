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
/**
 * \file       Extensions.xtend
 * 
 * \brief      Diverse useful extension methods
 */
package com.btc.serviceidl.util

import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.VoidType
import java.util.ArrayList
import java.util.Collection
import java.util.HashSet

class Extensions
{
    static def boolean isByte(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.integerType !== null && primitiveType.integerType.equals("byte"))
    }

    static def boolean isInt16(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.integerType !== null && primitiveType.integerType.equals("int16"))
    }

    static def boolean isInt32(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType !== null && primitiveType.integerType !== null &&
            primitiveType.integerType.equals("int32"))
    }

    static def boolean isInt64(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.integerType !== null && primitiveType.integerType.equals("int64"))
    }

    static def boolean isChar(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.charType !== null)
    }

    static def boolean isString(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.stringType !== null)
    }

    static def boolean isUUID(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.uuidType !== null)
    }

    static def boolean isBoolean(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.booleanType !== null)
    }

    static def boolean isDouble(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.floatingPointType !== null &&
            primitiveType.floatingPointType.equals("double"))
    }

    static def boolean isFloat(PrimitiveType primitiveType)
    {
        (primitiveType !== null && primitiveType.floatingPointType !== null &&
            primitiveType.floatingPointType.equals("float"))
    }

    static def boolean containsTypes(ModuleDeclaration module)
    {
        module.moduleComponents.exists[o|!(o instanceof AbstractContainerDeclaration)]
    }

    static def boolean containsInterfaces(ModuleDeclaration module)
    {
        module.moduleComponents.exists[o|o instanceof InterfaceDeclaration]
    }

    /**
     * For a given object, check in the container hierarchy whether it belongs
     * to a function parameter marked as "out".
     * 
     * \return true, if yes, false otherwise (also e.g. if such an owner could not be found at all)
     */
    static def boolean isOutputParameter(SequenceDeclaration element)
    {
        var container = element.eContainer

        while (container !== null)
        {
            if (container instanceof ParameterElement)
            {
                return (container.direction == ParameterDirection.PARAM_OUT)
            }
            container = container.eContainer
        }

        return false
    }

    /**
     * For a given interface, return all function it offers, i.e. own functions
     * as well as functions from all super classes.
     */
    static def Iterable<FunctionDeclaration> functions(InterfaceDeclaration interfaceDeclaration)
    {
        val functionCollection = new HashSet<FunctionDeclaration>

        functionCollection.addAll(interfaceDeclaration.contains.filter(FunctionDeclaration))
        for (parent : interfaceDeclaration.derivesFrom)
        {
            functionCollection.addAll(parent.functions)
        }

        return functionCollection.sortBy[name]
    }

    /**
     * For a given interface, return all function it offers, i.e. own functions
     * as well as functions from all super classes.
     */
    static def Iterable<EventDeclaration> events(InterfaceDeclaration interfaceDeclaration)
    {
        val eventCollection = new HashSet<EventDeclaration>

        eventCollection.addAll(interfaceDeclaration.contains.filter(EventDeclaration))
        for (parent : interfaceDeclaration.derivesFrom)
        {
            eventCollection.addAll(parent.events)
        }

        return eventCollection.sortBy[data.name]
    }

    /**
     * Allows to print the given text for any object: useful, when we need
     * to resolve a type, but do not want/may not print the resulting string.
     */
    @Deprecated
    static def String alias(Object object, String text)
    {
        text
    }

    /**
     * Requirements are all elements, which are essentially needed by the given
     * element, no matter if defined externally or internally.
     */
    static def dispatch Collection<AbstractTypeReference> requirements(StructDeclaration element)
    {
        val result = new HashSet<AbstractTypeReference>(element.members.size)
        for (member : element.members)
        {
            if (Util.isStruct(member.type))
                result.add(Util.getUltimateType(member.type) as StructDeclaration)
        }
        return result
    }

    static def dispatch Collection<AbstractTypeReference> requirements(ExceptionDeclaration element)
    {
        val result = new HashSet<AbstractTypeReference>(element.members.size)
        for (member : element.members)
        {
            if (Util.isException(member.type))
                result.add(Util.getUltimateType(member.type) as ExceptionDeclaration)
        }
        return result
    }

    static def dispatch Collection<AbstractTypeReference> requirements(AbstractTypeReference element)
    {
        return #[] // default: none
    }

    static def boolean isAllUpperCase(String text)
    {
        return text.chars.allMatch(c|Character.isUpperCase(c))
    }

    static def dispatch Collection<StructDeclaration> getBaseTypes(StructDeclaration element)
    {
        val baseTypes = new HashSet<StructDeclaration>
        var currentType = element.supertype
        while (currentType !== null && !(baseTypes.contains(currentType)))
        {
            baseTypes.add(currentType)
            currentType = currentType.supertype
        }
        return baseTypes
    }

    static def dispatch Collection<InterfaceDeclaration> getBaseTypes(InterfaceDeclaration element)
    {
        val baseTypes = new HashSet<InterfaceDeclaration>
        collectBaseTypes(element, baseTypes)
        return baseTypes
    }

    private static def void collectBaseTypes(InterfaceDeclaration element, HashSet<InterfaceDeclaration> baseTypes)
    {
        for (baseType : element.derivesFrom)
        {
            if (!baseTypes.contains(baseType))
            {
                baseTypes.add(baseType)
                collectBaseTypes(baseType, baseTypes)
            }
        }
    }

    static def dispatch Collection<AbstractException> getBaseTypes(ExceptionDeclaration element)
    {
        val baseTypes = new HashSet<AbstractException>
        var currentType = element.supertype
        while (currentType !== null && !(baseTypes.contains(currentType)))
        {
            baseTypes.add(currentType)
            if (currentType instanceof ExceptionDeclaration)
                currentType = currentType.supertype
            else
                currentType = null
        }
        return baseTypes
    }

    /**
     * For a given element, return all members it offers, i.e. own members
     * as well as members from all super classes.
     */
    static def dispatch Iterable<MemberElementWrapper> allMembers(StructDeclaration element)
    {
        if (element.supertype !== null)
        {
            val baseTypes = element.baseTypes as Collection<StructDeclaration>
            val allMembers = baseTypes.map[effectiveMembers].flatten.toList
            allMembers.addAll(element.effectiveMembers)
            return allMembers
        }
        else
        {
            return element.effectiveMembers
        }
    }

    static def dispatch Iterable<MemberElementWrapper> allMembers(ExceptionDeclaration element)
    {
        if (element.supertype !== null)
        {
            val baseTypes = element.baseTypes.filter(ExceptionDeclaration)
            val allMembers = baseTypes.map[members].flatten.map[e|e.wrapMember].toList
            allMembers.addAll(element.members.map[e|e.wrapMember])
            return allMembers
        }
        else
        {
            return element.members.map[e|e.wrapMember]
        }
    }

    /**
     * For a given element, return its effective members. Effective members are
     * all OWN (!) members + type declarations with an identifier. Example:
     * 
     * struct S1
     * {
     *     string mem1;
     *    
     *    struct S2
     *    {
     *        //...
     *    } mem2;
     * }
     * 
     * The result will be [mem1, mem2].
     * 
     */
    static def dispatch Iterable<MemberElementWrapper> effectiveMembers(StructDeclaration element)
    {
        val result = new ArrayList<MemberElementWrapper>
        result.addAll(element.members.map[e|e.wrapMember])
        element.typeDecls.filter(EnumDeclaration).filter[declarator !== null].forEach[e|result.add(e.wrapMember)]
        element.typeDecls.filter(StructDeclaration).filter[declarator !== null].forEach[e|result.add(e.wrapMember)]
        return result
    }

    static def dispatch Iterable<MemberElementWrapper> effectiveMembers(ExceptionDeclaration element)
    {
        return element.members.map[e|e.wrapMember]
    }

    static def dispatch Iterable<MemberElementWrapper> effectiveMembers(AbstractTypeReference element)
    {
        return #[] // default case: no members
    }

    private static def dispatch MemberElementWrapper wrapMember(MemberElement member)
    {
        return new MemberElementWrapper(member)
    }

    private static def dispatch MemberElementWrapper wrapMember(StructDeclaration struct)
    {
        return new MemberElementWrapper(struct)
    }

    private static def dispatch MemberElementWrapper wrapMember(EnumDeclaration enumDeclaration)
    {
        return new MemberElementWrapper(enumDeclaration)
    }

    static def namedEvents(InterfaceDeclaration interfaceDeclaration)
    {
        // TODO the events function also includes inherited events, check whether these 
        // should be included here as well. Adjust naming of the methods. 
        interfaceDeclaration.contains.filter(EventDeclaration).filter[name !== null]
    }

    static def getActualType(AbstractType abstractType)
    {
        JavaUtil.checkConsistency(abstractType);
        abstractType.primitiveType ?: abstractType.referenceType ?: abstractType.collectionType
    }

    static def AbstractTypeReference getActualType(ReturnTypeElement returnTypeElement)
    {
        if (returnTypeElement instanceof AbstractType)
            returnTypeElement.actualType
        else
            returnTypeElement as VoidType
    }
}
