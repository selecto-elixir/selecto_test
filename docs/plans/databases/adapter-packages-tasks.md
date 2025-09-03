# Database Adapter Packages - Development Task Lists

## selecto_db_mysql - MySQL/MariaDB Adapter Package

**Repository:** New separate package  
**Package Name:** `selecto_db_mysql`  
**Hex:** `selecto_db_mysql`  
**Priority:** High  
**Estimated Effort:** 3 weeks  

### Week 1: Package Setup & Core Implementation

#### 1.1 Package Infrastructure
- [ ] Create new Mix project `selecto_db_mysql`
- [ ] Set up GitHub/GitLab repository
- [ ] Configure CI/CD pipeline
- [ ] Set up test infrastructure with MySQL containers
- [ ] Add Hex package metadata
- [ ] Set up documentation generation

#### 1.2 Core Adapter Implementation
- [ ] Create `lib/selecto/db/mysql.ex` main module
- [ ] Create `lib/selecto/db/mysql/adapter.ex` implementing behavior
- [ ] Create `lib/selecto/db/mysql/connection.ex` for MyXQL integration
- [ ] Create `lib/selecto/db/mysql/dialect.ex` for MySQL SQL dialect
- [ ] Create `lib/selecto/db/mysql/types.ex` for type mappings
- [ ] Create `lib/selecto/db/mysql/features.ex` for capability detection

#### 1.3 MySQL-Specific Features
- [ ] Implement `?` parameter placeholder translation
- [ ] Handle backtick identifier quoting
- [ ] Implement LIMIT/OFFSET syntax
- [ ] Handle boolean as TINYINT(1)
- [ ] Implement INSERT ... ON DUPLICATE KEY UPDATE
- [ ] Handle MySQL date/time types

### Week 2: Advanced Features & Compatibility

#### 2.1 Version-Specific Features
- [ ] Detect MySQL version (5.7 vs 8.0)
- [ ] Implement CTE support for MySQL 8.0+
- [ ] Add window function support for MySQL 8.0+
- [ ] Handle LATERAL joins for MySQL 8.0.14+
- [ ] Implement JSON operations
- [ ] Add full-text search with MATCH AGAINST

#### 2.2 Query Translation
- [ ] Translate PostgreSQL-style queries to MySQL
- [ ] Handle missing features gracefully
- [ ] Implement feature emulation where possible
- [ ] Add query optimization for MySQL
- [ ] Handle index hints
- [ ] Implement EXPLAIN format differences

#### 2.3 Error Handling
- [ ] Map MySQL error codes to Selecto errors
- [ ] Handle connection errors gracefully
- [ ] Implement retry logic
- [ ] Add detailed error messages
- [ ] Handle charset/collation issues
- [ ] Process deadlock errors

### Week 3: Testing & Documentation

#### 3.1 Comprehensive Testing
- [ ] Unit tests for all adapter functions
- [ ] Integration tests with real MySQL
- [ ] Test with MariaDB compatibility
- [ ] Performance benchmarks
- [ ] Test version-specific features
- [ ] Test error scenarios

#### 3.2 Documentation & Release
- [ ] Write README with examples
- [ ] Document MySQL-specific features
- [ ] Create migration guide from PostgreSQL
- [ ] Document limitations and workarounds
- [ ] Publish to Hex.pm
- [ ] Create announcement blog post

---

## selecto_db_sqlite - SQLite Adapter Package

**Repository:** New separate package  
**Package Name:** `selecto_db_sqlite`  
**Hex:** `selecto_db_sqlite`  
**Priority:** High  
**Estimated Effort:** 2 weeks  

### Week 1: Core Implementation

#### 1.1 Package Setup
- [ ] Create new Mix project `selecto_db_sqlite`
- [ ] Set up repository and CI/CD
- [ ] Configure test infrastructure
- [ ] Add Exqlite dependency
- [ ] Set up in-memory database testing
- [ ] Configure documentation

#### 1.2 SQLite Adapter
- [ ] Create `lib/selecto/db/sqlite.ex` main module
- [ ] Implement Selecto.Database.Adapter behavior
- [ ] Handle Exqlite connection management
- [ ] Implement SQLite dialect
- [ ] Handle dynamic typing
- [ ] Support in-memory databases

#### 1.3 SQLite-Specific Features
- [ ] Handle ATTACH DATABASE functionality
- [ ] Implement FTS5 full-text search
- [ ] Support JSON1 extension
- [ ] Handle PRAGMA statements
- [ ] Implement VACUUM support
- [ ] Add backup/restore functionality

### Week 2: Limitations & Testing

#### 2.1 Handle Limitations
- [ ] Emulate RIGHT JOIN using LEFT JOIN
- [ ] Work around limited ALTER TABLE
- [ ] Handle missing stored procedures
- [ ] Emulate FULL OUTER JOIN
- [ ] Handle type affinity rules
- [ ] Implement workarounds for missing features

#### 2.2 Testing & Release
- [ ] Comprehensive test suite
- [ ] Test with different SQLite versions
- [ ] Performance benchmarks
- [ ] Memory usage tests
- [ ] Documentation
- [ ] Hex.pm release

---

## selecto_db_mssql - SQL Server Adapter Package

**Repository:** New separate package  
**Package Name:** `selecto_db_mssql`  
**Hex:** `selecto_db_mssql`  
**Priority:** Medium  
**Estimated Effort:** 3 weeks  

### Week 1: Core Implementation

#### 1.1 Package Setup
- [ ] Create new Mix project `selecto_db_mssql`
- [ ] Set up repository and CI/CD
- [ ] Configure SQL Server test containers
- [ ] Add Tds driver dependency
- [ ] Set up Azure SQL Database testing
- [ ] Configure documentation

#### 1.2 SQL Server Adapter
- [ ] Create `lib/selecto/db/mssql.ex` main module
- [ ] Implement adapter behavior with Tds
- [ ] Handle T-SQL dialect
- [ ] Implement bracket identifier quoting
- [ ] Handle @named parameters
- [ ] Support TOP clause

### Week 2: Advanced Features

#### 2.1 SQL Server Specific
- [ ] Implement CROSS APPLY / OUTER APPLY
- [ ] Support temporal tables
- [ ] Handle indexed views
- [ ] Implement MERGE statement
- [ ] Support XML data type
- [ ] Add hierarchyid support

#### 2.2 Compatibility
- [ ] Handle OFFSET FETCH syntax
- [ ] Implement ROW_NUMBER() for pagination
- [ ] Support JSON operations (SQL Server 2016+)
- [ ] Handle computed columns
- [ ] Implement filestream support
- [ ] Add Always Encrypted support

### Week 3: Testing & Release

#### 3.1 Testing
- [ ] Test with SQL Server 2016, 2019, 2022
- [ ] Test with Azure SQL Database
- [ ] Performance benchmarks
- [ ] Test failover scenarios
- [ ] Test with different collations
- [ ] Integration test suite

#### 3.2 Documentation & Release
- [ ] Comprehensive documentation
- [ ] Azure deployment guide
- [ ] Performance tuning guide
- [ ] Migration from PostgreSQL guide
- [ ] Hex.pm release
- [ ] Example applications

---

## selecto_db_oracle - Oracle Database Adapter Package

**Repository:** New separate package  
**Package Name:** `selecto_db_oracle`  
**Hex:** `selecto_db_oracle`  
**Priority:** Low  
**Estimated Effort:** 4 weeks  

### Week 1-2: Core Implementation

#### 1.1 Package Setup
- [ ] Create new Mix project
- [ ] Set up Oracle test environment
- [ ] Configure Oracle XE for testing
- [ ] Add jamdb_oracle dependency
- [ ] Set up CI/CD with Oracle
- [ ] Configure documentation

#### 1.2 Oracle Adapter
- [ ] Implement adapter behavior
- [ ] Handle :named parameters
- [ ] Support ROWNUM and FETCH FIRST
- [ ] Implement Oracle SQL dialect
- [ ] Handle uppercase identifiers
- [ ] Support dual table

### Week 3: Oracle-Specific Features

#### 3.1 Advanced Features
- [ ] Support flashback queries
- [ ] Implement partitioning
- [ ] Handle nested tables/VARRAYs
- [ ] Support Oracle Text
- [ ] Implement materialized views
- [ ] Add PL/SQL support

#### 3.2 Compatibility
- [ ] Handle CONNECT BY for hierarchical
- [ ] Support MODEL clause
- [ ] Implement PIVOT/UNPIVOT
- [ ] Handle Oracle-specific functions
- [ ] Support database links
- [ ] Add RAC support

### Week 4: Testing & Release

#### 4.1 Testing
- [ ] Test with Oracle 12c, 19c, 21c
- [ ] Test with Oracle Cloud
- [ ] Performance benchmarks
- [ ] Test with different character sets
- [ ] PL/SQL integration tests
- [ ] RAC failover testing

#### 4.2 Release
- [ ] Documentation
- [ ] Oracle Cloud guide
- [ ] Migration guide
- [ ] Performance guide
- [ ] Hex.pm release
- [ ] Enterprise examples

---

## Community Adapter Guidelines

### Template Repository: selecto_db_template

#### Package Structure
```
selecto_db_{database}/
├── lib/
│   └── selecto/
│       └── db/
│           └── {database}.ex
│           └── {database}/
│               ├── adapter.ex
│               ├── connection.ex
│               ├── dialect.ex
│               ├── types.ex
│               └── features.ex
├── test/
│   ├── adapter_test.exs
│   ├── integration_test.exs
│   └── test_helper.exs
├── mix.exs
├── README.md
├── LICENSE
├── CHANGELOG.md
└── .github/
    └── workflows/
        └── ci.yml
```

#### Required Implementation
1. Implement `Selecto.Database.Adapter` behavior
2. Provide connection management
3. Define SQL dialect
4. Map types between Elixir and database
5. Declare feature capabilities
6. Handle errors appropriately
7. Provide comprehensive tests
8. Document limitations and workarounds

#### Quality Standards
- [ ] 80%+ test coverage
- [ ] Passes Selecto adapter certification suite
- [ ] Includes integration tests
- [ ] Documented API
- [ ] Performance benchmarks
- [ ] CI/CD pipeline
- [ ] Semantic versioning
- [ ] Clear upgrade path

#### Publishing Checklist
- [ ] Package name follows convention: `selecto_db_{name}`
- [ ] Module naming: `Selecto.DB.{Name}`
- [ ] Hex metadata complete
- [ ] Documentation published on HexDocs
- [ ] Listed in Selecto adapter registry
- [ ] Announcement in Selecto community
- [ ] Example application provided
- [ ] Migration guide from PostgreSQL

---

## Adapter Certification Process

### Level 1: Basic Compatibility
- [ ] Implements all required callbacks
- [ ] Passes basic query tests
- [ ] Handles CRUD operations
- [ ] Connection management works
- [ ] Error handling implemented

### Level 2: Advanced Features
- [ ] Supports transactions
- [ ] Handles complex queries
- [ ] Implements streaming
- [ ] Provides introspection
- [ ] Performance acceptable

### Level 3: Production Ready
- [ ] Used in production
- [ ] Community tested
- [ ] Stable API
- [ ] Regular updates
- [ ] Active maintenance

---

## Success Criteria for Adapter Packages

1. **Independence**: Each adapter can be developed, tested, and released independently
2. **Compatibility**: All adapters pass the Selecto compatibility test suite
3. **Performance**: No more than 10% overhead compared to direct driver usage
4. **Documentation**: Comprehensive docs with examples and migration guides
5. **Community**: Active maintenance and community support
6. **Quality**: 80%+ test coverage and CI/CD pipeline
7. **Discoverability**: Listed on Hex.pm and Selecto documentation