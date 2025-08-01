-- Generated By protoc-gen-lua Do not Edit
local protobuf = require "protobuf/protobuf"
local CommonProto_pb = require("CommonProto_pb")
local ChatProto_pb = require("ChatProto_pb")
module('gtcprotos/WorldChatProto_pb')


REGGAMEINFOREQUEST = protobuf.Descriptor();
REGGAMEINFOREQUEST_SERVERID_FIELD = protobuf.FieldDescriptor();
REGGAMEINFOREQUEST_SERVERINFO_FIELD = protobuf.FieldDescriptor();
DELGAMEINFOREQUEST = protobuf.Descriptor();
DELGAMEINFOREQUEST_SERVERID_FIELD = protobuf.FieldDescriptor();
REGGAMEINFORESPONSE = protobuf.Descriptor();
REGGAMEINFORESPONSE_IP_FIELD = protobuf.FieldDescriptor();
REGGAMEINFORESPONSE_PORT_FIELD = protobuf.FieldDescriptor();
REGGAMEINFORESPONSE_GROUP_FIELD = protobuf.FieldDescriptor();
GETWORLDCHATMESSAGEINFOREQUEST = protobuf.Descriptor();
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD = protobuf.FieldDescriptor();
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD = protobuf.FieldDescriptor();
GETWORLDCHATMESSAGEINFORESPONSE = protobuf.Descriptor();
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD = protobuf.FieldDescriptor();
SENDWORLDCHATINFOREQUEST = protobuf.Descriptor();
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD = protobuf.FieldDescriptor();
SENDWORLDCHATINFORESPONSE = protobuf.Descriptor();
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD = protobuf.FieldDescriptor();
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD = protobuf.FieldDescriptor();
CHATSENDSTATUS = protobuf.Descriptor();
CHATSENDSTATUS_STATUS_FIELD = protobuf.FieldDescriptor();

REGGAMEINFOREQUEST_SERVERID_FIELD.name = "serverID"
REGGAMEINFOREQUEST_SERVERID_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoRequest.serverID"
REGGAMEINFOREQUEST_SERVERID_FIELD.number = 1
REGGAMEINFOREQUEST_SERVERID_FIELD.index = 0
REGGAMEINFOREQUEST_SERVERID_FIELD.label = 1
REGGAMEINFOREQUEST_SERVERID_FIELD.has_default_value = false
REGGAMEINFOREQUEST_SERVERID_FIELD.default_value = 0
REGGAMEINFOREQUEST_SERVERID_FIELD.type = 5
REGGAMEINFOREQUEST_SERVERID_FIELD.cpp_type = 1

REGGAMEINFOREQUEST_SERVERINFO_FIELD.name = "serverInfo"
REGGAMEINFOREQUEST_SERVERINFO_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoRequest.serverInfo"
REGGAMEINFOREQUEST_SERVERINFO_FIELD.number = 2
REGGAMEINFOREQUEST_SERVERINFO_FIELD.index = 1
REGGAMEINFOREQUEST_SERVERINFO_FIELD.label = 1
REGGAMEINFOREQUEST_SERVERINFO_FIELD.has_default_value = false
REGGAMEINFOREQUEST_SERVERINFO_FIELD.default_value = ""
REGGAMEINFOREQUEST_SERVERINFO_FIELD.type = 9
REGGAMEINFOREQUEST_SERVERINFO_FIELD.cpp_type = 9

REGGAMEINFOREQUEST.name = "RegGameInfoRequest"
REGGAMEINFOREQUEST.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoRequest"
REGGAMEINFOREQUEST.nested_types = {}
REGGAMEINFOREQUEST.enum_types = {}
REGGAMEINFOREQUEST.fields = {REGGAMEINFOREQUEST_SERVERID_FIELD, REGGAMEINFOREQUEST_SERVERINFO_FIELD}
REGGAMEINFOREQUEST.is_extendable = false
REGGAMEINFOREQUEST.extensions = {}
DELGAMEINFOREQUEST_SERVERID_FIELD.name = "serverID"
DELGAMEINFOREQUEST_SERVERID_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.DelGameInfoRequest.serverID"
DELGAMEINFOREQUEST_SERVERID_FIELD.number = 1
DELGAMEINFOREQUEST_SERVERID_FIELD.index = 0
DELGAMEINFOREQUEST_SERVERID_FIELD.label = 1
DELGAMEINFOREQUEST_SERVERID_FIELD.has_default_value = false
DELGAMEINFOREQUEST_SERVERID_FIELD.default_value = 0
DELGAMEINFOREQUEST_SERVERID_FIELD.type = 5
DELGAMEINFOREQUEST_SERVERID_FIELD.cpp_type = 1

DELGAMEINFOREQUEST.name = "DelGameInfoRequest"
DELGAMEINFOREQUEST.full_name = ".com.ljsd.jieling.protocols.worldchat.DelGameInfoRequest"
DELGAMEINFOREQUEST.nested_types = {}
DELGAMEINFOREQUEST.enum_types = {}
DELGAMEINFOREQUEST.fields = {DELGAMEINFOREQUEST_SERVERID_FIELD}
DELGAMEINFOREQUEST.is_extendable = false
DELGAMEINFOREQUEST.extensions = {}
REGGAMEINFORESPONSE_IP_FIELD.name = "ip"
REGGAMEINFORESPONSE_IP_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoResponse.ip"
REGGAMEINFORESPONSE_IP_FIELD.number = 1
REGGAMEINFORESPONSE_IP_FIELD.index = 0
REGGAMEINFORESPONSE_IP_FIELD.label = 1
REGGAMEINFORESPONSE_IP_FIELD.has_default_value = false
REGGAMEINFORESPONSE_IP_FIELD.default_value = ""
REGGAMEINFORESPONSE_IP_FIELD.type = 9
REGGAMEINFORESPONSE_IP_FIELD.cpp_type = 9

REGGAMEINFORESPONSE_PORT_FIELD.name = "port"
REGGAMEINFORESPONSE_PORT_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoResponse.port"
REGGAMEINFORESPONSE_PORT_FIELD.number = 2
REGGAMEINFORESPONSE_PORT_FIELD.index = 1
REGGAMEINFORESPONSE_PORT_FIELD.label = 1
REGGAMEINFORESPONSE_PORT_FIELD.has_default_value = false
REGGAMEINFORESPONSE_PORT_FIELD.default_value = ""
REGGAMEINFORESPONSE_PORT_FIELD.type = 9
REGGAMEINFORESPONSE_PORT_FIELD.cpp_type = 9

REGGAMEINFORESPONSE_GROUP_FIELD.name = "group"
REGGAMEINFORESPONSE_GROUP_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoResponse.group"
REGGAMEINFORESPONSE_GROUP_FIELD.number = 3
REGGAMEINFORESPONSE_GROUP_FIELD.index = 2
REGGAMEINFORESPONSE_GROUP_FIELD.label = 1
REGGAMEINFORESPONSE_GROUP_FIELD.has_default_value = false
REGGAMEINFORESPONSE_GROUP_FIELD.default_value = 0
REGGAMEINFORESPONSE_GROUP_FIELD.type = 5
REGGAMEINFORESPONSE_GROUP_FIELD.cpp_type = 1

REGGAMEINFORESPONSE.name = "RegGameInfoResponse"
REGGAMEINFORESPONSE.full_name = ".com.ljsd.jieling.protocols.worldchat.RegGameInfoResponse"
REGGAMEINFORESPONSE.nested_types = {}
REGGAMEINFORESPONSE.enum_types = {}
REGGAMEINFORESPONSE.fields = {REGGAMEINFORESPONSE_IP_FIELD, REGGAMEINFORESPONSE_PORT_FIELD, REGGAMEINFORESPONSE_GROUP_FIELD}
REGGAMEINFORESPONSE.is_extendable = false
REGGAMEINFORESPONSE.extensions = {}
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.name = "chatType"
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.GetWorldChatMessageInfoRequest.chatType"
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.number = 1
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.index = 0
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.label = 1
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.has_default_value = false
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.default_value = 0
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.type = 5
GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD.cpp_type = 1

GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.name = "messageId"
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.GetWorldChatMessageInfoRequest.messageId"
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.number = 2
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.index = 1
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.label = 1
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.has_default_value = false
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.default_value = 0
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.type = 4
GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD.cpp_type = 4

GETWORLDCHATMESSAGEINFOREQUEST.name = "GetWorldChatMessageInfoRequest"
GETWORLDCHATMESSAGEINFOREQUEST.full_name = ".com.ljsd.jieling.protocols.worldchat.GetWorldChatMessageInfoRequest"
GETWORLDCHATMESSAGEINFOREQUEST.nested_types = {}
GETWORLDCHATMESSAGEINFOREQUEST.enum_types = {}
GETWORLDCHATMESSAGEINFOREQUEST.fields = {GETWORLDCHATMESSAGEINFOREQUEST_CHATTYPE_FIELD, GETWORLDCHATMESSAGEINFOREQUEST_MESSAGEID_FIELD}
GETWORLDCHATMESSAGEINFOREQUEST.is_extendable = false
GETWORLDCHATMESSAGEINFOREQUEST.extensions = {}
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.name = "chatInfo"
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.GetWorldChatMessageInfoResponse.chatInfo"
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.number = 1
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.index = 0
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.label = 3
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.has_default_value = false
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.default_value = {}
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.message_type = ChatProto_pb.CHATINFO
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.type = 11
GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD.cpp_type = 10

GETWORLDCHATMESSAGEINFORESPONSE.name = "GetWorldChatMessageInfoResponse"
GETWORLDCHATMESSAGEINFORESPONSE.full_name = ".com.ljsd.jieling.protocols.worldchat.GetWorldChatMessageInfoResponse"
GETWORLDCHATMESSAGEINFORESPONSE.nested_types = {}
GETWORLDCHATMESSAGEINFORESPONSE.enum_types = {}
GETWORLDCHATMESSAGEINFORESPONSE.fields = {GETWORLDCHATMESSAGEINFORESPONSE_CHATINFO_FIELD}
GETWORLDCHATMESSAGEINFORESPONSE.is_extendable = false
GETWORLDCHATMESSAGEINFORESPONSE.extensions = {}
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.name = "chatInfo"
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.SendWorldChatInfoRequest.chatInfo"
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.number = 1
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.index = 0
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.label = 1
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.has_default_value = false
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.default_value = nil
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.message_type = ChatProto_pb.CHATINFO
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.type = 11
SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD.cpp_type = 10

SENDWORLDCHATINFOREQUEST.name = "SendWorldChatInfoRequest"
SENDWORLDCHATINFOREQUEST.full_name = ".com.ljsd.jieling.protocols.worldchat.SendWorldChatInfoRequest"
SENDWORLDCHATINFOREQUEST.nested_types = {}
SENDWORLDCHATINFOREQUEST.enum_types = {}
SENDWORLDCHATINFOREQUEST.fields = {SENDWORLDCHATINFOREQUEST_CHATINFO_FIELD}
SENDWORLDCHATINFOREQUEST.is_extendable = false
SENDWORLDCHATINFOREQUEST.extensions = {}
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.name = "chatInfo"
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.SendWorldChatInfoResponse.chatInfo"
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.number = 1
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.index = 0
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.label = 1
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.has_default_value = false
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.default_value = nil
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.message_type = ChatProto_pb.CHATINFO
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.type = 11
SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD.cpp_type = 10

SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.name = "messageId"
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.SendWorldChatInfoResponse.messageId"
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.number = 2
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.index = 1
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.label = 1
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.has_default_value = false
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.default_value = 0
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.type = 3
SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD.cpp_type = 2

SENDWORLDCHATINFORESPONSE.name = "SendWorldChatInfoResponse"
SENDWORLDCHATINFORESPONSE.full_name = ".com.ljsd.jieling.protocols.worldchat.SendWorldChatInfoResponse"
SENDWORLDCHATINFORESPONSE.nested_types = {}
SENDWORLDCHATINFORESPONSE.enum_types = {}
SENDWORLDCHATINFORESPONSE.fields = {SENDWORLDCHATINFORESPONSE_CHATINFO_FIELD, SENDWORLDCHATINFORESPONSE_MESSAGEID_FIELD}
SENDWORLDCHATINFORESPONSE.is_extendable = false
SENDWORLDCHATINFORESPONSE.extensions = {}
CHATSENDSTATUS_STATUS_FIELD.name = "status"
CHATSENDSTATUS_STATUS_FIELD.full_name = ".com.ljsd.jieling.protocols.worldchat.ChatSendStatus.status"
CHATSENDSTATUS_STATUS_FIELD.number = 1
CHATSENDSTATUS_STATUS_FIELD.index = 0
CHATSENDSTATUS_STATUS_FIELD.label = 1
CHATSENDSTATUS_STATUS_FIELD.has_default_value = false
CHATSENDSTATUS_STATUS_FIELD.default_value = 0
CHATSENDSTATUS_STATUS_FIELD.type = 5
CHATSENDSTATUS_STATUS_FIELD.cpp_type = 1

CHATSENDSTATUS.name = "ChatSendStatus"
CHATSENDSTATUS.full_name = ".com.ljsd.jieling.protocols.worldchat.ChatSendStatus"
CHATSENDSTATUS.nested_types = {}
CHATSENDSTATUS.enum_types = {}
CHATSENDSTATUS.fields = {CHATSENDSTATUS_STATUS_FIELD}
CHATSENDSTATUS.is_extendable = false
CHATSENDSTATUS.extensions = {}

ChatSendStatus = protobuf.Message(CHATSENDSTATUS)
DelGameInfoRequest = protobuf.Message(DELGAMEINFOREQUEST)
GetWorldChatMessageInfoRequest = protobuf.Message(GETWORLDCHATMESSAGEINFOREQUEST)
GetWorldChatMessageInfoResponse = protobuf.Message(GETWORLDCHATMESSAGEINFORESPONSE)
RegGameInfoRequest = protobuf.Message(REGGAMEINFOREQUEST)
RegGameInfoResponse = protobuf.Message(REGGAMEINFORESPONSE)
SendWorldChatInfoRequest = protobuf.Message(SENDWORLDCHATINFOREQUEST)
SendWorldChatInfoResponse = protobuf.Message(SENDWORLDCHATINFORESPONSE)

