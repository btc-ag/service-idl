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
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.btc.serviceidl.util.Util
import java.util.ArrayList
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PACKAGE_GETTER)
class BasicJavaSourceGenerator
{
    val IQualifiedNameProvider qualified_name_provider
    @Accessors(NONE) val ITargetVersionProvider targetVersionProvider
    val TypeResolver typeResolver
    val IDLSpecification idl
    val Map<String, ResolvedName> typedef_table

    def getTargetVersion()
    {
        ServiceCommVersion.get(targetVersionProvider.getTargetVersion(JavaConstants.SERVICECOMM_VERSION_KIND))
    }

    def public dispatch String toText(ExceptionDeclaration element)
    {
        val exception_name = typeResolver.resolveException(
            qualified_name_provider.getFullyQualifiedName(element).toString)
        if (exception_name.isPresent)
            return exception_name.get()
        else
            '''«typeResolver.resolve(element)»'''
    }

    def public dispatch String toText(SequenceDeclaration item)
    {
        val is_failable = item.failable

        '''«typeResolver.resolve(JavaClassNames.COLLECTION)»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«toText(item.type)»«IF is_failable»>«ENDIF»>'''
    }

    def public dispatch String toText(ParameterElement element)
    {
        '''
            «typeResolver.resolve(element)»
        '''
    }

    def public dispatch String toText(MemberElement element)
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

    def public dispatch String toText(ReturnTypeElement element)
    {
        if (element.isVoid)
            return "void"

        throw new IllegalArgumentException("Unknown ReturnTypeElement: " + element.class.toString)
    }

    def public dispatch String toText(AbstractType element)
    {
        if (element.primitiveType !== null)
            return toText(element.primitiveType)
        else if (element.referenceType !== null)
            return toText(element.referenceType)
        else if (element.collectionType !== null)
            return toText(element.collectionType)

        throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
    }

    def public dispatch String toText(PrimitiveType element)
    {
        return typeResolver.resolve(element).toString
    }

    def public dispatch String toText(AliasDeclaration element)
    {
        var type_name = typedef_table.get(element.name)
        val ultimate_type = element.type.ultimateType
        if (type_name === null)
        {
            type_name = typeResolver.resolve(ultimate_type)
            typedef_table.put(element.name, type_name)
        }

        if (!Util.isPrimitive(ultimate_type))
            typeResolver.resolve(type_name.fullyQualifiedName)
        return type_name.toString
    }

    def public dispatch String toText(EnumDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def public dispatch String toText(EventDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def public dispatch String toText(StructDeclaration element)
    {
        '''«typeResolver.resolve(element)»'''
    }

    def public dispatch String toDeclaration(EObject element)
    {
        '''
            // TODO: implement this...
        '''
    }

    def public dispatch String toDeclaration(ExceptionDeclaration element)
    {
        val class_members = new ArrayList<Pair<String, String>>
        for (member : element.effectiveMembers)
            class_members.add(Pair.of(member.name, toText(member.type)))

        '''
            public class «element.name» extends «IF element.supertype === null»Exception«ELSE»«toText(element.supertype)»«ENDIF» {
               
               static final long serialVersionUID = «element.name.hashCode»L;
               «FOR class_member : class_members BEFORE newLine»
                   private «class_member.value» «class_member.key»;
               «ENDFOR»
               
               public «element.name»() {
                  // this default constructor is always necessary for exception registration in ServiceComm framework
               }
               
               «IF !class_members.empty»
                   public «element.name»(«FOR class_member : class_members SEPARATOR ", "»«class_member.value» «class_member.key»«ENDFOR») {
                      «FOR class_member : class_members»
                          this.«class_member.key» = «class_member.key»;
                      «ENDFOR»
                   };
               «ENDIF»
               
               «FOR class_member : class_members SEPARATOR newLine»
                   «makeGetterSetter(class_member.value, class_member.key)»
               «ENDFOR»
               
               «IF !(class_members.size == 1 && class_members.head.value.equalsIgnoreCase("string"))»
                   public «element.name»(String message) {
                      // this default constructor is necessary to be able to use Exception#getMessage() method
                      super(message);
                   }
               «ENDIF»
            }
        '''
    }

    def public dispatch String toDeclaration(EnumDeclaration element)
    {
        '''
            public enum «element.name» {
               «FOR enum_value : element.containedIdentifiers SEPARATOR ","»
                   «enum_value»
               «ENDFOR»
            }
        '''
    }

    def public dispatch String toDeclaration(StructDeclaration element)
    {
        val class_members = new ArrayList<Pair<String, String>>
        for (member : element.effectiveMembers)
            class_members.add(Pair.of(member.name, member.format.toString))

        val all_class_members = new ArrayList<Pair<String, String>>
        for (member : element.allMembers)
            all_class_members.add(Pair.of(member.name, member.format.toString))

        val is_derived = ( element.supertype !== null )
        val related_event = element.getRelatedEvent

        '''
            public class «element.name» «IF is_derived»extends «toText(element.supertype)» «ENDIF»{
               «IF related_event !== null»
                   
                   public static final «typeResolver.resolve(JavaClassNames.UUID)» EventTypeGuid = UUID.fromString("«GuidMapper.get(related_event)»");
               «ENDIF»
               «FOR class_member : class_members BEFORE newLine»
                   private «class_member.value» «class_member.key»;
               «ENDFOR»
               
               «IF !class_members.empty»public «element.name»() { «IF is_derived»super(); «ENDIF»};«ENDIF»
               
               public «element.name»(«FOR class_member : all_class_members SEPARATOR ", "»«class_member.value» «class_member.key»«ENDFOR») {
               «IF is_derived»super(«element.supertype.allMembers.map[name].join(", ")»);«ENDIF»
               
               «FOR class_member : class_members»
                this.«class_member.key» = «class_member.key»;
               «ENDFOR»
               };
               
               «FOR class_member : class_members SEPARATOR newLine»
                «makeGetterSetter(class_member.value, class_member.key)»
               «ENDFOR»
               
               «FOR type : element.typeDecls SEPARATOR newLine AFTER newLine»
                «toDeclaration(type)»
               «ENDFOR»
            }
        '''
    }

    def public String makeInterfaceMethodSignature(FunctionDeclaration function)
    {
        val is_sync = function.isSync
        val is_void = function.returnedType.isVoid

        '''
        «IF !is_sync»«typeResolver.resolve("java.util.concurrent.Future")»<«ENDIF»«IF !is_sync && is_void»Void«ELSE»«toText(function.returnedType)»«ENDIF»«IF !function.isSync»>«ENDIF» «function.name.toFirstLower»(
           «FOR param : function.parameters SEPARATOR ","»
               «IF param.direction == ParameterDirection.PARAM_IN»final «ENDIF»«toText(param.paramType)» «toText(param)»
           «ENDFOR»
        ) throws«FOR exception : function.raisedExceptions SEPARATOR ',' AFTER ','» «toText(exception)»«ENDFOR» Exception'''
    }

    def public String makeDefaultValue(EObject element)
    {
        if (element instanceof PrimitiveType)
        {
            if (element.isString)
                return '''""'''
            else if (element.isUUID)
                return '''«typeResolver.resolve(JavaClassNames.UUID)».randomUUID()'''
            else if (element.isBoolean)
                return "false"
            else if (element.isChar)
                return "'\\u0000'"
            else if (element.isDouble)
                return "0D"
            else if (element.isFloat)
                return "0F"
            else if (element.isInt64)
                return "0L"
            else if (element.isByte)
                return "Byte.MIN_VALUE"
            else if (element.isInt16)
                return "Short.MIN_VALUE"
        }
        else if (element instanceof AliasDeclaration)
        {
            return makeDefaultValue(element.type)
        }
        else if (element instanceof AbstractType)
        {
            if (element.referenceType !== null)
                return makeDefaultValue(element.referenceType)
            else if (element.primitiveType !== null)
                return makeDefaultValue(element.primitiveType)
            else if (element.collectionType !== null)
                return makeDefaultValue(element.collectionType)
        }
        else if (element instanceof SequenceDeclaration)
        {
            val type = toText(element.type)
            val is_failable = element.failable
            // TODO this should better use Collections.emptyList
            return '''new «typeResolver.resolve("java.util.Vector")»<«IF is_failable»«typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)»<«ENDIF»«type»«IF is_failable»>«ENDIF»>()'''
        }
        else if (element instanceof StructDeclaration)
        {
            return '''new «typeResolver.resolve(element)»(«FOR member : element.allMembers SEPARATOR ", "»«IF member.optional»«typeResolver.resolve(JavaClassNames.OPTIONAL)».empty()«ELSE»«makeDefaultValue(member.type)»«ENDIF»«ENDFOR»)'''
        }
        else if (element instanceof EnumDeclaration)
        {
            return '''«toText(element)».«element.containedIdentifiers.head»''';
        }

        return '''0'''
    }

    private static def String makeGetterSetter(String type_name, String var_name)
    {
        '''
            «makeGetter(type_name, var_name)»
            
            «makeSetter(type_name, var_name)»
        '''
    }

    def public static String makeGetter(String type_name, String var_name)
    {
        '''
            public «type_name» get«var_name.toFirstUpper»() {
               return «var_name»;
            };
        '''
    }

    private static def String makeSetter(String type_name, String var_name)
    {
        '''
            public void set«var_name.toFirstUpper»(«type_name» «var_name») {
               this.«var_name» = «var_name»;
            };
        '''
    }

    def public static String newLine()
    {
        '''
        
        '''
    }

    def public static String asMethod(String name)
    {
        name.toFirstLower
    }

    def public static String asParameter(String name)
    {
        name.toFirstLower
    }

    def public static String asServiceFaultHandlerFactory(EObject container)
    {
        val name = if (container instanceof InterfaceDeclaration) container.name else ""
        '''«name»ServiceFaultHandlerFactory'''
    }

    def public static String makeDefaultMethodStub()
    {
        '''
            // TODO Auto-generated method stub
            throw new UnsupportedOperationException("«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»");
        '''
    }

    def resolveZeroMqServerConnectionFactory()
    {
        if (targetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory")
        else
            // typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.jzmq.JzmqServerConnectionFactory")
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.jeromq.JeroMqServerConnectionFactory")
    }

    def resolveZeroMqClientConnectionFactory()
    {
        if (targetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqClientConnectionFactory")
        else
            // typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.zeromq.jzmq.JzmqClientConnectionFactory")
            typeResolver.resolve("com.btc.cab.servicecomm.singlequeue.jeromq.JeroMqClientConnectionFactory")
    }

    def resolveLoggerFactory()
    {
        if (targetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("org.apache.log4j.Logger")
        else
            typeResolver.resolve("org.slf4j.LoggerFactory")
    }

    def resolveLogger()
    {
        if (targetVersion == ServiceCommVersion.V0_3)
            typeResolver.resolve("org.apache.log4j.Logger")
        else
            typeResolver.resolve("org.slf4j.Logger")
    }

}
