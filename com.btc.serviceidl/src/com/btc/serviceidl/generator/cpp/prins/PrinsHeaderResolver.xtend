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
package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.cpp.HeaderResolver
import com.btc.serviceidl.generator.cpp.TypeResolver

class PrinsHeaderResolver
{
    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val odb_header_mapper = #{
        "id_raw" -> "odb/oracle/traits.hxx",
        "id_uniqueidentifier" -> "odb/mssql/traits.hxx",
        "odb::nullable" -> "odb/nullable.hxx"
    }

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    private static val modules_header_mapper = #{
        "BTC::PRINS::Commons::GUID" -> "modules/Commons/include/GUID.h",
        "BTC::PRINS::Commons::Utilities::GUIDHelper" -> "modules/Commons/Utilities/include/GUIDHelper.h"
    }

    private def static withPrinsGroups(HeaderResolver.Builder builder)
    {
        builder.withBasicGroups.withGroup(odb_header_mapper, TypeResolver.ODB_INCLUDE_GROUP).withGroup(
            modules_header_mapper, TypeResolver.MODULES_INCLUDE_GROUP)
    }

    public def static create()
    {
        new HeaderResolver.Builder().withPrinsGroups.build
    }
}
