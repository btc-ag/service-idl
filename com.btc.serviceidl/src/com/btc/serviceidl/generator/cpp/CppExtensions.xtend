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
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.TypeWrapper
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Util
import java.util.ArrayList
import java.util.Collection
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.List
import org.eclipse.emf.ecore.EObject

import static extension com.btc.serviceidl.util.Extensions.*
import com.btc.serviceidl.generator.common.GeneratorUtil

class CppExtensions
{
    private static val CPP_NATURE = ArtifactNature.CPP

    def static String getIncludeFilePath(EObject referenced_object, ProjectType project_type)
    {
        val scope_determinant = if (referenced_object instanceof InterfaceDeclaration)
                referenced_object
            else
                Util.getScopeDeterminant(referenced_object)
        val is_common = (scope_determinant instanceof InterfaceDeclaration)

        val file_name = if (is_common)
                project_type.getClassName(CPP_NATURE, Names.plain(scope_determinant))
            else
                "Types"
        val module_stack = Util.getModuleStack(referenced_object)

        val param_bundle = new ParameterBundle.Builder()
        param_bundle.reset(CPP_NATURE)
        param_bundle.reset(module_stack)

        val include_folder = if (project_type == ProjectType.PROTOBUF) "gen" else "include"
        val file_extension = if (project_type == ProjectType.PROTOBUF) ".pb.h" else ".h"

        "modules/" + GeneratorUtil.transform(param_bundle.with(project_type).build, TransformType.FILE_SYSTEM) +
            "/" + include_folder + "/" + file_name + file_extension
    }

    /**
     * Returns sub-types of the given container sorted in their topological order.
     * If there are circular dependencies, then superior types are put into
     * forwardDeclarations collection, so that they can be handled in a specific
     * way.
     */
    def static Collection<TypeWrapper> getTopologicallySortedTypes(EObject owner)
    {
        // aggregate enums, typedefs, structs and exceptions into the same collection
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
    def static Collection<TypeWrapper> resolveAllDependencies(Iterable<? extends EObject> elements)
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
    def private static Collection<TypeWrapper> applyKahnsAlgorithm(HashSet<Pair<EObject, EObject>> graph,
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
                    type_wrapper.forwardDeclarations.add(dependency_wrapper.type)
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
    def static dispatch Collection<EObject> predecessors(StructDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            resolvePredecessor(member.type, result)
        }
        // base type must be handled also
        if (element.supertype !== null)
        {
            resolvePredecessor(element.supertype, result)
        }
        return result
    }

    def static dispatch Collection<EObject> predecessors(AliasDeclaration element)
    {
        val result = new HashSet<EObject>(1)
        resolvePredecessor(element.type, result)
        return result
    }

    def static dispatch Collection<EObject> predecessors(ExceptionDeclaration element)
    {
        val result = new HashSet<EObject>(element.members.size)
        for (member : element.members)
        {
            resolvePredecessor(member.type, result)
        }
        // base type must be handled also
        if (element.supertype !== null)
        {
            resolvePredecessor(element.supertype, result)
        }
        return result
    }

    def private static void resolvePredecessor(EObject element, Collection<EObject> predecessors)
    {
        val type = Util.getUltimateType(element, false)
        if (declaredInternally(element, type))
            predecessors.add(type)
    }

    def static dispatch Collection<EObject> predecessors(EObject element)
    {
        return new ArrayList<EObject> // by default, never need an external include
    }

    def static private boolean declaredInternally(EObject element, EObject type)
    {
        return (!(type instanceof PrimitiveType) && Util.getScopeDeterminant(type) == Util.getScopeDeterminant(element))
    }

    def private static dispatch void getUnderlyingTypes(StructDeclaration struct, HashSet<EObject> all_types)
    {
        val contained_types = struct.members.filter[Util.getUltimateType(type) instanceof StructDeclaration].map [
            Util.getUltimateType(type) as StructDeclaration
        ]

        for (type : contained_types)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }

        all_types.addAll(contained_types)
    }

    def private static dispatch void getUnderlyingTypes(ExceptionDeclaration element, HashSet<EObject> all_types)
    {
        val contained_types = element.members.filter[Util.getUltimateType(type) instanceof ExceptionDeclaration].map [
            Util.getUltimateType(type) as ExceptionDeclaration
        ]

        for (type : contained_types)
        {
            if (!all_types.contains(type))
                getUnderlyingTypes(type, all_types)
        }

        all_types.addAll(contained_types)
    }

    def private static dispatch void getUnderlyingTypes(EObject element, HashSet<EObject> all_types)
    {
        // default: no operation
    }

    def public static String openNamespaces(ParameterBundle param_bundle)
    {
        '''
            «FOR module : param_bundle.module_stack»
                namespace «module.name»
                {
            «ENDFOR»
            «IF param_bundle.getProjectType.present»
                namespace «param_bundle.getProjectType.get.getName»
                {
            «ENDIF»
        '''
    }

    def public static String closeNamespaces(ParameterBundle param_bundle)
    {
        '''
            «FOR module : param_bundle.module_stack»}«ENDFOR»«IF param_bundle.getProjectType.present»}«ENDIF»
            
        '''
    }
}
