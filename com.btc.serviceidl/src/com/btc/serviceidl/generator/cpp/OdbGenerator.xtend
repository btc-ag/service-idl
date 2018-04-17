package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.HashSet
import java.util.Set
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.idl.AbstractType

@Accessors
class OdbGenerator
{
    private val extension TypeResolver typeResolver

    def generateODBTraitsBody()
    {
        '''
            namespace odb
            {
               // ***** MSSQL *****
               namespace mssql
               {
                  template<>
                  struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
                  {
                     static const database_type_id db_type_id = «resolveODB("id_uniqueidentifier")»;
                  };
            
                  template<>
                  class value_traits<BTC::PRINS::Commons::GUID, id_uniqueidentifier>
                  {
                  public:
                     typedef BTC::PRINS::Commons::GUID   value_type;
                     typedef BTC::PRINS::Commons::GUID   query_type;
                     typedef uniqueidentifier            image_type;
            
                     static void set_value(value_type& val, const image_type& img, bool is_null)
                     {
                        if (!is_null)
                        {
                           «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                           «resolveSTL("std::array")»<char, 16> db_data;
                           «resolveSTL("std::memcpy")»(db_data.data(), &img, 16);
                           «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                           val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
                        }
                        else
                           val = BTC::PRINS::Commons::GUID::nullGuid;
                     }
            
                     static void set_image(image_type& img, bool& is_null, const value_type& val)
                     {
                        is_null = false;
                        auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                        std::array<char, 16> db_data;
                        BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                        std::memcpy(&img, db_data.data(), 16);
                     }
                  };
               }
               
               // ***** ORACLE *****
               namespace oracle
               {
                  template<>
                  struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
                  {
                     static const database_type_id db_type_id = «resolveODB("id_raw")»;
                  };
            
                  template<>
                  class value_traits<BTC::PRINS::Commons::GUID, id_raw>
                  {
                  public:
                     typedef BTC::PRINS::Commons::GUID   value_type;
                     typedef BTC::PRINS::Commons::GUID   query_type;
                     typedef char                        image_type[16];
            
                     static void set_value(value_type& val, const image_type img, std::size_t n, bool is_null)
                     {
                        «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                        «resolveSTL("std::vector")»<char> db_data;
                        db_data.reserve(n);
                        «resolveSTL("std::memcpy")»(db_data.data(), img, n);
                        «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                        val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
                     }
            
                     static void set_image(image_type img, std::size_t c, std::size_t& n, bool& is_null, const value_type& val)
                     {
                        is_null = false;
                        auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                        std::vector<char> db_data;
                        db_data.resize(16);
                        BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                        n = db_data.size();
                        std::memcpy (img, db_data.data(), n);
                     }
                  };
               }
            }
        '''

    }

    def private dispatch String resolveODBType(PrimitiveType element)
    {
        if (element.integerType !== null)
        {
            switch element.integerType
            {
                case "int64":
                    return "long"
                case "int32":
                    return "int"
                case "int16":
                    return "short"
                case "byte":
                    return "signed char"
                default:
                    return element.integerType
            }
        }
        else if (element.stringType !== null)
            return resolveSTL("std::string")
        else if (element.floatingPointType !== null)
            return element.floatingPointType
        else if (element.uuidType !== null)
            return resolveModules("BTC::PRINS::Commons::GUID")
        else if (element.booleanType !== null)
            return "bool"
        else if (element.charType !== null)
            return "char"

        throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
    }

    def private dispatch String resolveODBType(StructDeclaration element)
    {
        element.name
    }

    def private dispatch String resolveODBType(AliasDeclaration element)
    {
        resolveODBType(element.type)
    }

    def private dispatch String resolveODBType(SequenceDeclaration element)
    {
        '''«resolveSTL("std::vector")»<«resolveODBType(element.ultimateType)»>'''
    }

    def private dispatch String resolveODBType(EnumDeclaration element)
    {
        return "int"
    }

    def private dispatch String resolveODBType(AbstractType element)
    {
        if (element.primitiveType !== null)
            return resolveODBType(element.primitiveType)
        else if (element.referenceType !== null)
            return resolveODBType(element.referenceType)
        else if (element.collectionType !== null)
            return resolveODBType(element.collectionType)

        throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
    }

    def private String makeODBColumn(MemberElementWrapper member, Set<String> existing_column_names)
    {
        val column_name = member.name.toUpperCase
        val is_uuid = member.type.ultimateType.isUUIDType
        val is_optional = member.optional

        val is_sequence = member.type.isSequenceType
        if (is_sequence)
            return ""

        val ultimate_type = member.type.ultimateType
        if (ultimate_type instanceof StructDeclaration)
        {
            // no content for a DB column: leave
            // otherwise ODB error "No persistent data members in the class" 
            if (ultimate_type.members.empty)
                return ""
        }

        // Oracle does not support column names longer than 30 characters,
        // therefore we need to truncate names which exceeds this limit!
        var normalized_column_name = member.name.toUpperCase
        val size = member.calculateMaximalNameLength
        if (size > 30)
        {
            normalized_column_name = member.name.replaceAll("[a-z]", "").toUpperCase
            var temp_name = normalized_column_name
            var index = new AtomicInteger(1); // TODO why should this be atomic? we only use a single thread
            while (existing_column_names.contains(temp_name))
            {
                temp_name = normalized_column_name + (index.addAndGet(1) ).toString
            }
            normalized_column_name = temp_name
        }

        existing_column_names.add(normalized_column_name)

        '''
            #pragma db «IF is_uuid && column_name == "ID"»id «ENDIF»column("«normalized_column_name»")«IF is_uuid» oracle:type("RAW(16)") mssql:type("UNIQUEIDENTIFIER")«ENDIF»
            «IF is_optional»«resolveODB("odb::nullable")»<«ENDIF»«resolveODBType(member.type)»«IF is_optional»>«ENDIF» «column_name»;
        '''
    }

    def generateHxx(StructDeclaration struct)
    {
        val table_name = struct.name.toUpperCase
        val class_name = struct.name.toLowerCase

        val existing_column_names = new HashSet<String>

        '''
            #pragma db object table("«table_name»")
            class «class_name»
            {
            public:
               «class_name» () {}
               
               «FOR member : struct.allMembers»
                   «makeODBColumn(member, existing_column_names)»
               «ENDFOR»
            };
        '''
    }

    def generateCommonHxx(Iterable<StructDeclaration> common_types)
    {
        val existing_column_names = new HashSet<String>

        '''
            «FOR type : common_types»
                «IF !type.members.empty»
                    #pragma db value
                    struct «type.name»
                    {
                       «FOR member : type.allMembers»
                           «makeODBColumn(member, existing_column_names)»
                       «ENDFOR»
                    };
                «ENDIF»
            «ENDFOR»
        '''
    }
}
