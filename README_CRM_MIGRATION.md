# Customer CRM code (moved from App-crm)

Customer role sources live under `lib/roles/customer/` (122 Dart files).

## Package name

`quickboom_crm_customer` — use imports like:

`package:quickboom_crm_customer/roles/customer/...`

## What was moved from `App-crm`

- `lib/roles/customer/` → here
- Customer-related tests → `test/`
- Shared support: `lib/core/`, `lib/shared/`, `lib/screens/`
- Supporting role copied for compile: `lib/roles/employee/`
- Company admin code: package `quickboom_company_admin` (`../company_admin_app`)

## App-crm (employee / admin app)

`App-crm/pubspec.yaml` depends on this folder:

```yaml
quickboom_crm_customer:
  path: ../customer-app
```

Imports: `package:quickboom_crm_customer/roles/customer/...`

## Run customer app

```bash
cd customer-app
flutter pub get
flutter run
```

## Legacy QB customer shell

Previous `qb_customer` UI is under `lib_legacy_qb/` and `test_legacy_qb/` (excluded from analyzer).
