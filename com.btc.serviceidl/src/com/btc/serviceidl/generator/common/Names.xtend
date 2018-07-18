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
 * \file       Names.xtend
 * 
 * \brief      Functionality related to model element naming
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.idl.AbstractStructuralDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.NamedDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.VoidType

class Names
{
    def static dispatch String plain(ExceptionReferenceDeclaration element)
    { return element.name }

    def static dispatch String plain(ExceptionDeclaration element)
    { return element.name }

    def static dispatch String plain(AliasDeclaration element)
    { return element.name }

    def static dispatch String plain(EnumDeclaration element)
    { return element.name }

    def static dispatch String plain(MemberElement element)
    { return element.name }

    def static dispatch String plain(AbstractStructuralDeclaration element)
    { return (element as NamedDeclaration).name }

    def static dispatch String plain(FunctionDeclaration element)
    { return element.name }

    def static dispatch String plain(EventDeclaration element)
    { return element.name }

    def static dispatch String plain(ParameterElement element)
    { return element.paramName }

    def static dispatch String plain(SequenceDeclaration element)
    { return "Sequence" }

    def static dispatch String plain(TupleDeclaration element)
    { return "Tuple" }

    def static dispatch String plain(VoidType element)
    { "void" }

    def static dispatch String plain(AbstractType item)
    {
        if (item.referenceType !== null)
            return plain(item.referenceType)
        else if (item.collectionType !== null)
            return plain(item.collectionType)

        throw new IllegalArgumentException("Plain name not supported for " + item)
    }

    def static dispatch String plain(PrimitiveType item)
    {
        if (item.integerType !== null)
            return item.integerType
        else if (item.stringType !== null)
            return item.stringType
        else if (item.floatingPointType !== null)
            return item.floatingPointType
        else if (item.uuidType !== null)
            return item.uuidType
        else if (item.booleanType !== null)
            return item.booleanType
        else if (item.charType !== null)
            return item.charType

        throw new IllegalArgumentException("Unknown PrimitiveType: " + item.class.toString)
    }
}
