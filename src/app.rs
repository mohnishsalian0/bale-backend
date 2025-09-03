use std::sync::Arc;

use tokio::net::TcpListener;

use axum::{
    routing::{get, post},
    serve::Serve,
    Router,
};
use sqlx::{postgres::PgPoolOptions, PgPool};

use crate::{
    config::{DatabaseSettings, Settings},
    routes::{
        companies::{create_company, get_company, get_company_list},
        healthcheck::health_check,
    },
};

pub struct Application {
    port: u16,
    server: Serve<TcpListener, Router, Router>,
}

impl Application {
    pub async fn build(configuration: Settings) -> Result<Self, anyhow::Error> {
        let db_pool = get_db_pool(&configuration.database);

        let addr = format!(
            "{}:{}",
            configuration.application.host, configuration.application.port
        );
        let listener = TcpListener::bind(addr).await?;
        let port = listener.local_addr().unwrap().port();

        let admin_routes = Router::new().route("/companies", get(get_company_list));

        let api_v1_routes = Router::new()
            .route("/companies", post(create_company))
            .route("/companies/{company_id}", get(get_company));

        let app: Router = Router::new()
            .route("/health_check", get(health_check))
            .nest("/api/v1", api_v1_routes)
            .nest("/admin/v1", admin_routes)
            .with_state(Arc::new(db_pool));

        let server = axum::serve(listener, app);

        Ok(Self { port, server })
    }

    pub async fn run(self) -> anyhow::Result<()> {
        self.server.await?;
        Ok(())
    }

    pub fn port(&self) -> u16 {
        self.port
    }
}

pub fn get_db_pool(configuration: &DatabaseSettings) -> PgPool {
    PgPoolOptions::new().connect_lazy_with(configuration.connect_options())
}
