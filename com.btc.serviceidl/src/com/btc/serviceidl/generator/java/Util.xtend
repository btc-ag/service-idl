package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.ITargetVersionProvider

class Util
{
    static def getJavaTargetVersion(ITargetVersionProvider targetVersionProvider)
    {
        ServiceCommVersion.get(targetVersionProvider.getTargetVersion(JavaConstants.SERVICECOMM_VERSION_KIND))
    }
}
