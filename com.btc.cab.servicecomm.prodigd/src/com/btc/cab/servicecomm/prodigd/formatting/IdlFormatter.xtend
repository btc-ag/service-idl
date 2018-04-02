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
 * \file       IdlFormatter.xtend
 * 
 * \brief      This class contains custom formatting description.
 *             \see http://www.eclipse.org/Xtext/documentation.html#formatting
 * 
 * \remark     Generated by Xtext
*/
package com.btc.cab.servicecomm.prodigd.formatting

import org.eclipse.xtext.formatting.impl.AbstractDeclarativeFormatter
import org.eclipse.xtext.formatting.impl.FormattingConfig
import com.google.inject.Inject;
import com.btc.cab.servicecomm.prodigd.services.IdlGrammarAccess

class IdlFormatter extends AbstractDeclarativeFormatter
{

   @Inject extension IdlGrammarAccess grammarAccess
   
   override protected void configureFormatting(FormattingConfig c)
   {
      val module = grammarAccess.moduleDeclarationAccess
      c.setLinewrap.after(module.nameIDTerminalRuleCall_3_0)
      c.setLinewrap.after(module.leftCurlyBracketKeyword_4)
      c.setLinewrap.after(module.rightCurlyBracketKeyword_7)
      c.setIndentation(module.leftCurlyBracketKeyword_4, module.rightCurlyBracketKeyword_7)
      
      val interfaceDeclaration = grammarAccess.interfaceDeclarationAccess
      c.setLinewrap.after(interfaceDeclaration.leftCurlyBracketKeyword_6)
      c.setLinewrap.after(interfaceDeclaration.rightSquareBracketKeyword_4_2)
      c.setIndentation(interfaceDeclaration.leftCurlyBracketKeyword_6, interfaceDeclaration.rightCurlyBracketKeyword_8)
      
      val struct = grammarAccess.structDeclarationAccess
      c.setLinewrap.after(struct.nameIDTerminalRuleCall_1_0)
      c.setLinewrap.after(struct.leftCurlyBracketKeyword_3)
      c.setIndentation(struct.leftCurlyBracketKeyword_3, struct.rightCurlyBracketKeyword_5)
      c.setNoSpace.before(struct.semicolonKeyword_4_1)
      c.setLinewrap.after(struct.semicolonKeyword_4_1)
      
      val exceptionDeclaration = grammarAccess.exceptionDeclarationAccess
      c.setLinewrap.after(exceptionDeclaration.nameIDTerminalRuleCall_1_0)
      c.setLinewrap.after(exceptionDeclaration.leftCurlyBracketKeyword_3)
      c.setIndentation(exceptionDeclaration.leftCurlyBracketKeyword_3, exceptionDeclaration.rightCurlyBracketKeyword_5)
      c.setNoSpace.before(exceptionDeclaration.semicolonKeyword_4_1)
      c.setLinewrap.after(exceptionDeclaration.semicolonKeyword_4_1)
      
      val abstractInterfaceComponent = grammarAccess.abstractInterfaceComponentAccess
      c.setNoSpace.before(abstractInterfaceComponent.semicolonKeyword_0_1)
      c.setLinewrap.after(abstractInterfaceComponent.semicolonKeyword_0_1)
      c.setNoSpace.before(abstractInterfaceComponent.semicolonKeyword_1_1)
      c.setLinewrap.after(abstractInterfaceComponent.semicolonKeyword_1_1)
      c.setNoSpace.before(abstractInterfaceComponent.semicolonKeyword_2_1)
      c.setLinewrap.after(abstractInterfaceComponent.semicolonKeyword_2_1)
      
      val abstractModuleComponent = grammarAccess.abstractModuleComponentAccess
      c.setNoSpace.before(abstractModuleComponent.semicolonKeyword_0_1)
      c.setLinewrap(2).after(abstractModuleComponent.semicolonKeyword_0_1)
      c.setNoSpace.before(abstractModuleComponent.semicolonKeyword_1_1)
      c.setLinewrap(2).after(abstractModuleComponent.semicolonKeyword_1_1)
      c.setNoSpace.before(abstractModuleComponent.semicolonKeyword_2_1)
      c.setLinewrap(2).after(abstractModuleComponent.semicolonKeyword_2_1)
      c.setNoSpace.before(abstractModuleComponent.semicolonKeyword_3_1)
      c.setLinewrap(2).after(abstractModuleComponent.semicolonKeyword_3_1)
      
      val importDeclaration = grammarAccess.importDeclarationAccess
      c.setLinewrap.after(importDeclaration.importedNamespaceAssignment_1)
      
      // It's usually a good idea to activate the following three statements.
      // They will add and preserve newlines around comments
      c.setLinewrap(0, 1, 2).before(SL_COMMENTRule)
      c.setLinewrap(0, 1, 2).before(ML_COMMENTRule)
      c.setLinewrap(0, 1, 1).after(ML_COMMENTRule)
   }
}
