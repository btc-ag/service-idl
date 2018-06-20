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
package com.btc.serviceidl.generator.dotnet;

public enum ServiceCommVersion {
    V0_6("0.6");

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
        throw new IllegalArgumentException("Unknown .NET ServiceComm version: " + string);
    }
}
