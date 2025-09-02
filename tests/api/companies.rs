use bale_backend::routes::companies::Company;
use reqwest::StatusCode;
use uuid::Uuid;

use crate::test_app::TestApp;

// CREATE
// -------------------------------------------------------------------------------------

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

    assert_eq!(StatusCode::CREATED, res.status());
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
    let status = res.status();
    let company_id: Uuid = res.json().await.expect("Failed to parse company id.");

    let saved_record = sqlx::query!(r#"SELECT id, name from companies"#)
        .fetch_one(&app.db_pool)
        .await
        .expect("Failed to fetch saved company.");

    assert_eq!(StatusCode::CREATED, status);
    assert_eq!(saved_record.name, "Looms");
    assert_eq!(saved_record.id, company_id);
}

// READ
// -------------------------------------------------------------------------------------

#[tokio::test]
async fn read_company_returns_inserted_record() {
    let app = TestApp::build().await;

    let body = serde_json::json!({
        "name": "Looms".to_string(),
        "address_line1": Some( "Shop 1, Building 2, Street 3".to_string() ),
        "address_line2": Some( "50 street road".to_string() ),
        "city": Some("Mumbai".to_string()),
        "state": Some("Maharashtra".to_string()),
        "country": Some("India".to_string()),
        "pin_code": Some("12345".to_string()),
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
    let company_id: Uuid = res.json().await.expect("Failed to parse company id.");

    let res = client
        .get(format!("{}/companies/{}", app.address, company_id))
        .send()
        .await
        .unwrap();
    let status = res.status();
    let retrieved_company: Company = res.json().await.expect("Failed to parse company.");

    assert_eq!(StatusCode::OK, status);
    assert_eq!(body["name"], retrieved_company.name);
    assert_eq!(
        body["address_line1"],
        retrieved_company.address_line1.unwrap()
    );
    assert_eq!(
        body["address_line2"],
        retrieved_company.address_line2.unwrap()
    );
    assert_eq!(body["city"], retrieved_company.city.unwrap());
    assert_eq!(body["state"], retrieved_company.state.unwrap());
    assert_eq!(body["country"], retrieved_company.country.unwrap());
    assert_eq!(body["pin_code"], retrieved_company.pin_code.unwrap());
    assert_eq!(
        body["business_type"],
        retrieved_company.business_type.unwrap()
    );
    assert_eq!(body["gst_number"], retrieved_company.gst_number.unwrap());
    assert_eq!(body["pan_number"], retrieved_company.pan_number.unwrap());
    assert_eq!(body["logo_url"], retrieved_company.logo_url.unwrap());
}

#[tokio::test]
async fn read_company_returns_not_found_if_record_doesnt_exist() {
    let app = TestApp::build().await;

    let company_id = Uuid::new_v4();
    let client = reqwest::Client::new();
    let res = client
        .get(format!("{}/companies/{}", app.address, company_id))
        .send()
        .await
        .unwrap();
    let status = res.status();

    assert_eq!(StatusCode::NOT_FOUND, status);
}
