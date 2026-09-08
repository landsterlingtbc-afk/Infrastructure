// يُشغَّل تلقائيًا في كل عملية نشر على Netlify (انظر netlify.toml) — يكتب ملف public/env.js
// من متغيرات البيئة SUPABASE_URL و SUPABASE_ANON_KEY (نفس المتغيرات المستخدمة في دوال الخادم،
// انظر docs/SETUP.md). المفتاح anon مصمَّم من Supabase ليكون علنيًا وآمنًا داخل المتصفح — الحماية
// الفعلية مصدرها RLS في قاعدة البيانات، لا سرّية هذا المفتاح. مفتاح service_role لا يظهر هنا إطلاقًا.
const fs = require('fs');
const path = require('path');

const url = process.env.SUPABASE_URL || '';
const anonKey = process.env.SUPABASE_ANON_KEY || '';

if (!url || !anonKey) {
  console.warn('[gen-env] تحذير: SUPABASE_URL أو SUPABASE_ANON_KEY غير مضبوطين في متغيرات بيئة Netlify — سجّل الدخول لن يعمل حتى تُضاف من Site settings → Environment variables.');
}

const out = `window.__SUPABASE_URL__=${JSON.stringify(url)};\nwindow.__SUPABASE_ANON_KEY__=${JSON.stringify(anonKey)};\n`;
fs.writeFileSync(path.join(__dirname, '..', 'public', 'env.js'), out);
console.log('[gen-env] تم إنشاء public/env.js');
