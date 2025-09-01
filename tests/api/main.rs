use ctor::{ctor, dtor};
use once_cell::sync::Lazy;
use std::{process::Command, sync::Mutex};

mod healthcheck;
mod test_app;

struct TestDbContainer {
    id: String,
}

static DATABASE_CONTAINER_ID: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));

#[ctor]
fn setup() {
    println!("Starting database container...");
    let output = Command::new("bash")
        .arg(format!("{}/scripts/init_db.sh", env!("CARGO_MANIFEST_DIR")))
        .output()
        .expect("Failed to initialize database.");

    if output.status.success() {
        println!("Container started successfully!");
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
        }
    }
}
