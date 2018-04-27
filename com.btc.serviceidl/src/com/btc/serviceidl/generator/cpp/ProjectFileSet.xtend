package com.btc.serviceidl.generator.cpp

import java.util.HashSet
import java.util.Map
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import java.util.Set
import java.util.Collection
import java.util.Arrays
import java.util.HashMap

@Data
@Accessors(NONE)
class ProjectFileSet
{
    @Data
    static class FileGroup
    {
        String name
    }

    public static val CPP_FILE_GROUP = new FileGroup("cpp")
    public static val HEADER_FILE_GROUP = new FileGroup("header")
    public static val DEPENDENCY_FILE_GROUP = new FileGroup("dependency")
    public static val PROTOBUF_FILE_GROUP = new FileGroup("protobuf")
    public static val ODB_FILE_GROUP = new FileGroup("odb")

    // TODO remove this here and move to prins package
    public static val DEFAULT_FILE_GROUPS = Arrays.asList(CPP_FILE_GROUP, HEADER_FILE_GROUP, DEPENDENCY_FILE_GROUP,
        PROTOBUF_FILE_GROUP, ODB_FILE_GROUP)

    private val Map<FileGroup, Collection<String>> files

    @Deprecated
    def getCpp_files()
    {
        files.get(CPP_FILE_GROUP)
    }

    @Deprecated
    def getHeader_files()
    {
        files.get(HEADER_FILE_GROUP)
    }

    @Deprecated
    def getDependency_files()
    {
        files.get(DEPENDENCY_FILE_GROUP)
    }

    @Deprecated
    def getProtobuf_files()
    {
        files.get(PROTOBUF_FILE_GROUP)
    }

    @Deprecated
    def getOdb_files()
    {
        files.get(ODB_FILE_GROUP)
    }

    new()
    {
        this.files = new HashMap<FileGroup, Collection<String>>
        for (group : DEFAULT_FILE_GROUPS)
            this.files.put(group, new HashSet<String>)
    }

    private new(ProjectFileSet base)
    {
        this.files = base.files.unmodifiableView
    }

    def unmodifiableView()
    {
        new ProjectFileSet(this)
    }
}
