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
package com.btc.serviceidl.tests.generator.common

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class GeneratorUtilTest
{
    @Inject extension ParseHelper<IDLSpecification>

    @Test
    def void testGetFailableTypesWithFailableInput()
    {
        val idl = TestData.getGoodTestCase("interface-with-failable-input").parse
        val failableTypes = GeneratorUtil.getFailableTypes(idl.eAllContents.filter(InterfaceDeclaration).head).toList
        
        assertEquals(#[idl.eAllContents.filter(PrimitiveType).head], failableTypes)
    }
}
