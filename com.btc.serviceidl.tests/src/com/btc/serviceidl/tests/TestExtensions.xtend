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

import com.google.common.collect.ImmutableSet
import java.util.ArrayList
import java.util.Map.Entry
import org.eclipse.xtext.generator.InMemoryFileSystemAccess

import static org.junit.Assert.*

class TestExtensions
{
    static def <T> setOf(T... elements)
    { ImmutableSet.copyOf(elements) }

    static def <T> asSet(Iterable<T> iterable)
    { ImmutableSet.copyOf(iterable) }

    static def normalize(String arg)
    { arg.replaceAll("\\s+", " ").trim }

    static def assertEqualsNormalized(String expected, String actual)
    {
        assertEquals(expected.normalize, actual.normalize)
    }

    static def assertEqualsNormalized(CharSequence expected, CharSequence actual)
    {
        assertEquals(expected.toString.normalize, actual.toString.normalize)
    }

    static def void checkFile(InMemoryFileSystemAccess fsa, String headerLocation, String content)
    {
        assertTrue(headerLocation, fsa.textFiles.containsKey(headerLocation))

        println(fsa.textFiles.get(headerLocation))

        assertEqualsNormalized(
            content,
            fsa.textFiles.get(headerLocation)
        )
    }

    static def doForEachTestCase(Iterable<Entry<String, CharSequence>> entries,
        (Entry<String, CharSequence>)=>Iterable<String> runTestCase)
    {
        val errors = new ArrayList<String>
        for (testCase : entries)
        {
            System.out.println("Test case '" + testCase.key + "'")
            try
            {
                errors.addAll(runTestCase.apply(testCase))
            }
            catch (Exception e)
            {
                errors.add("Test case '" + testCase.key + "': Exception when parsing: " + e.toString)
            }
        }

        assertTrue(String.join("\n", errors), errors.empty)
    }

}
