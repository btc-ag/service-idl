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
 * \file       TransformType.java
 *
 * \brief      Used to transform a module structure into e.g. path/namespace/package representation
 */

package com.btc.serviceidl.generator.common;

import com.btc.serviceidl.util.Constants;

public enum TransformType {
    FILE_SYSTEM(false, Constants.SEPARATOR_FILE),
    PACKAGE(true, Constants.SEPARATOR_PACKAGE),
    NAMESPACE(true, Constants.SEPARATOR_NAMESPACE),
    EXPORT_HEADER(true, Constants.SEPARATOR_CPP_HEADER);

    private final boolean use_virtual;
    private final String  separator;

    TransformType(final boolean use_virtual, final String separator) {
        this.use_virtual = use_virtual;
        this.separator = separator;
    }

    public final String getSeparator() {
        return separator;
    }

    public final boolean useVirtual() {
        return use_virtual;
    }

}
