pub struct TestApp {
    pub address: String,
    pub port: u16,
    api_client: reqwest::Client,
}

pub async fn spawn_app() -> TestApp {
    // let app = Application

    let client = reqwest::Client::builder().build().unwrap();
    todo!()
}
