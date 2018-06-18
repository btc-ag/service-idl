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

import com.google.common.collect.ImmutableSet;

public class JavaConstants {
    public static final String      SERVICECOMM_VERSION_KIND = "java.servicecomm";
    public static final Set<String> SERVICECOMM_VERSIONS     = ImmutableSet.of("0.3", "0.5");
}
