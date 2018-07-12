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
 * \file       Util.xtend
 * 
 * \brief      Miscellaneous common utility methods
 */
package com.btc.serviceidl.util

import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractCrossReference
import com.btc.serviceidl.idl.AbstractException
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.DocCommentElement
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import java.util.ArrayDeque
import java.util.Deque
import java.util.HashSet
import java.util.Optional
import java.util.function.Function
import java.util.regex.Pattern
import java.util.stream.Stream
import java.util.stream.StreamSupport
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.util.Extensions.*

class Util
{
    /**
     * Given a predicate, add a new line or return empty string
     */
    def static String addNewLine(boolean add_new_line)
    {
        '''
            «IF add_new_line»
                
            «ENDIF»
        '''
    }

    def private static String makeBasicMessageName(String name, String message_type)
    {
        return name + message_type
    }

    /**
     * Converts the given name into Protobuf request message name.
     */
    def static String asRequest(String name)
    {
        makeBasicMessageName(name, Constants.PROTOBUF_REQUEST)
    }

    /**
     * Converts given name into Protobuf response message name.
     */
    def static String asResponse(String name)
    {
        makeBasicMessageName(name, Constants.PROTOBUF_RESPONSE)
    }

    def static Iterable<ModuleDeclaration> getModuleStack(EObject element)
    {
        var module_stack = new ArrayDeque<ModuleDeclaration>
        var current_container = if (element instanceof ModuleDeclaration) element else element.eContainer

        while (current_container !== null && !(current_container instanceof IDLSpecification))
        {
            if (current_container instanceof ModuleDeclaration)
                module_stack.push(current_container)
            current_container = current_container.eContainer
        }

        return module_stack
    }

    def static <T> T getParent(EObject element, Class<T> t)
    {
        if (t.isAssignableFrom(element.class)) element as T else getParent(element.eContainer, t)
    }

    def static AbstractContainerDeclaration getScopeDeterminant(EObject element)
    {
        var container = element
        while (container !== null)
        {
            if (container instanceof AbstractContainerDeclaration)
                return container
            else
                container = container.eContainer
        }
        throw new IllegalArgumentException 
    }

    def static EventDeclaration getRelatedEvent(StructDeclaration object)
    {
        return object.getParent(IDLSpecification).eAllContents.filter(EventDeclaration).findFirst[data === object]
    }

    def static EventDeclaration getAnonymousEvent(InterfaceDeclaration interface_declaration)
    {
        return interface_declaration.contains.filter(EventDeclaration).filter[name === null].head as EventDeclaration
    }

    /**
     * Get all structures which act message types in event within the given interface.
     */
    def static Iterable<StructDeclaration> getEventStructures(IDLSpecification idl,
        InterfaceDeclaration interface_declaration)
    {
        val event_structs = new HashSet<StructDeclaration>
        for (struct : idl.eAllContents.filter(StructDeclaration).toIterable)
        {
            if (!interface_declaration.contains.filter(EventDeclaration).filter[data === struct].empty)
                event_structs.add(struct)
        }
        return event_structs
    }

    def static Iterable<AbstractException> getRaisedExceptions(AbstractContainerDeclaration container)
    {
        val exceptions = new HashSet<AbstractException>
        for (function : container.eContents.filter(FunctionDeclaration))
        {
            for (exception : function.raisedExceptions)
            {
                exceptions.add(exception)
            }
        }

        return exceptions
    }

    /**
     * Is the given element a sequence? For example, we then need to call the
     * Google Protobuf method as get...List()
     */
    def static boolean isSequenceType(EObject element)
    {
        tryGetSequence(element).present
    }

    /**
     * Does the given element represents a UUID type? 
     */
    def static boolean isUUIDType(EObject element)
    {
        if (element === null) return false

        if (element instanceof PrimitiveType)
        {
            return (element.uuidType !== null)
        }
        else if (element instanceof AbstractType)
        {
            return isUUIDType(element.primitiveType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isUUIDType(element.type)
        }

        return false
    }

    /**
     * Does the given element represents an Enum type? 
     */
    def static boolean isEnumType(EObject element)
    {
        if (element === null) return false

        if (element instanceof EnumDeclaration)
            return true

        if (element instanceof AbstractType)
        {
            return isEnumType(element.referenceType)
        }

        if (element instanceof AliasDeclaration)
        {
            return isEnumType(element.type)
        }

        return false
    }

    /**
     * Does the given element represents a Byte type? 
     */
    def static boolean isByte(EObject element)
    {
        if (element === null) return false

        if (element instanceof PrimitiveType)
        {
            return element.isByte
        }
        else if (element instanceof AbstractType)
        {
            return isByte(element.primitiveType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isByte(element.type)
        }

        return false
    }

    /**
     * Does the given element represents a Int16 type? 
     */
    def static boolean isInt16(EObject element)
    {
        if (element === null) return false

        if (element instanceof PrimitiveType)
        {
            return element.isInt16
        }
        else if (element instanceof AbstractType)
        {
            return isInt16(element.primitiveType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isInt16(element.type)
        }

        return false
    }

    /**
     * Does the given element represents a Char type? 
     */
    def static boolean isChar(EObject element)
    {
        if (element === null) return false

        if (element instanceof PrimitiveType)
        {
            return (element.charType !== null)
        }
        else if (element instanceof AbstractType)
        {
            return isChar(element.primitiveType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isChar(element.type)
        }

        return false
    }

    /**
     * Does the given element represents a primitive type? 
     */
    def static boolean isPrimitive(EObject element)
    {
        if (element === null) return false

        if (element instanceof PrimitiveType)
        {
            return true
        }
        else if (element instanceof AbstractType)
        {
            return isPrimitive(element.primitiveType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isPrimitive(element.type)
        }

        return false
    }

    /**
     * Does the given element represents a structure type? 
     */
    def static boolean isStruct(EObject element)
    {
        if (element === null) return false

        if (element instanceof StructDeclaration)
        {
            return true
        }
        else if (element instanceof AbstractType)
        {
            return isStruct(element.referenceType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isStruct(element.type)
        }

        return false
    }

    def static AbstractTypeReference getStructType(EObject element)
    {
        if (element instanceof StructDeclaration)
        {
            return element
        }
        else if (element instanceof AbstractType)
        {
            return element.actualType
        }
        else if (element instanceof AliasDeclaration)
        {
            return element.type.actualType
        }

        throw new IllegalArgumentException
    }

    /**
     * Does the given element represents an exception type? 
     */
    def static boolean isException(EObject element)
    {
        if (element === null) return false

        if (element instanceof ExceptionDeclaration)
        {
            return true
        }
        else if (element instanceof AbstractType)
        {
            return isException(element.referenceType)
        }
        else if (element instanceof AliasDeclaration)
        {
            return isException(element.type)
        }

        return false
    }

    /**
     * Does the given element represents an abstract cross reference type? 
     */
    def static boolean isAbstractCrossReferenceType(EObject element)
    {
        if (element === null) return false

        if (element instanceof AbstractCrossReference)
        {
            return true
        }
        else if (element instanceof AbstractType)
        {
            return isAbstractCrossReferenceType(element.referenceType)
        }

        return false
    }

    /**
     * Does the given element represents an alias type? 
     */
    def static boolean isAlias(EObject element)
    {
        if (element === null) return false

        if (element instanceof AliasDeclaration)
        {
            return true
        }
        else if (element instanceof AbstractType)
        {
            return isAlias(element.referenceType)
        }

        return false
    }

    /**
     * Return the path to the *.proto file with base type definitions.
     */
    def static String getProtobufBaseTypesPath()
    {
        return "ServiceComm/ProtobufUtil/gen/BaseTypes.proto"
    }

    /**
     * If given element is a sequence (of sequence of sequence... of type T),
     * go deep to retrieve T; otherwise return element immediately. 
     */
    def static AbstractTypeReference getUltimateType(AbstractTypeReference element)
    {
        return getUltimateType(element, true)
    }

    def static AbstractTypeReference getUltimateType(AbstractType element)
    {
        element.actualType.ultimateType
    }

    def static boolean isFailable(EObject element)
    {
        val sequence = tryGetSequence(element)
        return (sequence.present && sequence.get.failable)
    }

    def static Optional<SequenceDeclaration> tryGetSequence(EObject element)
    {
        if (element instanceof SequenceDeclaration)
            return Optional.of(element)

        if (element instanceof AbstractType)
            return tryGetSequence(element.collectionType)

        if (element instanceof AliasDeclaration)
            return tryGetSequence(element.type)

        if (element instanceof MemberElement)
            return tryGetSequence(element.type)

        if (element instanceof ParameterElement)
            return tryGetSequence(element.paramType)

        return Optional.empty
    }

    /**
     * Core logic for getUltimateType; the flag "decompose_typedef" allows us either
     * to get the basic type defined by this typedef (true) or the typedef itself (false).
     */
    def static AbstractTypeReference getUltimateType(AbstractTypeReference element, boolean decompose_typedef)
    {
        if (element instanceof SequenceDeclaration)
            return getUltimateType(element.type.actualType, decompose_typedef)
        else if (element instanceof ParameterElement)
            return getUltimateType(element.paramType.actualType, decompose_typedef)
        else if (element instanceof AliasDeclaration)
        {
            if (decompose_typedef)
                return getUltimateType((element as AliasDeclaration).type.actualType, decompose_typedef)
            else
                return element
        }
        else
            return element
    }

    /**
     * Format a comment element as plain text. Line breaks are preserved at proper places!
     */
    def static String getPlainText(DocCommentElement comment)
    {
        return comment.text.replaceAll("\\p{Blank}+", " ").replaceAll("\\p{Cntrl}\\p{Blank}", "").replaceAll(
            Pattern.quote("<#"), "").replaceAll(Pattern.quote("#>"), "").replaceFirst("^" + Pattern.quote("#"), "").trim
    }

    /**
     * This method generates a consistent name for exceptions used on all sides
     * of the ServiceComm framework in order to correctly resolve the type.
     */
    static def String getCommonExceptionName(AbstractException exception, IQualifiedNameProvider name_provider)
    {
        return name_provider.getFullyQualifiedName(exception).toString
    }

    static def <T> boolean ensurePresentOrThrow(Optional<T> optional)
    {
        if (!optional.present)
            throw new IllegalArgumentException("Optional value missing!")

        return true
    }

    static def Iterable<AbstractException> getFailableExceptions(AbstractContainerDeclaration container)
    {
        var exceptions = new HashSet<AbstractException>

        // interfaces: special handling due to inheritance
        if (container instanceof InterfaceDeclaration)
        {
            // function parameters
            val from_parameters = container.functions.map[parameters].flatten.map[tryGetSequence].filter[present].map [
                get
            ].map[raisedExceptions].flatten

            // function return values
            val from_return_values = container.functions.map[returnedType].map[tryGetSequence].filter[present].map[get].
                map[raisedExceptions].flatten

            exceptions.addAll(from_parameters)
            exceptions.addAll(from_return_values)
        }

        val contents = container.eAllContents.toList

        // typedefs
        exceptions.addAll(
            contents.filter(AliasDeclaration).map[tryGetSequence].filter[present].map[get].map[raisedExceptions].flatten
        )

        // structs
        exceptions.addAll(
            contents.filter(StructDeclaration).map[members].flatten.map[tryGetSequence].filter[present].map[get].map [
                raisedExceptions
            ].flatten
        )

        return exceptions.sortBy[name]
    }

    static def <T> stream(Iterable<T> iterable)
    {
        StreamSupport.stream(iterable.spliterator, false)
    }

    static def <T> flatten(Stream<Stream<T>> stream)
    {
        stream.flatMap(
            Function.identity
        );
    }
}
