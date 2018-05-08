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
package com.btc.serviceidl.tests.cmdline

import java.io.File
import org.junit.Test

import static org.junit.Assert.*
import java.io.BufferedReader
import java.io.InputStreamReader
import org.junit.Ignore
import com.btc.serviceidl.generator.Main
import java.util.Arrays
import java.nio.file.Files

class CommandLineRunnerTest
{
    @Test
    def void testWithoutArgs()
    {
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main")

        assertEquals(1, process.waitFor)
    }

    @Test
    def void testWithNonExistentInputFile()
    {
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main Z:\\foo.bar")

        assertEquals(1, process.waitFor)
    }

    @Ignore("TODO check how to set the classpath such that this works from the test")
    @Test
    def void testWithValidInput()
    {
        val file = new File("src/com/btc/serviceidl/tests/testdata/base.idl");
        System.out.println(file.absolutePath);
        val process = Runtime.getRuntime().exec("java com.btc.serviceidl.generator.Main " + file.absolutePath)

        val errorReader = new BufferedReader(new InputStreamReader(process.errorStream))
        var res = new String
        var String line = null
        while ((line = errorReader.readLine()) !== null)
        {
            res += line;
        }
        System.out.println(res);

        assertEquals(0, process.waitFor)
    }

    def static Iterable<File> listFilesRecursively(File base)
    {
        if (base.directory)
            base.listFiles.map[it.listFilesRecursively].flatten
        else
            Arrays.asList(base)
    }

    @Test
    def void testWithValidInputInProcess()
    {
        val file = new File("src/com/btc/serviceidl/tests/testdata/base.idl")
        val path = Files.createTempDirectory("test-gen")
        Main.main(Arrays.asList(file.absolutePath, "-outputPath", path.toString))
        val files = path.toFile.listFilesRecursively
        assertEquals(25, files.size)
    }

    @Test
    def void testWithValidInputWithWarningsInProcess()
    {
        val file = new File("src/com/btc/serviceidl/tests/testdata/failable.idl")
        val path = Files.createTempDirectory("test-gen")
        Main.main(Arrays.asList(file.absolutePath, "-outputPath", path.toString))
        val files = path.toFile.listFilesRecursively
        // TODO check output for Warnings!
        assertEquals(103, files.size)
    }
}
