use reqwest::StatusCode;

use crate::test_app::TestApp;

#[tokio::test]
async fn create_company_returns_200_for_valid_form() {
    let app = TestApp::build().await;

    let body = serde_json::json!({
        "name": "Looms".to_string(),
        "address_line1": Some( "Shop 1, Building 2, Street 3".to_string() ),
        "address_line2": Some( "50 street road".to_string() ),
        "city": Some("Mumbai".to_string()),
        "state": Some("Maharashtra".to_string()),
        "country": Some("India".to_string()),
        "pincode": Some("12345".to_string()),
        "business_type": Some("Embroider".to_string()),
        "gst_number": Some("1234567".to_string()),
        "pan_number": Some("ABC123456".to_string()),
        "logo_url": Some("https://www.logourl.com".to_string()),
    });

    let client = reqwest::Client::new();
    let res = client
        .post(format!("{}/companies", app.address))
        .json(&body)
        .send()
        .await
        .unwrap();

    assert_eq!(StatusCode::OK, res.status());
}

#[tokio::test]
async fn create_company_persists_new_record_in_db() {
    let app = TestApp::build().await;

    let body = serde_json::json!({
        "name": "Looms".to_string(),
    });

    let client = reqwest::Client::new();
    let res = client
        .post(format!("{}/companies", app.address))
        .json(&body)
        .send()
        .await
        .unwrap();

    let saved_record = sqlx::query!(r#"SELECT id, name from companies"#)
        .fetch_one(&app.db_pool)
        .await
        .expect("Failed to fetch saved company.");

    assert_eq!(StatusCode::OK, res.status());
    assert_eq!(saved_record.name, "Looms");
}
