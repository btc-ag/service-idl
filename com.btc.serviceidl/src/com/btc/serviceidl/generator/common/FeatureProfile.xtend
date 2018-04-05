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
 * \file       FeatureProfile.xtend
 * 
 * \brief      Easy feature profiling for a given element or collection
 */

package com.btc.serviceidl.generator.common

import org.eclipse.emf.ecore.EObject
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration

class FeatureProfile<T extends EObject> {

   new(T element)
   {
      evaluate(element)
   }
   
   new (Iterable<T> contents)
   {
      for (c : contents)
         evaluate(c)
   }
   
   def private void evaluate(T element)
   {
      var contents = element.eAllContents.toList
      contents.add(element)
      
      uses_tuples = uses_tuples || contents.exists[o |o instanceof TupleDeclaration]
      
      uses_strings = uses_strings || contents.filter(PrimitiveType).exists[stringType !== null]
      
      uses_futures = uses_futures || contents.filter(FunctionDeclaration).exists[!isSync]
      
      uses_events = uses_events || contents.exists[o | o instanceof EventDeclaration]
      
      uses_sequences = uses_sequences || contents.exists[o | o instanceof SequenceDeclaration]
      
      uses_failable_handles = uses_failable_handles || contents.filter(SequenceDeclaration).exists[isFailable]
      
      uses_optionals = uses_optionals || contents.filter(MemberElement).exists[isOptional]
      
      uses_cstdint = uses_cstdint || contents.filter(PrimitiveType).exists[integerType !== null]
      
      uses_exceptions = uses_exceptions || contents.filter(ExceptionDeclaration).exists[supertype === null]
      
      uses_uuids = uses_uuids || contents.filter(PrimitiveType).exists[uuidType !== null]
      
      uses_objects = uses_objects || contents.filter(InterfaceDeclaration).exists[derivesFrom === null]
   }
   
   public boolean uses_tuples;
   public boolean uses_strings;
   public boolean uses_futures;
   public boolean uses_events;
   public boolean uses_sequences;
   public boolean uses_failable_handles;
   public boolean uses_optionals;
   public boolean uses_cstdint;
   public boolean uses_exceptions;
   public boolean uses_objects;
   public boolean uses_uuids;
}
