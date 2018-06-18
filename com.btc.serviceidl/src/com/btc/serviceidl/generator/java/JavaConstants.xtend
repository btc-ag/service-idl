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
package com.btc.serviceidl.generator.java;

import java.util.Set;

class JavaConstants {
    public static val String      SERVICECOMM_VERSION_KIND = "java.servicecomm";
    public static val Set<String> SERVICECOMM_VERSIONS     = ServiceCommVersion.values.map[label].toSet.immutableCopy;
}
