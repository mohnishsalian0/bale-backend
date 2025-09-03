use std::sync::Arc;

use anyhow::Context;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use strum_macros::{Display, EnumString};
use uuid::Uuid;

// ERROR
// -------------------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum CompanyError {
    #[error("{0}")]
    ValidationError(String),
    #[error("Company not found")]
    NotFound,
    #[error(transparent)]
    UnexpectedError(#[from] anyhow::Error),
}

impl IntoResponse for CompanyError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::ValidationError(_) => StatusCode::BAD_REQUEST,
            Self::NotFound => StatusCode::NOT_FOUND,
            Self::UnexpectedError(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
        .into_response()
    }
}

// CREATE
// -------------------------------------------------------------------------------------

#[derive(Default, Debug, Clone, Deserialize)]
pub struct NewCompany {
    name: String,
    address_line1: Option<String>,
    address_line2: Option<String>,
    city: Option<String>,
    state: Option<String>,
    country: Option<String>,
    pin_code: Option<String>,
    business_type: Option<String>,
    gst_number: Option<String>,
    pan_number: Option<String>,
    logo_url: Option<String>,
}

pub async fn create_company(
    State(db_pool): State<Arc<PgPool>>,
    Json(new_company): Json<NewCompany>,
) -> Result<(StatusCode, Json<Uuid>), CompanyError> {
    let company_id = insert_company_in_db(&db_pool, &new_company)
        .await
        .context("Failed to insert company in the database.")?;

    Ok((StatusCode::CREATED, Json(company_id)))
}

async fn insert_company_in_db(
    db_pool: &PgPool,
    new_company: &NewCompany,
) -> Result<Uuid, sqlx::Error> {
    let id = sqlx::query_scalar!(
                r#"
                INSERT INTO companies (name, address_line1, address_line2, city, state, country, pin_code, business_type, gst_number, pan_number, logo_url)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id
                "#,
                new_company.name,
                new_company.address_line1,
                new_company.address_line2,
                new_company.city,
                new_company.state,
                new_company.country,
                new_company.pin_code,
                new_company.business_type,
                new_company.gst_number,
                new_company.pan_number,
                new_company.logo_url
      )
      .fetch_one(db_pool)
      .await?;

    Ok(id)
}

// READ
// -------------------------------------------------------------------------------------

#[derive(Default, Debug, Clone, Deserialize, Serialize, sqlx::FromRow)]
pub struct Company {
    pub id: Uuid,
    pub name: String,
    pub address_line1: Option<String>,
    pub address_line2: Option<String>,
    pub city: Option<String>,
    pub state: Option<String>,
    pub country: Option<String>,
    pub pin_code: Option<String>,
    pub business_type: Option<String>,
    pub gst_number: Option<String>,
    pub pan_number: Option<String>,
    pub logo_url: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub created_by: Option<Uuid>,
    pub modified_by: Option<Uuid>,
    pub deleted_at: Option<DateTime<Utc>>,
}

#[derive(Deserialize)]
pub struct CompanyQuery {
    page: Option<i64>,
    limit: Option<i64>,
    sort: Option<String>,
    order: Option<String>,
}

#[allow(non_camel_case_types)]
#[derive(Display, EnumString)]
enum SortField {
    name,
    created_at,
}

impl SortField {
    pub fn parse(val: Option<String>) -> Self {
        val.as_deref()
            .map_or(Ok(Self::name), |s| s.parse())
            .unwrap_or(Self::name)
    }
}

#[allow(clippy::upper_case_acronyms)]
#[derive(Display, EnumString)]
#[strum(ascii_case_insensitive)]
enum SortOrder {
    ASC,
    DESC,
}

impl SortOrder {
    pub fn parse(val: Option<String>) -> Self {
        val.as_deref()
            .map_or(Ok(Self::ASC), |s| s.parse())
            .unwrap_or(Self::ASC)
    }
}

pub async fn get_company(
    State(db_pool): State<Arc<PgPool>>,
    Path(company_id): Path<Uuid>,
) -> Result<Json<Company>, CompanyError> {
    let company = fetch_company_from_db(&db_pool, company_id)
        .await
        .map_err(|e| match e {
            sqlx::Error::RowNotFound => CompanyError::NotFound,
            _ => CompanyError::UnexpectedError(
                anyhow::Error::from(e).context("Failed to fetch company from database."),
            ),
        })?;

    Ok(Json(company))
}

async fn fetch_company_from_db(db_pool: &PgPool, company_id: Uuid) -> Result<Company, sqlx::Error> {
    let company = sqlx::query_as!(
        Company,
        r#"
        SELECT id, name, address_line1, address_line2, city, state, country, pin_code, business_type, gst_number, pan_number, logo_url, created_at, updated_at, created_by, modified_by, deleted_at from companies 
        WHERE id = $1
        "#,
        company_id
    )
    .fetch_one(db_pool)
    .await?;

    Ok(company)
}

pub async fn get_company_list(
    State(db_pool): State<Arc<PgPool>>,
    Query(query): Query<CompanyQuery>,
) -> Result<Json<Vec<Company>>, CompanyError> {
    let company_list = fetch_company_list_from_db(&db_pool, query)
        .await
        .context("Failed to fetch company from database.")?;

    Ok(Json(company_list))
}

async fn fetch_company_list_from_db(
    db_pool: &PgPool,
    query: CompanyQuery,
) -> Result<Vec<Company>, sqlx::Error> {
    // Query params
    let page = query.page.unwrap_or(1).max(1);
    let limit = query.limit.unwrap_or(20).clamp(20, 50);
    let offset = (page - 1) * limit;
    let sort = SortField::parse(query.sort);
    let order = SortOrder::parse(query.order);

    let query = format!(
        r#"
        SELECT id, name, address_line1, address_line2, city, state, country, pin_code, business_type, gst_number, pan_number, logo_url, created_at, updated_at, created_by, modified_by, deleted_at from companies 
        WHERE deleted_at IS NULL
        ORDER BY {} {}
        LIMIT $1 OFFSET $2
        "#,
        sort, order
    );

    let companies = sqlx::query_as::<_, Company>(&query)
        .bind(limit)
        .bind(offset)
        .fetch_all(db_pool)
        .await?;

    Ok(companies)
}
