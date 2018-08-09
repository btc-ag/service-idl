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
package com.btc.serviceidl.tests.formatter

import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.google.inject.Inject
import org.eclipse.xtext.resource.SaveOptions
import org.eclipse.xtext.serializer.ISerializer
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static org.junit.Assert.*
import static extension com.btc.serviceidl.tests.TestExtensions.*
import com.btc.serviceidl.tests.testdata.TestData

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class IdlFormatterTest
{
    @Inject extension ParseHelper<IDLSpecification>
    @Inject extension ISerializer

    val expectedResult = '''
        virtual module Foo
        {
           module Bar
           {
              interface Demo [ guid = 8B08E141-4DB2-4AD2-BACF-FA4257C42481 ]
              {
                 sync DummyMethod(in string param1, in boolean param2) returns sequence<failable uuid>;
              };
           }
        }
    '''

    // malformed input with arbitrary spaces and line-breaks in-between!
    val testInput = '''virtual     module     Foo {    module    Bar    { 
        interface    Demo    [    guid   =    8B08E141-4DB2-4AD2-BACF-FA4257C42481    
        ]    {    sync    DummyMethod   (  in   string   param1   ,   in   boolean   param2 )   returns  sequence  <  failable   uuid >   ; };
   } }
   '''

    @Test
    def void testFormatter()
    {
        val testResult = testInput.parse.serialize(SaveOptions.newBuilder.format().getOptions()).replace("\t", "   ")
        assertEquals(expectedResult, testResult)
    }

    @Test
    def void testFormattingSmokeTest()
    {
        doForEachTestCase(
            TestData.goodTestCases,
            [ testCase |
                testCase.value.parse.serialize(SaveOptions.newBuilder.format().getOptions())
                // TODO assert that the syntax trees are equivalent 
                #[]
            ]
        )

    }
}
