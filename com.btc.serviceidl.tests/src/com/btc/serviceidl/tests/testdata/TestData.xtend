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
package com.btc.serviceidl.tests.testdata

import java.util.Map
import java.util.HashMap
import java.util.Collections
import java.nio.file.Paths
import com.google.common.io.Resources
import java.nio.charset.Charset
import java.util.jar.JarFile
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.ArrayList
import java.net.URL

class TestData
{
    static def CharSequence getBasic()
    {
        return '''
            virtual module BTC {
            virtual module PRINS { 
            module Infrastructure {
            module ServiceHost {
            module Demo { 
            module API {
            
            interface KeyValueStore[version=1.0.0 guid=384E277A-C343-4F37-B910-C2CE6B37FC8E] { 
            };
            }
            }
            }
            }
            }
            }
        '''

    }

    // TODO rename or change this, it only uses a small set of features of the IDL
    static def CharSequence getFull()
    {
        return '''
            virtual module BTC {
            virtual module PRINS { 
            module Infrastructure {
            module ServiceHost {
            module Demo { 
            module API {
                
            exception MyException {};
            
            struct EntryType 
            {
                uuid id;
                string name;
            };
            
            interface DemoX[version=1.0.0 guid=384E277A-C343-4F37-B910-C2CE6B37FC8E] {
                 AddEntries(in sequence<EntryType> entries) returns void raises MyException;
            };
            }
            }
            }
            }
            }
            }
        '''

    }

    static def CharSequence getEventTestCase()
    {
        return '''
            module foo {
                
            interface Test[version=1.0.0 guid=384E277A-C343-4F37-B910-C2CE6B37FC8E] {
                event TestEvent [guid = 9BFE9AB7-3AA6-441F-82D7-D1A27F6321CE] (TestEventArgs);
                
                struct TestEventArgs{
                  string text;
                };
            };
            }
        '''

    }

    // Adapted from https://stackoverflow.com/a/48190582
    static def Iterable<URL> getFilenamesForDirnameFromClassPath(String directoryName)
    {
        val filenames = new ArrayList<URL>();

        val url = Thread.currentThread().getContextClassLoader().getResource(directoryName);
        if (url !== null)
        {
            if (url.getProtocol().equals("file"))
            {
                val file = Paths.get(url.toURI()).toFile();
                if (file !== null)
                {
                    val files = file.listFiles();
                    if (files !== null)
                    {
                        for (filename : files)
                        {
                            filenames.add(filename.toURI.toURL);
                        }
                    }
                }
            }
            else if (url.getProtocol().equals("jar"))
            {
                val dirname = directoryName + "/";
                val path = url.getPath();
                val jarPath = path.substring(5, path.indexOf("!"));
                // TODO this should use try-with-resources
                val jar = new JarFile(URLDecoder.decode(jarPath, StandardCharsets.UTF_8.name()))
                val entries = jar.entries();
                while (entries.hasMoreElements())
                {
                    val entry = entries.nextElement();
                    val name = entry.getName();
                    if (name.startsWith(dirname) && !dirname.equals(name))
                    {
                        val resource = Thread.currentThread().getContextClassLoader().getResource(name);
                        filenames.add(resource);
                    }
                }
            }
        }
        return filenames;
    }

    /**
     * Enumerates all tests from the "good" directory, i.e. test cases that parse without any warning
     */
    static def Iterable<Map.Entry<String, CharSequence>> getGoodTestCases()
    {
        val testCaseFiles = #[
            getFilenamesForDirnameFromClassPath("com/btc/serviceidl/tests/testdata/good/"),
            getFilenamesForDirnameFromClassPath("com/btc/serviceidl/tests/testdata/good_ext/")
        ].flatten

        val resultMap = new HashMap<String, CharSequence>
        for (testCaseFile : testCaseFiles)
        {
            val path = Paths.get(testCaseFile.toURI)
            resultMap.put(path.getName(path.nameCount - 1).toString,
                Resources.toString(testCaseFile, Charset.defaultCharset))
        }

        return resultMap.entrySet
    }
}
