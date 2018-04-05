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
package com.btc.serviceidl.tests

import static org.junit.Assert.*

class TestExtensions {
	def static normalize(String arg) {
		arg.replaceAll("\\s+", " ").trim
	}
	
	def static assertEqualsNormalized(String expected, String actual)
	{
		assertEquals(expected.normalize, actual.normalize)
	}
	
	def static assertEqualsNormalized(CharSequence expected, CharSequence actual)
	{
		assertEquals(expected.toString.normalize, actual.toString.normalize)
	}
}
