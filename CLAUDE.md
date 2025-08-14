# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Bale Backend** is a Rust-based API server for a fabric inventory management system targeting Indian textile traders. The project uses Axum web framework with Supabase (PostgreSQL) as the database backend.

## Tech Stack

- **Backend**: Rust + Axum web framework
- **Database**: Supabase (PostgreSQL with Row Level Security)
- **Authentication**: Supabase Auth (JWT-based)
- **Storage**: Supabase Storage for file uploads
- **Mobile Client**: React Native (Android-first)
- **Deployment**: Railway or Fly.io

## Commands

```bash
# Build the project
cargo build

# Run in development mode
cargo run

# Run tests
cargo test

# Run a specific test
cargo test test_name

# Check code without building
cargo check

# Format code
cargo fmt

# Run clippy linter
cargo clippy

# Database migrations (when SQLx is added)
sqlx migrate run
sqlx migrate revert
```

## Architecture

### Database Design
The system uses a **multi-tenant architecture** with company-based isolation:

- **Core Entities**: Companies → Users → Warehouses → Products → Stock Units
- **Operations**: Sales Orders, Job Works, Goods Dispatch/Receipt
- **Security**: Row Level Security (RLS) policies for tenant isolation
- **Access Control**: Role-based (Admin/Staff) with warehouse-level restrictions

### Migration Structure
Database schema is managed through SQLx migrations in sequential order:
- `0001_initial_schema.sql`: Complete database schema with all tables, triggers, functions
- `0002_rls_policies.sql`: Row Level Security policies for multi-tenant access control

### Key Business Logic
- **Multi-tenant Isolation**: All operations scoped by `company_id`
- **Role-based Access**: 
  - Admin: Full company access across all warehouses
  - Staff: Restricted to assigned warehouse only
- **Inventory Control**: Stock units can only be added via Goods Receipt and removed via Goods Dispatch
- **Audit Trail**: All entities have audit fields (created_at, updated_at, created_by, modified_by, deleted_at)
- **Fabric-specific Features**: Color management, GSM tracking, material types, quality grades

### Domain Model
The system models the fabric trading workflow:
1. **Product Master**: Fabric specifications (material, color, GSM, measuring unit)
2. **Stock Units**: Individual fabric rolls/pieces with barcodes
3. **Sales Orders**: Customer orders with real-time fulfillment tracking
4. **Job Works**: Outsourced work (dyeing, embroidery, printing) with material dispatch/receipt
5. **Goods Dispatch**: Outward inventory movement (to partners or warehouse transfers)
6. **Goods Receipt**: Inward inventory movement (from partners or warehouse transfers)
7. **Partners**: Customers, suppliers, vendors, agents
8. **Barcode System**: QR code generation for stock unit tracking

### Authentication Model
- Supabase Auth integration with JWT tokens
- User records linked to Supabase auth via `auth_user_id` field
- Company-based tenant isolation with RLS policies

### File Storage
- Product images and attachments stored in Supabase Storage
- PDF generation for barcode printing
- Image optimization for mobile app performance

## Development Notes

- The project is in early stage - only migrations and PRD are complete
- SQLx should be added for database operations alongside Supabase client
- All database operations must respect RLS policies
- Mobile-first approach - no separate web dashboard planned
- Focus on offline-capable mobile operations for warehouse staff