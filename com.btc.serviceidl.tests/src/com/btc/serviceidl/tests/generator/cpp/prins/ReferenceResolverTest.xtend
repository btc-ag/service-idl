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
package com.btc.serviceidl.tests.generator.cpp.prins

import com.btc.serviceidl.generator.cpp.prins.ReferenceResolver
import org.eclipse.core.runtime.Path
import org.junit.Test

import static org.junit.Assert.*

class ReferenceResolverTest
{
    @Test(expected=IllegalArgumentException)
    def void testModulesHeaderPathToModuleName_Empty_Fails()
    {
        ReferenceResolver.modulesHeaderPathToModuleName(new Path(""))
    }

    @Test(expected=IllegalArgumentException)
    def void testModulesHeaderPathToModuleName_Incomplete_Fails()
    {
        ReferenceResolver.modulesHeaderPathToModuleName(new Path("modules/Commons/GUID.h"))
    }

    @Test(expected=IllegalArgumentException)
    def void testModulesHeaderPathToModuleName_MissingIncludeFragment_Fails()
    {
        ReferenceResolver.modulesHeaderPathToModuleName(new Path("modules/Commons/"))
    }

    @Test(expected=IllegalArgumentException)
    def void testModulesHeaderPathToModuleName_NonModules_Fails()
    {
        ReferenceResolver.modulesHeaderPathToModuleName(new Path("Commons/Core/include/CompilerSettings.h"))
    }

    @Test
    def void testModulesHeaderPathToModuleName_CommonsHeader()
    {
        assertEquals("BTC.PRINS.Commons",
            ReferenceResolver.modulesHeaderPathToModuleName(new Path("modules/Commons/include/GUID.h")))
    }

    @Test
    def void testModulesHeaderPathToModuleName_CommonsUtilitiesHeader()
    {
        assertEquals("BTC.PRINS.Commons.Utilities",
            ReferenceResolver.modulesHeaderPathToModuleName(new Path("modules/Commons/Utilities/include/GUIDHelper.h")))
    }
}
