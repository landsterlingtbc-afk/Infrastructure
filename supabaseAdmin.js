// عميل Supabase بصلاحية service_role — يعمل فقط داخل الخادم (Netlify Functions)
// ولا يصل إليه المتصفح إطلاقًا. هذا هو ما يجعل فرض الصلاحيات هنا حقيقيًا
// (بخلاف العرض التجريبي الذي كانت كل صلاحياته شكلية في الواجهة فقط).
const { createClient } = require('@supabase/supabase-js');

function getSupabaseAdmin() {
  const url = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) {
    throw new Error('متغيرات البيئة SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY غير مضبوطة على Netlify');
  }
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

module.exports = { getSupabaseAdmin };
