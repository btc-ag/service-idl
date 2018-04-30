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

import com.btc.serviceidl.generator.common.ParameterBundle;

public interface IProjectSet {
    String getVcxprojName(ParameterBundle builder);

    IProjectReference resolveHeader(HeaderResolver.GroupedHeader header);

    IProjectReference resolve(ParameterBundle paramBundle);
}
