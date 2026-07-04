# HRM ERP — Flutter + Supabase

A skeleton Clean-Architecture Flutter app wired to a live Supabase backend
(project `erp-hrm-crm-payroll`, ref `hbzzvttszanbecmdmuce`).

## What's here

- **Auth**: email/password sign-in via `supabase_flutter`, session-aware routing (`go_router` redirects to `/login` when signed out), plus a sign-up screen for self-serve account creation.
- **Dashboard**: live KPI cards (employee count, present today, on leave, payroll due) pulled directly from Postgres via `.count()` queries.
- **Employees**: searchable list + detail screen, backed by a repository (`EmployeeRepository` / `EmployeeRepositoryImpl`) following the doc's Clean Architecture split (`domain` = contracts, `data` = Supabase implementation). Includes a full create/edit form (hr/admin only — RLS enforces this regardless of what the UI shows) and document upload/view against a private Supabase Storage bucket.
- **Attendance**: check-in/check-out writing to the `attendance` table with an upsert on `(employee_id, date)`.
- **Leave**: apply for leave with a date-range picker. Managers/hr/admin get a second **Approvals** tab showing their team's pending requests with one-tap approve/reject (RLS scopes "team" automatically — managers see direct reports, hr/admin see everyone).
- **Payroll**: employees see their own payslips; hr/admin get a **Payroll Admin** screen (gear icon in the app bar, or via More) to create a monthly run, auto-generate payslips from each employee's current salary structure, and mark a run as paid.
- **CRM**: tabbed leads/deals view.
- **Projects**: list + detail (tasks tab, milestones tab), status-colored cards.
- **Task Tracking**: "My Tasks" view grouped by status (To Do → In Progress → In Review → Blocked → Done), tap to advance status, log hours against a task.
- **Scheduling**: upcoming agenda (meetings/shifts/deadlines/reminders) pulled from events you created or were invited to, with a create-event dialog.

CRM, Projects, Tasks, and Scheduling are reachable from the **More** tab (6th bottom-nav item) rather than crowding the main tab bar.

State management is Riverpod throughout (`presentation/providers`); navigation is `go_router` with a persistent bottom-nav `ShellRoute` (`presentation/shared/widgets/app_shell.dart`).

## Getting started

This environment can't run the Flutter toolchain (no network access to
pub.dev), so you'll need to do the following on your own machine:

```bash
flutter pub get
flutter run
```

The Supabase URL and anon key are already filled in as defaults in
`lib/core/constants/app_config.dart`. For multiple environments (dev/staging/prod),
override them at build time instead of editing the file:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

## Creating your first user

Since there's no sign-up screen yet, create a test user directly:

1. Supabase Dashboard → Authentication → Add user (or use the Admin API).
2. Insert a matching row into `employees` with that user's `id` as `user_id`, and a `role` of `'admin'` so you can see everything while testing:

```sql
insert into employees (user_id, emp_code, first_name, last_name, email, join_date, role)
values ('<auth-user-uuid>', 'EMP-0001', 'Jane', 'Doe', 'jane@example.com', current_date, 'admin');
```

3. Sign in with that email/password in the app.

## What's stubbed / not yet built

- Push notifications (Firebase Cloud Messaging is in pubspec.yaml but not wired up)
- Offline support (Hive is in pubspec.yaml but not wired up)
- PDF payslip export
- Custom app icon (currently the default Flutter launcher icon)

Everything else originally listed here — password reset, project/task creation forms, schedule event attendee invites, Kanban drag-and-drop, payroll proration for absences, full org-hierarchy access control — has been built. See git log for details on each.

## Database modules (Supabase project `hbzzvttszanbecmdmuce`)

| Module | Tables |
|---|---|
| HR core | departments, employees, employee_documents |
| Attendance/Leave | attendance, leave_types, leave_balances, leave_requests, holidays |
| Payroll | salary_structures, payroll_runs, payslips, expense_claims |
| CRM | clients, leads, deals, crm_activities |
| Projects | projects, project_members, milestones |
| Tasks | tasks, task_comments, time_logs |
| Scheduling | schedule_events, schedule_attendees |
| System | notifications, audit_logs |

All 28 tables have RLS enabled with role-aware policies (admin/hr/manager/employee) and are fully indexed on their foreign keys.

## CI/CD: building and testing without installing Flutter locally

A GitHub Actions workflow (`.github/workflows/build.yml`) builds this app in the cloud on every push to `main`:

- **Web** → builds `flutter build web` and deploys it to GitHub Pages. You get a shareable URL to open in any browser.
- **Android** → builds a release APK and attaches it to a new GitHub Release. Download the `.apk` and install it on an Android device (you'll need to allow "install from unknown sources" once).

### One-time setup after pushing this repo to GitHub

1. **Enable Pages**: repo → Settings → Pages → under "Build and deployment", set Source to **GitHub Actions**.
2. Push to `main` (or run the workflow manually from the Actions tab) — the first run creates the Pages site and the first Release.
3. Find your web URL under Settings → Pages once the `deploy-web` job finishes, and your APK under the repo's Releases tab.

No Firebase, Vercel, or other third-party account is required — everything runs on GitHub's own infrastructure.

iOS builds aren't included here since they need Apple Developer signing certificates; ask if you want that added later (GitHub Actions does support macOS runners for this).

## Folder structure

```
lib/
├── core/          # constants, theme, router, error types, formatters
├── data/          # Supabase datasource, models, repository implementations
├── domain/        # entities, repository contracts
└── presentation/  # riverpod providers + screens, grouped by module
```
