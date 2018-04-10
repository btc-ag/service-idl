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
 * \file       IdlSemanticHighlightingCalculator.java
 *
 * \brief      Custom semantic highlighting for the IDL
 */

package com.btc.serviceidl.ui;

import org.eclipse.xtext.ide.editor.syntaxcoloring.IHighlightedPositionAcceptor;
import org.eclipse.xtext.ide.editor.syntaxcoloring.ISemanticHighlightingCalculator;
import org.eclipse.xtext.nodemodel.ILeafNode;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.util.CancelIndicator;

import com.btc.serviceidl.idl.DocCommentElement;
import com.btc.serviceidl.idl.PrimitiveType;

public class IdlSemanticHighlightingCalculator implements ISemanticHighlightingCalculator {

    @Override
    public void provideHighlightingFor(final XtextResource resource, final IHighlightedPositionAcceptor acceptor,
            final CancelIndicator arg2) {
        if (resource == null || resource.getParseResult() == null) {
            return;
        }

        final INode root = resource.getParseResult().getRootNode();
        for (final ILeafNode node : root.getLeafNodes()) {
            if (node.getSemanticElement() instanceof DocCommentElement && !node.isHidden()) {
                acceptor.addPosition(node.getOffset(), node.getLength(),
                        IdlHighlightingConfiguration.DOCUMENTATION_COMMENT_ID);
            }
            if (node.getSemanticElement() instanceof PrimitiveType && !node.isHidden()) {
                acceptor.addPosition(node.getOffset(), node.getLength(),
                        IdlHighlightingConfiguration.PRIMITIVE_DATA_TYPE);
            }
        }
    }
}
