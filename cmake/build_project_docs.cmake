# Generate documentation by running doxygen/sphinx directly on the source tree.
# No project CMake configure or compilation needed.
#
# Parameters (via -D):
#   PROJECT     - project name
#   SOURCE_DIR  - project source tree (doxygen INPUT)
#   STAGING_DIR - STAGING_DIR/doc/cxx (and /python) will hold the output
#   BASE_DIR    - BASE_DIR/data gets the JS, BASE_DIR/work is created
#   JS_SRC      - pre-built ${project}-version.js
#   DOC_TYPES   - |-separated list of doc types to build: cxx, python

cmake_policy(SET CMP0057 NEW) # IN_LIST operator

foreach(_req PROJECT SOURCE_DIR STAGING_DIR BASE_DIR JS_SRC HEADER_HTML)
  if(NOT ${_req})
    message(FATAL_ERROR "build_project_docs.cmake: ${_req} is required")
  endif()
endforeach()

find_program(DOXYGEN_EXECUTABLE doxygen REQUIRED)

string(REPLACE "|" ";" _doc_types "${DOC_TYPES}")
if(NOT _doc_types)
  set(_doc_types cxx)
endif()

# Wipe previous run
file(REMOVE_RECURSE "${STAGING_DIR}" "${BASE_DIR}/data" "${BASE_DIR}/work" "${BASE_DIR}/deploy")
file(MAKE_DIRECTORY "${BASE_DIR}/data" "${BASE_DIR}/work")

# ---------------------------------------------------------------------------
# C++ docs via doxygen
# ---------------------------------------------------------------------------
if("cxx" IN_LIST _doc_types)
  set(_doxy_out "${STAGING_DIR}/doc/cxx")
  file(MAKE_DIRECTORY "${_doxy_out}")

  set(_doxyfile "${BASE_DIR}/doxyfile")
  file(WRITE "${_doxyfile}"
"PROJECT_NAME      = ${PROJECT}
INPUT             = ${SOURCE_DIR}
RECURSIVE         = YES
GENERATE_HTML     = YES
GENERATE_LATEX    = NO
HTML_HEADER       = ${HEADER_HTML}
HTML_OUTPUT       = .
OUTPUT_DIRECTORY  = ${_doxy_out}
QUIET             = YES
WARNINGS          = YES
FILE_PATTERNS     = *.h *.hxx *.hpp *.cxx *.cpp
EXCLUDE_PATTERNS  = */Testing/* */ThirdParty/* */.git/*
")

  message(STATUS "[${PROJECT}] Running doxygen on ${SOURCE_DIR}")
  execute_process(
    COMMAND ${DOXYGEN_EXECUTABLE} "${_doxyfile}"
    WORKING_DIRECTORY "${SOURCE_DIR}"
    RESULT_VARIABLE _rc
  )
  if(_rc)
    message(FATAL_ERROR "[${PROJECT}] doxygen failed (exit ${_rc})")
  endif()
endif()

# ---------------------------------------------------------------------------
# Python docs via sphinx-build
# ---------------------------------------------------------------------------
if("python" IN_LIST _doc_types)
  find_program(SPHINX_EXECUTABLE sphinx-build REQUIRED)

  # Locate the sphinx conf.py — projects keep it under Utilities/Sphinx/config
  # or docs/. Walk up a few candidate locations.
  foreach(_candidate
    "${SOURCE_DIR}/Utilities/Sphinx/config"
    "${SOURCE_DIR}/Utilities/Sphinx"
    "${SOURCE_DIR}/docs"
    "${SOURCE_DIR}/doc"
  )
    if(EXISTS "${_candidate}/conf.py")
      set(_sphinx_src "${_candidate}")
      break()
    endif()
  endforeach()

  if(NOT _sphinx_src)
    message(FATAL_ERROR "[${PROJECT}] Could not find sphinx conf.py under ${SOURCE_DIR}")
  endif()

  set(_sphinx_out "${STAGING_DIR}/doc/python")
  file(MAKE_DIRECTORY "${_sphinx_out}")

  message(STATUS "[${PROJECT}] Running sphinx-build from ${_sphinx_src}")
  execute_process(
    COMMAND ${SPHINX_EXECUTABLE} -b html "${_sphinx_src}" "${_sphinx_out}"
    RESULT_VARIABLE _rc
  )
  if(_rc)
    message(FATAL_ERROR "[${PROJECT}] sphinx-build failed (exit ${_rc})")
  endif()
endif()

# ---------------------------------------------------------------------------
# Provide the JS file in the data dir
# ---------------------------------------------------------------------------
file(COPY "${JS_SRC}" DESTINATION "${BASE_DIR}/data")

message(STATUS "[${PROJECT}] Fixture ready at ${BASE_DIR}")
