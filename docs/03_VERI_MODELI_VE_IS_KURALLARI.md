# Veri Modeli ve İş Kuralları

## Uygulamanın ana JSON modeli
`company_data.data` içinde uygulama verisinin ana yapısı:

```text
income[]
expense[]
fixed[]
forecast[]
fxTransfers[]
creditCards[]
creditCardPayments[]
banking {
  banks[]
  accounts[]
  accountTransactions[]
  transfers[]
  overdrafts[]
  overdraftTransactions[]
  cardTransactions[]
  cardInstallments[]
  investmentTransactions[]
  reversals[]
  settings{}
}
mtpro {
  meetings[]
  projects[]
  costs[]
  quotes[]
  files[]
  activity[]
}
categories {
  income[]
  expense[]
  fixed[]
}
```

## Supabase ana tabloları
Kurulum/migration dosyalarında bulunan temel tablolar:
- companies
- company_members
- company_data
- company_backups
- company_invitations
- subscription_requests
- support_tickets
- account_deletion_requests
- audit_logs
- settings_change_requests
- company_finance_permissions
- financial_institutions
- bank_accounts
- bank_account_transactions
- credit_cards
- credit_card_transactions
- credit_card_installments
- overdraft_accounts
- overdraft_transactions
- investment_accounts
- term_deposits
- investment_transactions
- account_transfers
- payment_allocations
- finance_reversals

## Temel RPC'ler
Mevcut HTML kaynak kodunda kullanılan önemli RPC'ler:
- np_get_my_companies
- np_create_company
- np_get_company_data
- np_save_company_data
- np_add_daily_record
- np_update_daily_record_link
- np_create_company_backup
- np_invite_member
- np_accept_invitation
- np_get_team
- np_update_member_role
- np_remove_member
- np_cancel_invitation
- np_save_fx_rate
- np_request_subscription
- np_get_subscription_requests
- np_request_account_deletion
- np_get_app_admin_context
- np_log_client_activity
- np_create_support_ticket
- np_get_my_support_tickets
- np_admin_get_dashboard
- np_admin_get_users
- np_admin_get_support_tickets
- np_admin_update_support_ticket
- np_admin_get_account_deletion_requests
- np_admin_get_audit_logs
- np_create_settings_request
- np_get_settings_requests
- np_decide_settings_request
- np_mark_settings_request_applied

## Muhasebe/bakiye kuralları
1. Gelir banka hesabına tahsil edilirse banka bakiyesi artar.
2. Gider banka hesabından ödenirse banka bakiyesi azalır.
3. Kredi kartıyla gider yapılırsa banka bakiyesi o anda azalmaz; kart borcu artar.
4. Kart borcu ödendiğinde seçilen banka hesabı azalır, kart borcu azalır.
5. KMH kullanımı KMH borcunu artırır; normal banka bakiyesi ile karıştırılmaz.
6. Hesaplar arası transfer gelir/gider sayılmaz.
7. Transfer masrafı/vergi/komisyon gerçek gider sayılır.
8. Fon/vadeli/yatırım ana para aktarımı gelir/gider sayılmaz.
9. Yatırım getirisi/zararı ve komisyon/stopaj ayrı etkiler olarak raporlanır.
10. Silme/iptal işlemlerinde `reversals[]` / ters kayıt mantığı korunmalıdır.
11. Düzenleme işleminde eski finansal etki önce geri alınmalı, yeni etki yalnız bir kez uygulanmalıdır.
12. Çoklu ödeme/tahsilat parçaları aynı ana gelir/gider kaydına bağlı kalmalıdır.
13. Para birimleri birbirine karıştırılmamalı; TL karşılığı yalnız raporlama/değerleme amacıyla hesaplanmalıdır.
14. Dashboard'da aynı borç veya bakiye iki farklı kaynaktan iki kez sayılmamalıdır.
15. Alternatif projeksiyon katmanları gerçek kayıtları değiştirmemelidir.

## Veri güvenliği
- Canlı JSON yedek üzerinde doğrudan kalıcı dönüştürme yapılmamalıdır.
- Şema değişecekse migration + geri dönüş planı olmalıdır.
- Kullanıcı yetkileri firma bazlı ve rol bazlı korunmalıdır.
- Service-role anahtarı, DB şifresi veya kullanıcı parolaları kaynak koda yazılmamalıdır.
