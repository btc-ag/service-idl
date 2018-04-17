package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import java.util.HashSet
import java.util.Optional

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

// TODO check splitting up this class by logical aspects
class Util
{
    def static Iterable<StructDeclaration> getUnderlyingTypes(StructDeclaration struct)
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
    def static String asMember(String name)
    {
        if (name.allUpperCase)
            name.toLowerCase // it looks better, if ID --> id and not ID --> iD
        else
            name.toFirstLower
    }

    /**
     * Make a C++ parameter name according to BTC naming conventions
     * \see https://wiki.btc-ag.com/confluence/display/GEPROD/Codierungsrichtlinien
     */
    def static String asParameter(String name)
    {
        asMember(name) // currently the same convention
    }

    def static String asBaseName(InterfaceDeclaration interface_declaration)
    {
        '''«interface_declaration.name»Base'''
    }

    def static String getRegisterServerFaults(InterfaceDeclaration interface_declaration, Optional<String> namespace)
    {
        '''«IF namespace.present»«namespace.get»::«ENDIF»Register«interface_declaration.name»ServiceFaults'''
    }

    def static String getObservableName(EventDeclaration event)
    {
        var basic_name = event.name ?: ""
        basic_name += "Observable"
        '''m_«basic_name.asMember»'''
    }

    def static String getObservableRegistrationName(EventDeclaration event)
    {
        event.observableName + "Registration"
    }

    def static String getEventParamsName(EventDeclaration event)
    {
        (event.name ?: "") + "EventParams"
    }

}
