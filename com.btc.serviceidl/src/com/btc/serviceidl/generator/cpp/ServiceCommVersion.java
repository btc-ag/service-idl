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

public enum ServiceCommVersion {
    V0_10("0.10"),
    V0_11("0.11"),
    V0_12("0.12");

    private final String label;

    ServiceCommVersion(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static ServiceCommVersion get(String string) {
        for (ServiceCommVersion value : values()) {
            if (value.getLabel().equals(string)) return value;
        }
        throw new IllegalArgumentException("Unknown C++ ServiceComm version: " + string);
    }
}
