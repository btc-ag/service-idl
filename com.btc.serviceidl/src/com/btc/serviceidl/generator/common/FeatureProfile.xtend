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
 * \file       FeatureProfile.xtend
 * 
 * \brief      Easy feature profiling for a given element or collection
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.idl.AbstractModuleComponent

class FeatureProfile
{

    new(AbstractContainerDeclaration element)
    {
        evaluate(element)
    }

    new(Iterable<AbstractModuleComponent> contents)
    {
        for (c : contents)
            evaluate(c)
    }

    private def void evaluate(EObject element)
    {
        var contents = element.eAllContents.toList
        contents.add(element)

        usesTuples = usesTuples || contents.exists[o|o instanceof TupleDeclaration]

        usesStrings = usesStrings || contents.filter(PrimitiveType).exists[stringType !== null]

        usesFutures = usesFutures || contents.filter(FunctionDeclaration).exists[!isSync]

        usesEvents = usesEvents || contents.exists[o|o instanceof EventDeclaration]

        usesSequences = usesSequences || contents.exists[o|o instanceof SequenceDeclaration]

        usesFailableHandles = usesFailableHandles || contents.filter(SequenceDeclaration).exists[isFailable]

        usesOptionals = usesOptionals || contents.filter(MemberElement).exists[isOptional]

        usesCstdint = usesCstdint || contents.filter(PrimitiveType).exists[integerType !== null]

        usesExceptions = usesExceptions || contents.filter(ExceptionDeclaration).exists[supertype === null]

        usesUuids = usesUuids || contents.filter(PrimitiveType).exists[uuidType !== null]

        usesObjects = usesObjects || contents.filter(InterfaceDeclaration).exists[derivesFrom === null]
    }

    public boolean usesTuples;
    public boolean usesStrings;
    public boolean usesFutures;
    public boolean usesEvents;
    public boolean usesSequences;
    public boolean usesFailableHandles;
    public boolean usesOptionals;
    public boolean usesCstdint;
    public boolean usesExceptions;
    public boolean usesObjects;
    public boolean usesUuids;
}
