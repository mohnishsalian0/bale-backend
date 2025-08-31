use tokio::net::TcpListener;

use axum::{http::status::StatusCode, routing::get, serve::Serve, Router};
use sqlx::{postgres::PgPoolOptions, PgPool};

use crate::{
    config::{DatabaseSettings, Settings},
    routes::healthcheck::health_check,
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
        // let server =

        let app: Router = Router::new().route("/health_check", get(health_check));

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
