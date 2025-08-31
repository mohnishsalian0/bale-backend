use bale_backend::{
    app::{get_db_pool, Application},
    config::{get_config, DatabaseSettings},
};
use secrecy::SecretString;
use sqlx::{Connection, PgConnection, PgPool};
use uuid::Uuid;

pub struct TestApp {
    pub address: String,
    pub port: u16,
    pub db_pool: PgPool,
    pub api_client: reqwest::Client,
}

impl TestApp {
    pub async fn build() -> Self {
        let config = {
            let mut c = get_config().expect("Failed to read configuration.");
            c.database.database_name = Uuid::new_v4().to_string();
            c.application.port = 0;
            c
        };

        configure_database(&config.database).await;
        let db_pool = get_db_pool(&config.database);

        let app = Application::build(config.clone())
            .await
            .expect("Failed to build application.");
        let port = app.port();
        let address = format!("http://localhost:{}", port);
        let _ = tokio::spawn(app.run());

        let api_client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .cookie_store(true)
            .build()
            .unwrap();

        Self {
            address,
            port,
            db_pool,
            api_client,
        }
    }
}

async fn configure_database(config: &DatabaseSettings) -> PgPool {
    let admin_settings = DatabaseSettings {
        database_name: "postgres".to_string(),
        username: "postgres".to_string(),
        password: SecretString::from("password".to_string()),
        ..config.clone()
    };

    let mut connection = PgConnection::connect_with(&admin_settings.connect_options())
        .await
        .expect("Failed to connect to Postgres.");
    sqlx::query(format!(r#"CREATE DATABASE "{}";"#, config.database_name).as_str())
        .execute(&mut connection)
        .await
        .expect("Failed to create database.");

    let connection_pool = PgPool::connect_with(config.connect_options())
        .await
        .expect("Failed to connect to Postgres.");
    sqlx::migrate!("./migrations")
        .run(&connection_pool)
        .await
        .expect("Failed to run migrations.");

    connection_pool
}
