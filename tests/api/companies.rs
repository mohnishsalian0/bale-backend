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
async fn read_company_list_returns_all_inserted_records() {
    let app = TestApp::build().await;

    // Create first company
    let body1 = serde_json::json!({
        "name": "Looms Ltd".to_string(),
        "city": Some("Mumbai".to_string()),
    });

    // Create second company
    let body2 = serde_json::json!({
        "name": "Textile Co".to_string(),
        "city": Some("Delhi".to_string()),
    });

    let client = reqwest::Client::new();

    // Insert first company
    let _company_id1: Uuid = client
        .post(format!("{}/companies", app.address))
        .json(&body1)
        .send()
        .await
        .unwrap()
        .json()
        .await
        .unwrap();

    // Insert second company
    let _company_id2: Uuid = client
        .post(format!("{}/companies", app.address))
        .json(&body2)
        .send()
        .await
        .unwrap()
        .json()
        .await
        .unwrap();

    // Get all companies
    let res = client
        .get(format!("{}/admin/companies", app.address))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(2, companies.len());

    let company_names: Vec<&str> = companies.iter().map(|c| c.name.as_str()).collect();
    assert!(company_names.contains(&"Looms Ltd"));
    assert!(company_names.contains(&"Textile Co"));
}

#[tokio::test]
async fn read_company_returns_inserted_record() {
    let app = TestApp::build().await;

    let body = serde_json::json!({
        "name": "Looms".to_string(),
        "city": Some("Mumbai".to_string()),
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
    assert_eq!(body["city"], retrieved_company.city.unwrap());
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

// PAGINATION
// -------------------------------------------------------------------------------------

#[tokio::test]
async fn read_company_list_with_default_pagination() {
    let app = TestApp::build().await;

    // Create 25 companies to test default page size
    let client = reqwest::Client::new();
    for i in 1..=25 {
        let body = serde_json::json!({
            "name": format!("Company {}", i),
        });
        client
            .post(format!("{}/companies", app.address))
            .json(&body)
            .send()
            .await
            .unwrap();
    }

    // Get companies with default pagination
    let res = client
        .get(format!("{}/admin/companies", app.address))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(20, companies.len()); // Default page size should be 20
}

#[tokio::test]
async fn read_company_list_with_custom_pagination() {
    let app = TestApp::build().await;

    // Create 3 companies
    let client = reqwest::Client::new();
    for i in 1..=30 {
        let body = serde_json::json!({
            "name": format!("Company {}", i),
        });
        client
            .post(format!("{}/companies", app.address))
            .json(&body)
            .send()
            .await
            .unwrap();
    }

    // Get first 2 companies (page 1, page_size 25)
    let res = client
        .get(format!(
            "{}/admin/companies?page=1&page_size=25",
            app.address
        ))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(25, companies.len());

    // Get remaining company (page 2, page_size 25)
    let res = client
        .get(format!(
            "{}/admin/companies?page=2&page_size=25",
            app.address
        ))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(5, companies.len()); // Only 5 company on page 2
}

#[tokio::test]
async fn read_company_list_clamps_page_size() {
    let app = TestApp::build().await;

    // Create 60 companies to properly test clamping
    let client = reqwest::Client::new();
    for i in 1..=60 {
        let body = serde_json::json!({
            "name": format!("Company {}", i),
        });
        client
            .post(format!("{}/companies", app.address))
            .json(&body)
            .send()
            .await
            .unwrap();
    }

    // Test page_size=5 (should clamp to 20)
    let res = client
        .get(format!("{}/admin/companies?page_size=5", app.address))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(20, companies.len()); // Should return 20, not 5

    // Test page_size=100 (should clamp to 50)
    let res = client
        .get(format!("{}/admin/companies?page_size=100", app.address))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(50, companies.len()); // Should return 50, not 100

    // Test valid page_size=30 (should return 30)
    let res = client
        .get(format!("{}/admin/companies?page_size=30", app.address))
        .send()
        .await
        .unwrap();

    let status = res.status();
    let companies: Vec<Company> = res.json().await.unwrap();

    assert_eq!(StatusCode::OK, status);
    assert_eq!(30, companies.len()); // Should return exactly 30
}

#[tokio::test]
async fn read_company_list_handles_invalid_page_numbers() {
    let app = TestApp::build().await;

    let client = reqwest::Client::new();
    let body = serde_json::json!({
        "name": "Test Company",
    });
    client
        .post(format!("{}/companies", app.address))
        .json(&body)
        .send()
        .await
        .unwrap();

    // Test negative page (should default to 1)
    let res = client
        .get(format!("{}/admin/companies?page=-1", app.address))
        .send()
        .await
        .unwrap();

    assert_eq!(StatusCode::OK, res.status());

    // Test page 0 (should default to 1)
    let res = client
        .get(format!("{}/admin/companies?page=0", app.address))
        .send()
        .await
        .unwrap();

    assert_eq!(StatusCode::OK, res.status());

    // Test non-numeric page (should default to 1)
    let res = client
        .get(format!("{}/admin/companies?page=abc", app.address))
        .send()
        .await
        .unwrap();

    assert_eq!(StatusCode::OK, res.status());
}
