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
 * \file       CppExtensions.xtend
 * 
 * \brief      Static extension methods used for name resolution in C++
 */
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TypeWrapper
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.MemberElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import java.util.ArrayList
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.List
import org.eclipse.core.runtime.IPath

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class CppExtensions
{
    static def IPath getIncludeFilePath(AbstractTypeReference referencedObject, ProjectType projectType,
        IModuleStructureStrategy moduleStructureStrategy)
    {
        val scopeDeterminant = referencedObject.scopeDeterminant

        val baseName = if (scopeDeterminant instanceof InterfaceDeclaration)
                projectType.getClassName(ArtifactNature.CPP, Names.plain(scopeDeterminant))
            else
                Constants.FILE_NAME_TYPES

        moduleStructureStrategy.getIncludeFilePath(referencedObject.scopeDeterminant.moduleStack, projectType, baseName,
            HeaderType.REGULAR_HEADER)
    }

    /**
     * Returns sub-types of the given container sorted in their topological order.
     * If there are circular dependencies, then superior types are put into
     * forwardDeclarations collection, so that they can be handled in a specific
     * way.
     */
    static def Iterable<TypeWrapper> getTopologicallySortedTypes(AbstractContainerDeclaration owner)
    {
        // aggregate enums, typedefs, structs and exceptions into the same collection
        val allElements = new HashSet<AbstractTypeReference>
        allElements.addAll(owner.eContents.filter(EnumDeclaration))
        allElements.addAll(owner.eContents.filter(AliasDeclaration))
        allElements.addAll(owner.eContents.filter(StructDeclaration))
        allElements.addAll(owner.eContents.filter(ExceptionDeclaration))

        // construct a directed graph representation; a dependency relation between two
        // elements is represented as a pair X -> Y (meaning: X depends on Y)
        val graph = new HashSet<Pair<AbstractTypeReference, AbstractTypeReference>>
        allElements.forEach[it.predecessors.forEach[dependency|graph.add(it -> dependency)]]

        // sort out all independent elements
        val independentElements = allElements.filter[it.predecessors.empty].toList

        return applyKahnsAlgorithm(graph, independentElements)
    }

    /**
     * For the given collection of structures, resolve all types (consequently going
     * into all possible depth) on which they depend. We need this e.g. for
     * generation of ODB files to resolve dependencies by sorting the types in
     * the topological order.
     */
    static def Iterable<TypeWrapper> resolveAllDependencies(Iterable<AbstractTypeReference> elements)
    {
        // construct a directed graph representation; a dependency relation between two
        // elements is represented as a pair X -> Y (meaning: X depends on Y)
        val graph = new HashSet<Pair<AbstractTypeReference, AbstractTypeReference>>

        val allTypes = new HashSet<AbstractTypeReference>
        allTypes.addAll(elements)
        for (e : elements)
        {
            getUnderlyingTypes(e, allTypes)
        }
        allTypes.forEach[it.requirements.forEach[dependency|graph.add(it -> dependency)]]

        return applyKahnsAlgorithm(graph, allTypes.filter[it.requirements.empty].toList)
    }

    /**
     * Execute topological sorting based on Kahn's algorithm
     */
    private static def Iterable<TypeWrapper> applyKahnsAlgorithm(
        HashSet<Pair<AbstractTypeReference, AbstractTypeReference>> graph,
        List<AbstractTypeReference> independentElements)
    {
        // list finally containing the sorted elements
        val result = new LinkedHashSet<TypeWrapper>

        while (!independentElements.empty)
        {
            val n = independentElements.remove(0)
            result.add(new TypeWrapper(n))
            for (m : graph.filter[value == n].map[key].toList)
            {
                val edge = graph.findFirst[key == m && value == n]
                graph.remove(edge)
                if (graph.filter[key == m].empty)
                    independentElements.add(m)
            }
        }

        // handle circular dependencies
        if (!graph.empty)
        {
            // ordered collection of mutually dependent types; position of the element
            // is important: if element depends on a type declared later, the 
            // effective type must be resolved as smart pointer of a forward
            // declaration, otherwise directly
            val indexedList = new ArrayList<TypeWrapper>
            while (!graph.empty)
            {
                // get next unhandled element
                val edge = graph.head
                var typeWrapper = new TypeWrapper(edge.key)

                // retrieve index of the element; if not yet existent, add it
                var index = indexedList.indexOf(typeWrapper)
                if (index < 0)
                {
                    indexedList.add(typeWrapper)
                    index = indexedList.indexOf(typeWrapper)
                }
                else
                {
                    typeWrapper = indexedList.get(index)
                }

                // retrieve index of the superior type; if not yet existent or 
                // coming later than the dependent type, add to dependency list
                val dependencyWrapper = new TypeWrapper(edge.value)
                val indexDependency = indexedList.indexOf(dependencyWrapper)

                if (indexDependency >= index || indexDependency < 0)
                {
                    typeWrapper.addForwardDeclaration(dependencyWrapper.type)
                }

                graph.remove(edge)
            }

            result.addAll(indexedList)
        }

        return result
    }

    /**
     * Predecessors are all elements in the SAME header as the given element,
     * which must be declared before the element itself. Elements from other
     * headers are NOT among the predecessors, since they are resolved based
     * on the #include directive. 
     */
    static def dispatch Iterable<AbstractTypeReference> predecessors(StructDeclaration element)
    {
        predecessors(element.supertype, element.members)
    }

    static def dispatch Iterable<AbstractTypeReference> predecessors(AliasDeclaration element)
    {
        resolvePredecessor(element.type.actualType)
    }

    static def dispatch Iterable<AbstractTypeReference> predecessors(ExceptionDeclaration element)
    {
        predecessors(element.supertype, element.members)
    }

    static def Iterable<AbstractTypeReference> predecessors(AbstractTypeReference supertype,
        Iterable<MemberElement> members)
    {
        #[members.map[type.actualType], #[supertype].reject[it === null]].flatten.flatMap[resolvePredecessor]
    }

    private static def Iterable<AbstractTypeReference> resolvePredecessor(AbstractTypeReference element)
    {
        val type = element.getUltimateType(false)
        if (declaredInternally(element, type))
            #[type]
        else
            #[]
    }

    static def dispatch Iterable<AbstractTypeReference> predecessors(AbstractTypeReference element)
    {
        #[] // by default, never need an external include
    }

    static def private boolean declaredInternally(AbstractTypeReference element, AbstractTypeReference type)
    {
        !(type instanceof PrimitiveType) && type.scopeDeterminant == element.scopeDeterminant
    }

    private static def dispatch void getUnderlyingTypes(StructDeclaration struct,
        HashSet<AbstractTypeReference> allTypes)
    {
        val containedTypes = struct.members.map[type.ultimateType].filter(StructDeclaration)

        for (type : containedTypes)
        {
            if (!allTypes.contains(type))
                getUnderlyingTypes(type, allTypes)
        }

        allTypes.addAll(containedTypes)
    }

    private static def dispatch void getUnderlyingTypes(ExceptionDeclaration element,
        HashSet<AbstractTypeReference> allTypes)
    {
        val containedTypes = element.members.map[type.ultimateType].filter(ExceptionDeclaration)

        for (type : containedTypes)
        {
            if (!allTypes.contains(type))
                getUnderlyingTypes(type, allTypes)
        }

        allTypes.addAll(containedTypes)
    }

    private static def dispatch void getUnderlyingTypes(AbstractTypeReference element,
        HashSet<AbstractTypeReference> allTypes)
    {
        // default: no operation
    }

    def static String openNamespaces(ParameterBundle paramBundle)
    {
        '''
            «FOR module : paramBundle.getModuleStack»
                namespace «module.name»
                {
            «ENDFOR»
            «IF paramBundle.getProjectType !== null»
                namespace «paramBundle.getProjectType.getName»
                {
            «ENDIF»
        '''
    }

    def static String closeNamespaces(ParameterBundle paramBundle)
    {
        '''
            «FOR module : paramBundle.moduleStack»}«ENDFOR»«IF paramBundle.getProjectType !== null»}«ENDIF»
            
        '''
    }
}
