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

import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IdlFactory
import org.junit.Test

import static org.junit.Assert.*

class ParameterBundleTest
{
    @Test
    def void testSet()
    {
        val moduleDeclarationA = IdlFactory.eINSTANCE.createModuleDeclaration
        moduleDeclarationA.name = "a"

        val moduleDeclarationB = IdlFactory.eINSTANCE.createModuleDeclaration
        moduleDeclarationB.name = "b"

        val parameterBundle1 = new ParameterBundle(#[moduleDeclarationA, moduleDeclarationB], ProjectType.SERVICE_API)
        val parameterBundle2 = new ParameterBundle(#[moduleDeclarationA, moduleDeclarationB], ProjectType.SERVICE_API)

        assertEquals(#{parameterBundle1}, #{parameterBundle1, parameterBundle2})
    }
}
