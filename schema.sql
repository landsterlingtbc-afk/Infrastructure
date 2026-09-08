-- =====================================================================
-- منصة TBC — قاعدة البيانات الإنتاجية (Supabase / PostgreSQL)
-- =====================================================================
-- تصميم هذا المخطط يعكس نموذج البيانات المستخدم في العرض التجريبي
-- (tbcdemo_1_v2.html) لكن بدون أي بيانات وهمية مولَّدة عشوائيًا — كل جدول
-- هنا يبدأ فارغًا ويُعبَّأ فقط ببيانات حقيقية (رفع الملف الرئيسي للمدارس،
-- ثم رفع ملفات البلاغات/الحصورات/الزيارات الفعلية لاحقًا).
--
-- ملاحظة أمنية: منطق الصلاحيات التفصيلي (من يرى أي مدرسة/بلاغ تحديدًا) يُطبَّق
-- في طبقة Netlify Functions باستخدام مفتاح service_role. أما الحماية العامة
-- فمفعّلة هنا مباشرة عبر RLS (انظر القسم الأخير من هذا الملف): كل جدول مغلق
-- تمامًا أمام أي وصول مباشر من الواجهة الأمامية (بمفتاح anon أو بأي حساب) —
-- الوصول الوحيد المسموح هو عبر service_role من الخادم.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) profiles — تُنشأ تلقائيًا مرتبطة بكل مستخدم في auth.users (Supabase Auth)
-- ---------------------------------------------------------------------
do $$ begin
  create type user_role as enum ('admin', 'engineer', 'supervisor');
exception when duplicate_object then null;
end $$;

create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  display_name    text not null,
  role            user_role not null default 'supervisor',
  -- person_name يربط الحساب باسم المهندس/المشرف كما يظهر في عمود "المهندس"/"المشرف"
  -- بجدول schools — يُستخدم لتحديد نطاق ما يراه هذا المستخدم (نفس فكرة
  -- engineerName/supervisorName في العرض التجريبي)
  person_name     text,
  can_history     boolean not null default false,
  can_users       boolean not null default false,
  created_at      timestamptz not null default now()
);
comment on table profiles is 'ملف كل مستخدم: دوره واسمه التشغيلي وصلاحياته الإضافية — مكمّل لحساب auth.users';

-- عند إنشاء أي حساب جديد عبر Supabase Auth (تسجيل مستخدم)، يُنشأ له تلقائيًا صف في
-- profiles بدور "مشرف" افتراضيًا (أقل صلاحية) — يرفعه مدير النظام لاحقًا يدويًا من
-- محرر جداول Supabase إلى "admin" عند إنشاء أول حساب إدارة، أو من صفحة "المستخدمون"
-- في الواجهة لاحقًا (مرحلة قادمة).
create or replace function handle_new_auth_user() returns trigger
language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', new.email), 'supervisor');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

-- ---------------------------------------------------------------------
-- 2) schools — الملف الرئيسي للمدارس (Master File)
-- ---------------------------------------------------------------------
create table if not exists schools (
  id                    text primary key,          -- الرقم الوزاري، مثال: S-41895
  name                  text not null,
  stage                 text,
  gender                text,
  city_ar               text,
  city_en               text,
  zone                  text,
  legacy_zone_code      text,
  office_name           text,
  address               text,
  building_own          text,
  building_size         text,
  school_size           text,
  shift                 text,
  school_type           text,                       -- "اساسي مشترك" / "مستقل" / ...
  building_type         text,
  classrooms            numeric,
  lat                   double precision,
  lon                   double precision,
  principal_name        text,
  principal_phone       text,
  engineer              text,                        -- اسم المهندس المسؤول
  supervisor            text,                        -- اسم المشرف المسؤول
  supervisor_data_issue text,
  cleaning_vendor       text,
  hvac_vendor           text,
  om_vendor             text,
  is_admin              boolean not null default false,
  is_closed             boolean not null default false,
  is_vacated            boolean not null default false,
  updated_at            timestamptz not null default now(),
  updated_by            uuid references auth.users(id)
);
create index if not exists idx_schools_supervisor on schools(supervisor);
create index if not exists idx_schools_engineer on schools(engineer);
create index if not exists idx_schools_zone on schools(zone);
create index if not exists idx_schools_type on schools(school_type);
comment on table schools is 'الملف الرئيسي للمدارس — مصدر الحقيقة الوحيد لإسناد كل مدرسة (مشرف/مهندس/زون)';

-- دالة مساعدة: هل نوع المدرسة من الفئتين المشمولتين بالحصر؟
-- (بحسب توضيح صريح من المستخدم: الحصر يشمل فقط "اساسي مشترك" و"مستقل")
create or replace function is_counted_school_type(t text) returns boolean
language sql immutable as $$
  select t in ('اساسي مشترك', 'مستقل');
$$;

-- ---------------------------------------------------------------------
-- 3) tickets — البلاغات (Corrective Work Orders)
-- ---------------------------------------------------------------------
create table if not exists tickets (
  id               text primary key,               -- Record No / رقم البلاغ
  status           text,
  status_ar        text,
  is_admin         boolean not null default false,
  cr               date,                             -- تاريخ الإنشاء
  fin              date,                             -- تاريخ الانتهاء
  sla_days         integer,
  sla              text,                             -- On Track / PASS / FAIL ...
  reopen           boolean not null default false,
  school_no        text references schools(id),      -- قد تكون NULL إذا لم تُطابَق أي مدرسة
  school_resolved  boolean not null default false,
  school_name      text,                             -- نص خام كما ورد بالملف إن لم تُطابَق مدرسة
  city_ar          text,
  city_en          text,
  zone             text,
  tso              text,                             -- اسم المشرف بعد التحقق من الماستر فايل
  raw_tso          text,                             -- الاسم الخام كما ورد بالملف
  tso_issue        text,                             -- سبب عدم مطابقة الاسم إن وُجد
  category         text,
  problem          text,
  priority         text,
  issue            text,
  vendor           text,
  source_sheet     text,                             -- اسم ملف/ورقة المصدر (رئيسي / غير مغلقة)
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists idx_tickets_school on tickets(school_no);
create index if not exists idx_tickets_zone on tickets(zone);
create index if not exists idx_tickets_tso on tickets(tso);
create index if not exists idx_tickets_status on tickets(status);
comment on table tickets is 'البلاغات — يُدرَج/يُحدَّث كل صف من ملفي "البلاغات الرئيسي" و"غير المغلقة"';

-- ---------------------------------------------------------------------
-- 4) inventory_types — أنواع الحصر (٨ أنواع افتراضية + أنواع مخصَّصة يضيفها المستخدم)
-- ---------------------------------------------------------------------
create table if not exists inventory_types (
  key              text primary key,                -- safety_systems / ac / pumps / ...
  label            text not null,
  template_fields  jsonb,                            -- [{key,label,options}, ...] أو NULL
  template_source  text,
  is_builtin       boolean not null default false,
  created_at       timestamptz not null default now()
);
comment on table inventory_types is 'أنواع الحصر — يشمل ٨ أنواع أساسية وأي نوع إضافي يُنشئه المستخدم من صفحة الحصورات';

-- ---------------------------------------------------------------------
-- 5) inventories — سجلات الحصر (تشمل حصر السلامة كنوع خاص)
-- ---------------------------------------------------------------------
create table if not exists inventories (
  id                text primary key,                -- INV-{schoolId}-{typeKey}
  school_id         text not null references schools(id),
  type_key          text not null references inventory_types(key),
  supervisor        text,
  date              date,
  status            text not null default 'pending',  -- pending / done  (⚠ "late" تُشتق وقت العرض من date+status، لا تُخزَّن)
  data              jsonb not null default '{}'::jsonb, -- قيم الحقول الديناميكية (بما فيها "ملاحظات" — لا تُحتسب ضمن الاكتمال)
  bulk_import_file  text,
  updated_at        timestamptz not null default now(),
  updated_by        uuid references auth.users(id),
  unique (school_id, type_key)
);
create index if not exists idx_inventories_school on inventories(school_id);
create index if not exists idx_inventories_type on inventories(type_key);
comment on table inventories is 'سجل حصر واحد لكل (مدرسة, نوع) — بحسب توضيح المستخدم: مقصور فعليًا على مدارس is_counted_school_type فقط، ولا تُدخَل فيه أي بيانات لمدرسة من غير هاتين الفئتين';

create table if not exists inventory_files (
  id           bigint generated always as identity primary key,
  inventory_id text not null references inventories(id) on delete cascade,
  file_path    text not null,                        -- مسار الملف داخل Supabase Storage
  file_name    text not null,
  uploaded_at  timestamptz not null default now(),
  uploaded_by  uuid references auth.users(id)
);
comment on table inventory_files is 'الملفات المرفقة لسجل حصر — لا تُحتسَب ضمن شرط الاكتمال بحسب توضيح المستخدم';

-- ---------------------------------------------------------------------
-- 6) visits — الزيارات الميدانية
-- ---------------------------------------------------------------------
create table if not exists visits (
  id                  text primary key,              -- VP-{schoolId} لزيارات خطة الزيارات الحقيقية
  school_id           text not null references schools(id),
  supervisor          text,
  site_code           text,
  visit_date          date,                            -- تاريخ الزيارة المخطَّطة — لا يعني الإتمام إطلاقًا
  status              text not null default 'scheduled', -- scheduled / in_progress / completed / cancelled
  completed_date      date,
  completed_by        uuid references auth.users(id),
  notes               text,
  recommendations     text,
  corrective_actions  text,
  source              text,                            -- "خطة الزيارات" أو مصدر آخر
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists idx_visits_school on visits(school_id);
create index if not exists idx_visits_supervisor on visits(supervisor);
comment on table visits is 'الزيارات — الإكمال يُحدَّد حصرًا عبر status = ''completed''، تاريخ الزيارة وحده لا يعني الإتمام';

create table if not exists visit_status_history (
  id          bigint generated always as identity primary key,
  visit_id    text not null references visits(id) on delete cascade,
  from_status text,
  to_status   text not null,
  changed_at  timestamptz not null default now(),
  changed_by  uuid references auth.users(id),
  source      text
);

create table if not exists visit_files (
  id           bigint generated always as identity primary key,
  visit_id     text not null references visits(id) on delete cascade,
  kind         text not null default 'file',          -- 'file' أو 'photo'
  file_path    text not null,
  file_name    text,
  uploaded_at  timestamptz not null default now(),
  uploaded_by  uuid references auth.users(id)
);

-- ---------------------------------------------------------------------
-- 7) import_history — سجل عمليات رفع الملفات
-- ---------------------------------------------------------------------
create table if not exists import_history (
  id          bigint generated always as identity primary key,
  at          timestamptz not null default now(),
  user_id     uuid references auth.users(id),
  user_name   text,
  file_name   text,
  kind        text,
  summary     text
);
comment on table import_history is 'سجل "آخر عمليات الاستيراد" المعروض في صفحة تحديث البيانات';

-- ---------------------------------------------------------------------
-- 8) user_grants (اختياري / مرحلة لاحقة) — صلاحيات استثنائية بالاسم بدل الحساب
-- ---------------------------------------------------------------------
-- ملاحظة: بما أن كل مستخدم إنتاجي له الآن حساب حقيقي في profiles، فإن حقل
-- role + can_history + can_users في profiles يغني عن USER_GRANTS (localStorage)
-- المستخدم في العرض التجريبي. هذا الجدول غير مطلوب حاليًا وتُرك هذه الملاحظة
-- توثيقًا لقرار التصميم فقط.

-- ---------------------------------------------------------------------
-- بيانات أولية: أنواع الحصر الثمانية الأساسية (بدون أي بيانات مدارس/حصر فعلية)
-- ---------------------------------------------------------------------
insert into inventory_types (key, label, is_builtin, template_fields, template_source) values
  ('safety_systems', 'حصر أنظمة السلامة', true,
   '[{"key":"hasSystem","label":"هل يوجد منظومة سلامة متكاملة بالمبنى","options":["نعم","لا"]},
     {"key":"pumps","label":"مضخات الحريق","options":["يوجد","لا يوجد"]},
     {"key":"pumpsStatus","label":"حالة المضخات","options":["سليمة","بحاجة لصيانة","تالفة وتحتاج استبدال"]},
     {"key":"fireLineStatus","label":"حالة خط الحريق","options":["سليمة","بحاجة لصيانة","تالفة وتحتاج استبدال"]},
     {"key":"alarmSystem","label":"هل يوجد منظومة أنذار","options":["يوجد","لا يوجد"]},
     {"key":"alarmStatus","label":"حالة منظومة الانذار","options":["سليمة","بحاجة لصيانة","تالفة وتحتاج استبدال"]},
     {"key":"fireBoxes","label":"هل يوجد صناديق حريق","options":["يوجد","لا يوجد"]},
     {"key":"fireBoxesStatus","label":"حالة صناديق الحريق","options":["سليمة","بحاجة لصيانة","تالفة وتحتاج استبدال"]},
     {"key":"emergencyDoors","label":"هل يوجد أبواب طوارئ","options":["يوجد","لا يوجد"]},
     {"key":"guideSigns","label":"هل يوجد لوحات ارشادية","options":["يوجد","لا يوجد"]},
     {"key":"notes","label":"ملاحظات","options":null}]'::jsonb,
   'معتمد من نموذج حصر احتياجات منطقة المدينة المنورة لمنظومة وسائل الأمن والسلامة'),
  ('ac', 'حصر أجهزة التكييف', true,
   '[{"key":"unitsCount","label":"عدد وحدات التكييف (تقريبي)","options":["أقل من ١٠","١٠ - ٢٥","٢٦ - ٥٠","أكثر من ٥٠"]},
     {"key":"systemType","label":"نوع نظام التكييف","options":["مركزي (تشيلر/باكدج)","سبليت (منفصل)","شباك","مزيج (أكثر من نوع)"]},
     {"key":"operationalStatus","label":"الحالة التشغيلية العامة","options":["يعمل بكفاءة","يعمل بكفاءة جزئية","متوقف/معطل جزئيًا","متوقف بالكامل"]},
     {"key":"maintenanceStatus","label":"حالة الصيانة الدورية","options":["منتظمة وموثّقة","غير منتظمة","لم تُنفَّذ"]},
     {"key":"filtersStatus","label":"حالة الفلاتر","options":["نظيفة/مستبدلة حديثًا","بحاجة لتنظيف","بحاجة لاستبدال"]},
     {"key":"electricalSafety","label":"سلامة التوصيلات الكهربائية","options":["سليمة","بحاجة لمتابعة","غير آمنة"]},
     {"key":"noiseIssue","label":"وجود ضوضاء أو اهتزاز غير طبيعي","options":["لا يوجد","يوجد بشكل طفيف","يوجد بشكل واضح"]},
     {"key":"notes","label":"ملاحظات","options":null}]'::jsonb, null),
  ('pumps', 'حصر المضخات', true, null, null),
  ('extinguishers', 'حصر الطفايات', true, null, null),
  ('tanks', 'حصر الخزانات', true, null, null),
  ('exits', 'حصر مخارج الطوارئ', true, null, null),
  ('backup_lighting', 'حصر الإنارة الاحتياطية', true, null, null),
  ('buildings', 'حصر المباني', true, null, null)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 9) تشديد أمني: تفعيل RLS على كل جدول بلا أي سياسات مسموحة لـ anon/authenticated
-- ---------------------------------------------------------------------
-- كل قراءة وكتابة يجب أن تمر حصرًا عبر Netlify Functions (التي تستخدم مفتاح
-- service_role، وهو المفتاح الوحيد الذي يتجاوز RLS في Supabase تلقائيًا).
-- تفعيل RLS بلا أي policy يعني رفض أي وصول مباشر من الواجهة الأمامية
-- (سواء بمفتاح anon أو حتى بحساب مستخدم مسجّل) لهذه الجداول عبر
-- REST API التلقائي الذي يوفّره Supabase لكل جدول — وهذا هو المطلوب هنا،
-- فالتحقق من الصلاحيات (من يرى أي مدرسة/بلاغ) مكانه كود الخادم فقط.
alter table profiles enable row level security;
alter table schools enable row level security;
alter table tickets enable row level security;
alter table inventory_types enable row level security;
alter table inventories enable row level security;
alter table inventory_files enable row level security;
alter table visits enable row level security;
alter table visit_status_history enable row level security;
alter table visit_files enable row level security;
alter table import_history enable row level security;

-- الاستثناء الوحيد: يسمح لأي مستخدم مسجّل دخول بقراءة "ملفه الشخصي" فقط
-- (دوره واسمه) مباشرة من الواجهة الأمامية دون المرور بخادم — مفيد لعرض
-- اسم/دور المستخدم فور تسجيل الدخول دون طلب إضافي.
create policy "read own profile" on profiles
  for select using (auth.uid() = id);
