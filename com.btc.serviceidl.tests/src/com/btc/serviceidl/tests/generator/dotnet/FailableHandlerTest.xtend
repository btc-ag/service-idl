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
package com.btc.serviceidl.tests.generator.dotnet

import com.btc.serviceidl.generator.dotnet.FailableAlias
import org.junit.Test

import static org.junit.Assert.*

class FailableHandlerTest
{
    @Test
    def void testBasicFailableAliasName()
    {
        val testObject = new FailableAlias("Foo")
        assertEquals("Failable_Foo", testObject.aliasName)
    }
    
    @Test
    def void testFullyQualifiedFailableAliasName()
    {
        val testObject = new FailableAlias("Foo.Bar.Xyz")
        assertEquals("Failable_Foo_Bar_Xyz", testObject.aliasName)
    }
    
    @Test
    def void testMixedCaseFailableAliasName()
    {
        val testObject = new FailableAlias("fOo")
        assertEquals("Failable_FOo", testObject.aliasName)
    }
    
    @Test
    def void testFailableAliasComparison()
    {
        val foo1 = new FailableAlias("Foo")
        val foo2 = new FailableAlias("Foo")
        val bar = new FailableAlias("Bar")
        
        assertEquals(true, foo1 == foo2)
        assertEquals(false, foo1 == bar)
    }
}
