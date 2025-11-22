# Haskell REST API

A lightweight REST API web server built with Haskell for learning purposes. This project demonstrates user authentication, database integration, and REST endpoint design using functional programming principles.

## Programming Language

**Haskell** - A statically-typed, purely functional programming language.

- **Compiler**: GHC (Glasgow Haskell Compiler)
- **Language Standard**: Haskell2010
- **Build System**: Cabal
- **Project Version**: 0.1.0.0

## Libraries and Dependencies

### Web Framework
- **Scotty** - Lightweight web framework for building REST APIs
- **WAI/Warp** - Web Application Interface and HTTP server library

### Database & ORM
- **Persistent** - Type-safe database library with ORM capabilities
- **Persistent-PostgreSQL** - PostgreSQL backend for Persistent
- **Persistent-Template** - Template Haskell support for database schema definition

### Data Handling
- **Aeson** - High-performance JSON encoding/decoding
- **Text** - Efficient Unicode text handling
- **ByteString** - Binary data handling

### Security
- **Cryptonite** - Cryptographic library (used for Argon2 password hashing)
- **Memory** - Secure memory handling utilities

### Utilities
- **Random** - Random number generation
- **Monad-Logger** - Logging framework
- **Transformers** - Monad transformers for IO operations
- **ResourceT** - Safe resource management

### Testing
- **hspec** - Behavior-Driven Development (BDD) testing framework
- **hspec-wai** - WAI testing utilities for HTTP endpoints
- **hspec-wai-json** - JSON assertions for API tests
- **hspec-discover** - Automatic test discovery
- **http-client** - HTTP client library for integration tests
- **Async** - Asynchronous programming support

## HTTP Endpoints

The server runs on **port 3000** and provides the following endpoints:

### Public Endpoints

#### Get Random Strings
```
GET /api/strings
```
Returns an array of 5 random strings.

**Example:**
```bash
curl http://localhost:3000/api/strings
```

**Response:**
```json
["abc123", "def456", "ghi789", "jkl012", "mno345"]
```

---

#### Save Item
```
POST /api/items
```
Saves an item to the database.

**Request Body:**
```json
{
  "item": "test item"
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/api/items \
  -H 'Content-Type: application/json' \
  -d '{"item":"test item"}'
```

**Response:**
```json
{
  "message": "Item saved successfully"
}
```

---

### User Authentication Endpoints

#### User Signup
```
POST /user/signup
```
Creates a new user account with username and password.

**Request Body:**
```json
{
  "username": "testuser",
  "password": "testpass"
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/user/signup \
  -H 'Content-Type: application/json' \
  -d '{"username":"testuser","password":"testpass"}'
```

**Response:**
```json
{
  "message": "User created successfully"
}
```

---

#### User Signin
```
POST /user/signin
```
Authenticates a user and returns a session token.

**Request Body:**
```json
{
  "username": "testuser",
  "password": "testpass"
}
```

**Example:**
```bash
curl -X POST http://localhost:3000/user/signin \
  -H 'Content-Type: application/json' \
  -d '{"username":"testuser","password":"testpass"}'
```

**Response:**
```json
{
  "token": "a1b2c3d4e5f6g7h8i9j0"
}
```

---

### Protected Endpoints (Require Authentication)

Protected endpoints require an `Authorization` header with the session token received from `/user/signin`.

#### Protected Resource
```
GET /user/protected
```
A protected endpoint that requires authentication.

**Example:**
```bash
curl http://localhost:3000/user/protected \
  -H 'Authorization: <session-token>'
```

**Response:**
```json
{
  "message": "Access granted to protected resource"
}
```

---

#### Get Current User
```
GET /user/me
```
Returns the authenticated user's information.

**Example:**
```bash
curl http://localhost:3000/user/me \
  -H 'Authorization: <session-token>'
```

**Response:**
```json
{
  "userId": 1
}
```

---

## Prerequisites

- **Haskell**: GHC and Cabal (recommended: use [GHCup](https://www.haskell.org/ghcup/))
- **Docker** and **Docker Compose**: For running PostgreSQL database
- **PostgreSQL** (optional, if not using Docker)

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd haskell-rest-api
```

### 2. Set Up the Database

Start the PostgreSQL database using Docker Compose:

```bash
docker-compose up -d
```

This will start a PostgreSQL 15 container with the following configuration:
- **Database**: `haskell_api`
- **User**: `haskell_user`
- **Password**: `haskell_pass`
- **Port**: `5432`

The database schema is automatically created and migrated when the application starts.

### 3. Build the Project

```bash
cabal build
```

This will download dependencies and compile the project.

### 4. Run the Server

```bash
cabal run
```

Or specify the executable name:

```bash
cabal run haskell-rest-api
```

The server will start on **http://localhost:3000** and display startup information including example curl commands.

### 5. Test the API

Once the server is running, you can test the endpoints:

```bash
# Test random strings endpoint
curl http://localhost:3000/api/strings

# Create a user
curl -X POST http://localhost:3000/user/signup \
  -H 'Content-Type: application/json' \
  -d '{"username":"myuser","password":"mypass"}'

# Sign in and get token
curl -X POST http://localhost:3000/user/signin \
  -H 'Content-Type: application/json' \
  -d '{"username":"myuser","password":"mypass"}'

# Access protected endpoint (replace <token> with the token from signin)
curl http://localhost:3000/user/protected \
  -H 'Authorization: <token>'
```

## Running Tests

The project includes a comprehensive test suite using hspec.

```bash
cabal test
```

The test suite covers:
- User signup endpoint
- User signin endpoint
- Protected endpoint authentication
- User profile retrieval (/user/me)
- Database operations

Tests automatically set up and clean up the database for each test run.

## Project Structure

```
haskell-rest-api/
├── app/
│   └── App.hs              # Main application module
│                           # - Route definitions
│                           # - Database operations
│                           # - Authentication logic
│
├── exe/
│   └── Main.hs             # Application entry point
│
├── test/
│   ├── Spec.hs             # Test configuration (hspec-discover)
│   ├── UserSignupSpec.hs   # User signup tests
│   ├── UserSigninSpec.hs   # User signin tests
│   └── UserMeSpec.hs       # User profile tests
│
├── haskell-rest-api.cabal  # Build configuration
├── docker-compose.yml      # PostgreSQL container setup
└── README.md               # This file
```

## Database Schema

The application uses three main database tables:

### User Table
- `id`: Auto-incrementing primary key
- `username`: Unique username
- `password`: Argon2-hashed password (stored as Base64)

### Session Table
- `id`: Auto-incrementing primary key
- `token`: Session token (unique)
- `userId`: Foreign key to User table

### Request Table
- `id`: Auto-incrementing primary key
- `item`: Text field for stored items

## Security Features

- **Password Hashing**: Passwords are hashed using Argon2 algorithm
- **Session Tokens**: Random session tokens for authentication
- **Protected Routes**: Authorization header validation for protected endpoints
- **Type Safety**: Leverages Haskell's type system for compile-time guarantees

## Development

### Hot Reloading

For development with automatic reloading on file changes, you can use tools like `ghcid`:

```bash
ghcid --command "cabal repl"
```

### Stopping the Database

To stop the PostgreSQL container:

```bash
docker-compose down
```

To stop and remove all data:

```bash
docker-compose down -v
```

## Learning Objectives

This project demonstrates:

1. **Functional Programming**: Pure functions, immutability, and type safety
2. **REST API Design**: RESTful endpoint structure and HTTP methods
3. **Database Integration**: ORM usage with type-safe queries
4. **Authentication**: Password hashing and session management
5. **Testing**: BDD-style testing with hspec
6. **Build Tools**: Cabal build system and dependency management

## License

This is a learning project. Feel free to use and modify as needed.

## Contributing

This is a learning project, but contributions and improvements are welcome!
