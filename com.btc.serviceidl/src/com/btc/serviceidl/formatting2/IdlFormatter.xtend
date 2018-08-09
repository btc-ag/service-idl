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
package com.btc.serviceidl.formatting2

import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.IdlPackage
import com.btc.serviceidl.idl.ImportDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.KeyElement
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.TypicalLengthHint
import com.btc.serviceidl.idl.TypicalSizeHint
import com.btc.serviceidl.idl.VoidType
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.formatting2.AbstractFormatter2
import org.eclipse.xtext.formatting2.IFormattableDocument

class IdlFormatter extends AbstractFormatter2
{
   def dispatch void format(IDLSpecification element, extension IFormattableDocument document)
   {
      element.importedEntities.forEach[format]
      if (!element.importedEntities.empty)
      {
         val lastElement = element.importedEntities.last
         element.importedEntities.filter[it !== lastElement].forEach[append[newLine]]
         lastElement.append[newLines = 2]
      }
      element.modules.forEach[format]
   }

   def dispatch void format(ImportDeclaration element, extension IFormattableDocument document)
   {
      element.prepend[noSpace]
      element.regionFor.feature(IdlPackage.Literals::IMPORT_DECLARATION__IMPORTED_NAMESPACE).prepend[oneSpace]
   }

   def dispatch void format(ModuleDeclaration element, extension IFormattableDocument document)
   {
      indentBlock(element, document)
      
      element.regionFor.feature(IdlPackage.Literals::MODULE_DECLARATION__VIRTUAL).prepend[noSpace].append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::MODULE_DECLARATION__MAIN).surround[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      
      element.nestedModules.forEach[format]
      
      separateByEmptyLines(element.moduleComponents, document)
      element.moduleComponents.forEach[format]
   }
   
   def dispatch void format(InterfaceDeclaration element, extension IFormattableDocument document)
   {
      indentBlock(element, document)
      
      element.regionFor.feature(IdlPackage.Literals::INTERFACE_DECLARATION__ABSTRACT).prepend[noSpace].append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.keyword("guid").surround[oneSpace]
      element.regionFor.keywords("=").forEach[surround[oneSpace]]
      element.regionFor.feature(IdlPackage.Literals::INTERFACE_DECLARATION__GUID).surround[oneSpace]
      
      separateByEmptyLines(element.contains, document)
      element.contains.forEach[format]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(StructDeclaration element, extension IFormattableDocument document)
   {
      indentBlock(element, document)
      
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::STRUCT_DECLARATION__DECLARATOR).prepend[oneSpace].append[noSpace]
      element.regionFor.keyword(":").surround[oneSpace]
      element.members.forEach[prepend[newLine]]
      element.members.forEach[format]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(MemberElement element, extension IFormattableDocument document)
   {
      element.regionFor.feature(IdlPackage.Literals::MEMBER_ELEMENT__OPTIONAL).append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::MEMBER_ELEMENT__NAME).prepend[oneSpace].append[noSpace]
      element.type.format
   }
   
   def dispatch void format(ExceptionDeclaration element, extension IFormattableDocument document)
   {
      indentBlock(element, document)
      
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.keyword(":").surround[oneSpace]
      element.members.forEach[prepend[newLine]]
      element.members.forEach[format]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(ExceptionReferenceDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.keyword("ref").append[oneSpace]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(AliasDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("typedef").append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).prepend[oneSpace]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(EnumDeclaration element, extension IFormattableDocument document)
   {
      indentBlock(element, document)
      
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::ENUM_DECLARATION__DECLARATOR).prepend[oneSpace].append[noSpace]
      element.regionFor.keywords(",").forEach[prepend[noSpace].append[newLine]]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(FunctionDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.feature(IdlPackage.Literals::FUNCTION_DECLARATION__SYNC).append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::FUNCTION_DECLARATION__QUERY).append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).append[noSpace]
      element.parameters.forEach[format]
      element.regionFor.keyword("(").surround[noSpace]
      element.regionFor.keyword(")").prepend[noSpace]
      element.regionFor.keywords(",").forEach[prepend[noSpace].append[oneSpace]]
      element.regionFor.keyword("returns").surround[oneSpace]
      element.regionFor.keyword("injectable").surround[oneSpace]
      element.regionFor.keyword("raises").surround[oneSpace]
      element.returnedType.format
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(ParameterElement element, extension IFormattableDocument document)
   {
      element.regionFor.feature(IdlPackage.Literals::PARAMETER_ELEMENT__DIRECTION).append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::PARAMETER_ELEMENT__PARAM_NAME).prepend[oneSpace].append[noSpace]
      element.paramType.format
   }
   
   def dispatch void format(EventDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("event").append[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::NAMED_DECLARATION__NAME).surround[oneSpace]
      element.regionFor.keyword("guid").surround[oneSpace]
      element.regionFor.keywords("=").forEach[surround[oneSpace]]
      element.regionFor.feature(IdlPackage.Literals::EVENT_DECLARATION__GUID).surround[oneSpace]
      element.regionFor.feature(IdlPackage.Literals::EVENT_DECLARATION__GUID).surround[oneSpace]
      element.regionFor.keywords("(").forEach[prepend[oneSpace].append[noSpace]]
      element.regionFor.keywords(")").forEach[prepend[noSpace]]
      element.regionFor.keyword("subscribe").surround[oneSpace]
      element.regionFor.keyword("with").surround[oneSpace]
      element.regionFor.keyword("raises").surround[oneSpace]
      element.regionFor.keywords(",").forEach[prepend[noSpace].append[oneSpace]]
      element.keys.forEach[format]
      
      formatClosingSemicolon(element, document)
   }
   
   def dispatch void format(KeyElement element, extension IFormattableDocument document)
   {
      element.regionFor.feature(IdlPackage.Literals::KEY_ELEMENT__KEY_NAME).prepend[oneSpace].append[noSpace]
   }
   
   def dispatch void format(SequenceDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("<").surround[noSpace]
      element.regionFor.keyword("failable").append[oneSpace]
      element.regionFor.keyword("raises").surround[oneSpace]
      element.regionFor.keywords(",").forEach[prepend[noSpace].append[oneSpace]]
      element.regionFor.keyword(">").prepend[noSpace]
      element.regionFor.keyword("[").surround[oneSpace]
      element.regionFor.keyword("]").surround[oneSpace]
      element.sequenceHints.forEach[format]
      element.type.format
   }
   
   def dispatch void format(TupleDeclaration element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("<").surround[noSpace]
      element.regionFor.keywords(",").forEach[prepend[noSpace].append[oneSpace]]
      element.regionFor.keyword(">").prepend[noSpace]
      element.types.forEach[format]
   }
   
   def dispatch void format(TypicalLengthHint element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("typical").surround[oneSpace]
      element.regionFor.keyword("sequence").surround[oneSpace]
      element.regionFor.keyword("length").surround[oneSpace]
      element.regionFor.keyword("=").surround[oneSpace]
   }
   
   def dispatch void format(TypicalSizeHint element, extension IFormattableDocument document)
   {
      element.regionFor.keyword("typical").surround[oneSpace]
      element.regionFor.keyword("element").surround[oneSpace]
      element.regionFor.keyword("size").surround[oneSpace]
      element.regionFor.keyword("=").surround[oneSpace]
   }
   
   def dispatch void format(ReturnTypeElement element, extension IFormattableDocument document)
   {
      if (!(element instanceof VoidType))
      {
         val abstractType = element as AbstractType
         if (abstractType.collectionType !== null)
         {
            abstractType.collectionType.format
         }
      }
   }
   
   /**
    * Increase indentation level for all content between opening and closing
    * curly bracket of an arbitrary element; brackets themselves will be
    * positioned on separate lines.
    */
   private def void indentBlock(EObject element, extension IFormattableDocument document)
   {
      val start = element.regionFor.keyword("{").prepend[newLine]
      val end = element.regionFor.keyword("}")
      interior(start, end)[newLine; indent]
   }
   
   /**
    * Remove spaces before the last semicolon keyword for a given element.
    */
   private def void formatClosingSemicolon(EObject element, extension IFormattableDocument document)
   {
      element.regionFor.keywords(";").last.surround[noSpace]
   }
   
   /**
    * Separate given elements by an empty line (except the last one).
    */
   private def void separateByEmptyLines(Iterable<? extends EObject> elements, extension IFormattableDocument document)
   {
      val lastElement = elements.last
      elements.filter[it !== lastElement].forEach[append[newLines = 2]]
   }
}
