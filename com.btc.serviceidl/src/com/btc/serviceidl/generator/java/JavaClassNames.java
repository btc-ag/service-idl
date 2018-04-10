package com.btc.serviceidl.generator.java;

import java.io.Closeable;
import java.util.Collection;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

public final class JavaClassNames {
    public static final String OPTIONAL           = Optional.class.getCanonicalName();
    public static final String UUID               = java.util.UUID.class.getCanonicalName();
    public static final String CLOSEABLE          = Closeable.class.getCanonicalName();
    public static final String COLLECTION         = Collection.class.getCanonicalName();
    public static final String COMPLETABLE_FUTURE = CompletableFuture.class.getCanonicalName();

    public static final String DEFAULT_SERVICE_FAULT_HANDLER = "com.btc.cab.servicecomm.faulthandling.DefaultServiceFaultHandler";
    public static final String SERVICE_FAULT_HANDLER         = "com.btc.cab.servicecomm.api.IServiceFaultHandler";
    public static final String ERROR                         = "com.btc.cab.servicecomm.api.IError";
    public static final String CLIENT_ENDPOINT               = "com.btc.cab.servicecomm.api.IClientEndpoint";
    public static final String SERVER_ENDPOINT               = "com.btc.cab.servicecomm.api.IServerEndpoint";

    public static final String OBSERVABLE = "com.btc.cab.commons.IObservable";
    public static final String OBSERVER   = "com.btc.cab.commons.IObserver";

    public static final String JUNIT_BEFORE       = "org.junit.Before";
    public static final String JUNIT_AFTER        = "org.junit.After";
    public static final String JUNIT_BEFORE_CLASS = "org.junit.BeforeClass";
    public static final String JUNIT_AFTER_CLASS  = "org.junit.AfterClass";
    public static final String JUNIT_IGNORE       = "org.junit.Ignore";
    public static final String JUNIT_ASSERT       = "org.junit.Assert";
    public static final String JUNIT_TEST         = "org.junit.Test";
}
