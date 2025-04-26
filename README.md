# A Demo Repository for the Model Context Protocol in OCaml

This is a demo repository for experimenting with [the Model Context
Protocol](https://modelcontextprotocol.io/introduction) in OCaml.

At present, there is no official MCP SDK for OCaml, nor did I find a third-party
one available as an open source software. Thus I am trying to write a client and
server library for the protocol as well, which is work in progress. This
repository contains both a library and a demo application (or applications).

## Rationale

OCaml is a strongly typed functional programming language, and it has been
adopted in production for mission critical systems (e.g. finance). It has also
added support for multi-core programming in version 5.
[Eio](https://github.com/ocaml-multicore/eio) library brings structured
concurrency to the language, which makes it even more suitable for building
robust, high-performant systems.

### MCP client

To write an AI agent in OCaml, integration with MCP servers is a must. Writing
AI agents in OCaml would be a great experience, especially for implementing
complex agentic systems, because of composability of the language.

### MCP server

OCaml is a solid language for backend systems, so writing an MCP server in the
language would make sense.

## Status

I am trying to implement a client that inspects an MCP server. My OCaml skills
are at an elementary level, so it will probably take longer than it would if it
were done by an experienced functional programmer.
