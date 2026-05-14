# Test fixture setup.
# Invoked by CTest with:
#   -DPROJECT=<name>  -DBASE_DIR=<path>  -DJS_SRC=<path-to-built-js>

file(REMOVE_RECURSE "${BASE_DIR}/work" "${BASE_DIR}/deploy" "${BASE_DIR}/data")
file(MAKE_DIRECTORY
  "${BASE_DIR}/build/doc/cxx"
  "${BASE_DIR}/build/doc/python"
  "${BASE_DIR}/work"
  "${BASE_DIR}/data"
)

# JS is already named ${project}-version.js by kdocs_build_js — just copy it.
file(COPY "${JS_SRC}" DESTINATION "${BASE_DIR}/data")
