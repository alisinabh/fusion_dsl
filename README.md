# FusionDSL

A simple, fault tolerant, scalable domain specific language.

FusionDSL runs on Erlang VM (BEAM) which has super capabilities for handling concurrency issues.

## About FusionDSL

A functional single file programming language, designed to be edited and managed through a Web UI.

### Hello World

```elixir
NAME: My Fusion APP
VERSION: 0.1-rc1

def main:
  Logger.log "Hello World!"
```

## Why a new language?

First, FusionDSL is not considered as a programming language. It is meant as a tool making development
of routine parts easier.

I chose to create FusionDSL because:

 1. A personal challenge to create a new language without using tools like (yecc, leex, etc).
 1. Making production ready programs on the fly.
 1. Limiting the programmer (Which usually is not a skilled programmer and may cause unwanted damage).
 1. Highly fault tolerant. Means it is hard to break the system by mistake.
 1. Brings a powerful layer of flexibility in services.
 1. Hot swapping capabilities. Super-Easy deployments.

## Install FusionDSL

**TODO: Add install guides**

## Learn to code

**TODO: Add learn guides**

## License

This project is licences under **MIT** license.

Refer to LICENSE file for more information.
