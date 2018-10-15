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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.PackageInfo
import com.btc.serviceidl.generator.dotnet.CSProjGenerator

import org.junit.Test

import static org.junit.Assert.*
import org.eclipse.emf.common.util.URI

class CSProjGeneratorTest
{
    @Test
    def void testGetProtoPathArguments()
    {
        val dependencies = #[
            new PackageInfo(#{ArtifactNature.DOTNET -> "BTC.PRINS.BaseModule"}, "0.0.3",
                URI.createFileURI("BTC.PRINS.BaseModule.idl")),
            new PackageInfo(#{ArtifactNature.DOTNET -> "BTC.PRINS.Editing"}, "0.1.0",
                URI.createFileURI("BTC.PRINS.Editing.idl"))
        ]
        val result = CSProjGenerator.getProtoPathArguments("$(SolutionDir)", dependencies.toSet)

        assertEquals(
            "--proto_path=$(SolutionDir) --proto_path=$(SolutionDir)packages\\BTC.PRINS.BaseModule\\proto --proto_path=$(SolutionDir)packages\\BTC.PRINS.Editing\\proto",
            result)
    }
}
