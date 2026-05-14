# kitware-doxygen

Generic tooling to publish Kitware project documentation with a version
selector widget for Doxygen (C++) and Sphinx (Python) outputs.

## selector widget

`Src/selector.js` injects a version selector into C++ and Python documentation
pages. It reads `versions.json` from the docs site root and renders a `<select>`
dropdown plus a language toggle link.

Build with `make`, passing project-specific variables:

```
make PROJECT=paraview DOCS_BASE=paraview-docs LOGO=paraview-logo.png
```

| Variable      | Default                              | Description                          |
|---------------|--------------------------------------|--------------------------------------|
| `PROJECT`     | `paraview`                           | Project name                         |
| `DOCS_BASE`   | `$(PROJECT)-docs`                    | URL path prefix for the docs site    |
| `PROJECT_URL` | `https://www.$(PROJECT).org/...`     | Full base URL (used by upload script)|
| `LOGO`        | `$(PROJECT)-logo.png`                | Logo filename injected into header   |

The output is `Dist/$(PROJECT)-version.js`.

`Templates/header.html` is generated from `Templates/header.html.in` by the
same `make` invocation.

## docs_uploader

Shell script to publish a built documentation tree to the Kitware web server.

```
usage: docs_uploader [options]
  options:
    -p name       Project name (e.g. paraview), <MANDATORY>.
    -U url        Base URL of the docs site, <MANDATORY>.
    -s path       Project source directory, <MANDATORY>.
    -b path       Project build directory, <MANDATORY>.
    -w path       Working directory for this program, <MANDATORY>.
    -t types      Space-separated list of doc subdirs to publish, Default: 'cxx python'.
    -k path       SSH key to upload the docs.
    -v version    Force a version, Default: git-describe on source dir.
    -u            Update latest release.
```

Example for ParaView:

```sh
Scripts/docs_uploader \
  -p paraview \
  -U https://www.paraview.org/paraview-docs \
  -s /path/to/paraview-src \
  -b /path/to/paraview-build \
  -w /tmp/work \
  -k ~/.ssh/docs_key \
  -v nightly
```

Pass `-u` only when publishing a tagged release to also update the `latest`
symlink.
