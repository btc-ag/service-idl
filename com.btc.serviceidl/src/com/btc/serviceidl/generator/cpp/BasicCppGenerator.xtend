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

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.GuidMapper
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.HeaderResolver.OutputConfigurationItem
import com.btc.serviceidl.generator.cpp.TypeResolver.IncludeGroup
import com.btc.serviceidl.idl.AbstractStructuralDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.DocCommentElement
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.VoidType
import com.btc.serviceidl.util.Constants
import java.util.ArrayList
import java.util.Comparator
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class BasicCppGenerator
{
    // must be protected to allow subclasses to benefit from extension declaration
    @Accessors(PUBLIC_GETTER) protected val extension TypeResolver typeResolver
    @Accessors(PUBLIC_GETTER) val ITargetVersionProvider targetVersionProvider
    @Accessors(PUBLIC_GETTER) val ParameterBundle paramBundle

    def String generateCppDestructor(InterfaceDeclaration interfaceDeclaration)
    {
        val className = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType,
            interfaceDeclaration.name)

        '''
            «className»::~«className»()
            {}
        '''
    }

    def String generateInheritedInterfaceMethods(InterfaceDeclaration interfaceDeclaration)
    {
        val className = resolve(interfaceDeclaration, paramBundle.projectType)

        '''
            «FOR function : interfaceDeclaration.functions»
                «IF !function.isSync»«resolveSymbol("BTC::Commons::CoreExtras::Future")»<«ENDIF»«toText(function.returnedType, interfaceDeclaration)»«IF !function.isSync»>«ENDIF» «className.shortName»::«function.name»(«generateParameters(function)»)«IF function.isQuery» const«ENDIF»
                {
                   «generateFunctionBody(interfaceDeclaration, function)»
                }
                
            «ENDFOR»
        '''
    }

    def generateFunctionBody(InterfaceDeclaration interfaceDeclaration, FunctionDeclaration function)
    {
        // TODO make this function abstract and move implementation to subclass
        '''
            «IF paramBundle.projectType == ProjectType.IMPL || paramBundle.projectType == ProjectType.EXTERNAL_DB_IMPL»
                // \todo Auto-generated method stub! Implement actual business logic!
                «resolveSymbol("CABTHROW_V2")»(«resolveSymbol("BTC::Commons::Core::UnsupportedOperationException")»( "«Constants.AUTO_GENERATED_METHOD_STUB_MESSAGE»" ));
            «ENDIF»
        '''
    }

    def String generateParameters(FunctionDeclaration function)
    {
        '''«FOR parameter : function.parameters SEPARATOR ", "»«toText(parameter, function)»«ENDFOR»'''
    }

    def dispatch String toText(ParameterElement item, EObject context)
    {
        if (item.paramType.isSequenceType)
            '''«toText(item.paramType, context.eContainer)» «IF item.direction == ParameterDirection.PARAM_OUT»&«ENDIF»«item.paramName»'''
        else
            '''«toText(item.paramType, context.eContainer)»«IF item.direction == ParameterDirection.PARAM_IN» const«ENDIF» &«item.paramName»'''
    }

    def dispatch String toText(VoidType returnType, EObject context)
    {
        "void"
    }

    def dispatch String toText(AbstractType item, EObject context)
    {
        return toText(item.actualType, item)
    }

    def dispatch String toText(AliasDeclaration item, EObject context)
    {
        if (context instanceof AbstractStructuralDeclaration)
            '''typedef «toText(item.type, context)» «item.name»;'''
        else
            '''«resolve(item)»'''
    }

    def dispatch String toText(EnumDeclaration item, EObject context)
    {
        if (context instanceof AbstractStructuralDeclaration)
            '''
                enum class «item.name»
                {
                   «FOR enumValue : item.containedIdentifiers»
                       «enumValue»«IF enumValue != item.containedIdentifiers.last»,«ENDIF»
                   «ENDFOR»
                }«IF item.declarator !== null» «item.declarator»«ENDIF»;
            '''
        else
            '''«resolve(item)»'''
    }

    def dispatch String toText(StructDeclaration item, EObject context)
    {

        if (context instanceof AbstractStructuralDeclaration)
        {
            val relatedEvent = item.relatedEvent
            val makeCompareOperator = item.needsCompareOperator

            '''
                struct «makeExportMacro()» «item.name»«IF item.supertype !== null» : «resolve(item.supertype)»«ENDIF»
                {
                   «FOR typeDeclaration : item.typeDecls»
                       «toText(typeDeclaration, item)»
                   «ENDFOR»
                   «FOR member : item.members»
                       «val isPointer = useSmartPointer(item, member.type.actualType)»
                       «val isOptional = member.isOptional»
                       «IF isOptional && !isPointer»«resolveSymbol("BTC::Commons::CoreExtras::Optional")»< «ENDIF»«IF isPointer»«resolveSymbol("std::shared_ptr")»< «ENDIF»«toText(member.type, item)»«IF isPointer» >«ENDIF»«IF isOptional && !isPointer» >«ENDIF» «member.name.asMember»;
                   «ENDFOR»
                   
                   «IF relatedEvent !== null»
                       /** \return {«GuidMapper.get(relatedEvent)»} */
                       static «resolveSymbol("BTC::Commons::CoreExtras::UUID")» EVENT_TYPE_GUID();
                       
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

    private def boolean needsCompareOperator(StructDeclaration declaration)
    {
        declaration.members.exists[name == "Id" && type.primitiveType !== null && type.primitiveType.uuidType !== null]
    }

    def dispatch String toText(ExceptionReferenceDeclaration item, EObject context)
    {
        if (context instanceof FunctionDeclaration)
            '''«Names.plain(item)»'''
    }

    def dispatch String toText(ExceptionDeclaration item, EObject context)
    {
        if (context instanceof AbstractStructuralDeclaration)
        {
            if (item.members.empty)
                '''
                    «resolveSymbol("CAB_SIMPLE_EXCEPTION_DEFINITION")»( «item.name», «IF item.supertype !== null»«resolve(item.supertype)»«ELSE»«resolveSymbol("BTC::Commons::Core::Exception")»«ENDIF», «makeExportMacro()» )
                '''
            else
            {
                val className = item.name
                val baseClassName = makeBaseExceptionType(item)
                '''                    
                    // based on CAB macro CAB_SIMPLE_EXCEPTION_DEFINITION_EX from Exception.h
                    struct «makeExportMacro» «className» : public virtual «baseClassName»
                    {
                       typedef «baseClassName» BASE;
                       
                       «className»();
                       explicit «className»(«resolveSymbol("BTC::Commons::Core::String")» const &msg);
                       «className»( «FOR member : item.members SEPARATOR ", "»«toText(member.type, item)» const& «member.name.asMember»«ENDFOR» );
                       
                       virtual ~«className»() = default;
                       
                       virtual void Throw() const override;
                       
                       «IF targetVersion == ServiceCommVersion.V0_10 || targetVersion == ServiceCommVersion.V0_11»
                           virtual void Throw() override;
                       «ENDIF»
                       
                       «FOR member : item.members»
                           «toText(member.type, item)» «member.name.asMember»;
                       «ENDFOR»
                       
                       protected:
                          «IF targetVersion == ServiceCommVersion.V0_10 || targetVersion == ServiceCommVersion.V0_11»
                              virtual «resolveSymbol("BTC::Commons::Core::Exception")» *IntClone() const;
                          «ELSE»
                              virtual «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Exception")»> IntClone() const override;
                          «ENDIF»
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
        val innerType = '''«IF item.failable»«

        resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")»< «ENDIF»«toText(item.type, item)»«IF item.failable» >«ENDIF»'''

        if (item.isOutputParameter)
            '''«resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< «innerType» >::Type'''
        else if (context.eContainer instanceof MemberElement)
            '''«resolveSymbol("std::vector")»< «innerType» >'''
        else
            '''«resolveSymbol("BTC::Commons::Core::ForwardConstIterator")»< «innerType» >'''
    }

    def dispatch String toText(TupleDeclaration item, EObject context)
    {
        '''«resolveSymbol("std::tuple")»<«FOR type : item.types»«toText(type, item)»«IF type != item.types.last», «ENDIF»«ENDFOR»>'''
    }

    def dispatch String toText(EventDeclaration item, EObject context)
    {
        '''«toText(item.data, item)»'''
    }

    def dispatch String toText(DocCommentElement item, EObject context)
    {
        item.plainText
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
        GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.EXPORT_HEADER).
            toUpperCase + Constants.SEPARATOR_CPP_HEADER + "EXPORT"
    }

    private def String makeBaseExceptionType(ExceptionDeclaration exception)
    {
        '''«IF exception.supertype === null»«resolveSymbol("BTC::Commons::Core::Exception")»«ELSE»«resolve(exception.supertype)»«ENDIF»'''
    }

    def String generateHConstructor(InterfaceDeclaration interfaceDeclaration)
    {
        val className = resolve(interfaceDeclaration, paramBundle.projectType)

        '''
            /**
               \brief Object constructor
            */
            «className.shortName»
            (
               «resolveSymbol("BTC::Commons::Core::Context")» &context
               ,«resolveSymbol("BTC::Logging::API::LoggerFactory")» &loggerFactory
               «IF paramBundle.projectType == ProjectType.PROXY»
                   ,«resolveSymbol("BTC::ServiceComm::API::IClientEndpoint")» &localEndpoint
                   ,«resolveSymbol("BTC::Commons::CoreExtras::Optional")»<«resolveSymbol("BTC::Commons::CoreExtras::UUID")»> const &serverServiceInstanceGuid 
                      = «resolveSymbol("BTC::Commons::CoreExtras::Optional")»<«resolveSymbol("BTC::Commons::CoreExtras::UUID")»>()
               «ELSEIF paramBundle.projectType == ProjectType.DISPATCHER»
                   ,«resolveSymbol("BTC::ServiceComm::API::IServerEndpoint")»& serviceEndpoint
                   ,«resolveSymbol("BTC::Commons::Core::AutoPtr")»< «resolve(interfaceDeclaration, ProjectType.SERVICE_API)» > dispatchee
               «ENDIF»
            );
        '''
    }

    def String generateHDestructor(InterfaceDeclaration interfaceDeclaration)
    {
        val className = GeneratorUtil.getClassName(ArtifactNature.CPP, paramBundle.projectType,
            interfaceDeclaration.name)

        '''
            /**
               \brief Object destructor
            */
            virtual ~«className»();
        '''
    }

    private static def <K, V> Iterable<V> extractAllExcludeNull(Map<K, V> map, Iterable<K> keys)
    {
        val result = new ArrayList<V>
        for (key : keys)
        {
            if (map.containsKey(key))
            {
                result.add(map.get(key))
                map.remove(key)
            }
        }
        result
    }

    def CharSequence generateIncludes(boolean isHeader)
    {
        // TODO filter out self from includes (here, or already in the TypeResolver.resolve call?
        val includes = typeResolver.includes
        val result = new StringBuilder()

        for (outputConfigurationItem : headerResolver.outputConfiguration)
        {
            generateIncludesSection(isHeader, outputConfigurationItem, includes, result)
        }

        if (!includes.empty)
        {
            throw new IllegalArgumentException("Unconfigured include groups: " + includes.keySet.join(", "))
        }

        // TODO remove this (at least from here)
        if (!isHeader && paramBundle.projectType == ProjectType.SERVER_RUNNER)
            result.append(    
            '''            
                
                #ifndef NOMINMAX
                #define NOMINMAX
                #endif
                #include <windows.h>
            ''')

        return result
    }

    def generateIncludesSection(boolean isHeader, OutputConfigurationItem outputConfigurationItem,
        Map<IncludeGroup, Set<IPath>> includes, StringBuilder result)
    {
        val sortedElements = includes.extractAllExcludeNull(outputConfigurationItem.includeGroups).flatten.sortWith(
                Comparator.comparing[toString])
        if (!sortedElements.empty)
        {
            result.append(outputConfigurationItem.prefix)
            for (element : sortedElements)
            {
                result.append("#include ")
                result.append(if (outputConfigurationItem.systemIncludeStyle) "<" else "\"")
                result.append(element)
                result.append(if (outputConfigurationItem.systemIncludeStyle) ">" else "\"")
                result.append(System.lineSeparator)
            }
            result.append(outputConfigurationItem.suffix)
            result.append(System.lineSeparator)
        }

        // TODO remove this
        if (outputConfigurationItem.precedence == 0 && isHeader && paramBundle.projectType == ProjectType.PROXY)
        {
            result.append('''
                // resolve naming conflict between Windows' API function InitiateShutdown and CAB's AServiceProxyBase::InitiateShutdown
                #ifdef InitiateShutdown
                #undef InitiateShutdown
                #endif
                                
            ''')
        }
    }

    def String makeExceptionImplementation(ExceptionDeclaration exception)
    {
        '''
            «IF exception.members.empty»
                «resolveSymbol("CAB_SIMPLE_EXCEPTION_IMPLEMENTATION")»( «resolve(exception).shortName» )
            «ELSE»
                «val className = exception.name»
                // based on CAB macro CAB_SIMPLE_EXCEPTION_IMPLEMENTATION_DEFAULT_MSG from Exception.h
                «className»::«className»() : BASE("")
                {}
                
                «className»::«className»(«resolveSymbol("BTC::Commons::Core::String")» const &msg) : BASE("")
                {}
                
                «className»::«className»(
                   «FOR member : exception.members SEPARATOR ", "»«toText(member.type, exception)» const& «member.name.asMember»«ENDFOR»
                ) : BASE("")
                   «FOR member : exception.members», «member.name.asMember»( «member.name.asMember» )«ENDFOR»
                {}
                
                «IF targetVersion == ServiceCommVersion.V0_10 || targetVersion == ServiceCommVersion.V0_11»
                    void «className»::Throw() const
                    {
                       throw this;
                    }
                    
                    void «className»::Throw()
                    {
                       throw this;
                    }
                    
                    «resolveSymbol("BTC::Commons::Core::Exception")» *«className»::IntClone() const
                    {
                        return new «className»(*this);
                    }
                «ELSE»
                    void «className»::Throw() const
                    {
                       throw *this;
                    }
                    
                    «resolveSymbol("BTC::Commons::Core::UniquePtr")»<«resolveSymbol("BTC::Commons::Core::Exception")»> «className»::IntClone() const
                    {
                       return «resolveSymbol("BTC::Commons::Core::CreateUnique")»<«className»>(*this);
                    }
                «ENDIF»
                
            «ENDIF»
        '''
    }

    protected def getTargetVersion()
    {
        ServiceCommVersion.get(targetVersionProvider.getTargetVersion(CppConstants.SERVICECOMM_VERSION_KIND))
    }

}
