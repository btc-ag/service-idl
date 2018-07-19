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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.btc.serviceidl.util.Util
import java.util.ArrayList
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.java.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PACKAGE_GETTER)
class BasicJavaSourceGenerator
{
    val IQualifiedNameProvider qualifiedNameProvider
    @Accessors(NONE) val ITargetVersionProvider targetVersionProvider
    val TypeResolver typeResolver
    val IDLSpecification idl
    val Map<String, ResolvedName> typedefTable
    val MavenResolver mavenResolver

    def dispatch String toText(ExceptionDeclaration element)
    {
        typeResolver.resolveException(qualifiedNameProvider.getFullyQualifiedName(element).toString) ?:
            '''«typeResolver.resolve(element)»'''
    }

    def dispatch String toText(SequenceDeclaration item)
    {
        val isFailable = item.failable

        '''«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF isFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«toText(item.type)»«IF isFailable»>«ENDIF»>'''
    }

    def dispatch String toText(ParameterElement element)
    {
        '''
            «typeResolver.resolve(element)»
        '''
    }

    def dispatch String toText(MemberElement element)
    {
        new MemberElementWrapper(element).format.toString
    }

    private def format(MemberElementWrapper element)
    {
        formatMaybeOptional(element.optional, toText(element.type))
    }

    public def formatMaybeOptional(boolean isOptional, String typeName)
    {
        '''«IF isOptional»«typeResolver.resolve(JavaClassNames.OPTIONAL)»<«ENDIF»«typeName»«IF isOptional»>«ENDIF»'''
    }

    def dispatch String toText(VoidType element)
    {
        "void"
    }

    def dispatch String toText(AbstractType element)
    {
        toText(element.actualType)
    }

    def dispatch String toText(PrimitiveType element)
    {
        return typeResolver.resolve(element).toString
    }

    def dispatch String toText(AliasDeclaration element)
    {
        val ultimateType = element.type.ultimateType
        val typeName = typedefTable.computeIfAbsent(element.name, [typeResolver.resolve(ultimateType)])

        if (!Util.isPrimitive(ultimateType))
            typeResolver.resolve(typeName.fullyQualifiedName)
        return typeName.toString
    }

    def dispatch String toText(EnumDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def dispatch String toText(EventDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def dispatch String toText(StructDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def dispatch String toDeclaration(EObject element)
    {
        '''
            // TODO: implement this...
        '''
    }

    def dispatch String toDeclaration(ExceptionDeclaration element)
    {
        val classMembers = new ArrayList<Pair<String, String>>
        for (member : element.effectiveMembers)
            classMembers.add(Pair.of(member.name, toText(member.type)))

        '''
            public class «element.name» extends «IF element.supertype === null»Exception«ELSE»«toText(element.supertype)»«ENDIF» {
               
               static final long serialVersionUID = «element.name.hashCode»L;
               «FOR classMember : classMembers BEFORE newLine»
                   private «classMember.value» «classMember.key»;
               «ENDFOR»
               
               public «element.name»() {
                  // this default constructor is always necessary for exception registration in ServiceComm framework
               }
               
               «IF !classMembers.empty»
                   public «element.name»(«FOR classMember : classMembers SEPARATOR ", "»«classMember.value» «classMember.key»«ENDFOR») {
                      «FOR classMember : classMembers»
                          this.«classMember.key» = «classMember.key»;
                      «ENDFOR»
                   };
               «ENDIF»
               
               «FOR classMember : classMembers SEPARATOR newLine»
                   «makeGetterSetter(classMember.value, classMember.key)»
               «ENDFOR»
               
               «IF !(classMembers.size == 1 && classMembers.head.value.equalsIgnoreCase("string"))»
                   public «element.name»(String message) {
                      // this default constructor is necessary to be able to use Exception#getMessage() method
                      super(message);
                   }
               «ENDIF»
            }
        '''
    }

    def dispatch String toDeclaration(EnumDeclaration element)
    {
        '''
            public enum «element.name» {
               «FOR enumValue : element.containedIdentifiers SEPARATOR ","»
                   «enumValue»
               «ENDFOR»
            }
        '''
    }

    def dispatch String toDeclaration(StructDeclaration element)
    {
        val classMembers = new ArrayList<Pair<String, String>>
        for (member : element.effectiveMembers)
            classMembers.add(Pair.of(member.name, member.format.toString))

        val allClassMembers = new ArrayList<Pair<String, String>>
        for (member : element.allMembers)
            allClassMembers.add(Pair.of(member.name, member.format.toString))

        val isDerived = ( element.supertype !== null )
        val relatedEvent = element.getRelatedEvent

        '''
            public class «element.name» «IF isDerived»extends «toText(element.supertype)» «ENDIF»{
               «IF relatedEvent !== null»
                   
                   public static final «typeResolver.resolve(JavaClassNames.UUID)» EventTypeGuid = UUID.fromString("«GuidMapper.get(relatedEvent)»");
               «ENDIF»
               «FOR classMember : classMembers BEFORE newLine»
                   private «classMember.value» «classMember.key»;
               «ENDFOR»
               
               «IF !classMembers.empty»public «element.name»() { «IF isDerived»super(); «ENDIF»};«ENDIF»
               
               public «element.name»(«FOR classMember : allClassMembers SEPARATOR ", "»«classMember.value» «classMember.key»«ENDFOR») {
               «IF isDerived»super(«element.supertype.allMembers.map[name].join(", ")»);«ENDIF»
               
               «FOR classMember : classMembers»
                this.«classMember.key» = «classMember.key»;
               «ENDFOR»
               };
               
               «FOR classMember : classMembers SEPARATOR newLine»
                «makeGetterSetter(classMember.value, classMember.key)»
               «ENDFOR»
               
               «FOR type : element.typeDecls SEPARATOR newLine AFTER newLine»
                «toDeclaration(type)»
               «ENDFOR»
            }
        '''
    }

    def String makeInterfaceMethodSignature(FunctionDeclaration function)
    {
        val isSync = function.isSync
        val isVoid = function.returnedType instanceof VoidType

        '''
        «IF !isSync»«typeResolver.resolve("java.util.concurrent.Future")»<«ENDIF»«IF !isSync && isVoid»Void«ELSE»«toText(function.returnedType)»«ENDIF»«IF !function.isSync»>«ENDIF» «function.name.toFirstLower»(
           «FOR param : function.parameters SEPARATOR ","»
               «IF param.direction == ParameterDirection.PARAM_IN»final «ENDIF»«toText(param.paramType)» «toText(param)»
           «ENDFOR»
        ) throws«FOR exception : function.raisedExceptions SEPARATOR ',' AFTER ','» «toText(exception)»«ENDFOR» Exception'''
    }

    def dispatch String makeDefaultValue(PrimitiveType element)
    {
        if (element.isString)
            '''""'''
        else if (element.isUUID)
            '''«typeResolver.resolve(JavaClassNames.UUID)».randomUUID()'''
        else if (element.isBoolean)
            "false"
        else if (element.isChar)
            "'\\u0000'"
        else if (element.isDouble)
            "0D"
        else if (element.isFloat)
            "0F"
        else if (element.isInt64)
            "0L"
        else if (element.isByte)
            "Byte.MIN_VALUE"
        else if (element.isInt16)
            "Short.MIN_VALUE"
        else
            '''0'''
    }

    def dispatch String makeDefaultValue(AliasDeclaration element)
    {
        makeDefaultValue(element.type)
    }

    def dispatch String makeDefaultValue(AbstractType element)
    {
        makeDefaultValue(element.actualType)
    }

    def dispatch String makeDefaultValue(SequenceDeclaration element)
    {
        val type = toText(element.type)
        val isFailable = element.failable

        // TODO this should better use Collections.emptyList
        '''new «typeResolver.resolve("java.util.Vector")»<«IF isFailable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«type»«IF isFailable»>«ENDIF»>()'''
    }

    def dispatch String makeDefaultValue(StructDeclaration element)
    {
        '''new «typeResolver.resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«IF member.optional»«typeResolver.resolve(JavaClassNames.OPTIONAL)».empty()«ELSE»«makeDefaultValue(member.type)»«ENDIF»«ENDFOR»)'''
    }

    def dispatch String makeDefaultValue(EnumDeclaration element)
    {
        '''«toText(element)».«element.containedIdentifiers.head»'''
    }

    def dispatch String makeDefaultValue(EObject element)
    {
        throw new IllegalArgumentException("Cannot make default value for element of type " + element.eClass.name)
    }

    private static def String makeGetterSetter(String typeName, String varName)
    {
        '''
            «makeGetter(typeName, varName)»
            
            «makeSetter(typeName, varName)»
        '''
    }

    def static String makeGetter(String typeName, String varName)
    {
        '''
            public «typeName» get«varName.toFirstUpper»() {
               return «varName»;
            };
        '''
    }

    private static def String makeSetter(String typeName, String varName)
    {
        '''
            public void set«varName.toFirstUpper»(«typeName» «varName») {
               this.«varName» = «varName»;
            };
        '''
    }

    def static String newLine()
    {
        '''
        
        '''
    }

    def static String asMethod(String name)
    {
        name.toFirstLower
    }

    def static String asParameter(String name)
    {
        name.toFirstLower
    }

    static def getPrefix(AbstractContainerDeclaration container)
    {
        if (container instanceof InterfaceDeclaration) container.name else ""
    }

    def static String asServiceFaultHandlerFactory(AbstractContainerDeclaration container)
    {
        '''«container.prefix»ServiceFaultHandlerFactory'''
    }

    def static String makeDefaultMethodStub()
    {
        '''
            // TODO Auto-generated method stub
            throw new UnsupportedOperationException("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
        '''
    }

    def resolveZeroMqServerConnectionFactory()
    {
        if (javaTargetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory")
        else
            // typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.jzmq.JzmqServerConnectionFactory")
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.jeromq.JeroMqServerConnectionFactory")
    }

    def resolveZeroMqClientConnectionFactory()
    {
        if (javaTargetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")
        else
            // typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.jzmq.JzmqClientConnectionFactory")
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.jeromq.JeroMqClientConnectionFactory")
    }

    def resolveLoggerFactory()
    {
        if (javaTargetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("org.apache.log4j.Logger")
        else
            typeResolver.resolve("org.slf4j.LoggerFactory")
    }

    def resolveLogger()
    {
        if (javaTargetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("org.apache.log4j.Logger")
        else
            typeResolver.resolve("org.slf4j.Logger")
    }

    protected def getJavaTargetVersion()
    {
        targetVersionProvider.javaTargetVersion
    }
}
