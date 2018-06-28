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
package com.btc.serviceidl.generator.dotnet

import com.google.common.base.CaseFormat

import static com.btc.serviceidl.generator.common.GeneratorUtil.*
import com.btc.serviceidl.util.MemberElementWrapper

class ProtobufUtil
{
    static def String asDotNetProtobufName(String name)
    {
        // TODO change this function to accept a model construct rather than a bare name
        asProtobufName(name, CaseFormat.UPPER_CAMEL)
    }

    static def getProtobufName(MemberElementWrapper element)
    {
        asDotNetProtobufName(element.name)
    }

}
