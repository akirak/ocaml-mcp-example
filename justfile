# The default cache path is immutable when odig is installed using Nix
export ODIG_CACHE_DIR := justfile_directory() + "/_build/default/.odig"
# Using _build directory may not be properly allowed for storing user contents
export SHERLODOC_DB := justfile_directory() + "/_build/default/.sherlodoc.marshal"

client *ARGS:
    dune exec mcp_example -- {{ARGS}}

client-everything:
    dune exec mcp_example -- npx -y "@modelcontextprotocol/server-everything"

client-filesystem:
    dune exec mcp_example -- npx -y "@modelcontextprotocol/server-filesystem" _build

odig-odoc:
    odig odoc

sherlodoc-index: odig-odoc
    find "${ODIG_CACHE_DIR}/odoc" -name '*.odocl' \
    | grep -v '__' \
    | xargs sherlodoc index

sherlodoc-serve:
    sherlodoc serve
