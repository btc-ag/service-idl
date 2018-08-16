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

import com.btc.serviceidl.generator.dotnet.NuGetPackage
import org.junit.Test

import static org.junit.Assert.*

import static extension com.btc.serviceidl.generator.dotnet.Util.*

class UtilTest
{
    @Test
    def void testGetFlatPackages()
    {
        val input = #[
            new NuGetPackage(#[new Pair<String, String>("B", "1.0.0")], "B", "packages/B.dll"),
            new NuGetPackage(#[new Pair<String, String>("A", "1.0.0")], "A", "packages/A.dll"),
            new NuGetPackage(#[new Pair<String, String>("A", "1.0.0")], "A", "packages/A.dll")
        ]
        val result = input.flatPackages
        assertArrayEquals(#[new Pair<String, String>("A", "1.0.0"), new Pair<String, String>("B", "1.0.0")], result)
    }
}
