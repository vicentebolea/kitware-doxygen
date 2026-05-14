cmake_minimum_required(VERSION 3.15)
project(kitware-doxygen NONE)

set(CMAKE_INSTALL_LIBDIR "lib" CACHE PATH "Object code libraries")
include(GNUInstallDirs)

find_program(NPM_EXECUTABLE npm REQUIRED)

set(KDOCS_PROJECT   "paraview"              CACHE STRING "Project name (e.g. paraview, vtk)")
set(KDOCS_DOCS_BASE "${KDOCS_PROJECT}-docs" CACHE STRING "URL base path for the docs site")
set(KDOCS_LOGO      "${KDOCS_PROJECT}-logo.png" CACHE STRING "Logo filename in the doxygen header")

# ---------------------------------------------------------------------------
# Generate header.html from template (@ONLY so doxygen $variables are intact)
# ---------------------------------------------------------------------------
set(PROJECT   "${KDOCS_PROJECT}")
set(DOCS_BASE "${KDOCS_DOCS_BASE}")
set(LOGO      "${KDOCS_LOGO}")
configure_file(Templates/header.html.in ${CMAKE_CURRENT_BINARY_DIR}/header.html @ONLY)

# ---------------------------------------------------------------------------
# Configure the upload script with the installed data directory
# ---------------------------------------------------------------------------
configure_file(Scripts/docs_uploader.in ${CMAKE_CURRENT_BINARY_DIR}/docs_uploader @ONLY)

# ---------------------------------------------------------------------------
# npm install (stamp tracks package.json changes)
# ---------------------------------------------------------------------------
add_custom_command(
  OUTPUT  ${CMAKE_CURRENT_BINARY_DIR}/node_modules_stamp
  COMMAND ${NPM_EXECUTABLE} install
  COMMAND ${CMAKE_COMMAND} -E touch ${CMAKE_CURRENT_BINARY_DIR}/node_modules_stamp
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS   ${CMAKE_CURRENT_SOURCE_DIR}/package.json
  COMMENT   "Installing npm dependencies"
)

# ---------------------------------------------------------------------------
# Build one $project-version.js with its DOCS_BASE baked in by DefinePlugin.
# A global-property guard prevents duplicate custom commands when the same
# project is requested by both the main build and a test.
# ---------------------------------------------------------------------------
function(kdocs_build_js project docs_base)
  get_property(_done GLOBAL PROPERTY _kdocs_built_${project})
  if(_done)
    return()
  endif()
  set_property(GLOBAL PROPERTY _kdocs_built_${project} TRUE)

  add_custom_command(
    OUTPUT  ${CMAKE_CURRENT_BINARY_DIR}/${project}-version.js
    COMMAND ${CMAKE_COMMAND} -E env
              PROJECT=${project}
              DOCS_BASE=${docs_base}
              OUTPUT_DIR=${CMAKE_CURRENT_BINARY_DIR}
            ${NPM_EXECUTABLE} run build:release
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS
      ${CMAKE_CURRENT_BINARY_DIR}/node_modules_stamp
      ${CMAKE_CURRENT_SOURCE_DIR}/webpack.config.js
      ${CMAKE_CURRENT_SOURCE_DIR}/Src/selector.js
      ${CMAKE_CURRENT_SOURCE_DIR}/Src/style.css
      ${CMAKE_CURRENT_SOURCE_DIR}/Assets/cpp.png
      ${CMAKE_CURRENT_SOURCE_DIR}/Assets/python.png
    COMMENT "Building ${project}-version.js (DOCS_BASE=${docs_base})"
  )
  add_custom_target(kdocs_js_${project} ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${project}-version.js
  )
endfunction()

# Main installable JS
kdocs_build_js(${KDOCS_PROJECT} ${KDOCS_DOCS_BASE})

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/${KDOCS_PROJECT}-version.js
  DESTINATION ${CMAKE_INSTALL_DATADIR}/kitware-doxygen
)
install(
  FILES
    ${CMAKE_CURRENT_BINARY_DIR}/header.html
    ${CMAKE_CURRENT_SOURCE_DIR}/Templates/footer.html
  DESTINATION ${CMAKE_INSTALL_DATADIR}/kitware-doxygen/Templates
)
install(
  PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/docs_uploader
  DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
enable_testing()

# Unit tests: mock doc dirs, verify the deploy script logic end-to-end.
# Chain: setup → deploy → verify via CTest fixtures.
# kdocs_build_js per project ensures each JS has its own baked-in DOCS_BASE.
function(kdocs_add_deploy_test project docs_base version)
  kdocs_build_js(${project} ${docs_base})

  set(_base ${CMAKE_CURRENT_BINARY_DIR}/test/${project})

  add_test(NAME ${project}_deploy_setup
    COMMAND ${CMAKE_COMMAND}
      -DPROJECT=${project}
      -DBASE_DIR=${_base}
      -DJS_SRC=${CMAKE_CURRENT_BINARY_DIR}/${project}-version.js
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/setup_test.cmake
  )
  set_tests_properties(${project}_deploy_setup PROPERTIES
    FIXTURES_SETUP ${project}_dirs
  )

  add_test(NAME ${project}_deploy
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/docs_uploader
      -p ${project}
      -U https://www.${project}.org/${docs_base}
      -s ${_base}/src
      -b ${_base}/build
      -w ${_base}/work
      -d ${_base}/deploy
      -v ${version}
  )
  set_tests_properties(${project}_deploy PROPERTIES
    FIXTURES_REQUIRED ${project}_dirs
    FIXTURES_SETUP    ${project}_deployed
    ENVIRONMENT       "KDOCS_DATA_DIR=${_base}/data"
  )

  add_test(NAME ${project}_deploy_verify
    COMMAND ${CMAKE_COMMAND}
      -DDEPLOY_DIR=${_base}/deploy
      -DPROJECT=${project}
      -DDOCS_BASE=${docs_base}
      -DVERSION=${version}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/verify_deploy.cmake
  )
  set_tests_properties(${project}_deploy_verify PROPERTIES
    FIXTURES_REQUIRED ${project}_deployed
  )
endfunction()

kdocs_add_deploy_test(paraview paraview-docs v5.12.0)
kdocs_add_deploy_test(vtk      vtk-docs      v9.4.0)

# ---------------------------------------------------------------------------
# Integration tests (optional): build real doxygen then run the deploy script.
#
# Enable by pointing at actual project source trees:
#   cmake -DKDOCS_PARAVIEW_SOURCE_DIR=/path/to/paraview ...
#   cmake -DKDOCS_VTK_SOURCE_DIR=/path/to/vtk ...
#
# Run with: ctest -L integration
# ---------------------------------------------------------------------------
set(KDOCS_PARAVIEW_SOURCE_DIR "" CACHE PATH "ParaView source tree for integration test")
set(KDOCS_VTK_SOURCE_DIR      "" CACHE PATH "VTK source tree for integration test")

# project    - name
# source_dir - source tree (empty → test is skipped)
# doc_types  - |-separated list of doc types to build: cxx, python
# version    - version string passed to -v
function(kdocs_add_integration_test project source_dir doc_types version)
  if(NOT source_dir)
    return()
  endif()

  kdocs_build_js(${project} ${project}-docs)

  set(_base    ${CMAKE_CURRENT_BINARY_DIR}/itest/${project})
  set(_staging ${_base}/staging)

  # Setup: run doxygen/sphinx directly on the source tree — no project build needed
  add_test(NAME ${project}_integration_setup
    COMMAND ${CMAKE_COMMAND}
      -DPROJECT=${project}
      -DSOURCE_DIR=${source_dir}
      -DSTAGING_DIR=${_staging}
      -DBASE_DIR=${_base}
      "-DDOC_TYPES=${doc_types}"
      -DJS_SRC=${CMAKE_CURRENT_BINARY_DIR}/${project}-version.js
      -DHEADER_HTML=${CMAKE_CURRENT_BINARY_DIR}/header.html
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/build_project_docs.cmake
  )
  set_tests_properties(${project}_integration_setup PROPERTIES
    FIXTURES_SETUP ${project}_idirs
    TIMEOUT        3600
    LABELS         integration
  )

  # Expand |-separated doc_types to space-separated for -t argument
  string(REPLACE "|" " " _doc_types_arg "${doc_types}")

  add_test(NAME ${project}_integration_deploy
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/docs_uploader
      -p ${project}
      -U https://www.${project}.org/${project}-docs
      -s ${source_dir}
      -b ${_staging}
      -w ${_base}/work
      -d ${_base}/deploy
      -v ${version}
      -t "${_doc_types_arg}"
  )
  set_tests_properties(${project}_integration_deploy PROPERTIES
    FIXTURES_REQUIRED ${project}_idirs
    FIXTURES_SETUP    ${project}_ideployed
    ENVIRONMENT       "KDOCS_DATA_DIR=${_base}/data"
    TIMEOUT           300
    LABELS            integration
  )

  # Pass doc_types as semicolon list for verify script
  string(REPLACE "|" ";" _doc_types_list "${doc_types}")
  add_test(NAME ${project}_integration_verify
    COMMAND ${CMAKE_COMMAND}
      -DDEPLOY_DIR=${_base}/deploy
      -DPROJECT=${project}
      -DDOCS_BASE=${project}-docs
      -DVERSION=${version}
      "-DDOC_TYPES=${_doc_types_list}"
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/verify_deploy.cmake
  )
  set_tests_properties(${project}_integration_verify PROPERTIES
    FIXTURES_REQUIRED ${project}_ideployed
    LABELS            integration
  )
endfunction()

kdocs_add_integration_test(vtk      "${KDOCS_VTK_SOURCE_DIR}"     "cxx" v9.6.2)
kdocs_add_integration_test(paraview "${KDOCS_PARAVIEW_SOURCE_DIR}" "cxx" v6.0.1)
