resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

resource "google_firebase_web_app" "default" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Expenso Web App"
  depends_on   = [google_firebase_project.default]
}

resource "google_firebase_apple_app" "default" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Expenso iOS App"
  bundle_id    = "com.example.expenso"
  depends_on   = [google_firebase_project.default]
}

resource "google_firebase_android_app" "default" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Expenso Android App"
  package_name = "com.example.expenso"
  depends_on   = [google_firebase_project.default]
}
