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
package com.btc.serviceidl.util.tests

import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.util.Constants
import com.google.inject.Inject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*

import static extension com.btc.serviceidl.util.Util.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class UtilTest
{
    @Inject extension ParseHelper<IDLSpecification>

    @Test
    def void testResolveVersionWithVersion()
    {
        val idl = '''version 1.2.3; module foo { interface Bar {}; }'''.parse
        assertEquals("1.2.3", idl.resolveVersion)
    }

    @Test
    def void testResolveVersionWithOutVersion()
    {
        val idl = '''module foo { interface Bar {}; }'''.parse
        assertEquals(Constants.DEFAULT_VERSION, idl.resolveVersion)
    }
}
