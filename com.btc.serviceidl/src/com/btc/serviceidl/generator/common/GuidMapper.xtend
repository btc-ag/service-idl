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
/** 
 * \file       GuidMapper.xtend
 * 
 * \brief      Distribute GUIDs for interfaces and events
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.idl.UniquelyIdentifiedDeclaration
import java.util.HashMap
import java.util.UUID

class GuidMapper
{
    static val guidMap = new HashMap<UniquelyIdentifiedDeclaration, String>

    def static void put(UniquelyIdentifiedDeclaration object, String guid)
    {
        guidMap.put(object, guid)
    }

    def static String get(UniquelyIdentifiedDeclaration object)
    {
        guidMap.computeIfAbsent(object, [UUID.randomUUID.toString.toUpperCase])
    }
}
