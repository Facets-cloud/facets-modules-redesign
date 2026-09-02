locals {
  output_interfaces = {}
  output_attributes = {
    keyring_id   = google_kms_key_ring.this.id
    keyring_name = google_kms_key_ring.this.name
    location     = google_kms_key_ring.this.location
    key_ids = {
      for name, key in google_kms_crypto_key.keys : name => key.id
    }
  }
}
