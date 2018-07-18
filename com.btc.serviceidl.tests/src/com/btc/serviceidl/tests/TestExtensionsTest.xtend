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
package com.btc.serviceidl.tests

import org.junit.Test

import static extension com.btc.serviceidl.tests.TestExtensions.*
import static org.junit.Assert.*

class TestExtensionsTest
{
    @Test
    def void testNormalizeWithNewlines()
    {
        val normalized = '''
        a
        b'''.toString.normalize
        assertEquals("a b", normalized)
    }

    @Test
    def void testNormalizeLeading()
    {
        val normalized = "  a".normalize
        assertEquals("a", normalized)
    }

    @Test
    def void testNormalizeTrailing()
    {
        val normalized = "a   ".normalize
        assertEquals("a", normalized)
    }

    @Test
    def void testNormalizeMultiple()
    {
        val normalized = "a   b".normalize
        assertEquals("a b", normalized)
    }
}
