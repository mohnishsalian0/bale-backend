use axum::http::status::StatusCode;

pub async fn health_check() -> StatusCode {
    StatusCode::OK
}
