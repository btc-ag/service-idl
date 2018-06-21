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
package com.btc.serviceidl.ui.tests

import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.ui.testing.AbstractContentAssistTest
import org.junit.runner.RunWith
import org.junit.Test

@RunWith(XtextRunner)
@InjectWith(IdlUiInjectorProvider)
class IdlContentAssistTest extends AbstractContentAssistTest
{
    @Test
    def void testOuterAutoCompletion()
    {
        newBuilder.append("i").assertText("import")
    }
    
    @Test
    def void testNestedAutoCompletion()
    {
        newBuilder.append("module {").append("i").assertText("interface")
    }
}
