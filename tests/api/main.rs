use ctor::{ctor, dtor};
use once_cell::sync::Lazy;
use std::{process::Command, sync::Mutex};

mod companies;
mod healthcheck;
mod test_app;

static DATABASE_CONTAINER_ID: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));

#[ctor]
fn setup() {
    println!("Starting database container...");
    let script_path = format!("{}/scripts/init_db.sh", env!("CARGO_MANIFEST_DIR"));
    let output = Command::new(script_path)
        .env("DB_PORT", "5433")
        .env("ENVIRONMENT", "test")
        .output()
        .expect("Failed to initialize database.");

    if output.status.success() {
        println!("Container started successfully!");
    } else {
        println!("Failed to start container");
    }

    let container_id = String::from_utf8(output.stdout)
        .expect("Invalid UTF-8")
        .trim()
        .to_string();

    *DATABASE_CONTAINER_ID.lock().unwrap() = Some(container_id);
}

#[dtor]
fn cleanup() {
    println!("Shuting down database container...");

    if let Some(container_id) = DATABASE_CONTAINER_ID.lock().unwrap().as_ref() {
        let output = Command::new("docker")
            .arg("kill")
            .arg(container_id)
            .output()
            .expect("Failed to kill database container.");

        if output.status.success() {
            println!("Container shut down successfully!");
        } else {
            println!("Failed to shut down container");
        }
    }
}
