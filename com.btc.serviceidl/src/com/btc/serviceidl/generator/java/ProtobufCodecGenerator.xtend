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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.ArrayList
import java.util.Collection
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufCodecGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateProtobufCodecBody(AbstractContainerDeclaration container, String codecName)
    {
        // collect all used data types to avoid duplicates
        val dataTypes = GeneratorUtil.getEncodableTypes(container)

        val javaUuid = typeResolver.resolve(JavaClassNames.UUID)
        val byteString = typeResolver.resolve("com.google.protobuf.ByteString")
        val byteBuffer = typeResolver.resolve("java.nio.ByteBuffer")
        val iError = typeResolver.resolve(JavaClassNames.ERROR)
        val serviceFaultHandlerFactory = typeResolver.resolve(
            typeResolver.resolvePackage(container, container.mainProjectType) + TransformType.PACKAGE.separator +
                container.asServiceFaultHandlerFactory)
        val completableFuture = typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)
        val method = typeResolver.resolve("java.lang.reflect.Method")
        val collection = typeResolver.resolve(JavaClassNames.COLLECTION)
        val collectors = typeResolver.resolve("java.util.stream.Collectors")

        '''
            public class «codecName» {
               
               private static «iError» encodeException(Exception e)
               {
                  Exception cause = (Exception) «typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getRootCause(e);
                  return «serviceFaultHandlerFactory».createError(cause);
               }
               
               private static Exception decodeException(String errorType, String message, String stackTrace)
               {
                  return «serviceFaultHandlerFactory».createException(errorType, message, stackTrace);
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<TOut> encode(Collection<TIn> plainData) {
                  return
                     plainData
                     .stream()
                     .map(item -> (TOut) encode(item))
                     .collect(«collectors».toList());
               }
               
               public static<TOut, TIn> «collection»<TOut> encodeFailable(«collection»<«completableFuture»<TIn>> plainData, Class<TOut> targetType)
               {
                  return
                     plainData
                     .stream()
                     .map(item -> encodeFailableWrapper(item, targetType) )
                     .collect(«collectors».toList());
               }
               
               private static<TOut, TIn> TOut encodeFailableWrapper(«completableFuture»<TIn> failableData, Class<TOut> targetType)
               {
                  try { return encodeFailable(failableData, targetType); }
                  catch (Exception e) { throw new RuntimeException(e); }
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<TOut> decode(«collection»<TIn> encodedData) {
                  return
                     encodedData
                     .stream()
                     .map(item -> (item instanceof «byteString») ? (TOut) decode( («byteString») item) : (TOut) decode(item))
                     .collect(«collectors».toList());
               }
               
               public static «byteString» encode(«javaUuid» plainData) {
                  
                  byte[] rawBytes = «byteBuffer».allocate(16)
                     .putLong(plainData.getMostSignificantBits())
                     .putLong(plainData.getLeastSignificantBits())
                     .array();
            
                  return «byteString».copyFrom( switchByteOrder(rawBytes) );
               }
               
               @SuppressWarnings( {"boxing", "unchecked"} )
               private static<TOut, TIn> TOut encodeFailable(«completableFuture»<TIn> failableData, Class<TOut> targetType) throws Exception
               {
                  if (failableData == null)
                     throw new NullPointerException();
               
                  if (failableData.isCompletedExceptionally())
                  {
                    try
                    {
                       failableData.get();
                    } catch (Exception e) // retrieve and encode underlying exception
                    {
                       «typeResolver.resolve(JavaClassNames.ERROR)» error = encodeException(e);
                       «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                       Object builder = newBuilderMethod.invoke(null);
                       «method» setExceptionMethod = builder.getClass().getDeclaredMethod("setException", String.class);
                       setExceptionMethod.invoke(builder, error.getServerErrorType());
                       «method» setMessageMethod = builder.getClass().getDeclaredMethod("setMessage", String.class);
                       setMessageMethod.invoke(builder, error.getMessage());
                       «method» setStacktraceMethod = builder.getClass().getDeclaredMethod("setStacktrace", String.class);
                       setStacktraceMethod.invoke(builder, error.getServerContextInformation());
                       «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                       return (TOut) buildMethod.invoke(builder);
                    }
                  }
                  else
                  {
                    TIn plainData = failableData.get();
                    «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                    Object builder = newBuilderMethod.invoke(null);
                    «method» getValueMethod = builder.getClass().getDeclaredMethod("getValue");
                    Class<?> paramType = getValueMethod.getReturnType();
                    «method» setValueMethod = builder.getClass().getDeclaredMethod("setValue", paramType);
                    setValueMethod.invoke(builder, encode( plainData ));
                    «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                    return (TOut) buildMethod.invoke(builder);
                  }
                  
                  throw new IllegalArgumentException("Unknown target type for encoding: " + targetType.getCanonicalName());
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<«completableFuture»<TOut>> decodeFailable(«collection»<TIn> encodedData)
               {
                  return
                     encodedData
                     .stream()
                     .map( item -> («completableFuture»<TOut>) decodeFailableWrapper(item) )
                     .collect(«collectors».toList());
               }
               
               private static<TOut, TIn> «completableFuture»<TOut> decodeFailableWrapper(TIn encodedData)
               {
                  try { return decodeFailable(encodedData); }
                  catch (Exception e) { throw new RuntimeException(e); }
               }
               
               @SuppressWarnings( {"boxing", "unchecked"} )
               public static<TOut, TIn> «completableFuture»<TOut> decodeFailable(TIn encodedData) throws Exception
               {
                  if (encodedData == null)
                     throw new NullPointerException();
            
                  «completableFuture»<TOut> result = new «completableFuture»<TOut>();
                  
                  «method» hasValueMethod = encodedData.getClass().getDeclaredMethod("hasValue");
                  Boolean hasValue = (Boolean) hasValueMethod.invoke(encodedData);
                  if (hasValue)
                  {
                     «method» getValueMethod = encodedData.getClass().getDeclaredMethod("getValue");
                     Object value = getValueMethod.invoke(encodedData);
                     if (encodedData.getClass().getSimpleName().toLowerCase().endsWith("_uuid")) // it's a failable UUID: explicit handling
                        result.complete( (TOut) decode( («byteString») value) );
                     else
                        result.complete( (TOut) decode(value) );
                     return result;
                  }
                  else
                  {
                     «method» hasExceptionMethod = encodedData.getClass().getDeclaredMethod("hasException");
                     Boolean hasException = (Boolean) hasExceptionMethod.invoke(encodedData);
                     if (hasException)
                     {
                        «method» getExceptionMethod = encodedData.getClass().getDeclaredMethod("getException");
                        String errorType = getExceptionMethod.invoke(encodedData).toString();
                        «method» getMessageMethod = encodedData.getClass().getDeclaredMethod("getMessage");
                        String message = getMessageMethod.invoke(encodedData).toString();
                        «method» getStacktraceMethod = encodedData.getClass().getDeclaredMethod("getStacktrace");
                        String stackTrace = getStacktraceMethod.invoke(encodedData).toString();
                        result.completeExceptionally( decodeException(errorType, message, stackTrace) );
                        return result;
                     }
                  }
                  
                  throw new IllegalArgumentException("Failed to decode the type: " + encodedData.getClass().getCanonicalName());
               }
               
               public static «javaUuid» decode(«byteString» encodedData) {
                  «byteBuffer» byteBuffer = «byteBuffer».wrap(switchByteOrder(encodedData.toByteArray()));
                  return new «javaUuid»(byteBuffer.getLong(), byteBuffer.getLong());
               }
               
               /**
                * Utility function to change the endianness of the given GUID bytes.
                */
               private static byte[] switchByteOrder(byte[] rawBytes) {
                  
                  // raw GUID data have this format: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
                  byte[] switchedBytes = new byte[16];
            
                  // switch AAAAAAAA bytes
                  switchedBytes[0] = rawBytes[3];
                  switchedBytes[1] = rawBytes[2];
                  switchedBytes[2] = rawBytes[1];
                  switchedBytes[3] = rawBytes[0];
            
                  // switch BBBB bytes
                  switchedBytes[4] = rawBytes[5];
                  switchedBytes[5] = rawBytes[4];
            
                  // switch CCCC bytes
                  switchedBytes[6] = rawBytes[7];
                  switchedBytes[7] = rawBytes[6];
            
                  // switch EEEEEEEEEEEE bytes
                  for (int i = 8; i < 16; i++)
                     switchedBytes[i] = rawBytes[i];
            
                  return switchedBytes;
               }
               
               @SuppressWarnings("boxing")
               public static Object encode(Object plainData) {
               
                  if (plainData == null)
                     throw new NullPointerException();
               
                  if (plainData instanceof «javaUuid»)
                     return encode( («javaUuid») plainData );
            
                  «FOR dataType : dataTypes»
                      if (plainData instanceof «typeResolver.resolve(dataType)»)
                      {
                         «makeEncode(dataType)»
                      }
                      
                  «ENDFOR»
                  return plainData;
               }
               
               @SuppressWarnings("boxing")
               public static Object decode(Object encodedData) {
               
                  if (encodedData == null)
                     throw new NullPointerException();
               
                  «FOR dataType : dataTypes»
                      if (encodedData instanceof «ProtobufUtil.resolveProtobuf(typeResolver, dataType, Optional.empty)»)
                      {
                         «makeDecode(dataType)»
                      }
                  «ENDFOR»
                  
                  return encodedData;
               }
            }
        '''
    }

    private def dispatch String makeDecode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeDecode(element.referenceType)
    }

    private def dispatch String makeDecode(EnumDeclaration element)
    {
        val apiTypeName = typeResolver.resolve(element)
        val protobufTypeName = resolveProtobuf(element, Optional.empty)

        '''
            «protobufTypeName» typedData = («protobufTypeName») encodedData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobufTypeName».«item»)
                   return «apiTypeName».«item»;
            «ENDFOR»
            else
               throw new «typeResolver.resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeDecode(StructDeclaration element)
    {
        makeDecodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
    }

    private def dispatch String makeDecode(ExceptionDeclaration element)
    {
        makeDecodeStructOrException(element, element.allMembers, Optional.empty)
    }

    private def String makeDecodeStructOrException(AbstractTypeReference element, Iterable<MemberElementWrapper> members,
        Optional<Collection<AbstractTypeDeclaration>> typeDeclarations)
    {
        val apiTypeName = typeResolver.resolve(element)
        val protobufTypeName = resolveProtobuf(element, Optional.empty)

        val allTypes = new ArrayList<MemberElementWrapper>
        allTypes.addAll(members)

        if (typeDeclarations.present)
            typeDeclarations.get.filter(StructDeclaration).filter[declarator !== null].forEach [
                allTypes.add(new MemberElementWrapper(it))
            ]

        '''
            «protobufTypeName» typedData = («protobufTypeName») encodedData;
            «FOR member : members»
                «val codec = resolveCodec(member.type, typeResolver)»
                «val isSequence = member.type.isSequenceType»
                «val isFailable = isSequence && member.type.isFailable»
                «val isByte = member.type.isByte»
                «val isShort = member.type.isInt16»
                «val isChar = member.type.isChar»
                «val useCodec = GeneratorUtil.useCodec(member.type, ArtifactNature.JAVA)»
                «val isOptional = member.optional»
                «val apiType = basicJavaSourceGenerator.toText(member.type)»
                «val parameterName = member.name.asParameter»
                «basicJavaSourceGenerator.formatMaybeOptional(isOptional, apiType)» «parameterName» = «IF isOptional»(typedData.«IF isSequence»get«ELSE»has«ENDIF»«member.name.asJavaProtobufName»«IF isSequence»Count«ENDIF»()«IF isSequence» > 0«ENDIF») ? «ENDIF»«IF isOptional»Optional.of(«ENDIF»«IF useCodec»«IF !isSequence»(«apiType») «ENDIF»«codec».decode«IF isFailable»Failable«ENDIF»(«ENDIF»«IF isShort || isByte || isChar»(«IF isByte»byte«ELSEIF isChar»char«ELSE»short«ENDIF») «ENDIF»typedData.get«member.name.asJavaProtobufName»«IF isSequence»List«ENDIF»()«IF useCodec»)«ENDIF»«IF isOptional»)«ENDIF»«IF isOptional» : Optional.empty()«ENDIF»;
            «ENDFOR»
            
            return new «apiTypeName» (
               «FOR member : members SEPARATOR ","»
                   «member.name.asParameter»
               «ENDFOR»
            );
        '''
    }

    private def dispatch String makeEncode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeEncode(element.referenceType)
    }

    private def dispatch String makeEncode(EnumDeclaration element)
    {
        val apiTypeName = typeResolver.resolve(element)
        val protobufTypeName = resolveProtobuf(element, Optional.empty)

        '''
            «apiTypeName» typedData = («apiTypeName») plainData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «apiTypeName».«item»)
                   return «protobufTypeName».«item»;
            «ENDFOR»
            else
               throw new «typeResolver.resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeEncode(StructDeclaration element)
    {
        makeEncodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
    }

    private def dispatch String makeEncode(ExceptionDeclaration element)
    {
        makeEncodeStructOrException(element, element.allMembers, Optional.empty)
    }

    private def String makeEncodeStructOrException(AbstractTypeReference element, Iterable<MemberElementWrapper> members,
        Optional<Collection<AbstractTypeDeclaration>> typeDeclarations)
    {
        val protobufType = resolveProtobuf(element, Optional.empty)
        val plainType = typeResolver.resolve(element)

        '''
            «IF !members.empty»«plainType» typedData = («plainType») plainData;«ENDIF»
            «protobufType».Builder builder
               = «protobufType».newBuilder();
            «FOR member : members»
                «val useCodec = GeneratorUtil.useCodec(member.type, ArtifactNature.JAVA)»
                «val isSequence = member.type.isSequenceType»
                «val isFailable = isSequence && member.type.isFailable»
                «val protobufName = member.name.asJavaProtobufName»
                «val commonName = member.commonName»
                «val methodName = '''«IF isSequence»addAll«ELSE»set«ENDIF»«protobufName»'''»
                «IF member.optional»
                    if (typedData.get«typeResolver.resolve(JavaClassNames.OPTIONAL).alias(commonName)»().isPresent())
                    {
                        builder.«methodName»(«IF useCodec»«IF !isSequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF isFailable»Failable«ENDIF»(«ENDIF»typedData.get«protobufName»().get()«IF isFailable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualifiedNameProvider, member.type, member.type.scopeDeterminant)».class«ENDIF»«IF useCodec»)«ENDIF»);
                    }
                «ELSE»
                builder.«methodName»(«IF useCodec»«IF !isSequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF isFailable»Failable«ENDIF»(«ENDIF»typedData.get«commonName»()«IF isFailable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualifiedNameProvider, member.type, member.type.scopeDeterminant)».class«ENDIF»«IF useCodec»)«ENDIF»);
               «ENDIF»
            «ENDFOR»
            return builder.build();
        '''
    }

    // TODO change this to accept an IDL element rather than a bare string
    private static def getCommonName(MemberElementWrapper member)
    {
        // TODO use a proper naming convention transformation
        member.name.toFirstUpper
    }

    def resolveProtobuf(AbstractTypeReference object, Optional<ProtobufType> optionaProtobufTypel)
    {
        ProtobufUtil.resolveProtobuf(typeResolver, object, optionaProtobufTypel)
    }

}
