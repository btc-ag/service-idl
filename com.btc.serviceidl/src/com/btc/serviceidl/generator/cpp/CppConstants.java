package com.btc.serviceidl.generator.cpp;

import java.util.Set;

import com.btc.serviceidl.util.Constants;
import com.google.common.collect.ImmutableSet;

public class CppConstants {

    public static final String PROTOBUF_INCLUDE_DIRECTORY_NAME = Constants.PROTOBUF_GENERATION_DIRECTORY_NAME;

    public static final String      SERVICECOMM_VERSION_KIND = "cpp.servicecomm";
    public static final Set<String> SERVICECOMM_VERSIONS     = ImmutableSet.of("0.10", "0.11", "0.12");

}
