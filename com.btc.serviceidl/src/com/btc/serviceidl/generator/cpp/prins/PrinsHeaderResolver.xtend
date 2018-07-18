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
import java.util.Arrays

class PrinsHeaderResolver
{
    public static val ODB_INCLUDE_GROUP = new TypeResolver.IncludeGroup("ODB")

    // ******************************* PLEASE ALWAYS KEEP THIS LIST ALPHABETICALLY SORTED !!! ******************************* //
    static val odbHeaderMapper = #{
        "id_binary" -> "odb/mssql/traits.hxx",
        "id_raw" -> "odb/oracle/traits.hxx",
        "id_uniqueidentifier" -> "odb/mssql/traits.hxx",
        "odb::nullable" -> "odb/nullable.hxx"
    }

    private static def withPrinsGroups(HeaderResolver.Builder builder)
    {
        builder.withBasicGroups.withGroup(odbHeaderMapper, ODB_INCLUDE_GROUP).configureGroup(
            Arrays.asList(TypeResolver.TARGET_INCLUDE_GROUP), 0, "", "", false).
            configureGroup(TypeResolver.CAB_INCLUDE_GROUP, 10,
                '''#include "modules/Commons/include/BeginCabInclude.h"     // CAB -->''' + System.lineSeparator, '''#include "modules/Commons/include/EndCabInclude.h"       // <-- CAB

         ''', false).configureGroup(TypeResolver.BOOST_INCLUDE_GROUP, 20,
                '''#include "modules/Commons/include/BeginBoostInclude.h"   // BOOST -->''' + System.lineSeparator, '''#include "modules/Commons/include/EndBoostInclude.h"     // <-- BOOST

         ''', true).configureGroup(ODB_INCLUDE_GROUP, 30, "// ODB" + System.lineSeparator, '''

         ''', true).configureGroup(TypeResolver.STL_INCLUDE_GROUP, 40,
                '''#include "modules/Commons/include/BeginStdInclude.h"     // STD -->''' + System.lineSeparator, '''#include "modules/Commons/include/EndStdInclude.h"       // <-- STD

         ''', true)
    }

    static def create()
    {
        new HeaderResolver.Builder().withPrinsGroups.build
    }
}
