# frozen_string_literal: true

module Wbem
  ERRORS = {
    CIM_ERR_UNKNOWN: 'Unknown error occurred',
    CIM_ERR_FAILED: 'A general error occurred',
    CIM_ERR_ACCESS_DENIED: 'Resource not available',
    CIM_ERR_INVALID_NAMESPACE: 'The target namespace does not exist',
    CIM_ERR_INVALID_PARAMETER: 'Parameter value(s) invalid',
    CIM_ERR_INVALID_CLASS: 'The specified Class does not exist',
    CIM_ERR_NOT_FOUND: 'Requested object could not be found',
    CIM_ERR_NOT_SUPPORTED: 'Operation not supported',
    CIM_ERR_CLASS_HAS_CHILDREN: 'Class has subclasses',
    CIM_ERR_CLASS_HAS_INSTANCES: 'Class has instances',
    CIM_ERR_INVALID_SUPERCLASS: 'Superclass does not exist',
    CIM_ERR_ALREADY_EXISTS: 'Object already exists',
    CIM_ERR_NO_SUCH_PROPERTY: 'Property does not exist',
    CIM_ERR_TYPE_MISMATCH: 'Value incompatible with type',
    CIM_ERR_QUERY_LANGUAGE_NOT_SUPPORTED: 'Query language not supported',
    CIM_ERR_INVALID_QUERY: 'Query not valid',
    CIM_ERR_METHOD_NOT_AVAILABLE: 'Extrinsic method not executed',
    CIM_ERR_METHOD_NOT_FOUND: 'Extrinsic method does not exist',
    CIM_ERR_NAMESPACE_NOT_EMPTY: 'Namespace not empty',
    CIM_ERR_INVALID_ENUMERATION_CONTEXT: 'Enumeration context is invalid',
    CIM_ERR_INVALID_OPERATION_TIMEOUT: 'Operation timeout not supported',
    CIM_ERR_PULL_HAS_BEEN_ABANDONED: 'Pull operation has been abandoned',
    CIM_ERR_PULL_CANNOT_BE_ABANDONED: 'Attempt to abandon a pull operation failed',
    CIM_ERR_FILTERED_ENUMERATION_NOT_SUPPORTED: 'Filtered pulled enumeration not supported',
    CIM_ERR_CONTINUATION_ON_ERROR_NOT_SUPPORTED: 'WBEM server does not support continuation on error',
    CIM_ERR_SERVER_LIMITS_EXCEEDED: 'WBEM server limits exceeded',
    CIM_ERR_SERVER_IS_SHUTTING_DOWN: 'WBEM server is shutting down'
  }.freeze

  DEFAULT_NAMESPACE = 'root/cimv2'
end
