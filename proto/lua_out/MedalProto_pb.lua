-- Generated By protoc-gen-lua Do not Edit
local protobuf = require "protobuf/protobuf"
local CommonProto_pb = require("CommonProto_pb")
module('MedalProto_pb')


MEDALSELLREQUEST = protobuf.Descriptor();
MEDALSELLREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALSELLRESPONSE = protobuf.Descriptor();
MEDALSELLRESPONSE_DROP_FIELD = protobuf.FieldDescriptor();
MEDALGETALLREQUEST = protobuf.Descriptor();
MEDALGETALLREPONSE = protobuf.Descriptor();
MEDALGETALLREPONSE_MEDAL_FIELD = protobuf.FieldDescriptor();
MEDALGETONEREPONSE = protobuf.Descriptor();
MEDALGETONEREPONSE_MEDAL_FIELD = protobuf.FieldDescriptor();
MEDALHEROINFOREPONSE = protobuf.Descriptor();
MEDALHEROINFOREPONSE_HERO_FIELD = protobuf.FieldDescriptor();
MEDALWEARREQUEST = protobuf.Descriptor();
MEDALWEARREQUEST_HEROID_FIELD = protobuf.FieldDescriptor();
MEDALWEARREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALWEARREQUEST_SITETYPE_FIELD = protobuf.FieldDescriptor();
MEDALCHANGEREQUEST = protobuf.Descriptor();
MEDALCHANGEREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALCHANGEREQUEST_CONFMEDALID_FIELD = protobuf.FieldDescriptor();
MEDALCHANGEREQUEST_HEROID_FIELD = protobuf.FieldDescriptor();
MEDALCHANGEREQUEST_POSITION_FIELD = protobuf.FieldDescriptor();
MEDALUNLOADREQUEST = protobuf.Descriptor();
MEDALUNLOADREQUEST_HEROID_FIELD = protobuf.FieldDescriptor();
MEDALUNLOADREQUEST_SITETYPE_FIELD = protobuf.FieldDescriptor();
MEDALUNLOADREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALUNLOADRESPONSE = protobuf.Descriptor();
MEDALUNLOADRESPONSE_RESULT_FIELD = protobuf.FieldDescriptor();
MEDALMERGEREQUEST = protobuf.Descriptor();
MEDALMERGEREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALMERGEREQUEST_PROPERTY_FIELD = protobuf.FieldDescriptor();
MEDALREFINEREQUEST = protobuf.Descriptor();
MEDALREFINEREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALREFINEREQUEST_PROPERTY_FIELD = protobuf.FieldDescriptor();
MEDALREFINERESPONSE = protobuf.Descriptor();
MEDALREFINERESPONSE_PROPERTY_FIELD = protobuf.FieldDescriptor();
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD = protobuf.FieldDescriptor();
MEDALREFINECONFIRMREQUEST = protobuf.Descriptor();
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALREFINETEMPPROPERTYREQUEST = protobuf.Descriptor();
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALREFINETEMPPROPERTYRESPONSE = protobuf.Descriptor();
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD = protobuf.FieldDescriptor();
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD = protobuf.FieldDescriptor();
MEDALSAVEPOS = protobuf.Descriptor();
MEDALSAVEPOS_POS_FIELD = protobuf.FieldDescriptor();
MEDALSAVEPOS_NAME_FIELD = protobuf.FieldDescriptor();
MEDALSAVEPOS_MEDALID_FIELD = protobuf.FieldDescriptor();
MEDALSAVEPOS_ACTIVEPOS_FIELD = protobuf.FieldDescriptor();
BUYSAVEPOSREQUEST = protobuf.Descriptor();
BUYSAVEPOSREQUEST_POS_FIELD = protobuf.FieldDescriptor();
USESAVEPOSREQUEST = protobuf.Descriptor();
USESAVEPOSREQUEST_HEROID_FIELD = protobuf.FieldDescriptor();
USESAVEPOSREQUEST_POS_FIELD = protobuf.FieldDescriptor();
WEARSAVEPOSREQUEST = protobuf.Descriptor();
WEARSAVEPOSREQUEST_POS_FIELD = protobuf.FieldDescriptor();
WEARSAVEPOSREQUEST_MEDALIDS_FIELD = protobuf.FieldDescriptor();
GETSAVEPOSREQUEST = protobuf.Descriptor();
GETSAVEPOSREPONSE = protobuf.Descriptor();
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD = protobuf.FieldDescriptor();
SETNAMEREQUEST = protobuf.Descriptor();
SETNAMEREQUEST_POS_FIELD = protobuf.FieldDescriptor();
SETNAMEREQUEST_NAME_FIELD = protobuf.FieldDescriptor();
MEDALUNLOAD2REQUEST = protobuf.Descriptor();
MEDALUNLOAD2REQUEST_HEROID_FIELD = protobuf.FieldDescriptor();

MEDALSELLREQUEST_MEDALID_FIELD.name = "medalId"
MEDALSELLREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSellRequest.medalId"
MEDALSELLREQUEST_MEDALID_FIELD.number = 1
MEDALSELLREQUEST_MEDALID_FIELD.index = 0
MEDALSELLREQUEST_MEDALID_FIELD.label = 1
MEDALSELLREQUEST_MEDALID_FIELD.has_default_value = false
MEDALSELLREQUEST_MEDALID_FIELD.default_value = ""
MEDALSELLREQUEST_MEDALID_FIELD.type = 9
MEDALSELLREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALSELLREQUEST.name = "MedalSellRequest"
MEDALSELLREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalSellRequest"
MEDALSELLREQUEST.nested_types = {}
MEDALSELLREQUEST.enum_types = {}
MEDALSELLREQUEST.fields = {MEDALSELLREQUEST_MEDALID_FIELD}
MEDALSELLREQUEST.is_extendable = false
MEDALSELLREQUEST.extensions = {}
MEDALSELLRESPONSE_DROP_FIELD.name = "drop"
MEDALSELLRESPONSE_DROP_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSellResponse.drop"
MEDALSELLRESPONSE_DROP_FIELD.number = 1
MEDALSELLRESPONSE_DROP_FIELD.index = 0
MEDALSELLRESPONSE_DROP_FIELD.label = 1
MEDALSELLRESPONSE_DROP_FIELD.has_default_value = false
MEDALSELLRESPONSE_DROP_FIELD.default_value = nil
MEDALSELLRESPONSE_DROP_FIELD.message_type = CommonProto_pb.DROP
MEDALSELLRESPONSE_DROP_FIELD.type = 11
MEDALSELLRESPONSE_DROP_FIELD.cpp_type = 10

MEDALSELLRESPONSE.name = "MedalSellResponse"
MEDALSELLRESPONSE.full_name = ".com.ljsd.jieling.protocols.MedalSellResponse"
MEDALSELLRESPONSE.nested_types = {}
MEDALSELLRESPONSE.enum_types = {}
MEDALSELLRESPONSE.fields = {MEDALSELLRESPONSE_DROP_FIELD}
MEDALSELLRESPONSE.is_extendable = false
MEDALSELLRESPONSE.extensions = {}
MEDALGETALLREQUEST.name = "MedalGetAllRequest"
MEDALGETALLREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalGetAllRequest"
MEDALGETALLREQUEST.nested_types = {}
MEDALGETALLREQUEST.enum_types = {}
MEDALGETALLREQUEST.fields = {}
MEDALGETALLREQUEST.is_extendable = false
MEDALGETALLREQUEST.extensions = {}
MEDALGETALLREPONSE_MEDAL_FIELD.name = "medal"
MEDALGETALLREPONSE_MEDAL_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalGetAllReponse.medal"
MEDALGETALLREPONSE_MEDAL_FIELD.number = 1
MEDALGETALLREPONSE_MEDAL_FIELD.index = 0
MEDALGETALLREPONSE_MEDAL_FIELD.label = 3
MEDALGETALLREPONSE_MEDAL_FIELD.has_default_value = false
MEDALGETALLREPONSE_MEDAL_FIELD.default_value = {}
MEDALGETALLREPONSE_MEDAL_FIELD.message_type = CommonProto_pb.MEDAL
MEDALGETALLREPONSE_MEDAL_FIELD.type = 11
MEDALGETALLREPONSE_MEDAL_FIELD.cpp_type = 10

MEDALGETALLREPONSE.name = "MedalGetAllReponse"
MEDALGETALLREPONSE.full_name = ".com.ljsd.jieling.protocols.MedalGetAllReponse"
MEDALGETALLREPONSE.nested_types = {}
MEDALGETALLREPONSE.enum_types = {}
MEDALGETALLREPONSE.fields = {MEDALGETALLREPONSE_MEDAL_FIELD}
MEDALGETALLREPONSE.is_extendable = false
MEDALGETALLREPONSE.extensions = {}
MEDALGETONEREPONSE_MEDAL_FIELD.name = "medal"
MEDALGETONEREPONSE_MEDAL_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalGetOneReponse.medal"
MEDALGETONEREPONSE_MEDAL_FIELD.number = 1
MEDALGETONEREPONSE_MEDAL_FIELD.index = 0
MEDALGETONEREPONSE_MEDAL_FIELD.label = 1
MEDALGETONEREPONSE_MEDAL_FIELD.has_default_value = false
MEDALGETONEREPONSE_MEDAL_FIELD.default_value = nil
MEDALGETONEREPONSE_MEDAL_FIELD.message_type = CommonProto_pb.MEDAL
MEDALGETONEREPONSE_MEDAL_FIELD.type = 11
MEDALGETONEREPONSE_MEDAL_FIELD.cpp_type = 10

MEDALGETONEREPONSE.name = "MedalGetOneReponse"
MEDALGETONEREPONSE.full_name = ".com.ljsd.jieling.protocols.MedalGetOneReponse"
MEDALGETONEREPONSE.nested_types = {}
MEDALGETONEREPONSE.enum_types = {}
MEDALGETONEREPONSE.fields = {MEDALGETONEREPONSE_MEDAL_FIELD}
MEDALGETONEREPONSE.is_extendable = false
MEDALGETONEREPONSE.extensions = {}
MEDALHEROINFOREPONSE_HERO_FIELD.name = "hero"
MEDALHEROINFOREPONSE_HERO_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalHeroInfoReponse.hero"
MEDALHEROINFOREPONSE_HERO_FIELD.number = 1
MEDALHEROINFOREPONSE_HERO_FIELD.index = 0
MEDALHEROINFOREPONSE_HERO_FIELD.label = 1
MEDALHEROINFOREPONSE_HERO_FIELD.has_default_value = false
MEDALHEROINFOREPONSE_HERO_FIELD.default_value = nil
MEDALHEROINFOREPONSE_HERO_FIELD.message_type = CommonProto_pb.HERO
MEDALHEROINFOREPONSE_HERO_FIELD.type = 11
MEDALHEROINFOREPONSE_HERO_FIELD.cpp_type = 10

MEDALHEROINFOREPONSE.name = "MedalHeroInfoReponse"
MEDALHEROINFOREPONSE.full_name = ".com.ljsd.jieling.protocols.MedalHeroInfoReponse"
MEDALHEROINFOREPONSE.nested_types = {}
MEDALHEROINFOREPONSE.enum_types = {}
MEDALHEROINFOREPONSE.fields = {MEDALHEROINFOREPONSE_HERO_FIELD}
MEDALHEROINFOREPONSE.is_extendable = false
MEDALHEROINFOREPONSE.extensions = {}
MEDALWEARREQUEST_HEROID_FIELD.name = "heroId"
MEDALWEARREQUEST_HEROID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalWearRequest.heroId"
MEDALWEARREQUEST_HEROID_FIELD.number = 1
MEDALWEARREQUEST_HEROID_FIELD.index = 0
MEDALWEARREQUEST_HEROID_FIELD.label = 1
MEDALWEARREQUEST_HEROID_FIELD.has_default_value = false
MEDALWEARREQUEST_HEROID_FIELD.default_value = ""
MEDALWEARREQUEST_HEROID_FIELD.type = 9
MEDALWEARREQUEST_HEROID_FIELD.cpp_type = 9

MEDALWEARREQUEST_MEDALID_FIELD.name = "medalId"
MEDALWEARREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalWearRequest.medalId"
MEDALWEARREQUEST_MEDALID_FIELD.number = 2
MEDALWEARREQUEST_MEDALID_FIELD.index = 1
MEDALWEARREQUEST_MEDALID_FIELD.label = 1
MEDALWEARREQUEST_MEDALID_FIELD.has_default_value = false
MEDALWEARREQUEST_MEDALID_FIELD.default_value = ""
MEDALWEARREQUEST_MEDALID_FIELD.type = 9
MEDALWEARREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALWEARREQUEST_SITETYPE_FIELD.name = "siteType"
MEDALWEARREQUEST_SITETYPE_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalWearRequest.siteType"
MEDALWEARREQUEST_SITETYPE_FIELD.number = 3
MEDALWEARREQUEST_SITETYPE_FIELD.index = 2
MEDALWEARREQUEST_SITETYPE_FIELD.label = 1
MEDALWEARREQUEST_SITETYPE_FIELD.has_default_value = false
MEDALWEARREQUEST_SITETYPE_FIELD.default_value = 0
MEDALWEARREQUEST_SITETYPE_FIELD.type = 5
MEDALWEARREQUEST_SITETYPE_FIELD.cpp_type = 1

MEDALWEARREQUEST.name = "MedalWearRequest"
MEDALWEARREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalWearRequest"
MEDALWEARREQUEST.nested_types = {}
MEDALWEARREQUEST.enum_types = {}
MEDALWEARREQUEST.fields = {MEDALWEARREQUEST_HEROID_FIELD, MEDALWEARREQUEST_MEDALID_FIELD, MEDALWEARREQUEST_SITETYPE_FIELD}
MEDALWEARREQUEST.is_extendable = false
MEDALWEARREQUEST.extensions = {}
MEDALCHANGEREQUEST_MEDALID_FIELD.name = "medalId"
MEDALCHANGEREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalChangeRequest.medalId"
MEDALCHANGEREQUEST_MEDALID_FIELD.number = 1
MEDALCHANGEREQUEST_MEDALID_FIELD.index = 0
MEDALCHANGEREQUEST_MEDALID_FIELD.label = 1
MEDALCHANGEREQUEST_MEDALID_FIELD.has_default_value = false
MEDALCHANGEREQUEST_MEDALID_FIELD.default_value = ""
MEDALCHANGEREQUEST_MEDALID_FIELD.type = 9
MEDALCHANGEREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALCHANGEREQUEST_CONFMEDALID_FIELD.name = "confMedalId"
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalChangeRequest.confMedalId"
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.number = 2
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.index = 1
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.label = 1
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.has_default_value = false
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.default_value = 0
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.type = 5
MEDALCHANGEREQUEST_CONFMEDALID_FIELD.cpp_type = 1

MEDALCHANGEREQUEST_HEROID_FIELD.name = "heroId"
MEDALCHANGEREQUEST_HEROID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalChangeRequest.heroId"
MEDALCHANGEREQUEST_HEROID_FIELD.number = 3
MEDALCHANGEREQUEST_HEROID_FIELD.index = 2
MEDALCHANGEREQUEST_HEROID_FIELD.label = 1
MEDALCHANGEREQUEST_HEROID_FIELD.has_default_value = false
MEDALCHANGEREQUEST_HEROID_FIELD.default_value = ""
MEDALCHANGEREQUEST_HEROID_FIELD.type = 9
MEDALCHANGEREQUEST_HEROID_FIELD.cpp_type = 9

MEDALCHANGEREQUEST_POSITION_FIELD.name = "position"
MEDALCHANGEREQUEST_POSITION_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalChangeRequest.position"
MEDALCHANGEREQUEST_POSITION_FIELD.number = 4
MEDALCHANGEREQUEST_POSITION_FIELD.index = 3
MEDALCHANGEREQUEST_POSITION_FIELD.label = 1
MEDALCHANGEREQUEST_POSITION_FIELD.has_default_value = false
MEDALCHANGEREQUEST_POSITION_FIELD.default_value = 0
MEDALCHANGEREQUEST_POSITION_FIELD.type = 5
MEDALCHANGEREQUEST_POSITION_FIELD.cpp_type = 1

MEDALCHANGEREQUEST.name = "MedalChangeRequest"
MEDALCHANGEREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalChangeRequest"
MEDALCHANGEREQUEST.nested_types = {}
MEDALCHANGEREQUEST.enum_types = {}
MEDALCHANGEREQUEST.fields = {MEDALCHANGEREQUEST_MEDALID_FIELD, MEDALCHANGEREQUEST_CONFMEDALID_FIELD, MEDALCHANGEREQUEST_HEROID_FIELD, MEDALCHANGEREQUEST_POSITION_FIELD}
MEDALCHANGEREQUEST.is_extendable = false
MEDALCHANGEREQUEST.extensions = {}
MEDALUNLOADREQUEST_HEROID_FIELD.name = "heroId"
MEDALUNLOADREQUEST_HEROID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalUnloadRequest.heroId"
MEDALUNLOADREQUEST_HEROID_FIELD.number = 1
MEDALUNLOADREQUEST_HEROID_FIELD.index = 0
MEDALUNLOADREQUEST_HEROID_FIELD.label = 1
MEDALUNLOADREQUEST_HEROID_FIELD.has_default_value = false
MEDALUNLOADREQUEST_HEROID_FIELD.default_value = ""
MEDALUNLOADREQUEST_HEROID_FIELD.type = 9
MEDALUNLOADREQUEST_HEROID_FIELD.cpp_type = 9

MEDALUNLOADREQUEST_SITETYPE_FIELD.name = "siteType"
MEDALUNLOADREQUEST_SITETYPE_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalUnloadRequest.siteType"
MEDALUNLOADREQUEST_SITETYPE_FIELD.number = 2
MEDALUNLOADREQUEST_SITETYPE_FIELD.index = 1
MEDALUNLOADREQUEST_SITETYPE_FIELD.label = 1
MEDALUNLOADREQUEST_SITETYPE_FIELD.has_default_value = false
MEDALUNLOADREQUEST_SITETYPE_FIELD.default_value = 0
MEDALUNLOADREQUEST_SITETYPE_FIELD.type = 5
MEDALUNLOADREQUEST_SITETYPE_FIELD.cpp_type = 1

MEDALUNLOADREQUEST_MEDALID_FIELD.name = "medalId"
MEDALUNLOADREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalUnloadRequest.medalId"
MEDALUNLOADREQUEST_MEDALID_FIELD.number = 3
MEDALUNLOADREQUEST_MEDALID_FIELD.index = 2
MEDALUNLOADREQUEST_MEDALID_FIELD.label = 1
MEDALUNLOADREQUEST_MEDALID_FIELD.has_default_value = false
MEDALUNLOADREQUEST_MEDALID_FIELD.default_value = ""
MEDALUNLOADREQUEST_MEDALID_FIELD.type = 9
MEDALUNLOADREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALUNLOADREQUEST.name = "MedalUnloadRequest"
MEDALUNLOADREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalUnloadRequest"
MEDALUNLOADREQUEST.nested_types = {}
MEDALUNLOADREQUEST.enum_types = {}
MEDALUNLOADREQUEST.fields = {MEDALUNLOADREQUEST_HEROID_FIELD, MEDALUNLOADREQUEST_SITETYPE_FIELD, MEDALUNLOADREQUEST_MEDALID_FIELD}
MEDALUNLOADREQUEST.is_extendable = false
MEDALUNLOADREQUEST.extensions = {}
MEDALUNLOADRESPONSE_RESULT_FIELD.name = "result"
MEDALUNLOADRESPONSE_RESULT_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalUnloadResponse.result"
MEDALUNLOADRESPONSE_RESULT_FIELD.number = 1
MEDALUNLOADRESPONSE_RESULT_FIELD.index = 0
MEDALUNLOADRESPONSE_RESULT_FIELD.label = 1
MEDALUNLOADRESPONSE_RESULT_FIELD.has_default_value = false
MEDALUNLOADRESPONSE_RESULT_FIELD.default_value = 0
MEDALUNLOADRESPONSE_RESULT_FIELD.type = 5
MEDALUNLOADRESPONSE_RESULT_FIELD.cpp_type = 1

MEDALUNLOADRESPONSE.name = "MedalUnloadResponse"
MEDALUNLOADRESPONSE.full_name = ".com.ljsd.jieling.protocols.MedalUnloadResponse"
MEDALUNLOADRESPONSE.nested_types = {}
MEDALUNLOADRESPONSE.enum_types = {}
MEDALUNLOADRESPONSE.fields = {MEDALUNLOADRESPONSE_RESULT_FIELD}
MEDALUNLOADRESPONSE.is_extendable = false
MEDALUNLOADRESPONSE.extensions = {}
MEDALMERGEREQUEST_MEDALID_FIELD.name = "medalId"
MEDALMERGEREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalMergeRequest.medalId"
MEDALMERGEREQUEST_MEDALID_FIELD.number = 1
MEDALMERGEREQUEST_MEDALID_FIELD.index = 0
MEDALMERGEREQUEST_MEDALID_FIELD.label = 3
MEDALMERGEREQUEST_MEDALID_FIELD.has_default_value = false
MEDALMERGEREQUEST_MEDALID_FIELD.default_value = {}
MEDALMERGEREQUEST_MEDALID_FIELD.type = 9
MEDALMERGEREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALMERGEREQUEST_PROPERTY_FIELD.name = "property"
MEDALMERGEREQUEST_PROPERTY_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalMergeRequest.property"
MEDALMERGEREQUEST_PROPERTY_FIELD.number = 2
MEDALMERGEREQUEST_PROPERTY_FIELD.index = 1
MEDALMERGEREQUEST_PROPERTY_FIELD.label = 3
MEDALMERGEREQUEST_PROPERTY_FIELD.has_default_value = false
MEDALMERGEREQUEST_PROPERTY_FIELD.default_value = {}
MEDALMERGEREQUEST_PROPERTY_FIELD.message_type = CommonProto_pb.PROPERTY
MEDALMERGEREQUEST_PROPERTY_FIELD.type = 11
MEDALMERGEREQUEST_PROPERTY_FIELD.cpp_type = 10

MEDALMERGEREQUEST.name = "MedalMergeRequest"
MEDALMERGEREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalMergeRequest"
MEDALMERGEREQUEST.nested_types = {}
MEDALMERGEREQUEST.enum_types = {}
MEDALMERGEREQUEST.fields = {MEDALMERGEREQUEST_MEDALID_FIELD, MEDALMERGEREQUEST_PROPERTY_FIELD}
MEDALMERGEREQUEST.is_extendable = false
MEDALMERGEREQUEST.extensions = {}
MEDALREFINEREQUEST_MEDALID_FIELD.name = "medalId"
MEDALREFINEREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineRequest.medalId"
MEDALREFINEREQUEST_MEDALID_FIELD.number = 1
MEDALREFINEREQUEST_MEDALID_FIELD.index = 0
MEDALREFINEREQUEST_MEDALID_FIELD.label = 1
MEDALREFINEREQUEST_MEDALID_FIELD.has_default_value = false
MEDALREFINEREQUEST_MEDALID_FIELD.default_value = ""
MEDALREFINEREQUEST_MEDALID_FIELD.type = 9
MEDALREFINEREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALREFINEREQUEST_PROPERTY_FIELD.name = "property"
MEDALREFINEREQUEST_PROPERTY_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineRequest.property"
MEDALREFINEREQUEST_PROPERTY_FIELD.number = 2
MEDALREFINEREQUEST_PROPERTY_FIELD.index = 1
MEDALREFINEREQUEST_PROPERTY_FIELD.label = 3
MEDALREFINEREQUEST_PROPERTY_FIELD.has_default_value = false
MEDALREFINEREQUEST_PROPERTY_FIELD.default_value = {}
MEDALREFINEREQUEST_PROPERTY_FIELD.type = 5
MEDALREFINEREQUEST_PROPERTY_FIELD.cpp_type = 1

MEDALREFINEREQUEST.name = "MedalRefineRequest"
MEDALREFINEREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalRefineRequest"
MEDALREFINEREQUEST.nested_types = {}
MEDALREFINEREQUEST.enum_types = {}
MEDALREFINEREQUEST.fields = {MEDALREFINEREQUEST_MEDALID_FIELD, MEDALREFINEREQUEST_PROPERTY_FIELD}
MEDALREFINEREQUEST.is_extendable = false
MEDALREFINEREQUEST.extensions = {}
MEDALREFINERESPONSE_PROPERTY_FIELD.name = "property"
MEDALREFINERESPONSE_PROPERTY_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineResponse.property"
MEDALREFINERESPONSE_PROPERTY_FIELD.number = 1
MEDALREFINERESPONSE_PROPERTY_FIELD.index = 0
MEDALREFINERESPONSE_PROPERTY_FIELD.label = 3
MEDALREFINERESPONSE_PROPERTY_FIELD.has_default_value = false
MEDALREFINERESPONSE_PROPERTY_FIELD.default_value = {}
MEDALREFINERESPONSE_PROPERTY_FIELD.message_type = CommonProto_pb.PROPERTY
MEDALREFINERESPONSE_PROPERTY_FIELD.type = 11
MEDALREFINERESPONSE_PROPERTY_FIELD.cpp_type = 10

MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.name = "refineAttrNum"
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineResponse.refineAttrNum"
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.number = 2
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.index = 1
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.label = 1
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.has_default_value = false
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.default_value = 0
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.type = 5
MEDALREFINERESPONSE_REFINEATTRNUM_FIELD.cpp_type = 1

MEDALREFINERESPONSE.name = "MedalRefineResponse"
MEDALREFINERESPONSE.full_name = ".com.ljsd.jieling.protocols.MedalRefineResponse"
MEDALREFINERESPONSE.nested_types = {}
MEDALREFINERESPONSE.enum_types = {}
MEDALREFINERESPONSE.fields = {MEDALREFINERESPONSE_PROPERTY_FIELD, MEDALREFINERESPONSE_REFINEATTRNUM_FIELD}
MEDALREFINERESPONSE.is_extendable = false
MEDALREFINERESPONSE.extensions = {}
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.name = "medalId"
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineConfirmRequest.medalId"
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.number = 1
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.index = 0
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.label = 1
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.has_default_value = false
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.default_value = ""
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.type = 9
MEDALREFINECONFIRMREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALREFINECONFIRMREQUEST.name = "MedalRefineConfirmRequest"
MEDALREFINECONFIRMREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalRefineConfirmRequest"
MEDALREFINECONFIRMREQUEST.nested_types = {}
MEDALREFINECONFIRMREQUEST.enum_types = {}
MEDALREFINECONFIRMREQUEST.fields = {MEDALREFINECONFIRMREQUEST_MEDALID_FIELD}
MEDALREFINECONFIRMREQUEST.is_extendable = false
MEDALREFINECONFIRMREQUEST.extensions = {}
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.name = "medalId"
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineTempPropertyRequest.medalId"
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.number = 1
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.index = 0
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.label = 1
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.has_default_value = false
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.default_value = ""
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.type = 9
MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD.cpp_type = 9

MEDALREFINETEMPPROPERTYREQUEST.name = "MedalRefineTempPropertyRequest"
MEDALREFINETEMPPROPERTYREQUEST.full_name = ".com.ljsd.jieling.protocols.MedalRefineTempPropertyRequest"
MEDALREFINETEMPPROPERTYREQUEST.nested_types = {}
MEDALREFINETEMPPROPERTYREQUEST.enum_types = {}
MEDALREFINETEMPPROPERTYREQUEST.fields = {MEDALREFINETEMPPROPERTYREQUEST_MEDALID_FIELD}
MEDALREFINETEMPPROPERTYREQUEST.is_extendable = false
MEDALREFINETEMPPROPERTYREQUEST.extensions = {}
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.name = "property"
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineTempPropertyResponse.property"
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.number = 1
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.index = 0
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.label = 3
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.has_default_value = false
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.default_value = {}
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.message_type = CommonProto_pb.PROPERTY
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.type = 11
MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD.cpp_type = 10

MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.name = "refineAttrNum"
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalRefineTempPropertyResponse.refineAttrNum"
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.number = 2
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.index = 1
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.label = 1
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.has_default_value = false
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.default_value = 0
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.type = 5
MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD.cpp_type = 1

MEDALREFINETEMPPROPERTYRESPONSE.name = "MedalRefineTempPropertyResponse"
MEDALREFINETEMPPROPERTYRESPONSE.full_name = ".com.ljsd.jieling.protocols.MedalRefineTempPropertyResponse"
MEDALREFINETEMPPROPERTYRESPONSE.nested_types = {}
MEDALREFINETEMPPROPERTYRESPONSE.enum_types = {}
MEDALREFINETEMPPROPERTYRESPONSE.fields = {MEDALREFINETEMPPROPERTYRESPONSE_PROPERTY_FIELD, MEDALREFINETEMPPROPERTYRESPONSE_REFINEATTRNUM_FIELD}
MEDALREFINETEMPPROPERTYRESPONSE.is_extendable = false
MEDALREFINETEMPPROPERTYRESPONSE.extensions = {}
MEDALSAVEPOS_POS_FIELD.name = "pos"
MEDALSAVEPOS_POS_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSavePos.pos"
MEDALSAVEPOS_POS_FIELD.number = 1
MEDALSAVEPOS_POS_FIELD.index = 0
MEDALSAVEPOS_POS_FIELD.label = 1
MEDALSAVEPOS_POS_FIELD.has_default_value = false
MEDALSAVEPOS_POS_FIELD.default_value = 0
MEDALSAVEPOS_POS_FIELD.type = 5
MEDALSAVEPOS_POS_FIELD.cpp_type = 1

MEDALSAVEPOS_NAME_FIELD.name = "name"
MEDALSAVEPOS_NAME_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSavePos.name"
MEDALSAVEPOS_NAME_FIELD.number = 2
MEDALSAVEPOS_NAME_FIELD.index = 1
MEDALSAVEPOS_NAME_FIELD.label = 1
MEDALSAVEPOS_NAME_FIELD.has_default_value = false
MEDALSAVEPOS_NAME_FIELD.default_value = ""
MEDALSAVEPOS_NAME_FIELD.type = 9
MEDALSAVEPOS_NAME_FIELD.cpp_type = 9

MEDALSAVEPOS_MEDALID_FIELD.name = "medalId"
MEDALSAVEPOS_MEDALID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSavePos.medalId"
MEDALSAVEPOS_MEDALID_FIELD.number = 3
MEDALSAVEPOS_MEDALID_FIELD.index = 2
MEDALSAVEPOS_MEDALID_FIELD.label = 3
MEDALSAVEPOS_MEDALID_FIELD.has_default_value = false
MEDALSAVEPOS_MEDALID_FIELD.default_value = {}
MEDALSAVEPOS_MEDALID_FIELD.type = 9
MEDALSAVEPOS_MEDALID_FIELD.cpp_type = 9

MEDALSAVEPOS_ACTIVEPOS_FIELD.name = "activePos"
MEDALSAVEPOS_ACTIVEPOS_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalSavePos.activePos"
MEDALSAVEPOS_ACTIVEPOS_FIELD.number = 4
MEDALSAVEPOS_ACTIVEPOS_FIELD.index = 3
MEDALSAVEPOS_ACTIVEPOS_FIELD.label = 1
MEDALSAVEPOS_ACTIVEPOS_FIELD.has_default_value = false
MEDALSAVEPOS_ACTIVEPOS_FIELD.default_value = 0
MEDALSAVEPOS_ACTIVEPOS_FIELD.type = 5
MEDALSAVEPOS_ACTIVEPOS_FIELD.cpp_type = 1

MEDALSAVEPOS.name = "MedalSavePos"
MEDALSAVEPOS.full_name = ".com.ljsd.jieling.protocols.MedalSavePos"
MEDALSAVEPOS.nested_types = {}
MEDALSAVEPOS.enum_types = {}
MEDALSAVEPOS.fields = {MEDALSAVEPOS_POS_FIELD, MEDALSAVEPOS_NAME_FIELD, MEDALSAVEPOS_MEDALID_FIELD, MEDALSAVEPOS_ACTIVEPOS_FIELD}
MEDALSAVEPOS.is_extendable = false
MEDALSAVEPOS.extensions = {}
BUYSAVEPOSREQUEST_POS_FIELD.name = "pos"
BUYSAVEPOSREQUEST_POS_FIELD.full_name = ".com.ljsd.jieling.protocols.BuySavePosRequest.pos"
BUYSAVEPOSREQUEST_POS_FIELD.number = 1
BUYSAVEPOSREQUEST_POS_FIELD.index = 0
BUYSAVEPOSREQUEST_POS_FIELD.label = 1
BUYSAVEPOSREQUEST_POS_FIELD.has_default_value = false
BUYSAVEPOSREQUEST_POS_FIELD.default_value = 0
BUYSAVEPOSREQUEST_POS_FIELD.type = 5
BUYSAVEPOSREQUEST_POS_FIELD.cpp_type = 1

BUYSAVEPOSREQUEST.name = "BuySavePosRequest"
BUYSAVEPOSREQUEST.full_name = ".com.ljsd.jieling.protocols.BuySavePosRequest"
BUYSAVEPOSREQUEST.nested_types = {}
BUYSAVEPOSREQUEST.enum_types = {}
BUYSAVEPOSREQUEST.fields = {BUYSAVEPOSREQUEST_POS_FIELD}
BUYSAVEPOSREQUEST.is_extendable = false
BUYSAVEPOSREQUEST.extensions = {}
USESAVEPOSREQUEST_HEROID_FIELD.name = "heroId"
USESAVEPOSREQUEST_HEROID_FIELD.full_name = ".com.ljsd.jieling.protocols.UseSavePosRequest.heroId"
USESAVEPOSREQUEST_HEROID_FIELD.number = 1
USESAVEPOSREQUEST_HEROID_FIELD.index = 0
USESAVEPOSREQUEST_HEROID_FIELD.label = 1
USESAVEPOSREQUEST_HEROID_FIELD.has_default_value = false
USESAVEPOSREQUEST_HEROID_FIELD.default_value = ""
USESAVEPOSREQUEST_HEROID_FIELD.type = 9
USESAVEPOSREQUEST_HEROID_FIELD.cpp_type = 9

USESAVEPOSREQUEST_POS_FIELD.name = "pos"
USESAVEPOSREQUEST_POS_FIELD.full_name = ".com.ljsd.jieling.protocols.UseSavePosRequest.pos"
USESAVEPOSREQUEST_POS_FIELD.number = 2
USESAVEPOSREQUEST_POS_FIELD.index = 1
USESAVEPOSREQUEST_POS_FIELD.label = 1
USESAVEPOSREQUEST_POS_FIELD.has_default_value = false
USESAVEPOSREQUEST_POS_FIELD.default_value = 0
USESAVEPOSREQUEST_POS_FIELD.type = 5
USESAVEPOSREQUEST_POS_FIELD.cpp_type = 1

USESAVEPOSREQUEST.name = "UseSavePosRequest"
USESAVEPOSREQUEST.full_name = ".com.ljsd.jieling.protocols.UseSavePosRequest"
USESAVEPOSREQUEST.nested_types = {}
USESAVEPOSREQUEST.enum_types = {}
USESAVEPOSREQUEST.fields = {USESAVEPOSREQUEST_HEROID_FIELD, USESAVEPOSREQUEST_POS_FIELD}
USESAVEPOSREQUEST.is_extendable = false
USESAVEPOSREQUEST.extensions = {}
WEARSAVEPOSREQUEST_POS_FIELD.name = "pos"
WEARSAVEPOSREQUEST_POS_FIELD.full_name = ".com.ljsd.jieling.protocols.WearSavePosRequest.pos"
WEARSAVEPOSREQUEST_POS_FIELD.number = 1
WEARSAVEPOSREQUEST_POS_FIELD.index = 0
WEARSAVEPOSREQUEST_POS_FIELD.label = 1
WEARSAVEPOSREQUEST_POS_FIELD.has_default_value = false
WEARSAVEPOSREQUEST_POS_FIELD.default_value = 0
WEARSAVEPOSREQUEST_POS_FIELD.type = 5
WEARSAVEPOSREQUEST_POS_FIELD.cpp_type = 1

WEARSAVEPOSREQUEST_MEDALIDS_FIELD.name = "medalIds"
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.full_name = ".com.ljsd.jieling.protocols.WearSavePosRequest.medalIds"
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.number = 2
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.index = 1
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.label = 3
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.has_default_value = false
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.default_value = {}
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.type = 9
WEARSAVEPOSREQUEST_MEDALIDS_FIELD.cpp_type = 9

WEARSAVEPOSREQUEST.name = "WearSavePosRequest"
WEARSAVEPOSREQUEST.full_name = ".com.ljsd.jieling.protocols.WearSavePosRequest"
WEARSAVEPOSREQUEST.nested_types = {}
WEARSAVEPOSREQUEST.enum_types = {}
WEARSAVEPOSREQUEST.fields = {WEARSAVEPOSREQUEST_POS_FIELD, WEARSAVEPOSREQUEST_MEDALIDS_FIELD}
WEARSAVEPOSREQUEST.is_extendable = false
WEARSAVEPOSREQUEST.extensions = {}
GETSAVEPOSREQUEST.name = "GetSavePosRequest"
GETSAVEPOSREQUEST.full_name = ".com.ljsd.jieling.protocols.GetSavePosRequest"
GETSAVEPOSREQUEST.nested_types = {}
GETSAVEPOSREQUEST.enum_types = {}
GETSAVEPOSREQUEST.fields = {}
GETSAVEPOSREQUEST.is_extendable = false
GETSAVEPOSREQUEST.extensions = {}
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.name = "medalSavePos"
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.full_name = ".com.ljsd.jieling.protocols.GetSavePosReponse.medalSavePos"
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.number = 1
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.index = 0
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.label = 3
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.has_default_value = false
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.default_value = {}
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.message_type = MEDALSAVEPOS
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.type = 11
GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD.cpp_type = 10

GETSAVEPOSREPONSE.name = "GetSavePosReponse"
GETSAVEPOSREPONSE.full_name = ".com.ljsd.jieling.protocols.GetSavePosReponse"
GETSAVEPOSREPONSE.nested_types = {}
GETSAVEPOSREPONSE.enum_types = {}
GETSAVEPOSREPONSE.fields = {GETSAVEPOSREPONSE_MEDALSAVEPOS_FIELD}
GETSAVEPOSREPONSE.is_extendable = false
GETSAVEPOSREPONSE.extensions = {}
SETNAMEREQUEST_POS_FIELD.name = "pos"
SETNAMEREQUEST_POS_FIELD.full_name = ".com.ljsd.jieling.protocols.SetNameRequest.pos"
SETNAMEREQUEST_POS_FIELD.number = 1
SETNAMEREQUEST_POS_FIELD.index = 0
SETNAMEREQUEST_POS_FIELD.label = 1
SETNAMEREQUEST_POS_FIELD.has_default_value = false
SETNAMEREQUEST_POS_FIELD.default_value = 0
SETNAMEREQUEST_POS_FIELD.type = 5
SETNAMEREQUEST_POS_FIELD.cpp_type = 1

SETNAMEREQUEST_NAME_FIELD.name = "name"
SETNAMEREQUEST_NAME_FIELD.full_name = ".com.ljsd.jieling.protocols.SetNameRequest.name"
SETNAMEREQUEST_NAME_FIELD.number = 2
SETNAMEREQUEST_NAME_FIELD.index = 1
SETNAMEREQUEST_NAME_FIELD.label = 1
SETNAMEREQUEST_NAME_FIELD.has_default_value = false
SETNAMEREQUEST_NAME_FIELD.default_value = ""
SETNAMEREQUEST_NAME_FIELD.type = 9
SETNAMEREQUEST_NAME_FIELD.cpp_type = 9

SETNAMEREQUEST.name = "SetNameRequest"
SETNAMEREQUEST.full_name = ".com.ljsd.jieling.protocols.SetNameRequest"
SETNAMEREQUEST.nested_types = {}
SETNAMEREQUEST.enum_types = {}
SETNAMEREQUEST.fields = {SETNAMEREQUEST_POS_FIELD, SETNAMEREQUEST_NAME_FIELD}
SETNAMEREQUEST.is_extendable = false
SETNAMEREQUEST.extensions = {}
MEDALUNLOAD2REQUEST_HEROID_FIELD.name = "heroId"
MEDALUNLOAD2REQUEST_HEROID_FIELD.full_name = ".com.ljsd.jieling.protocols.MedalUnload2Request.heroId"
MEDALUNLOAD2REQUEST_HEROID_FIELD.number = 1
MEDALUNLOAD2REQUEST_HEROID_FIELD.index = 0
MEDALUNLOAD2REQUEST_HEROID_FIELD.label = 1
MEDALUNLOAD2REQUEST_HEROID_FIELD.has_default_value = false
MEDALUNLOAD2REQUEST_HEROID_FIELD.default_value = ""
MEDALUNLOAD2REQUEST_HEROID_FIELD.type = 9
MEDALUNLOAD2REQUEST_HEROID_FIELD.cpp_type = 9

MEDALUNLOAD2REQUEST.name = "MedalUnload2Request"
MEDALUNLOAD2REQUEST.full_name = ".com.ljsd.jieling.protocols.MedalUnload2Request"
MEDALUNLOAD2REQUEST.nested_types = {}
MEDALUNLOAD2REQUEST.enum_types = {}
MEDALUNLOAD2REQUEST.fields = {MEDALUNLOAD2REQUEST_HEROID_FIELD}
MEDALUNLOAD2REQUEST.is_extendable = false
MEDALUNLOAD2REQUEST.extensions = {}

BuySavePosRequest = protobuf.Message(BUYSAVEPOSREQUEST)
GetSavePosReponse = protobuf.Message(GETSAVEPOSREPONSE)
GetSavePosRequest = protobuf.Message(GETSAVEPOSREQUEST)
MedalChangeRequest = protobuf.Message(MEDALCHANGEREQUEST)
MedalGetAllReponse = protobuf.Message(MEDALGETALLREPONSE)
MedalGetAllRequest = protobuf.Message(MEDALGETALLREQUEST)
MedalGetOneReponse = protobuf.Message(MEDALGETONEREPONSE)
MedalHeroInfoReponse = protobuf.Message(MEDALHEROINFOREPONSE)
MedalMergeRequest = protobuf.Message(MEDALMERGEREQUEST)
MedalRefineConfirmRequest = protobuf.Message(MEDALREFINECONFIRMREQUEST)
MedalRefineRequest = protobuf.Message(MEDALREFINEREQUEST)
MedalRefineResponse = protobuf.Message(MEDALREFINERESPONSE)
MedalRefineTempPropertyRequest = protobuf.Message(MEDALREFINETEMPPROPERTYREQUEST)
MedalRefineTempPropertyResponse = protobuf.Message(MEDALREFINETEMPPROPERTYRESPONSE)
MedalSavePos = protobuf.Message(MEDALSAVEPOS)
MedalSellRequest = protobuf.Message(MEDALSELLREQUEST)
MedalSellResponse = protobuf.Message(MEDALSELLRESPONSE)
MedalUnload2Request = protobuf.Message(MEDALUNLOAD2REQUEST)
MedalUnloadRequest = protobuf.Message(MEDALUNLOADREQUEST)
MedalUnloadResponse = protobuf.Message(MEDALUNLOADRESPONSE)
MedalWearRequest = protobuf.Message(MEDALWEARREQUEST)
SetNameRequest = protobuf.Message(SETNAMEREQUEST)
UseSavePosRequest = protobuf.Message(USESAVEPOSREQUEST)
WearSavePosRequest = protobuf.Message(WEARSAVEPOSREQUEST)

