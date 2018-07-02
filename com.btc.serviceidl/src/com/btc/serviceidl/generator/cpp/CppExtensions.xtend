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
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.StructDeclaration
import java.util.ArrayList
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.List
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class CppExtensions
{
    static def IPath getIncludeFilePath(EObject referenced_object, ProjectType project_type,
        IModuleStructureStrategy moduleStructureStrategy)
    {
        val scope_determinant = if (referenced_object instanceof InterfaceDeclaration)
                referenced_object
            else
                referenced_object.scopeDeterminant

        val baseName = if (scope_determinant instanceof InterfaceDeclaration)
                project_type.getClassName(ArtifactNature.CPP, Names.plain(scope_determinant))
            else
                "Types"

        moduleStructureStrategy.getIncludeFilePath(referenced_object.moduleStack, project_type, baseName,
            HeaderType.REGULAR_HEADER)
    }

    /**
     * Returns sub-types of the given container sorted in their topological order.
     * If there are circular dependencies, then superior types are put into
     * forwardDeclarations collection, so that they can be handled in a specific
     * way.
     */
    static def Iterable<TypeWrapper> getTopologicallySortedTypes(EObject owner)
    {
        // aggregate enums, typedefs, structs and exceptions into the same collection
        // TODO change metamodel such that these types have a common supertype (besides EObject)
        val all_elements = new HashSet<EObject>
        all_elements.addAll(owner.eContents.filter(EnumDeclaration))
        all_elements.addAll(owner.eContents.filter(AliasDeclaration))
        all_elements.addAll(owner.eContents.filter(StructDeclaration))
        all_elements.addAll(owner.eContents.filter(ExceptionDeclaration))

        // construct a directed graph representation; a dependency relation between two
        // elements is represented as a pair X -> Y (meaning: X depends on Y)
        val graph = new HashSet<Pair<EObject, EObject>>
        all_elements.forEach[it.predecessors.forEach[EObject dependency|graph.add(it -> dependency)]]

        // sort out all independent elements
        val independent_elements = new ArrayList<EObject>
        independent_elements.addAll(all_elements.filter[it.predecessors.empty])

        return applyKahnsAlgorithm(graph, independent_elements)
    }

    /**
     * For the given collection of structures, resolve all types (consequently going
     * into all possible depth) on which they depend. We need this e.g. for
     * generation of ODB files to resolve dependencies by sorting the types in
     * the topological order.
     */
    static def Iterable<TypeWrapper> resolveAllDependencies(Iterable<? extends EObject> elements)
    {
        // construct a directed graph representation; a dependency relation between two
        // elements is represented as a pair X -> Y (meaning: X depends on Y)
        val graph = new HashSet<Pair<EObject, EObject>>

        val all_types = new HashSet<EObject>
        all_types.addAll(elements)
        for (e : elements)
        {
            getUnderlyingTypes(e, all_types)
        }
        all_types.forEach[it.requirements.forEach[EObject dependency|graph.add(it -> dependency)]]

        return applyKahnsAlgorithm(graph, all_types.filter[it.requirements.empty].map(e|e as EObject).toList)
    }

    /**
     * Execute topological sorting based on Kahn's algorithm
     */
    private static def Iterable<TypeWrapper> applyKahnsAlgorithm(HashSet<Pair<EObject, EObject>> graph,
        List<EObject> independent_elements)
    {
        // list finally containing the sorted elements
        val result = new LinkedHashSet<TypeWrapper>

        while (!independent_elements.empty)
        {
            val n = independent_elements.remove(0)
            result.add(new TypeWrapper(n))
            for (m : graph.filter[value == n].map[key].toList)
            {
                val edge = graph.findFirst[key == m && value == n]
                graph.remove(edge)
                if (graph.filter[key == m].empty)
                    independent_elements.add(m)
            }
        }

        // handle circular dependencies
        if (!graph.empty)
        {
            // ordered collection of mutually dependent types; position of the element
            // is important: if element depends on a type declared later, the 
            // effective type must be resolved as smart pointer of a forward
            // declaration, otherwise directly
            val indexed_list = new ArrayList<TypeWrapper>
            while (!graph.empty)
            {
                // get next unhandled element
                val edge = graph.head
                var type_wrapper = new TypeWrapper(edge.key)

                // retrieve index of the element; if not yet existent, add it
                var index = indexed_list.indexOf(type_wrapper)
                if (index < 0)
                {
                    indexed_list.add(type_wrapper)
                    index = indexed_list.indexOf(type_wrapper)
                }
                else
                {
                    type_wrapper = indexed_list.get(index)
                }

                // retrieve index of the superior type; if not yet existent or 
                // coming later than the dependent type, add to dependency list
                val dependency_wrapper = new TypeWrapper(edge.value)
                val index_dependency = indexed_list.indexOf(dependency_wrapper)

                if (index_dependency >= index || index_dependency < 0)
                {
                    type_wrapper.addForwardDeclaration(dependency_wrapper.type)
                }

                graph.remove(edge)
            }

            result.addAll(indexed_list)
        }

        return result
    }

    /**
     * Predecessors are all elements in the SAME header as the given element,
     * which must be declared before the element itself. Elements from other
     * headers are NOT among the predecessors, since they are resolved based
     * on the #include directive. 
     */
    static def dispatch Iterable<EObject> predecessors(StructDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            result.addAll(resolvePredecessor(member.type))
        }
        // base type must be handled also
        if (element.supertype !== null)
        {
            result.addAll(resolvePredecessor(element.supertype))
        }
        return result
    }

    static def dispatch Iterable<EObject> predecessors(AliasDeclaration element)
    {
        resolvePredecessor(element.type)
    }

    static def dispatch Iterable<EObject> predecessors(ExceptionDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            result.addAll(resolvePredecessor(member.type))
        }
        // base type must be handled also
        if (element.supertype !== null)
        {
            result.addAll(resolvePredecessor(element.supertype))
        }
        return result
    }

    private static def Iterable<EObject> resolvePredecessor(EObject element)
    {
        val type = element.getUltimateType(false)
        if (declaredInternally(element, type))
            #[type]
        else
            #[]
    }

    static def dispatch Iterable<EObject> predecessors(EObject element)
    {
        new ArrayList<EObject> // by default, never need an external include
    }

    static def private boolean declaredInternally(EObject element, EObject type)
    {
        !(type instanceof PrimitiveType) && type.scopeDeterminant == element.scopeDeterminant
    }
    
    private static def dispatch void getUnderlyingTypes(StructDeclaration struct, HashSet<EObject> all_types)
    {
        val contained_types = struct.members.map[type.ultimateType].filter(StructDeclaration)

        for (type : contained_types)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }

        all_types.addAll(contained_types)
    }

    private static def dispatch void getUnderlyingTypes(ExceptionDeclaration element, HashSet<EObject> all_types)
    {
        val contained_types = element.members.map[type.ultimateType].filter(ExceptionDeclaration)

        for (type : contained_types)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }

        all_types.addAll(contained_types)
    }

    private static def dispatch void getUnderlyingTypes(EObject element, HashSet<EObject> all_types)
    {
        // default: no operation
    }

    def static String openNamespaces(ParameterBundle param_bundle)
    {
        '''
            «FOR module : param_bundle.getModuleStack»
                namespace «module.name»
                {
            «ENDFOR»
            «IF param_bundle.getProjectType !== null»
                namespace «param_bundle.getProjectType.getName»
                {
            «ENDIF»
        '''
    }

    def static String closeNamespaces(ParameterBundle param_bundle)
    {
        '''
            «FOR module : param_bundle.moduleStack»}«ENDFOR»«IF param_bundle.getProjectType !== null»}«ENDIF»
            
        '''
    }
}
