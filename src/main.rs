use bale_backend::{app::Application, config::get_config};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let configuration = get_config()?;

    let app = Application::build(configuration).await?;

    app.run().await?;

    Ok(())
}
