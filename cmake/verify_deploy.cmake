# Deploy output verification.
# Invoked by CTest with:
#   -DDEPLOY_DIR=<path>  -DPROJECT=<name>  -DDOCS_BASE=<base>  -DVERSION=<version>
#   -DDOC_TYPES=<semicolon-separated list, default: cxx;python>

if(NOT DOC_TYPES)
  set(DOC_TYPES "cxx;python")
endif()

foreach(_item
  "${DEPLOY_DIR}/versions"
  "${DEPLOY_DIR}/versions.json"
  "${DEPLOY_DIR}/${PROJECT}-version.js"
)
  if(NOT EXISTS "${_item}")
    message(FATAL_ERROR "Expected path not found: ${_item}")
  endif()
endforeach()

foreach(_dtype IN LISTS DOC_TYPES)
  if(NOT IS_DIRECTORY "${DEPLOY_DIR}/${VERSION}/${_dtype}")
    message(FATAL_ERROR "Expected doc dir not found: ${DEPLOY_DIR}/${VERSION}/${_dtype}")
  endif()
endforeach()

file(READ "${DEPLOY_DIR}/versions" _versions)
if(NOT _versions MATCHES "${VERSION}")
  message(FATAL_ERROR "${VERSION} not found in versions file")
endif()

file(READ "${DEPLOY_DIR}/versions.json" _json)
if(NOT _json MATCHES "${VERSION}")
  message(FATAL_ERROR "${VERSION} not found in versions.json")
endif()

# Verify the JS was built with the correct DOCS_BASE baked in by DefinePlugin
file(READ "${DEPLOY_DIR}/${PROJECT}-version.js" _js)
if(NOT _js MATCHES "${DOCS_BASE}")
  message(FATAL_ERROR "${PROJECT}-version.js does not contain '${DOCS_BASE}'")
endif()

message(STATUS "OK: ${PROJECT} ${VERSION} deploy verified (DOCS_BASE=${DOCS_BASE}, types=${DOC_TYPES})")
