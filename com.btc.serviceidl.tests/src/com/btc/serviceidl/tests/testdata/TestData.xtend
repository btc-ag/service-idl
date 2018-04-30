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

}
