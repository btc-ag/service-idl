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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
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
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.ReturnTypeElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.util.Constants
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class BasicCppGenerator
{
    protected val extension TypeResolver typeResolver
    protected val ParameterBundle param_bundle
    protected val IDLSpecification idl

    def String generateCppDestructor(InterfaceDeclaration interface_declaration)
    {
        val class_name = GeneratorUtil.getClassName(param_bundle, interface_declaration.name)

        '''
            «class_name»::~«class_name»()
            {}
        '''
    }

    def String generateInheritedInterfaceMethods(InterfaceDeclaration interface_declaration)
    {
        val class_name = resolve(interface_declaration, param_bundle.projectType.get)

        '''
            «FOR function : interface_declaration.functions»
                «IF !function.isSync»«resolveCAB("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interface_declaration)»«IF !function.isSync»>«ENDIF» «class_name.shortName»::«function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»
                {
                   «generateFunctionBody(interface_declaration, function)»
                }
                
            «ENDFOR»
        '''
    }

    def generateFunctionBody(InterfaceDeclaration interface_declaration, FunctionDeclaration function)
    {
        // TODO make this function abstract and move implementation to subclass
        '''
            «IF param_bundle.projectType == ProjectType.IMPL || param_bundle.projectType == ProjectType.EXTERNAL_DB_IMPL»
                // \todo Auto-generated method stub! Implement actual business logic!
                «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::UnsupportedOperationException")»( "«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»" ));
            «ENDIF»
        '''
    }

    def String generateParameters(FunctionDeclaration function)
    {
        '''«FOR parameter : function.parameters SEPARATOR ", "»«toText(parameter, function)»«ENDFOR»'''
    }

    def dispatch String toText(ParameterElement item, EObject context)
    {
        val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(item.paramType)
        if (is_sequence)
            '''«toText(item.paramType, context.eContainer)» «IF item.direction == ParameterDirection.PARAM_OUT»&«ENDIF»«item.paramName»'''
        else
            '''«toText(item.paramType, context.eContainer)»«IF item.direction == ParameterDirection.PARAM_IN» const«ENDIF» &«item.paramName»'''
    }

    def dispatch String toText(ReturnTypeElement return_type, EObject context)
    {
        if (return_type.isVoid)
            return "void"

        throw new IllegalArgumentException("Unknown ReturnTypeElement: " + return_type.class.toString)
    }

    def dispatch String toText(AbstractType item, EObject context)
    {
        if (item.primitiveType !== null)
            return toText(item.primitiveType, item)
        else if (item.referenceType !== null)
            return toText(item.referenceType, item)
        else if (item.collectionType !== null)
            return toText(item.collectionType, item)

        throw new IllegalArgumentException("Unknown AbstractType: " + item.class.toString)
    }

    def dispatch String toText(AliasDeclaration item, EObject context)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
            '''typedef «toText(item.type, context)» «item.name»;'''
        else
            '''«resolve(item)»'''
    }

    def dispatch String toText(EnumDeclaration item, EObject context)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
            '''
                enum class «item.name»
                {
                   «FOR enum_value : item.containedIdentifiers»
                       «enum_value»«IF enum_value != item.containedIdentifiers.last»,«ENDIF»
                   «ENDFOR»
                }«IF item.declarator !== null» «item.declarator»«ENDIF»;
            '''
        else
            '''«resolve(item)»'''
    }

    def dispatch String toText(StructDeclaration item, EObject context)
    {

        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
        {
            val related_event = com.btc.serviceidl.util.Util.getRelatedEvent(item, idl)
            var makeCompareOperator = false
            for (member : item.members)
            {
                if (member.name == "Id" && member.type.primitiveType !== null &&
                    member.type.primitiveType.uuidType !== null)
                    makeCompareOperator = true
            }

            '''
                struct «makeExportMacro()» «item.name»«IF item.supertype !== null» : «resolve(item.supertype)»«ENDIF»
                {
                   «FOR type_declaration : item.typeDecls»
                       «toText(type_declaration, item)»
                   «ENDFOR»
                   «FOR member : item.members»
                       «val is_pointer = useSmartPointer(item, member.type)»
                       «val is_optional = member.isOptional»
                       «IF is_optional && !is_pointer»«resolveCAB("BTC::Commons::CoreExtras::Optional")»< «ENDIF»«IF is_pointer»«resolveSTL("std::shared_ptr")»< «ENDIF»«toText(member.type, item)»«IF is_pointer» >«ENDIF»«IF is_optional && !is_pointer» >«ENDIF» «member.name.asMember»;
                   «ENDFOR»
                   
                   «IF related_event !== null»
                       /** \return {«GuidMapper.get(related_event)»} */
                       static «resolveCAB("BTC::Commons::CoreExtras::UUID")» EVENT_TYPE_GUID();
                       
                   «ENDIF»
                   
                   «IF makeCompareOperator»
                       bool operator==( «item.name» const &other ) const
                          {   return id == other.id; }
                   «ENDIF»
                }«IF item.declarator !== null» «item.declarator»«ENDIF»;
            '''
        }
        else
            '''«resolve(item)»'''
    }

    def dispatch String toText(ExceptionReferenceDeclaration item, EObject context)
    {
        if (context instanceof FunctionDeclaration)
            '''«Names.plain(item)»'''
    }

    def dispatch String toText(ExceptionDeclaration item, EObject context)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
        {
            if (item.members.empty)
                '''
                    «resolveCAB("CAB_SIMPLE_EXCEPTION_DEFINITION")»( «item.name», «IF item.supertype !== null»«resolve(item.supertype)»«ELSE»«resolveCAB("BTC::Commons::Core::Exception")»«ENDIF», «makeExportMacro()» )
                '''
            else
            {
                val class_name = item.name
                val base_class_name = makeBaseExceptionType(item)
                '''                    
                    // based on CAB macro CAB_SIMPLE_EXCEPTION_DEFINITION_EX from Exception.h
                    struct «makeExportMacro» «class_name» : public virtual «base_class_name»
                    {
                       typedef «base_class_name» BASE;
                       
                       «class_name»();
                       explicit «class_name»(«resolveCAB("BTC::Commons::Core::String")» const &msg);
                       «class_name»( «FOR member : item.members SEPARATOR ", "»«toText(member.type, item)» const& «member.name.asMember»«ENDFOR» );
                       
                       virtual ~«class_name»();
                       virtual void Throw() const;
                       virtual void Throw();
                       
                       «FOR member : item.members»
                           «toText(member.type, item)» «member.name.asMember»;
                       «ENDFOR»
                       
                       protected:
                          virtual «resolveCAB("BTC::Commons::Core::Exception")» *IntClone() const;
                    };
                '''
            }
        }
        else
            resolve(item).toString
    }

    def dispatch String toText(PrimitiveType item, EObject context)
    {
        getPrimitiveTypeName(item)
    }

    def dispatch String toText(SequenceDeclaration item, EObject context)
    {
        val inner_type = '''«IF item.failable»«

resolveCAB
("BTC::Commons::CoreExtras::FailableHandle")»< «ENDIF»«toText
(item.type, item)»«IF item
.failable» >«ENDIF»'''

        if (item.isOutputParameter)
            '''«resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< «inner_type» >::Type'''
        else if (context.eContainer instanceof MemberElement)
            '''«resolveSTL("std::vector")»< «inner_type» >'''
        else
            '''«resolveCAB("BTC::Commons::Core::ForwardConstIterator")»< «inner_type» >'''
    }

    def dispatch String toText(TupleDeclaration item, EObject context)
    {
        '''«resolveSTL("std::tuple")»<«FOR type : item.types»«toText(type, item)»«IF type != item.types.last», «ENDIF»«ENDFOR»>'''
    }

    def dispatch String toText(EventDeclaration item, EObject context)
    {
        '''«toText(item.data, item)»'''
    }

    def dispatch String toText(DocCommentElement item, EObject context)
    {
        com.btc.serviceidl.util.Util.getPlainText(item)
    }

    def dispatch String toText(ModuleDeclaration item, EObject context)
    {
        Names.plain(item)
    }

    def dispatch String toText(InterfaceDeclaration item, EObject context)
    {
        Names.plain(item)
    }

    def String makeExportMacro()
    {
        GeneratorUtil.transform(param_bundle, TransformType.EXPORT_HEADER).toUpperCase +
            Constants.SEPARATOR_CPP_HEADER + "EXPORT"
    }

    def private String makeBaseExceptionType(ExceptionDeclaration exception)
    {
        '''«IF exception.supertype === null»«resolveCAB("BTC::Commons::Core::Exception")»«ELSE»«resolve(exception.supertype)»«ENDIF»'''
    }

    def String generateHConstructor(InterfaceDeclaration interface_declaration)
    {
        val class_name = resolve(interface_declaration, param_bundle.projectType.get)

        '''
            /**
               \brief Object constructor
            */
            «class_name.shortName»
            (
               «resolveCAB("BTC::Commons::Core::Context")» &context
               ,«resolveCAB("BTC::Logging::API::LoggerFactory")» &loggerFactory
               «IF param_bundle.projectType == ProjectType.PROXY»
                   ,«resolveCAB("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
                   ,«resolveCAB("BTC::Commons::CoreExtras::Optional")»<«resolveCAB("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid 
                      = «resolveCAB("BTC::Commons::CoreExtras::Optional")»<«resolveCAB("BTC::Commons::CoreExtras::UUID")»>()
               «ELSEIF param_bundle.projectType == ProjectType.DISPATCHER»
                   ,«resolveCAB("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
                   ,«resolveCAB("BTC::Commons::Core::AutoPtr")»< «resolve(interface_declaration, ProjectType.SERVICE_API)» > dispatchee
               «ENDIF»
            );
        '''
    }

    def String generateHDestructor(InterfaceDeclaration interface_declaration)
    {
        val class_name = GeneratorUtil.getClassName(param_bundle, interface_declaration.name)

        '''
            /**
               \brief Object destructor
            */
            virtual ~«class_name»();
        '''
    }

    def String generateIncludes(boolean is_header)
    {
        '''
            «FOR module_header : modules_includes.sort»
                #include "«module_header»"
            «ENDFOR»
            
            «IF is_header && typeResolver.param_bundle.projectType == ProjectType.PROXY»
                // resolve naming conflict between Windows' API function InitiateShutdown and CAB's AServiceProxyBase::InitiateShutdown
                #ifdef InitiateShutdown
                #undef InitiateShutdown
                #endif
                
            «ENDIF»
            «FOR cab_header : cab_includes.sort BEFORE '''#include "modules/Commons/include/BeginCabInclude.h"     // CAB -->''' + System.lineSeparator AFTER '''#include "modules/Commons/include/EndCabInclude.h"       // <-- CAB

         '''»
                #include "«cab_header»"
            «ENDFOR»
            «FOR boost_header : boost_includes.sort BEFORE '''#include "modules/Commons/include/BeginBoostInclude.h"   // BOOST -->''' + System.lineSeparator AFTER '''#include "modules/Commons/include/EndBoostInclude.h"     // <-- BOOST

         '''»
                #include <«boost_header»>
            «ENDFOR»
            «FOR odb_header : odb_includes.sort BEFORE "// ODB" + System.lineSeparator AFTER '''

         '''»
                #include <«odb_header»>
            «ENDFOR»
            «FOR stl_header : stl_includes.sort BEFORE '''#include "modules/Commons/include/BeginStdInclude.h"     // STD -->''' + System.lineSeparator AFTER '''#include "modules/Commons/include/EndStdInclude.h"       // <-- STD

         '''»
                #include <«stl_header»>
            «ENDFOR»
            «IF !is_header && typeResolver.param_bundle.projectType == ProjectType.SERVER_RUNNER»
                
                #ifndef NOMINMAX
                #define NOMINMAX
                #endif
                #include <windows.h>
            «ENDIF»
        '''
    }

    def String makeExceptionImplementation(ExceptionDeclaration exception)
    {
        '''
            «IF exception.members.empty»
                «resolveCAB("CAB_SIMPLE_EXCEPTION_IMPLEMENTATION")»( «resolve(exception).shortName» )
            «ELSE»
                «val class_name = exception.name»
                // based on CAB macro CAB_SIMPLE_EXCEPTION_IMPLEMENTATION_DEFAULT_MSG from Exception.h
                «class_name»::«class_name»() : BASE("")
                {}
                
                «class_name»::«class_name»(«resolveCAB("BTC::Commons::Core::String")» const &msg) : BASE("")
                {}
                
                «class_name»::«class_name»(
                   «FOR member : exception.members SEPARATOR ", "»«toText(member.type, exception)» const& «member.name.asMember»«ENDFOR»
                ) : BASE("")
                   «FOR member : exception.members», «member.name.asMember»( «member.name.asMember» )«ENDFOR»
                {}
                
                «class_name»::~«class_name»()
                {}
                
                void «class_name»::Throw() const
                {
                   throw this;
                }
                
                void «class_name»::Throw()
                {
                   throw this;
                }
                
                «resolveCAB("BTC::Commons::Core::Exception")» *«class_name»::IntClone() const
                {
                   return new «class_name»(GetSingleMsg());
                }
            «ENDIF»
        '''
    }

}
