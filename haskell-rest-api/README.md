# Haskell REST API Example

A simple REST API built with Haskell to learn the language.

## Features
- HTTP web server using Scotty framework
- Single GET endpoint that returns random strings
- JSON response format

## Dependencies
- **Scotty**: Lightweight web framework
- **Aeson**: JSON encoding/decoding
- **WAI/Warp**: HTTP server infrastructure

## Building
```bash
cabal build
```

## Running
```bash
cabal run
```

## Testing
```bash
curl http://localhost:3000/api/strings
```
