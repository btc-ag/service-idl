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

import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.DocCommentElement
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.ArrayList
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.util.Pair
import org.eclipse.xtext.util.Triple
import org.eclipse.xtext.util.Tuples

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors(PACKAGE_GETTER)
class BasicCSharpSourceGenerator {
    val extension TypeResolver typeResolver 
    val Map<String, String> typedef_table    
    val IDLSpecification idl
    
   def public dispatch String toText(AliasDeclaration element, EObject context)
   {
      var type_name = typedef_table.get(element.name)
      if (type_name === null)
      {
         type_name = toText(element.type, element)
         typedef_table.put(element.name, type_name)
      }

      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
         return "" // in this context, we only denote the substitute type without any output
      else
         return type_name
   }
   
   def public dispatch String toText(AbstractType element, EObject context)
   {
      if (element.primitiveType !== null)
         return toText(element.primitiveType, element)
      else if (element.referenceType !== null)
         return toText(element.referenceType, element)
      else if (element.collectionType !== null)
         return toText(element.collectionType, element)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   def public dispatch String toText(ParameterElement element, EObject context)
   {
      '''«element.paramName.asParameter»'''
   }
   
   def public dispatch String toText(ReturnTypeElement element, EObject context)
   {
      if (element.isVoid)
         return "void"

      throw new IllegalArgumentException("Unknown ReturnTypeElement: " + element.class.toString)
   }
   
   def public dispatch String toText(PrimitiveType element, EObject context)
   {
      typeResolver.primitiveTypeName(element)
   }
   
   def public dispatch String toText(EnumDeclaration element, EObject context)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
      '''
      public enum «element.name»
      {
         «FOR enum_value : element.containedIdentifiers SEPARATOR ","»
            «enum_value»
         «ENDFOR»
      }
      '''
      else
         '''«resolve(element)»'''
   }
   
   def public dispatch String toText(EventDeclaration element, EObject context)
   {
      '''«resolve(element.data).alias(getObservableName(element))»'''
   }
   
   def public dispatch String toText(StructDeclaration element, EObject context)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
      {
         val class_members = new ArrayList<Triple<String, String, String>>
         for (member : element.effectiveMembers) class_members.add(Tuples.create(member.name.asProperty, toText(member, element), maybeOptional(member)))
         
         val all_class_members = new ArrayList<Triple<String, String, String>>
         element.allMembers.forEach[e | all_class_members.add(Tuples.create(e.name.asProperty, toText(e, element), maybeOptional(e)))]

         val related_event =  com.btc.serviceidl.util.Util.getRelatedEvent(element)
         
         '''
         public class «element.name»«IF element.supertype !== null» : «resolve(element.supertype)»«ENDIF»
         {
            «IF related_event !== null»
               
               public static readonly «resolve("System.Guid")» «eventTypeGuidProperty» = new Guid("«GuidMapper.get(related_event.data)»");
            «ENDIF»
            «FOR class_member : class_members BEFORE System.lineSeparator»
               public «class_member.second»«class_member.third» «class_member.first» { get; private set; }
            «ENDFOR»
            
            «IF !class_members.empty»
               public «element.name»(«FOR class_member : all_class_members SEPARATOR ", "»«class_member.second»«class_member.third» «class_member.first.asParameter»«ENDFOR»)
               «IF element.supertype !== null» : base(«element.supertype.allMembers.map[name.asParameter].join(", ")»)«ENDIF»
               {
                  «FOR class_member : class_members»
                     this.«class_member.first» = «class_member.first.asParameter»;
                  «ENDFOR»
               }
            «ENDIF»
            
            «FOR type : element.typeDecls SEPARATOR System.lineSeparator AFTER System.lineSeparator»
               «toText(type, element)»
            «ENDFOR»
         }
         '''
      }
      else
         '''«resolve(element)»'''
   }
   
   def public dispatch String toText(ExceptionReferenceDeclaration element, EObject context)
   {
      if (context instanceof FunctionDeclaration) '''«resolve(element)»'''
   }
   
   def public dispatch String toText(MemberElementWrapper element, EObject context)
   {
      '''«toText(element.type, null)»'''
   }
   
   def public dispatch String toText(ExceptionDeclaration element, EObject context)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
      {
         val class_members = new ArrayList<Pair<MemberElementWrapper, String>>
         for (member : element.effectiveMembers) class_members.add(Tuples.create(member, toText(member, element)))

         '''
         public class «element.name» : «IF element.supertype === null»«resolve("System.Exception")»«ELSE»«toText(element.supertype, element)»«ENDIF»
         {
            
            public «element.name»(«FOR class_member : class_members SEPARATOR ", "»«class_member.second»«maybeOptional(class_member.first)» «class_member.first.name.asParameter»«ENDFOR»)
            «IF element.supertype !== null && (element.supertype instanceof ExceptionDeclaration)» : base(«»)«ENDIF»
            {
               «FOR class_member : class_members»
                  this.«class_member.first.name.asProperty» = «class_member.first.name.asParameter»;
               «ENDFOR»
            }
            
            «IF !(class_members.size == 1 && class_members.head.second.equalsIgnoreCase("string"))»
            public «element.name»(«resolve("System.string")» msg) : base(msg)
            {
               // this dummy constructor is necessary because otherwise
               // MultipleExceptionTypesServiceFaultHandler::RegisterException will fail!
            }
            «ENDIF»
            
            «FOR class_member : class_members SEPARATOR System.lineSeparator»
               public «class_member.second»«maybeOptional(class_member.first)» «class_member.first.name.asProperty» { get; private set; }
            «ENDFOR»
         }
         '''
      }
      else
         '''«resolve(element)»'''
   }
   
   def public dispatch String toText(SequenceDeclaration element, EObject context)
   {
      val isFailable = element.failable
      val basicType = resolve(element.type)
      val effectiveType = if (isFailable) resolveFailableType(basicType.fullyQualifiedName) else basicType
      
      '''«resolve("System.Collections.Generic.IEnumerable")»<«effectiveType»>'''
   }
   
   def public dispatch String toText(TupleDeclaration element, EObject context)
   {
      '''«resolve("System.Tuple")»<«FOR type : element.types SEPARATOR ","»«toText(type, element)»«ENDFOR»>'''
   }
   
   def public dispatch String toText(DocCommentElement item, EObject context)
   {
      '''/// «com.btc.serviceidl.util.Util.getPlainText(item).replaceAll("\\r", System.lineSeparator + "/// ")»'''
   }
}
