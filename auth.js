// التحقق من هوية المستخدم وصلاحياته — يُستدعى في بداية كل Function حساسة.
// المتصفح يرسل رمز الدخول (JWT) الذي يُصدره Supabase Auth بعد تسجيل الدخول
// عبر ترويسة: Authorization: Bearer <token>
const { getSupabaseAdmin } = require('./supabaseAdmin');

// نتيجة ناجحة: { user, profile }  — user هو حساب auth.users، profile هو صف جدول profiles
// نتيجة فاشلة: { error: { statusCode, message } }
async function requireUser(event) {
  const authHeader = event.headers.authorization || event.headers.Authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    return { error: { statusCode: 401, message: 'مطلوب تسجيل الدخول — لا يوجد رمز دخول (Authorization header)' } };
  }
  const supabase = getSupabaseAdmin();
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data || !data.user) {
    return { error: { statusCode: 401, message: 'رمز الدخول غير صالح أو منتهي — الرجاء تسجيل الدخول مرة أخرى' } };
  }
  const { data: profile, error: profileErr } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', data.user.id)
    .single();
  if (profileErr || !profile) {
    return { error: { statusCode: 403, message: 'لا يوجد ملف صلاحيات لهذا الحساب — راجع مدير النظام' } };
  }
  return { user: data.user, profile };
}

// هل يملك هذا الملف الشخصي صلاحية "الرفع" (نفس منطق can('upload') في العرض التجريبي)؟
function canUpload(profile) {
  return profile.role === 'admin' || profile.role === 'engineer';
}

// نفس منطق canUploadInventory(): رفع الحصر مقصور على الإدارة، أو من يُمنح صراحة
// (يُضاف لاحقًا كإعداد في جدول منفصل عند الحاجة — حاليًا: الإدارة فقط + المهندسون
// الذين تملك صلاحية الرفع العامة، مطابقةً للسلوك الافتراضي "mode: all" في العرض التجريبي)
function canUploadInventory(profile) {
  return canUpload(profile);
}

// نطاق المدارس التي يحق لهذا المستخدم رؤيتها/تعديل بياناتها (يوازي execScopedSchools
// المبني على session.engineer / session.sup في العرض التجريبي)
function scopeFilterForSchools(profile) {
  if (profile.role === 'admin') return null; // بلا قيد
  if (profile.role === 'engineer') return { column: 'engineer', value: profile.person_name };
  if (profile.role === 'supervisor') return { column: 'supervisor', value: profile.person_name };
  return { column: 'id', value: '__none__' };
}

module.exports = { requireUser, canUpload, canUploadInventory, scopeFilterForSchools };
