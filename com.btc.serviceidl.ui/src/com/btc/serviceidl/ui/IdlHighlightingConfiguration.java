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
 * \file       IdlHighlightingConfiguration.java
 *
 * \brief      Custom highlighting configuration for the IDL
 */

package com.btc.serviceidl.ui;

import org.eclipse.swt.graphics.RGB;
import org.eclipse.xtext.ui.editor.syntaxcoloring.DefaultHighlightingConfiguration;
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfigurationAcceptor;
import org.eclipse.xtext.ui.editor.utils.TextStyle;

public class IdlHighlightingConfiguration extends DefaultHighlightingConfiguration {
    // provide ID strings for the highlighting calculator
    public static final String DOCUMENTATION_COMMENT_ID = "documentation.comment";
    public static final String PRIMITIVE_DATA_TYPE      = "primitive.data.type";

    @Override
    public void configure(final IHighlightingConfigurationAcceptor acceptor) {
        // let the default implementation first do the job
        super.configure(acceptor);

        // here our custom styles are used
        acceptor.acceptDefaultHighlighting(DOCUMENTATION_COMMENT_ID, "Documentation comment",
                documentationCommentTextStyle());
        acceptor.acceptDefaultHighlighting(PRIMITIVE_DATA_TYPE, "Primitive data type", primitiveDataTypeTextStyle());
    }

    public TextStyle documentationCommentTextStyle() {
        final TextStyle textStyle = defaultTextStyle().copy();
        textStyle.setColor(new RGB(63, 95, 191)); // default Eclipse JavaDoc color
        return textStyle;
    }

    public TextStyle primitiveDataTypeTextStyle() {
        final TextStyle textStyle = keywordTextStyle().copy();
        textStyle.setColor(new RGB(0, 0, 192));

        return textStyle;
    }
}
