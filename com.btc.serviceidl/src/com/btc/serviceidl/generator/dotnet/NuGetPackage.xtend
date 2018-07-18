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
 * \file       NuGetPackage.xtend
 * 
 * \brief      Representation of a NuGet package
 */
package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Data

// TODO this is not correctly modeled, this assumes there is a single assembly per package
@Data
class NuGetPackage
{
    val Iterable<Pair<String, String>> packageVersions
    val String assemblyName
    val String assemblyPath
}
