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
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.Arrays
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufCodecGenerator extends ProxyDispatcherGeneratorBase
{
    def generate(AbstractContainerDeclaration owner, String class_name)
    {
        val enumerable = resolve("System.Collections.Generic.IEnumerable")
        resolve("System.Linq.Enumerable")
        val task = resolve("System.Threading.Tasks.Task")
        val string = resolve("System.string")
        val object = resolve("System.object")
        val type = resolve("System.Type")
        val guid = resolve("System.Guid")
        val byteString = resolve("Google.ProtocolBuffers.ByteString")
        val bindingFlags = resolve("System.Reflection.BindingFlags")

        // reference main project for common fault handling
        val serviceFaultHandling = Util.resolveServiceFaultHandling(typeResolver, owner).fullyQualifiedName

        // collect all data types which are relevant for encoding
        val data_types = GeneratorUtil.getEncodableTypes(owner)

        '''
            public static class «class_name»
            {
               public static IEnumerable<TOut> encodeEnumerable<TOut, TIn>(IEnumerable<TIn> plainData)
               {
                  return plainData.Select(item => (TOut) encode(item)).ToList();
               }
               
               public static «enumerable»<TOut> encodeFailable<TOut, TIn>(«enumerable»<«task»<TIn>> plainData)
               {
                  return plainData.Select(item => encodeFailable<TOut, TIn>(item)).ToList();
               }
               
               private static TOut encodeFailable<TOut, TIn>(«task»<TIn> plainData)
               {
                  var builder = typeof(TOut).GetMethod("CreateBuilder", new «type»[0]).Invoke(null, null);
                  var builderType = builder.GetType();
                  if (plainData.IsFaulted)
                  {
                     // encode error from exception
                     var exception = plainData.Exception.Flatten().InnerException;
                     builderType.GetMethod("SetException").Invoke(builder, new «object»[] { «serviceFaultHandling».resolveError(exception) });
                     builderType.GetMethod("SetMessage").Invoke(builder, new «object»[] { exception.Message ?? «string».Empty });
                     builderType.GetMethod("SetStacktrace").Invoke(builder, new «object»[] { exception.StackTrace ?? «string».Empty });
                  }
                  else
                  {
                     // encode value
                     TIn value = plainData.Result;
                     «object» encodedValue = default(TOut);
                     if (typeof(TIn) == typeof(«guid»))
                        encodedValue = encodeUUID((«guid»)(«object») value);
                     else
                        encodedValue = encode(value);
                     builderType.GetProperty("Value", «bindingFlags».Public | «bindingFlags».Instance).SetValue(builder, encodedValue);
                  }
                  return (TOut) builderType.GetMethod("Build").Invoke(builder, null);
               }
            
               public static int encodeByte(byte plainData)
               {
               return plainData;
               }
            
               public static int encodeShort(short plainData)
               {
               return plainData;
               }
               
               public static int encodeChar(char plainData)
               {
                  return plainData;
               }
            
               public static «resolve(TypeResolver.PROTOBUF_UUID_TYPE)» encodeUUID(«resolve("System.Guid")» plainData)
               {
               return Google.ProtocolBuffers.ByteString.CopyFrom(plainData.ToByteArray());
               }
            
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<byte> plainData)
               {
               return plainData.Select(item => (int)item).ToList();
               }
            
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<short> plainData)
               {
                return plainData.Select(item => (int)item).ToList();
               }
               
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<char> plainData)
               {
                   return plainData.Select(item => (int)item).ToList();
               }
               
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<«resolve(TypeResolver.PROTOBUF_UUID_TYPE)»> encodeEnumerable<TOut, TIn>(IEnumerable<«resolve("System.Guid")»> plainData)
               {
                   return plainData.Select(item => encodeUUID(item)).ToList();
               }
               
               public static «resolve("System.object")» encode(object plainData)
               {
                  if (plainData == null)
                     throw new «resolve("System.ArgumentNullException")»();
            
                  «FOR data_type : data_types»
                      if (plainData.GetType() == typeof(«resolve(data_type)»))
                      {
                         «makeEncode(data_type, owner)»
                      }
                  «ENDFOR»
                  
                  return plainData;
               }
               
               public static IEnumerable<TOut> decodeEnumerable<TOut, TIn>(IEnumerable<TIn> encodedData)
               {
                  return encodedData.Select(item => (TOut) decode(item)).ToList();
               }
               
               public static «enumerable»<«task»<TOut>> decodeFailable<TOut, TIn>(«enumerable»<TIn> encodedData)
               {
                  return encodedData.Select(item => decodeFailable<TOut, TIn>(item)).ToList();
               }
               
               private static «task»<TOut> decodeFailable<TOut, TIn>(TIn encodedData)
               {
                  var encodedType = encodedData.GetType();
                  bool hasValue = (bool) encodedType.GetProperty("HasValue").GetValue(encodedData);
                  if (hasValue)
                  {
                     // get encoded value and decode it
                     var value = encodedType.GetProperty("Value").GetValue(encodedData);
                     «object» decodedValue = default(TOut);
                     if (typeof(TOut) == typeof(«guid») && value.GetType() == typeof(«byteString»))
                        decodedValue = decodeUUID((«byteString»)(«object») value);
                     else
                        decodedValue = decode(value);
                     return «task».FromResult<TOut>((TOut) decodedValue);
                  }
                  else
                  {
                     // get error and map it to proper exception
                     var exception = («string») encodedType.GetProperty("Exception").GetValue(encodedData);
                     var message = («string») encodedType.GetProperty("Message").GetValue(encodedData);
                     var stacktrace = («string») encodedType.GetProperty("Stacktrace").GetValue(encodedData);
                     return «task».FromException<TOut>(«serviceFaultHandling».resolveError(exception, message, stacktrace));
                  }
               }
               
               public static IEnumerable<byte> decodeEnumerableByte(IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (byte) item).ToList();
               }
               
               public static IEnumerable<short> decodeEnumerableShort (IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (short)item).ToList();
               }
               
               public static IEnumerable<char> decodeEnumerableChar (IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (char)item).ToList();
               }
               
               public static IEnumerable<«resolve("System.Guid")»> decodeEnumerableUUID (IEnumerable<«resolve(TypeResolver.PROTOBUF_UUID_TYPE)»> encodedData)
               {
                  return encodedData.Select(item => decodeUUID(item)).ToList();
               }
               
               public static byte decodeByte(int encodedData)
               {
                  return (byte) encodedData;
               }
               
               public static short decodeShort(int encodedData)
               {
                  return (short) encodedData;
               }
               
               public static char decodeChar(int encodedData)
               {
                  return (char) encodedData;
               }
               
               public static «resolve("System.Guid")» decodeUUID(«resolve(TypeResolver.PROTOBUF_UUID_TYPE)» encodedData)
               {
                  return new System.Guid(encodedData.ToByteArray());
               }
               
               public static object decode(object encodedData)
               {
                  if (encodedData == null)
                     throw new «resolve("System.ArgumentNullException")»();
            
                  «FOR data_type : data_types»
                      if (encodedData.GetType() == typeof(«resolve(data_type, ProjectType.PROTOBUF)»))
                      {
                         «makeDecode(data_type, owner)»
                      }
                  «ENDFOR»
            
               return encodedData;
                  }
               }
        '''
    }

    private def dispatch String makeEncode(EnumDeclaration element, AbstractContainerDeclaration owner)
    {
        val api_type_name = resolve(element)
        val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)

        '''
            «api_type_name» typedData = («api_type_name») plainData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «api_type_name».«item»)
                   return «protobuf_type_name».«item»;
            «ENDFOR»
            else
               throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeEncode(StructDeclaration element, AbstractContainerDeclaration owner)
    {
        makeEncodeStructOrException(element, element.allMembers, element.typeDecls)
    }

    private def dispatch String makeEncode(ExceptionDeclaration element, AbstractContainerDeclaration owner)
    {
        makeEncodeStructOrException(element, element.allMembers, Arrays.asList)
    }

    private def dispatch String makeEncode(AbstractType element, AbstractContainerDeclaration owner)
    {
        if (element.referenceType !== null)
            return makeEncode(element.referenceType, owner)
    }

    private def String makeEncodeStructOrException(EObject element, Iterable<MemberElementWrapper> members,
        Iterable<AbstractTypeDeclaration> type_declarations)
    {
        val api_type_name = resolve(element)
        val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
        val container = element.scopeDeterminant

        '''
            «api_type_name» typedData = («api_type_name») plainData;
            var builder = «protobuf_type_name».CreateBuilder();
            «FOR member : members»
                «val codec = resolveCodec(typeResolver, parameterBundle, member.type)»
                «val isFailable = member.type.isFailable»
                «val useCodec = isFailable || GeneratorUtil.useCodec(member.type, ArtifactNature.DOTNET)»
                «val useCast = useCodec && !isFailable»
                «val encodeMethod = getEncodeMethod(member.type, container)»
                «val method_name = if (com.btc.serviceidl.util.Util.isSequenceType(member.type)) "AddRange" + member.name.asDotNetProtobufName else "Set" + member.name.asDotNetProtobufName»
                «IF com.btc.serviceidl.util.Util.isAbstractCrossReferenceType(member.type) && !(com.btc.serviceidl.util.Util.isEnumType(member.type))»
                    if (typedData.«member.name.asProperty» != null)
                    {
                builder.«method_name»(«IF useCodec»«IF useCast»(«resolveEncode(member.type)») «ENDIF»«codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»«IF useCodec»)«ENDIF»);
                }
                «ELSE»
                «val is_nullable = (member.optional && member.type.valueType)»
                «val is_optional_reference = (member.optional && !member.type.valueType)»
                «IF com.btc.serviceidl.util.Util.isByte(member.type) || com.btc.serviceidl.util.Util.isInt16(member.type) || com.btc.serviceidl.util.Util.isChar(member.type)»
                    «IF is_nullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»builder.«method_name»(typedData.«member.name.asProperty»«IF is_nullable».Value«ENDIF»);
                «ELSE»
                «IF is_nullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»«IF is_optional_reference»if (typedData.«member.name.asProperty» != null) «ENDIF»builder.«method_name»(«IF useCodec»«IF useCast»(«resolveEncode(member.type)») «ENDIF»«codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»«IF is_nullable».Value«ENDIF»«IF useCodec»)«ENDIF»);
                «ENDIF»
                «ENDIF»
            «ENDFOR»
                «FOR struct_decl : type_declarations.filter(StructDeclaration).filter[declarator !== null]»
                «val codec = resolveCodec(typeResolver, parameterBundle, struct_decl)»
                builder.Set«new MemberElementWrapper(struct_decl).protobufName»((«protobuf_type_name».Types.«struct_decl.name») «codec».encode(typedData.«struct_decl.declarator.asProperty»));
                «ENDFOR»
                «FOR enum_decl : type_declarations.filter(EnumDeclaration).filter[declarator !== null]»
                «val codec = resolveCodec(typeResolver, parameterBundle, enum_decl)»
                builder.Set«new MemberElementWrapper(enum_decl).protobufName»((«protobuf_type_name».Types.«enum_decl.name») «codec».encode(typedData.«enum_decl.declarator»));
                «ENDFOR»
            return builder.BuildPartial();
        '''
    }

    private def dispatch String makeDecode(EnumDeclaration element, EObject owner)
    {
        val api_type_name = resolve(element)
        val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)

        '''
            «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobuf_type_name».«item»)
                   return «api_type_name».«item»;
            «ENDFOR»
            else
               throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeDecode(StructDeclaration element, EObject owner)
    {
        makeDecodeStructOrException(element, element.allMembers, element.typeDecls)
    }

    private def dispatch String makeDecode(ExceptionDeclaration element, EObject owner)
    {
        makeDecodeStructOrException(element, element.allMembers, Arrays.asList)
    }

    private def String makeDecodeStructOrException(EObject element, Iterable<MemberElementWrapper> members,
        Iterable<AbstractTypeDeclaration> type_declarations)
    {
        val api_type_name = resolve(element)
        val protobuf_type_name = resolve(element, ProjectType.PROTOBUF)
        val container = com.btc.serviceidl.util.Util.getScopeDeterminant(element)

        '''
            «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
            return new «api_type_name» (
               «FOR member : members SEPARATOR ","»
                   «val codec = resolveCodec(typeResolver, parameterBundle, member.type)»
                   «val isFailable = com.btc.serviceidl.util.Util.isFailable(member.type)»
                   «val useCodec = isFailable || GeneratorUtil.useCodec(member.type, ArtifactNature.DOTNET)»
                   «val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(member.type)»
                   «val is_optional = member.optional && !is_sequence»
                   «val useCast = useCodec && !isFailable»
                   «IF com.btc.serviceidl.util.Util.isByte(member.type) || com.btc.serviceidl.util.Util.isInt16(member.type) || com.btc.serviceidl.util.Util.isChar(member.type)»
                       «member.name.asParameter»: «IF is_optional»(typedData.«hasField(member)») ? «ENDIF»(«resolve(member.type)») typedData.«member.protobufName»«IF is_optional» : («toText(member.type, null)»?) null«ENDIF»
                   «ELSE»
                       «val decode_method = getDecodeMethod(member.type, container)»
                   «member.name.asParameter»: «IF is_optional»(typedData.«hasField(member)») ? «ENDIF»«IF useCodec»«IF useCast»(«resolveDecode(member.type)») «ENDIF»«codec».«decode_method»(«ENDIF»typedData.«member.protobufName»«IF is_sequence»List«ENDIF»«IF useCodec»)«ENDIF»«IF is_optional» : «IF member.type.isNullable»(«toText(member.type, null)»?) «ENDIF»null«ENDIF»
               «ENDIF»
               «ENDFOR»
                «FOR struct_decl : type_declarations.filter(StructDeclaration).filter[declarator !== null] SEPARATOR ","»
                «val codec = resolveCodec(typeResolver, parameterBundle, struct_decl)»
                «struct_decl.declarator.asParameter»: («resolve(struct_decl)») «codec».decode(typedData.«new MemberElementWrapper(struct_decl).protobufName»)
                «ENDFOR»
                «FOR enum_decl : type_declarations.filter(EnumDeclaration).filter[declarator !== null] SEPARATOR ","»
                «val codec = resolveCodec(typeResolver, parameterBundle, enum_decl)»
                «enum_decl.declarator.asParameter»: («api_type_name + Constants.SEPARATOR_PACKAGE + enum_decl.name») «codec».decode(typedData.«new MemberElementWrapper(enum_decl).protobufName»)
                «ENDFOR»
               );
        '''
    }

    private def dispatch String makeDecode(AbstractType element, EObject owner)
    {
        if (element.referenceType !== null)
            return makeDecode(element.referenceType, owner)
    }

}
