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

}
