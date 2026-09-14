# Değişiklik Şablonları

Şablonlar yalnız ihtiyaç duyulan artifact için kullanılır. `{{TOKEN}}` değerleri gerçek ve doğrulanmış bilgilerle değiştirilir; bilinmeyen alanlar şeması izin veriyorsa `null` kalır, sahte issue/branch/tarih yazılmaz.

Temel token'lar: `WORK_ID`, `WORK_TITLE`, `PROFILE`, `PROFILE_REASON`, `BACKEND_TYPE`, `BACKEND_SOURCE`, `BACKEND_ROOT`, `CREATED_AT`, `UPDATED_AT` ve artifact yolları.
