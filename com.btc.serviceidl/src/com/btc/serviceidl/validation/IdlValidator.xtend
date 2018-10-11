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
 * This class contains custom validation rules. 
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
package com.btc.serviceidl.validation

import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.EventDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.ExceptionReferenceDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.IdlPackage
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.KeyElement
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.idl.TypicalLengthHint
import com.btc.serviceidl.idl.TypicalSizeHint
import com.btc.serviceidl.util.Util
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.regex.Pattern
import org.eclipse.xtext.validation.Check

import static extension com.btc.serviceidl.util.Extensions.*
import static extension org.eclipse.xtext.EcoreUtil2.*

class IdlValidator extends AbstractIdlValidator
{
    // TODO add a warning for interfaces without any operation
    // TODO add an error if interface or event GUIDs are not unique
//	public static val INVALID_NAME = 'invalidName'
//
//	@Check
//	def checkGreetingStartsWithCapital(Greeting greeting) {
//		if (!Character.isUpperCase(greeting.name.charAt(0))) {
//			warning('Name should start with a capital', 
//					IdlPackage.Literals.GREETING__NAME,
//					INVALID_NAME)
//		}
//	}
    // unique identification codes for quickfixes
    public static final String INTERFACE_GUID = "com.btc.serviceidl.validation.ensureInterfaceGUID";
    public static final String DEPRECATED_INTERFACE_VERSION = "com.btc.serviceidl.validation.deprecatedInterfaceVersion";
    public static final String UNIQUE_MAIN_MODULE = "com.btc.serviceidl.validation.uniqueMainModule";
    public static final String EMPTY_NON_MAIN_MODULE = "com.btc.serviceidl.validation.emptyNonMainModule";
    public static final String INDETERMINATE_IMPLICIT_MAIN_MODULE = "com.btc.serviceidl.validation.indeterminateImplicitMainModule";
    public static final String AMBIGUOUS_IMPLICIT_MAIN_MODULE = "com.btc.serviceidl.validation.ambiguousImplicitMainModule";

    /**
     * Verify, that at most 1 anonymous event exists per interface.
     */
    @Check
    def checkMultipleAnonymousEvents(InterfaceDeclaration element)
    {

        val anonymousEvents = element.contains.filter(EventDeclaration).filter[name === null]
        if (anonymousEvents.size > 1)
        {
            error(
                "Only 1 anonymous event is allowed per interface",
                anonymousEvents.last,
                IdlPackage.Literals.NAMED_DECLARATION__NAME
            )
        }
    }

    /**
     * Verify, that at most 2 sequence hints are allowed and they must have different types.
     */
    @Check
    def checkSequenceHints(SequenceDeclaration element)
    {
        val sizeHints = element.sequenceHints.filter(TypicalSizeHint)
        if (sizeHints.size > 1)
        {
            error(
                "Typical element size already defined",
                sizeHints.last,
                IdlPackage.Literals.TYPICAL_SIZE_HINT__SIZE
            )
        }

        val lengthHints = element.sequenceHints.filter(TypicalLengthHint)
        if (lengthHints.size > 1)
        {
            error(
                "Typical sequence length already defined",
                lengthHints.last,
                IdlPackage.Literals.TYPICAL_LENGTH_HINT__LENGTH
            )
        }
    }

    /**
     * Verify, that a non-virtual module does not contain any nested virtual modules.
     */
    @Check
    def checkModuleStructure(ModuleDeclaration module)
    {
        if (module.isVirtual && module.eContainer instanceof ModuleDeclaration)
        {
            val parentModule = module.eContainer as ModuleDeclaration
            if (!parentModule.isVirtual)
            {
                error(
                    "Virtual modules cannot be nested within non-virtual modules",
                    module,
                    IdlPackage.Literals.NAMED_DECLARATION__NAME
                )
            }
        }
    }

    /**
     * Verify, that a type is not extending itself.
     */
    @Check
    def checkInheritance(InterfaceDeclaration element)
    {
        if (!element.derivesFrom.empty && element.baseTypes.contains(element))
            error(Messages.CIRCULAR_INHERITANCE, element, IdlPackage.Literals.INTERFACE_DECLARATION__DERIVES_FROM)
    }

    @Check
    def checkInheritance(ExceptionDeclaration element)
    {
        if (element.supertype !== null && element.baseTypes.contains(element))
            error(Messages.CIRCULAR_INHERITANCE, element, IdlPackage.Literals.EXCEPTION_DECLARATION__SUPERTYPE)
    }

    @Check
    def checkInheritance(StructDeclaration element)
    {
        if (element.supertype !== null && element.baseTypes.contains(element))
            error(Messages.CIRCULAR_INHERITANCE, element, IdlPackage.Literals.STRUCT_DECLARATION__SUPERTYPE)
    }

    /**
     * Verify, that module names and interface names are unique: otherwise 
     * problems with currently implemented way of Profotbuf artifacts generation.
     */
    @Check
    def namingCollisions(IDLSpecification idlSpecification)
    {
        val nameMap = new HashMap<String, Boolean>

        for (module : idlSpecification.eAllContents.filter(ModuleDeclaration).toIterable)
        {
            if (nameMap.containsKey(module.name))
                error(Messages.NAME_COLLISION, module, IdlPackage.Literals.NAMED_DECLARATION__NAME)
            else
                nameMap.put(module.name, Boolean.TRUE)
        }

        for (interfaceDeclaration : idlSpecification.eAllContents.filter(InterfaceDeclaration).toIterable)
        {
            if (nameMap.containsKey(interfaceDeclaration.name))
                error(Messages.NAME_COLLISION, interfaceDeclaration, IdlPackage.Literals.NAMED_DECLARATION__NAME)
            else
                nameMap.put(interfaceDeclaration.name, Boolean.TRUE)
        }
    }

    /**
     * Inherited types may not have equally named members as their base types!
     */
    @Check
    def namingCollisions(StructDeclaration element)
    {
        if (element.supertype !== null)
        {
            val baseTypes = element.baseTypes as Collection<StructDeclaration>
            val allMemberNames = baseTypes.map[members].flatten.map[name].toList
            if (element.members.findFirst[e|allMemberNames.contains(e.name)] !== null)
            {
                error(Messages.NAME_COLLISION_MEMBERS, element, IdlPackage.Literals.STRUCT_DECLARATION__MEMBERS)
            }
        }
    }

    /**
     * Verify, that a structure is used as event type in at most 1 event.
     * Reason: the structure will get an event type GUID from the event; it is
     * not possible to have multiple GUIDs for the same structure!
     */
    @Check
    def checkRelatedEvents(IDLSpecification idlSpecification)
    {
        for (eventData : idlSpecification.eAllContents.filter(StructDeclaration).toIterable)
        {
            val relatedEvents = idlSpecification.eAllContents.filter(EventDeclaration).filter[data === eventData].toList
            if (relatedEvents.size > 1)
            {
                for (event : relatedEvents.drop(1))
                {
                    error("Event type " + event.data.name +
                        " is already used in another event. Multiple events cannot use the same type due to GUID collisions",
                        event, IdlPackage.Literals.EVENT_DECLARATION__DATA)
                }
            }
        }
    }

    /**
     * Verify, that there is at most one "main" module responsible for custom
     * namespace decorations (e.g. in .NET this module will get the ".NET" extension)
     */
    @Check
    def checkUniqueMainModule(IDLSpecification idlSpecification)
    {
        if (idlSpecification.eAllContents.filter(ModuleDeclaration).filter[main].size > 1)
        {
            error(Messages.UNIQUE_MAIN_MODULE,
                idlSpecification.eAllContents.filter(ModuleDeclaration).filter[main].tail.head,
                IdlPackage.Literals.MODULE_DECLARATION__MAIN, UNIQUE_MAIN_MODULE)
        }
    }

    /**
     * Verify that there is a module declared as main if there are multiple non-empty modules. 
     */
    @Check
    def checkMainModuleDeclaredIfAmbiguous(IDLSpecification idlSpecification)
    {
        val mainModule = idlSpecification.eAllContents.filter(ModuleDeclaration).filter[main].head
        if (mainModule === null)
        {
            val modulesWithComponents = idlSpecification.eAllContents.filter(ModuleDeclaration).filter [
                !moduleComponents.empty
            ].toList
            val topLevelModules = modulesWithComponents.map[topLevelModule].toSet
            if (topLevelModules.size > 1)
            {
                for (module : topLevelModules)
                {
                    error(Messages.INDETERMINATE_IMPLICIT_MAIN_MODULE, module, null, INDETERMINATE_IMPLICIT_MAIN_MODULE)
                }
            }
            else if (modulesWithComponents.size > 1)
            {
                for (module : modulesWithComponents)
                {
                    warning(Messages.AMBIGUOUS_IMPLICIT_MAIN_MODULE, module, null, AMBIGUOUS_IMPLICIT_MAIN_MODULE)
                }
            }

        }
    }

    private def getTopLevelModule(ModuleDeclaration moduleDeclaration)
    {
        var previousModule = moduleDeclaration
        var currentModule = previousModule.eContainer.getContainerOfType(ModuleDeclaration)
        while (currentModule !== null)
        {
            previousModule = currentModule
            currentModule = currentModule.eContainer.getContainerOfType(ModuleDeclaration)
        }
        return previousModule
    }

    /**
     * Verify, that all modules outside the main module are empty (i.e. they
     * may only contain an inner module that is a parent of the main module).
     */
    @Check
    def checkModulesOutsideMainAreEmpty(IDLSpecification idlSpecification)
    {
        val mainModule = idlSpecification.eAllContents.filter(ModuleDeclaration).filter[main].head
        if (mainModule !== null)
        {
            var previousModule = mainModule
            var currentModule = mainModule.eContainer.getContainerOfType(ModuleDeclaration)
            while (currentModule !== null)
            {
                val innerModule = previousModule
                if (!currentModule.eContents.filter[it !== innerModule].empty)
                {
                    error(Messages.EMPTY_NON_MAIN_MODULE, currentModule,
                        IdlPackage.Literals.MODULE_DECLARATION__NESTED_MODULES, EMPTY_NON_MAIN_MODULE)
                }

                previousModule = currentModule
                currentModule = currentModule.eContainer.getContainerOfType(ModuleDeclaration)
            }

            val innerModule = previousModule
            val otherModules = idlSpecification.modules.filter[it !== innerModule]
            for (module : otherModules)
            {
                error(Messages.EMPTY_NON_MAIN_MODULE, module, IdlPackage.Literals.MODULE_DECLARATION__NESTED_MODULES,
                    EMPTY_NON_MAIN_MODULE)
            }
        }
    }

    /**
     * Verify, that a tuple may have at most 8 items. This restriction originates
     * in .NET Framework System.Tuple type.
     */
    @Check
    def checkTupleTemplateNumber(TupleDeclaration tupleDeclaration)
    {
        if (tupleDeclaration.types.size > 8)
        {
            error(
                "No more than 8 tuple items (octuple) are supported to comply with the .NET Framework System.Tuple type",
                tupleDeclaration, IdlPackage.Literals.TUPLE_DECLARATION__TYPES)
        }
    }

    /**
     * Verify, that no keywords from C++, Java or C# are used as identifiers.
     */
    @Check
    def dispatch checkKeywordsAsIdentifiers(StructDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.LITERAL))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }

        if (element.declarator !== null && KeywordValidator.isKeyword(element.declarator, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.ENUM_DECLARATION__DECLARATOR)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(ModuleDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(ExceptionDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.LITERAL))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(EnumDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.LITERAL))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }

        if (KeywordValidator.isKeyword(element.declarator, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.ENUM_DECLARATION__DECLARATOR)
        }

        for (identifier : element.containedIdentifiers)
        {
            if (KeywordValidator.isKeyword(identifier, Pattern.LITERAL))
                error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element,
                    IdlPackage.Literals.ENUM_DECLARATION__CONTAINED_IDENTIFIERS)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(MemberElement element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.MEMBER_ELEMENT__NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(KeyElement element)
    {
        if (KeywordValidator.isKeyword(element.keyName, Pattern.LITERAL))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.KEY_ELEMENT__KEY_NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(FunctionDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(ParameterElement element)
    {
        if (KeywordValidator.isKeyword(element.paramName, Pattern.CASE_INSENSITIVE))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.PARAMETER_ELEMENT__PARAM_NAME)
        }
    }

    @Check
    def dispatch checkKeywordsAsIdentifiers(EventDeclaration element)
    {
        if (KeywordValidator.isKeyword(element.name, Pattern.LITERAL))
        {
            error(Messages.IDENTIFIER_NAME_IS_KEYWORD, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }
    }

    @Check
    def ensureInterfaceGUID(InterfaceDeclaration element)
    {
        if (element.guid === null)
        {
            info(
                "Every interface requires a GUID. Provide a custom one or press CTRL+1 for a Quick Fix. Otherwise it will be added automatically.",
                IdlPackage.Literals.INTERFACE_DECLARATION__GUID, INTERFACE_GUID)
        }
    }

    /**
     * This check verifies that a struct is actually constructable, especially in
     * .NET and Java. Background: Protobuf has "required" field marker, so everything
     * from the IDL which is not explicitly makred as "optional" will be "required".
     * In case of non-primitive structure members, it is required, that underlying
     * types contain either primitive types only or are marked as optional, otherwise
     * it is impossible to construct a valid instance. Example:
     * struct A { B b; } and struct B { A a; }. Since in .NET we must provide all
     * members in the constructor, we have new A{ b: new B { a: new A { b: new B { ... and so on.
     * If struct A { optional B b; } or B { optional A a; } no problem: new A { b: null }
     */
    @Check
    def ensureConstructability(StructDeclaration element)
    {
        val questionableTypes = new HashSet<AbstractTypeReference>
        questionableTypes.add(element)

        if (!isConstructible(element, questionableTypes))
        {
            error(Messages.TYPE_NOT_CONSTRUCTIBLE, element, IdlPackage.Literals.NAMED_DECLARATION__NAME)
        }
    }

    private def boolean isConstructible(AbstractTypeReference element,
        Collection<AbstractTypeReference> questionableTypes)
    {
        val nonPrimitiveTypes = element.effectiveMembers.filter[!optional].filter[!Util.isSequenceType(type)].filter [
            !Util.isPrimitive(type)
        ].map[Util.getUltimateType(type)]

        if (!nonPrimitiveTypes.empty)
        {
            for (type : nonPrimitiveTypes)
            {
                if (questionableTypes.contains(type))
                    return false

                questionableTypes.add(type)
                if (!isConstructible(type, questionableTypes))
                    return false
            }
        }

        questionableTypes.remove(element)
        return true
    }

    @Check
    def checkUniqueParameterNames(FunctionDeclaration element)
    {
        val map = new HashMap<String, Boolean>

        for (param : element.parameters)
        {
            val name = param.paramName.toLowerCase
            if (map.containsKey(name)) // ignore case, since e.g. in Protobuf identifiers will also be lower case!
            {
                error(Messages.NAME_COLLISION_PARAMETERS, element, IdlPackage.Literals.FUNCTION_DECLARATION__PARAMETERS)
            }
            else
                map.put(name, Boolean.TRUE)
        }
    }

    /**
     * In Java, immutable classes like String, UUID, enums or primitive type wrappers (Integer, Boolean, etc.)
     * cannot be used as output parameters due to language design!
     */
    @Check
    def checkImmutableOutputParameters(FunctionDeclaration element)
    {
        for (param : element.parameters.filter[direction == ParameterDirection.PARAM_OUT])
        {
            if (!(Util.isStruct(param.paramType) || Util.isSequenceType(param.paramType)))
            {
                error(Messages.IMMUTABLE_OUTPUT_PARAMETER, element,
                    IdlPackage.Literals.FUNCTION_DECLARATION__PARAMETERS)
            }
        }
    }

    @Check
    def checkDuplicateExceptions(FunctionDeclaration element)
    {
        if (element.raisedExceptions.size != element.raisedExceptions.toSet.size)
        {
            warning(Messages.DUPLICATE_EXCEPTION_TYPES, element,
                IdlPackage.Literals.FUNCTION_DECLARATION__RAISED_EXCEPTIONS)
        }
    }

    @Check
    def checkDuplicateExceptions(SequenceDeclaration element)
    {
        if (element.raisedExceptions.size != element.raisedExceptions.toSet.size)
        {
            warning(Messages.DUPLICATE_EXCEPTION_TYPES, element,
                IdlPackage.Literals.SEQUENCE_DECLARATION__RAISED_EXCEPTIONS)
        }
    }

    /* ==========================================================================
     *  The following warnings should only exist as long as some grammar features
     *  are not actually supported in regard to the code generation!
     ========================================================================= */
    @Check
    def unsupportedFeatureWarning(FunctionDeclaration element)
    {
        if (element.isInjected)
        {
            warning(
                "The 'injectable' keyword has currently no effect on the generated code",
                element,
                IdlPackage.Literals.FUNCTION_DECLARATION__INJECTED
            )
        }
    }

    @Check
    def unsupportedFeatureWarning(TypicalLengthHint element)
    {
        warning(
            "The 'typical sequence length' hint has currently no effect on the generated code",
            element,
            IdlPackage.Literals.TYPICAL_LENGTH_HINT__LENGTH
        )
    }

    @Check
    def unsupportedFeatureWarning(TypicalSizeHint element)
    {
        warning(
            "The 'typical element size' keyword hint currently no effect on the generated code",
            element,
            IdlPackage.Literals.TYPICAL_SIZE_HINT__SIZE
        )
    }

    @Check
    def unsupportedFeatureWarning(EventDeclaration element)
    {
        if (!element.raisedExceptions.empty)
        {
            warning(
                Messages.FEATURE_NOT_SUPPORED_BY_CAB,
                element,
                IdlPackage.Literals.EVENT_DECLARATION__RAISED_EXCEPTIONS
            )
        }

        // no ServiceComm support for key-based subscription in Java yet;
        // see mail from Niels Streekmann on July 2, 2015
        if (!element.keys.empty)
        {
            warning(
                Messages.FEATURE_NOT_SUPPORED_BY_CAB,
                element,
                IdlPackage.Literals.EVENT_DECLARATION__KEYS
            )
        }
    }

    /* ==========================================================================
     *  The following errors prevent the usage of some grammatically valid
     *  features which are known to be unsupported, unstable etc.
     ========================================================================= */
    @Check
    def unsupportedFeatureError(TupleDeclaration element)
    {
        error(Messages.TUPLE_TYPE_NOT_SUPPORTED, element, IdlPackage.Literals.TUPLE_DECLARATION__TYPES)
    }

//   /*
//      Currently, it's too expensive to make forward declarations for elements
//      defined in external namespaces, since we can do "struct NS01::NS02::NS03::Dummy"
//      only with C++17. Otherwise we need to generate an extra namespace for
//      the forward-declared type, which is too complex. Therefore we prohibit
//      the possibility for circular dependencies over module borders.
//   */
//   @Check
//   def unsupportedTransboundaryCircularDependencies(ModuleDeclaration module)
//   {
//      val externalForwardDeclarations =
//         module
//         .eContents
//         .toList
//         .resolveAllDependencies
//         .filter[ e | !e.forwardDeclarations.filter[!module.eContents.toList.contains(it)].empty ]
//         .map[type]
//      
//      for ( item : externalForwardDeclarations )
//      {
//         if (item instanceof StructDeclaration)
//         {
//            error(Messages.EXTERNAL_CIRCULAR_DEPENDENCIES, item, IdlPackage.Literals.STRUCT_DECLARATION__NAME)
//         }
//         else if (item instanceof ExceptionDeclaration)
//         {
//            error(Messages.EXTERNAL_CIRCULAR_DEPENDENCIES, item, IdlPackage.Literals.ABSTRACT_EXCEPTION__NAME)
//         }
//      }
//   }
    /**
     * Prohibit nested sequences, they would cause a lot of troubles...
     */
    @Check
    def unsupportedFeatureError(SequenceDeclaration element)
    {
        if (Util.isSequenceType(element.type))
        {
            error(Messages.NESTED_SEQUENCES_NOT_SUPPORTED, element, IdlPackage.Literals.SEQUENCE_DECLARATION__TYPE)
        }
    }

    @Check
    def unsupportedFeatureError(AliasDeclaration element)
    {
        if (Util.isSequenceType(element.type))
        {
            error(Messages.ALIAS_SEQUENCES_NOT_SUPPORTED, element, IdlPackage.Literals.ALIAS_DECLARATION__TYPE)
        }
    }

    /**
     * Prohibit exception reference, since there is currently no concept how to practically use it.
     */
    @Check
    def unsupportedFeatureError(ExceptionReferenceDeclaration element)
    {
        error(Messages.EXCEPTION_REFERENCE_NOT_SUPPORTED, element,
            IdlPackage.Literals.EXCEPTION_REFERENCE_DECLARATION__LOCATION)
    }

    @Check
    def unsupportedFeatureError(StructDeclaration element)
    {
        if (element.typeDecls !== null && !element.typeDecls.empty)
            error(Messages.DEPRECATED_NESTED_TYPE_DECLARATION, element,
                IdlPackage.Literals.STRUCT_DECLARATION__TYPE_DECLS)

        if (element.declarator !== null)
            error(Messages.DEPRECATED_ADHOC_DECLARATION, element, IdlPackage.Literals.STRUCT_DECLARATION__TYPE_DECLS)
    }

    @Check
    def unsupportedFeatureError(EnumDeclaration element)
    {
        if (element.declarator !== null)
            error(Messages.DEPRECATED_ADHOC_DECLARATION, element, IdlPackage.Literals.ENUM_DECLARATION__DECLARATOR)
    }

    @Check
    def deprecatedVersionDeclaration(InterfaceDeclaration element)
    {
        if (element.version !== null)
            error(Messages.DEPRECATED_VERSION_DECLARATION, element, IdlPackage.Literals.INTERFACE_DECLARATION__VERSION,
                DEPRECATED_INTERFACE_VERSION)
    }
}
