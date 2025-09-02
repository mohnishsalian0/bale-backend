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
    routes::{companies::create_company, healthcheck::health_check},
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

        let app: Router = Router::new()
            .route("/health_check", get(health_check))
            .route("/companies", post(create_company))
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
