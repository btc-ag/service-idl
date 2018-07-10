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

import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
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
import com.btc.serviceidl.idl.StructDeclaration
import java.util.ArrayList
import java.util.Collection
import java.util.HashSet
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.idl.AbstractContainerDeclaration

class Extensions
{
    static def boolean isByte(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("byte"))
    }

    static def boolean isInt16(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("int16"))
    }

    static def boolean isInt32(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type !== null && primitive_type.integerType !== null &&
            primitive_type.integerType.equals("int32"))
    }

    static def boolean isInt64(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.integerType !== null && primitive_type.integerType.equals("int64"))
    }

    static def boolean isChar(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.charType !== null)
    }

    static def boolean isString(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.stringType !== null)
    }

    static def boolean isUUID(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.uuidType !== null)
    }

    static def boolean isBoolean(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.booleanType !== null)
    }

    static def boolean isDouble(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.floatingPointType !== null &&
            primitive_type.floatingPointType.equals("double"))
    }

    static def boolean isFloat(PrimitiveType primitive_type)
    {
        (primitive_type !== null && primitive_type.floatingPointType !== null &&
            primitive_type.floatingPointType.equals("float"))
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
    static def boolean isOutputParameter(EObject element)
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
    static def Iterable<FunctionDeclaration> functions(InterfaceDeclaration interface_declaration)
    {
        val function_collection = new HashSet<FunctionDeclaration>

        function_collection.addAll(interface_declaration.contains.filter(FunctionDeclaration))
        for (parent : interface_declaration.derivesFrom)
        {
            function_collection.addAll(parent.functions)
        }

        return function_collection.sortBy[name]
    }

    /**
     * For a given interface, return all function it offers, i.e. own functions
     * as well as functions from all super classes.
     */
    static def Iterable<EventDeclaration> events(InterfaceDeclaration interface_declaration)
    {
        val event_collection = new HashSet<EventDeclaration>

        event_collection.addAll(interface_declaration.contains.filter(EventDeclaration))
        for (parent : interface_declaration.derivesFrom)
        {
            event_collection.addAll(parent.events)
        }

        return event_collection.sortBy[data.name]
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
    static def dispatch Collection<EObject> requirements(StructDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            if (Util.isStruct(member.type))
                result.add(Util.getUltimateType(member.type) as StructDeclaration)
        }
        return result
    }

    static def dispatch Collection<EObject> requirements(ExceptionDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            if (Util.isException(member.type))
                result.add(Util.getUltimateType(member.type) as ExceptionDeclaration)
        }
        return result
    }

    static def dispatch Collection<EObject> requirements(EObject element)
    {
        return #[] // default: none
    }

    private static def dispatch void getUnderlyingTypes(StructDeclaration element, HashSet<EObject> all_types)
    {
        for (type : element.members)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }
    }

    private static def dispatch void getUnderlyingTypes(AliasDeclaration element, HashSet<EObject> all_types)
    {
        val type = Util.getUltimateType(element)

        if (!all_types.contains(type))
            getUnderlyingTypes(type, all_types)

        if (!Util.isPrimitive(type))
            all_types.add(type)
    }

    private static def dispatch void getUnderlyingTypes(ExceptionDeclaration element, HashSet<EObject> all_types)
    {
        for (type : element.members)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }
    }

    private static def dispatch void getUnderlyingTypes(EObject element, HashSet<EObject> all_types)
    {
        // do nothing by default
    }

    static def boolean isAllUpperCase(String text)
    {
        return text.chars.allMatch(c|Character.isUpperCase(c))
    }

    static def dispatch Collection<StructDeclaration> getBaseTypes(StructDeclaration element)
    {
        val base_types = new HashSet<StructDeclaration>
        var current_type = element.supertype
        while (current_type !== null && !(base_types.contains(current_type)))
        {
            base_types.add(current_type)
            current_type = current_type.supertype
        }
        return base_types
    }

    static def dispatch Collection<InterfaceDeclaration> getBaseTypes(InterfaceDeclaration element)
    {
        val base_types = new HashSet<InterfaceDeclaration>
        collectBaseTypes(element, base_types)
        return base_types
    }

    private static def void collectBaseTypes(InterfaceDeclaration element, HashSet<InterfaceDeclaration> base_types)
    {
        for (base_type : element.derivesFrom)
        {
            if (!base_types.contains(base_type))
            {
                base_types.add(base_type)
                collectBaseTypes(base_type, base_types)
            }
        }
    }

    static def dispatch Collection<AbstractException> getBaseTypes(ExceptionDeclaration element)
    {
        val base_types = new HashSet<AbstractException>
        var current_type = element.supertype
        while (current_type !== null && !(base_types.contains(current_type)))
        {
            base_types.add(current_type)
            if (current_type instanceof ExceptionDeclaration)
                current_type = current_type.supertype
            else
                current_type = null
        }
        return base_types
    }

    /**
     * For a given element, return all members it offers, i.e. own members
     * as well as members from all super classes.
     */
    static def dispatch Iterable<MemberElementWrapper> allMembers(StructDeclaration element)
    {
        if (element.supertype !== null)
        {
            val base_types = element.baseTypes as Collection<StructDeclaration>
            val all_members = base_types.map[effectiveMembers].flatten.toList
            all_members.addAll(element.effectiveMembers)
            return all_members
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
            val base_types = element.baseTypes.filter(ExceptionDeclaration)
            val all_members = base_types.map[members].flatten.map[e|e.wrapMember].toList
            all_members.addAll(element.members.map[e|e.wrapMember])
            return all_members
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

    static def dispatch Iterable<MemberElementWrapper> effectiveMembers(EObject element)
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

    private static def dispatch MemberElementWrapper wrapMember(EnumDeclaration enum_declaration)
    {
        return new MemberElementWrapper(enum_declaration)
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
}
