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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.PackageInfoProvider
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.btc.serviceidl.util.Constants
import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class PackageInfoTest
{
    @Inject extension ParseHelper<IDLSpecification>
    @Inject Provider<ResourceSet> rsp
    
    @Test
    def testDefaultVersion()
    {
        val result = PackageInfoProvider.getVersion(TestData.basic.parse.eResource)
        assertEquals(Constants.DEFAULT_VERSION, result)
    }
    
    @Test
    def testCustomVersion()
    {
        val result = PackageInfoProvider.getVersion(TestData.versioned.parse.eResource)
        assertEquals("0.7.0", result)
    }
    
    @Test
    def testPackageInfo()
    {
        val rs = rsp.get()
        val resource = rs.getResource(URI.createURI("src/com/btc/serviceidl/tests/testdata/import-imported.idl"), true)
        val result = PackageInfoProvider.getPackageInfo(resource)
        assertEquals("BTC.PRINS.Imported", result.getID(ArtifactNature.CPP))
        assertEquals("0.3.0", result.version)
    }
    
    @Test
    def testNameFullyQualifiedBased()
    {
        val expected = "BTC.PRINS.DemoPackage"
        ProjectType.values.forEach[assertEquals(expected, PackageInfoProvider.getID('''BTC.PRINS.DemoPackage.«it.getName»'''))]
        assertEquals(expected, PackageInfoProvider.getID('''BTC.PRINS.DemoPackage.«ProjectType.COMMON.getName».ContainingInterface.NestedClass'''))
    }

    @Test
    def testNamePathBased()
    {
        val expected = "BTC.PRINS.DemoPackage"
        ProjectType.values.forEach[assertEquals(expected, PackageInfoProvider.getID('''BTC/PRINS/DemoPackage/«it.getName»'''))]
    }
}
