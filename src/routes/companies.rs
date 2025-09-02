use std::sync::Arc;

use anyhow::Context;
use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

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

// ERROR
// -------------------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum CompanyError {
    #[error("{0}")]
    ValidationError(String),
    #[error(transparent)]
    UnexpectedError(#[from] anyhow::Error),
}

impl IntoResponse for CompanyError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::ValidationError(_) => StatusCode::BAD_REQUEST,
            Self::UnexpectedError(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
        .into_response()
    }
}

// CREATE
// -------------------------------------------------------------------------------------

pub async fn create_company(
    State(db_pool): State<Arc<PgPool>>,
    Json(new_company): Json<NewCompany>,
) -> Result<StatusCode, CompanyError> {
    let _company_id = insert_company(&db_pool, &new_company)
        .await
        .context("Failed to insert company in the database.")?;
    Ok(StatusCode::OK)
}

async fn insert_company(db_pool: &PgPool, new_company: &NewCompany) -> Result<Uuid, sqlx::Error> {
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
