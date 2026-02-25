# E-Ticket Database Management System (MSSQL)

Bu proje, kapsamlı bir elektronik biletleme sistemi (konser, spor, ulaşım vb.) için geliştirilmiş profesyonel bir veritabanı mimarisidir. 

## 🚀 Özellikler
- **Kapsamlı Şema:** Kullanıcılar, Etkinlikler, Mekanlar, Rezervasyonlar ve Biletler arasında ilişkisel yapı.
- **Otomatik Stok Yönetimi:** Triggerlar sayesinde bilet satıldığında kontenjan otomatik güncellenir.
- **Güvenli İşlemler:** Stored Procedure kullanımı ile atomik rezervasyon süreçleri.
- **Denetim Kayıtları:** Bilet kullanım ve giriş-çıkış loglama sistemi.

## 🛠 Kurulum
1. SQL Server Management Studio (SSMS) açın.
2. `sql-scripts/database_schema.sql` dosyasını çalıştırın.
3. Örnek verileri eklemek için `sql-scripts/sample_data.sql` dosyasını kullanın.

## 📊 Veritabanı Yapısı<img width="1540" height="780" alt="sql diagrams" src="https://github.com/user-attachments/assets/f6c3cf8f-0159-4a61-b029-ae6a8828e284" />



## 📝 Kullanılan Teknolojiler
- **RDBMS:** Microsoft SQL Server (MSSQL)
- **Dil:** T-SQL
