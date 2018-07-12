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
 * \file       MemberElementWrapper.xtend
 * 
 * \brief      Wrapper class to represent a generic struct member.
 *             Reason: the grammar allows to define new types/enums within
 *             a struct; if they have a name ("declarator"), not only the
 *             type itself is defined, but also a member with this name
 *             is added to the struct. Due to struct inheritance, we need
 *             in several places to get all members of the class. Since such
 *             nested type definitions are not contained in the "members"
 *             collection (but effectively lead to struct member in the
 *             generated code and need to be handled as such), we need a way
 *             to use a common representation of "real" and "conceptual" members.
 * 
 * \attention  Be aware, that this is NOT a regular struct member, in particular,
 *             it is NOT part of the abstract syntax tree model of the IDL.
 */
package com.btc.serviceidl.util

import com.btc.serviceidl.idl.AbstractStructuralDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.StructDeclaration
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(PUBLIC_GETTER)
class MemberElementWrapper
{
    val AbstractTypeReference type
    val String name
    val boolean optional
    val AbstractStructuralDeclaration container

    new(MemberElement member)
    {
        type = member.type.actualType
        name = member.name
        optional = member.optional
        container = member.eContainer as AbstractStructuralDeclaration
    }

    new(StructDeclaration struct)
    {
        type = struct
        name = struct.declarator
        optional = false
        container = struct.eContainer as AbstractStructuralDeclaration
    }

    new(EnumDeclaration enum_declaration)
    {
        type = enum_declaration
        name = enum_declaration.declarator
        optional = false
        container = enum_declaration.eContainer as AbstractStructuralDeclaration
    }
}
