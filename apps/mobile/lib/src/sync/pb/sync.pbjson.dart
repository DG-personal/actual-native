// This is a generated file - do not edit.
//
// Generated from sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use encryptedDataDescriptor instead')
const EncryptedData$json = {
  '1': 'EncryptedData',
  '2': [
    {'1': 'iv', '3': 1, '4': 1, '5': 12, '10': 'iv'},
    {'1': 'authTag', '3': 2, '4': 1, '5': 12, '10': 'authTag'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `EncryptedData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List encryptedDataDescriptor = $convert.base64Decode(
    'Cg1FbmNyeXB0ZWREYXRhEg4KAml2GAEgASgMUgJpdhIYCgdhdXRoVGFnGAIgASgMUgdhdXRoVG'
    'FnEhIKBGRhdGEYAyABKAxSBGRhdGE=');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'dataset', '3': 1, '4': 1, '5': 9, '10': 'dataset'},
    {'1': 'row', '3': 2, '4': 1, '5': 9, '10': 'row'},
    {'1': 'column', '3': 3, '4': 1, '5': 9, '10': 'column'},
    {'1': 'value', '3': 4, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEhgKB2RhdGFzZXQYASABKAlSB2RhdGFzZXQSEAoDcm93GAIgASgJUgNyb3cSFg'
    'oGY29sdW1uGAMgASgJUgZjb2x1bW4SFAoFdmFsdWUYBCABKAlSBXZhbHVl');

@$core.Deprecated('Use messageEnvelopeDescriptor instead')
const MessageEnvelope$json = {
  '1': 'MessageEnvelope',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 9, '10': 'timestamp'},
    {'1': 'isEncrypted', '3': 2, '4': 1, '5': 8, '10': 'isEncrypted'},
    {'1': 'content', '3': 3, '4': 1, '5': 12, '10': 'content'},
  ],
};

/// Descriptor for `MessageEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageEnvelopeDescriptor = $convert.base64Decode(
    'Cg9NZXNzYWdlRW52ZWxvcGUSHAoJdGltZXN0YW1wGAEgASgJUgl0aW1lc3RhbXASIAoLaXNFbm'
    'NyeXB0ZWQYAiABKAhSC2lzRW5jcnlwdGVkEhgKB2NvbnRlbnQYAyABKAxSB2NvbnRlbnQ=');

@$core.Deprecated('Use syncRequestDescriptor instead')
const SyncRequest$json = {
  '1': 'SyncRequest',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.MessageEnvelope',
      '10': 'messages'
    },
    {'1': 'fileId', '3': 2, '4': 1, '5': 9, '10': 'fileId'},
    {'1': 'groupId', '3': 3, '4': 1, '5': 9, '10': 'groupId'},
    {'1': 'keyId', '3': 5, '4': 1, '5': 9, '10': 'keyId'},
    {'1': 'since', '3': 6, '4': 1, '5': 9, '10': 'since'},
  ],
};

/// Descriptor for `SyncRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncRequestDescriptor = $convert.base64Decode(
    'CgtTeW5jUmVxdWVzdBIsCghtZXNzYWdlcxgBIAMoCzIQLk1lc3NhZ2VFbnZlbG9wZVIIbWVzc2'
    'FnZXMSFgoGZmlsZUlkGAIgASgJUgZmaWxlSWQSGAoHZ3JvdXBJZBgDIAEoCVIHZ3JvdXBJZBIU'
    'CgVrZXlJZBgFIAEoCVIFa2V5SWQSFAoFc2luY2UYBiABKAlSBXNpbmNl');

@$core.Deprecated('Use syncResponseDescriptor instead')
const SyncResponse$json = {
  '1': 'SyncResponse',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.MessageEnvelope',
      '10': 'messages'
    },
    {'1': 'merkle', '3': 2, '4': 1, '5': 9, '10': 'merkle'},
  ],
};

/// Descriptor for `SyncResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncResponseDescriptor = $convert.base64Decode(
    'CgxTeW5jUmVzcG9uc2USLAoIbWVzc2FnZXMYASADKAsyEC5NZXNzYWdlRW52ZWxvcGVSCG1lc3'
    'NhZ2VzEhYKBm1lcmtsZRgCIAEoCVIGbWVya2xl');
