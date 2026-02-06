// This is a generated file - do not edit.
//
// Generated from sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class EncryptedData extends $pb.GeneratedMessage {
  factory EncryptedData({
    $core.List<$core.int>? iv,
    $core.List<$core.int>? authTag,
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (iv != null) result.iv = iv;
    if (authTag != null) result.authTag = authTag;
    if (data != null) result.data = data;
    return result;
  }

  EncryptedData._();

  factory EncryptedData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EncryptedData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EncryptedData',
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'iv', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'authTag', $pb.PbFieldType.OY,
        protoName: 'authTag')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EncryptedData copyWith(void Function(EncryptedData) updates) =>
      super.copyWith((message) => updates(message as EncryptedData))
          as EncryptedData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EncryptedData create() => EncryptedData._();
  @$core.override
  EncryptedData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EncryptedData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EncryptedData>(create);
  static EncryptedData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get iv => $_getN(0);
  @$pb.TagNumber(1)
  set iv($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIv() => $_has(0);
  @$pb.TagNumber(1)
  void clearIv() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get authTag => $_getN(1);
  @$pb.TagNumber(2)
  set authTag($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthTag() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthTag() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get data => $_getN(2);
  @$pb.TagNumber(3)
  set data($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasData() => $_has(2);
  @$pb.TagNumber(3)
  void clearData() => $_clearField(3);
}

class Message extends $pb.GeneratedMessage {
  factory Message({
    $core.String? dataset,
    $core.String? row,
    $core.String? column,
    $core.String? value,
  }) {
    final result = create();
    if (dataset != null) result.dataset = dataset;
    if (row != null) result.row = row;
    if (column != null) result.column = column;
    if (value != null) result.value = value;
    return result;
  }

  Message._();

  factory Message.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Message.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Message',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dataset')
    ..aOS(2, _omitFieldNames ? '' : 'row')
    ..aOS(3, _omitFieldNames ? '' : 'column')
    ..aOS(4, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Message copyWith(void Function(Message) updates) =>
      super.copyWith((message) => updates(message as Message)) as Message;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Message create() => Message._();
  @$core.override
  Message createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Message getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Message>(create);
  static Message? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dataset => $_getSZ(0);
  @$pb.TagNumber(1)
  set dataset($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDataset() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataset() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get row => $_getSZ(1);
  @$pb.TagNumber(2)
  set row($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRow() => $_has(1);
  @$pb.TagNumber(2)
  void clearRow() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get column => $_getSZ(2);
  @$pb.TagNumber(3)
  set column($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasColumn() => $_has(2);
  @$pb.TagNumber(3)
  void clearColumn() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get value => $_getSZ(3);
  @$pb.TagNumber(4)
  set value($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearValue() => $_clearField(4);
}

class MessageEnvelope extends $pb.GeneratedMessage {
  factory MessageEnvelope({
    $core.String? timestamp,
    $core.bool? isEncrypted,
    $core.List<$core.int>? content,
  }) {
    final result = create();
    if (timestamp != null) result.timestamp = timestamp;
    if (isEncrypted != null) result.isEncrypted = isEncrypted;
    if (content != null) result.content = content;
    return result;
  }

  MessageEnvelope._();

  factory MessageEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageEnvelope',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'timestamp')
    ..aOB(2, _omitFieldNames ? '' : 'isEncrypted', protoName: 'isEncrypted')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'content', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageEnvelope copyWith(void Function(MessageEnvelope) updates) =>
      super.copyWith((message) => updates(message as MessageEnvelope))
          as MessageEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageEnvelope create() => MessageEnvelope._();
  @$core.override
  MessageEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageEnvelope>(create);
  static MessageEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get timestamp => $_getSZ(0);
  @$pb.TagNumber(1)
  set timestamp($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTimestamp() => $_has(0);
  @$pb.TagNumber(1)
  void clearTimestamp() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isEncrypted => $_getBF(1);
  @$pb.TagNumber(2)
  set isEncrypted($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsEncrypted() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsEncrypted() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get content => $_getN(2);
  @$pb.TagNumber(3)
  set content($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);
}

class SyncRequest extends $pb.GeneratedMessage {
  factory SyncRequest({
    $core.Iterable<MessageEnvelope>? messages,
    $core.String? fileId,
    $core.String? groupId,
    $core.String? keyId,
    $core.String? since,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    if (fileId != null) result.fileId = fileId;
    if (groupId != null) result.groupId = groupId;
    if (keyId != null) result.keyId = keyId;
    if (since != null) result.since = since;
    return result;
  }

  SyncRequest._();

  factory SyncRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncRequest',
      createEmptyInstance: create)
    ..pPM<MessageEnvelope>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: MessageEnvelope.create)
    ..aOS(2, _omitFieldNames ? '' : 'fileId', protoName: 'fileId')
    ..aOS(3, _omitFieldNames ? '' : 'groupId', protoName: 'groupId')
    ..aOS(5, _omitFieldNames ? '' : 'keyId', protoName: 'keyId')
    ..aOS(6, _omitFieldNames ? '' : 'since')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncRequest copyWith(void Function(SyncRequest) updates) =>
      super.copyWith((message) => updates(message as SyncRequest))
          as SyncRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncRequest create() => SyncRequest._();
  @$core.override
  SyncRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncRequest>(create);
  static SyncRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MessageEnvelope> get messages => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get fileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set fileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearFileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get groupId => $_getSZ(2);
  @$pb.TagNumber(3)
  set groupId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroupId() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroupId() => $_clearField(3);

  @$pb.TagNumber(5)
  $core.String get keyId => $_getSZ(3);
  @$pb.TagNumber(5)
  set keyId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasKeyId() => $_has(3);
  @$pb.TagNumber(5)
  void clearKeyId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get since => $_getSZ(4);
  @$pb.TagNumber(6)
  set since($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasSince() => $_has(4);
  @$pb.TagNumber(6)
  void clearSince() => $_clearField(6);
}

class SyncResponse extends $pb.GeneratedMessage {
  factory SyncResponse({
    $core.Iterable<MessageEnvelope>? messages,
    $core.String? merkle,
  }) {
    final result = create();
    if (messages != null) result.messages.addAll(messages);
    if (merkle != null) result.merkle = merkle;
    return result;
  }

  SyncResponse._();

  factory SyncResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncResponse',
      createEmptyInstance: create)
    ..pPM<MessageEnvelope>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: MessageEnvelope.create)
    ..aOS(2, _omitFieldNames ? '' : 'merkle')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncResponse copyWith(void Function(SyncResponse) updates) =>
      super.copyWith((message) => updates(message as SyncResponse))
          as SyncResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncResponse create() => SyncResponse._();
  @$core.override
  SyncResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncResponse>(create);
  static SyncResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MessageEnvelope> get messages => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get merkle => $_getSZ(1);
  @$pb.TagNumber(2)
  set merkle($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMerkle() => $_has(1);
  @$pb.TagNumber(2)
  void clearMerkle() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
