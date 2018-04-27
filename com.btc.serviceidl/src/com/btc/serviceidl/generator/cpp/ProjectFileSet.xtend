package com.btc.serviceidl.generator.cpp

import org.eclipse.xtend.lib.annotations.Data
import java.util.HashSet
import java.util.Set

@Data
class ProjectFileSet
{
    private val Set<String> cpp_files
    private val Set<String> header_files
    private val Set<String> dependency_files
    private val Set<String> protobuf_files
    private val Set<String> odb_files

    new()
    {
        cpp_files = new HashSet<String>
        header_files = new HashSet<String>
        dependency_files = new HashSet<String>
        protobuf_files = new HashSet<String>
        odb_files = new HashSet<String>
    }

    private new(ProjectFileSet base)
    {
        this.cpp_files = base.cpp_files.unmodifiableView
        this.header_files = base.header_files.unmodifiableView
        this.dependency_files = base.dependency_files.unmodifiableView
        this.protobuf_files = base.protobuf_files.unmodifiableView
        this.odb_files = base.odb_files.unmodifiableView
    }

    def unmodifiableView()
    {
        new ProjectFileSet(this)
    }
}
