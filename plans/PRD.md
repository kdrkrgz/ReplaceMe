# RM — Product Requirements Document (PRD)

**Version:** 1.0  
**Platform:** macOS (AppKit + Swift)  
**Distribution:** Direct / notarized DMG  
**Minimum macOS:** 13.0 (Ventura)

---

## 2.1 Problem Statement

Kullanıcılar, sistem genelinde belirli harf veya kelimeleri yazdıklarında otomatik olarak başka harf veya kelimelerle değiştirilmesini istemektedir. Mevcut araçlar ya yeterince düşük seviyede değildir (sistem genelinde çalışmaz) ya da kullanıcı tarafından özelleştirilemez yapıdadır. RM, macOS menubar'ında sessizce çalışan, Accessibility izni ile tüm uygulamalarda geçerli olan, kullanıcı tarafından tam olarak yapılandırılabilen bir metin replace motoru olarak bu boşluğu dolduracaktır.

---

## 2.2 Goals

1. Sistem genelinde (tüm uygulamalarda) harf ve kelime bazlı otomatik metin değiştirme.
2. Kullanıcının kolayca düzenleyebileceği, kalıcı olarak saklanan replace sözlükleri.
3. Tek tıkla aktif/pasif duruma geçiş.
4. CSV import/export ile toplu sözlük yönetimi.
5. macOS Services entegrasyonu ile seçili metni hızlıca sözlüğe ekleme.
6. Dock'ta görünmeden yalnızca menubar'dan yönetim.

---

## 2.3 Non-Goals

- iOS / iPadOS desteği (yalnızca macOS).
- iCloud senkronizasyonu (ilk sürüm).
- Per-application kısıtlama (ilk sürüm).
- Kullanım istatistikleri ve telemetri (ilk sürüm).
- App Store dağıtımı (Accessibility + CGEventTap App Store kısıtlamaları nedeniyle).
- Makro / multi-step replace zincirleri.

---

## 2.4 User Stories

| # | Aktör | Yetenek | Değer |
|---|-------|---------|-------|
| US-01 | Kullanıcı | Harf replace sözlüğü tanımlamak | Yanlış tuşa bastığımda doğru karakter yazılsın |
| US-02 | Kullanıcı | Kelime replace sözlüğü tanımlamak | Kısa kodlar yazarak uzun cümleler enjekte etmek |
| US-03 | Kullanıcı | Tek tıkla motoru aktif/pasif yapmak | İhtiyaç olmadığında müdahale olmasın |
| US-04 | Kullanıcı | Harf ve kelime replace'i bağımsız açıp kapamak | Sadece istediğim modu kullanmak |
| US-05 | Kullanıcı | CSV dosyasından sözlük içe aktarmak | Toplu olarak çok sayıda kural eklemek |
| US-06 | Kullanıcı | Mevcut sözlüğü CSV olarak dışa aktarmak | Yedek almak veya paylaşmak |
| US-07 | Kullanıcı | Seçili metni sağ tık menüsünden sözlüğe eklemek | Replace kuralını hızlıca tanımlamak |
| US-08 | Kullanıcı | Uygulama açılışında Accessibility iznini onaylamak | Uygulamanın çalışması için gerekli izni vermek |

---

## 2.5 Functional Requirements

| ID | Gereksinim |
|----|-----------|
| FR-01 | Uygulama, macOS Accessibility iznini kontrol etmeli; yoksa kullanıcıyı Sistem Ayarları'na yönlendirmelidir. |
| FR-02 | CGEventTap ile sistem genelinde keyDown event'leri yakalanmalıdır. |
| FR-03 | Motor pasif durumdayken event'ler müdahalesiz iletilmelidir. |
| FR-04 | Harf replace: Gelen karakter harf sözlüğünde eşleşirse, orijinal event iptal edilmeli ve yeni karakter enjekte edilmelidir. |
| FR-05 | Kelime replace: Karakterler buffer'da birikmeli; space/enter/noktalama geldiğinde buffer'daki kelime sözlükte aranmalıdır. Eşleşme varsa kelime uzunluğu kadar backspace + yeni kelime enjekte edilmelidir. |
| FR-06 | Harf replace ve kelime replace modları bağımsız checkbox ile açılıp kapatılabilmelidir. |
| FR-07 | Global aktif/pasif durum, menubar ikonuna sol tıklanarak değiştirilebilmelidir. |
| FR-08 | Menubar ikonu aktifken vurgulu, pasifken soluk görünmelidir. |
| FR-09 | Ayarlar penceresi, kelime ve harf replace kurallarını satır satır "orijinal,replace" formatında düzenlemeyi sağlamalıdır. |
| FR-10 | Sözlük verileri Application Support klasöründe JSON olarak kalıcı saklanmalıdır. |
| FR-11 | Aktiflik durumu ve mod bayrakları UserDefaults'ta saklanmalıdır. |
| FR-12 | Kelime replace listesi için CSV import (dosya seç → parse → ekle) desteklenmelidir. |
| FR-13 | Kelime replace listesi için CSV export (mevcut → dosya yaz) desteklenmelidir. |
| FR-14 | macOS Services mekanizması ile "RM – Sözlüğe Ekle" sağ tık seçeneği sunulmalıdır. |
| FR-15 | Services seçeneğine tıklandığında küçük bir popup açılmalı, replace karşılığı alındıktan sonra kelime sözlüğe eklenmelidir. |
| FR-16 | Uygulama Dock'ta görünmemelidir (LSUIElement = true). |
| FR-17 | Enjeksiyon sırasında kendi ürettiği event'leri tekrar yakalaması önlenmelidir (event source kontrolü). |

---

## 2.6 Non-Functional Requirements

| Boyut | Gereksinim | Ölçüm |
|-------|-----------|-------|
| Başlatma Süresi | < 300ms cold start | Xcode Instruments |
| Bellek | Baseline < 30 MB RAM | Instruments Allocations |
| Ana Thread Blokajı | Tüm UI güncelleme < 8ms | Time Profiler |
| Klavye Gecikmesi | Event işleme < 2ms | CGEventTap callback süresi |
| Güvenilirlik | Crash-free rate > 99.9% | Crash raporu |
| Disk Kullanımı | JSON dosyaları < 5 MB normal kullanımda | Dosya boyutu monitörü |
| Erişilebilirlik İzni | İzin yoksa uygulama çalışmaz, kullanıcı yönlendirilir | Manuel test |
| Infinite Loop Koruması | Kendi enjekte ettiği event'leri yakala**ma**malı | Integration test |

---

## 2.7 Constraints

- **CGEventTap** Accessibility iznine ihtiyaç duyar; App Store'da kullanılamaz.
- **App Sandbox** devre dışı bırakılmalıdır (CGEventTap + global event tap gereksinimi).
- **LSUIElement = YES**: Info.plist'te set edilmeli, Dock ikonu gizlenmelidir.
- **macOS Services**: NSServices Info.plist girişi gerektirir ve re-login sonrası aktif olur.
- **Hareket**: CGEventTap callback, RunLoop'ta çalışır; UI güncellemeleri MainActor'a dispatch edilmelidir.
- **Swift 5.9+**, Xcode 15+.

---

## 2.8 Acceptance Criteria

| AC | Kriter |
|----|--------|
| AC-01 | Accessibility izni verilmemişse, ayarlar açılır ve klavye yakalama başlamaz. |
| AC-02 | "a,b" harf kuralı tanımlandığında, tüm uygulamalarda "a" yazıldığında "b" görünür. |
| AC-03 | "brb,be right back" kelime kuralı tanımlandığında, "brb " yazıldığında "brb" silinip "be right back " yazılır. |
| AC-04 | Motor pasifken hiçbir tuşa müdahale edilmez. |
| AC-05 | Harf replace pasifken harf kuralları çalışmaz; kelime replace aktifken çalışır. |
| AC-06 | CSV import sonrası yeni kurallar anında aktif olur. |
| AC-07 | Services menüsünden eklenen kelime, anında replace listesine dahil olur. |
| AC-08 | Uygulama kapatılıp yeniden açıldığında tüm kurallar ve ayarlar geri yüklenir. |
| AC-09 | Enjeksiyon sırasında sonsuz döngü oluşmaz. |
| AC-10 | Dock'ta uygulama ikonu görünmez. |
