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
package com.btc.serviceidl.generator.cpp;

import java.util.Set;

import com.btc.serviceidl.util.Constants;

class CppConstants
{
    public static val String PROTOBUF_INCLUDE_DIRECTORY_NAME = Constants.PROTOBUF_GENERATION_DIRECTORY_NAME

    public static val String SERVICECOMM_VERSION_KIND = "cpp.servicecomm"
    public static val Set<String> SERVICECOMM_VERSIONS = ServiceCommVersion.values.map[label].toSet.immutableCopy
}
