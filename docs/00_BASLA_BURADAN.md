# NakitPilot / MT-PRO-Finans — Claude Aktarım Paketi

Bu paket, NakitPilot / MT-PRO-Finans projesini başka bir yapay zekâ çalışma alanına (özellikle Claude Projects) devretmek için hazırlanmıştır.

## En doğru aktarım sırası

1. Claude'da yeni bir Project oluşturun: **NakitPilot / MT-PRO-Finans**.
2. Bu paketteki `docs/01_CLAUDE_ILK_MESAJ.txt` içeriğini ilk mesaja yapıştırın.
3. Project Files / Knowledge bölümüne şunları yükleyin:
   - `docs/02_PROJE_TAM_BAGLAM.md`
   - `docs/03_VERI_MODELI_VE_IS_KURALLARI.md`
   - `docs/04_SURUM_GECMISI.md`
   - `docs/05_SUPABASE_VE_CANLI_VERI_AKTARIMI.md`
   - `current/index-v0.8.2.html`
   - `sql/` klasöründeki SQL dosyaları
   - `requirements/ORIJINAL_BANKA_MERKEZI_GELISTIRME_TALEBI.txt`
4. NakitPilot uygulamasından **her firma için ayrı JSON yedek** indirin ve Claude Project'e yükleyin. Detaylar `docs/05_SUPABASE_VE_CANLI_VERI_AKTARIMI.md` dosyasındadır.
5. Supabase Storage'daki proje dosyalarını ayrıca arşivleyin. JSON yedek, dosyanın kendisini değil dosya bağlantısı/metadata bilgisini taşır.
6. Claude'a bundan sonra her geliştirmede **mevcut `index-v0.8.2.html` üzerinden devam etmesini, veri kaybına yol açmamasını ve sürüm numarasını yükseltmesini** söyleyin.

## Önemli

Bu pakette mevcut kaynak kod, SQL kurulum/migration dosyaları, sürüm notları ve proje bağlamı vardır. Ancak **Supabase'teki canlı şirket kayıtlarının güncel satırları bu pakette yoktur**; onları NakitPilot içindeki JSON dışa aktarma ile siz indirmelisiniz. Bu, en güncel canlı veriyi eksiksiz taşımak için zorunludur.
