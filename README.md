# BERSIH LAUNDRY (Flutter)

Aplikasi kasir laundry: jenis layanan & harga bisa diedit, invoice via WhatsApp,
laporan keuangan, dan hitung upah setrika borongan. Desain biru-putih. Data tersimpan
offline di HP.

## Cara mendapatkan APK (tanpa install Flutter di komputer)

1. Buat akun di https://github.com (gratis), lalu buat repository baru (boleh private).
2. Unggah **seluruh isi folder ini** ke repository itu (tombol *Add file → Upload files*).
   Pastikan folder `.github` ikut terunggah.
3. Buka tab **Actions**. Proses "Build APK Bersih Laundry" berjalan otomatis
   (jika tidak, pilih workflow itu lalu klik *Run workflow*). Tunggu sekitar 5-10 menit.
4. Setelah centang hijau, klik hasil build, lalu unduh **BersihLaundry-APK** di bagian *Artifacts*.
5. Ekstrak zip-nya, kirim `app-release.apk` ke HP, lalu pasang
   (izinkan "Install dari sumber tidak dikenal").

## Cara build di komputer sendiri

```
flutter create --platforms=android --org com.bersihlaundry --project-name bersih_laundry .
dart run flutter_launcher_icons
flutter build apk --release
```
Lalu tambahkan di `android/app/src/main/AndroidManifest.xml` sebelum `<application`:

```
<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>
```
(agar tombol WhatsApp bisa membuka aplikasi di Android 11+). APK ada di
`build/app/outputs/flutter-apk/app-release.apk`.
