package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.HashSet
import java.util.Optional

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

// TODO check splitting up this class by logical aspects
class Util
{
    /**
     * Returns the name of the include directory within a module for a header of the given type.
     */
    static def getIncludeDirectoryName(HeaderType headerType)
    {
        // TODO probably, this should also be made part of a strategy, at least the non-protobuf folder name may be chosen arbitrarily
        if (headerType == HeaderType.PROTOBUF_HEADER) CppConstants.PROTOBUF_INCLUDE_DIRECTORY_NAME else "include"
    }

    static def getFileExtension(HeaderType headerType)
    {
        // TODO probably, this should also be made part of a strategy, at least the non-protobuf folder name may be chosen arbitrarily
        if (headerType == HeaderType.PROTOBUF_HEADER) "pb.h" else "h"
    }

    static def Iterable<StructDeclaration> getUnderlyingTypes(StructDeclaration struct)
    {
        val all_types = new HashSet<StructDeclaration>
        val contained_types = struct.members.filter[type.ultimateType instanceof StructDeclaration].map [
            type.ultimateType as StructDeclaration
        ]

        for (type : contained_types)
        {
            if (!all_types.contains(type))
                all_types.addAll(getUnderlyingTypes(type))
        }

        all_types.addAll(contained_types)
        return all_types
    }

    /**
     * Make a C++ member variable name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    static def String asMember(String name)
    {
        // TODO this should somehow use CaseFormat
        if (name.allUpperCase)
            name.toLowerCase // it looks better, if ID --> id and not ID --> iD
        else
            name.toFirstLower
    }

    /**
     * Make a C++ parameter name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    static def String asParameter(String name)
    {
        asMember(name) // currently the same convention
    }

    static def String asBaseName(InterfaceDeclaration interface_declaration)
    {
        '''«interface_declaration.name»Base'''
    }

    static def String getRegisterServerFaults(InterfaceDeclaration interface_declaration, Optional<String> namespace)
    {
        '''«IF namespace.present»«namespace.get»::«ENDIF»Register«interface_declaration.name»ServiceFaults'''
    }

    static def String getObservableName(EventDeclaration event)
    {
        val basic_name = (event.name ?: "") + "Observable"

        '''m_«basic_name.asMember»'''
    }

    static def String getObservableRegistrationName(EventDeclaration event)
    {
        event.observableName + "Registration"
    }

    static def String getEventParamsName(EventDeclaration event)
    {
        (event.name ?: "") + "EventParams"
    }

    static def int calculateMaximalNameLength(MemberElementWrapper member)
    {
        return member.name.length + if (member.type.isStruct)
            (member.type.ultimateType as StructDeclaration).allMembers.map[calculateMaximalNameLength(it)].max
        else
            0
    }
}
