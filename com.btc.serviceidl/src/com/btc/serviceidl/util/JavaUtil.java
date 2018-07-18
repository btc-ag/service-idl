package com.btc.serviceidl.util;

import com.btc.serviceidl.idl.AbstractType;

public class JavaUtil {
    static void checkConsistency(AbstractType abstractType) {
        assert 1 == ((abstractType.getCollectionType() != null ? 1 : 0)
                + (abstractType.getPrimitiveType() != null ? 1 : 0)
                + (abstractType.getReferenceType() != null ? 1 : 0));
    }
}
