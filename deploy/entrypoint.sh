#!/usr/bin/env bash
# ICTHospital demo container start: schema + demo data (idempotent), demo
# branding, admin password from env, then serve. Safe on every container start.
set -uo pipefail
cd /app

mkdir -p database storage/framework/sessions storage/framework/views storage/framework/cache storage/logs bootstrap/cache
[ -f database/database.sqlite ] || touch database/database.sqlite
chmod -R ug+rwX storage bootstrap/cache database 2>/dev/null || true

php artisan migrate --force --no-interaction
php artisan db:seed --class=UserTableSeeder --force --no-interaction
php artisan db:seed --class=DemoDataSeeder --force --no-interaction
php artisan db:seed --class=FrontDeskDemoSeeder --force --no-interaction || echo "FrontDeskDemoSeeder skipped (non-fatal)"

if [ ! -f storage/oauth-private.key ]; then
  php artisan passport:keys --force --no-interaction || echo "passport keys skipped (non-fatal)"
fi

php artisan tinker --execute='
$inst = \App\Models\Institute::first();
if ($inst && $inst->name === "ICTHospital") { $inst->name = "Demo City Hospital (ICTHospital open-source demo)"; $inst->save(); echo "hospital renamed\n"; }
$pw = getenv("ADMIN_PASSWORD");
if ($pw) { \App\Models\User::where("login", "admin")->update(["password" => \Illuminate\Support\Facades\Hash::make($pw)]); echo "admin password set\n"; }
'

exec php artisan serve --host=0.0.0.0 --port "${PORT:-8000}"
