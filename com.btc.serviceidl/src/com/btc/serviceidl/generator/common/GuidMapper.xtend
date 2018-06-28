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

import java.util.HashMap
import org.eclipse.emf.ecore.EObject
import java.util.UUID

class GuidMapper
{

    static val guid_map = new HashMap<EObject, String>

    def static void put(EObject object, String guid)
    {
        guid_map.put(object, guid)
    }

    def static String get(EObject object)
    {
        var guid = guid_map.get(object)
        if (guid === null)
        {
            guid = UUID.randomUUID.toString.toUpperCase
            put(object, guid)
        }
        return guid
    }
}
