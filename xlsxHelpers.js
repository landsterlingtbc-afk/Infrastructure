// دوال مطابقة وتحليل الملفات — منقولة بالحرف من منطق العرض التجريبي
// (tbcdemo_1_v2.html) حتى تبقى قواعد المطابقة والتحقق كما اعتُمدت وجُرِّبت،
// بدل إعادة اختراعها وربما إدخال فروقات سلوك غير مقصودة.
const XLSX = require('xlsx');

function normalizeHeaderText(s) {
  return String(s == null ? '' : s)
    .replace(/[ً-ْـ‏‎]/g, '')
    .replace(/["'“”'،,]/g, '')
    .replace(/\s+/g, '')
    .trim()
    .toLowerCase();
}

// تحويل قيمة تاريخ من إكسل (كائن Date، رقم تسلسلي، أو نص) إلى نص YYYY-MM-DD
function parseExcelDateStr(v) {
  if (v == null || v === '') return null;
  if (v instanceof Date) return isNaN(v) ? null : v.toISOString().slice(0, 10);
  if (typeof v === 'number') {
    const d = new Date(Date.UTC(1899, 11, 30) + Math.round(v) * 86400000);
    return isNaN(d) ? null : d.toISOString().slice(0, 10);
  }
  const s = String(v).trim();
  if (!s) return null;
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (iso) return `${iso[1]}-${String(iso[2]).padStart(2, '0')}-${String(iso[3]).padStart(2, '0')}`;
  const dmY = s.match(/^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})/);
  if (dmY) return `${dmY[3]}-${String(dmY[2]).padStart(2, '0')}-${String(dmY[1]).padStart(2, '0')}`;
  const d = new Date(s);
  return isNaN(d) ? null : d.toISOString().slice(0, 10);
}

// يقرأ ملف إكسل (Buffer) ويُعيد أول ورقة تحتوي أعمدة مطابقة، أو أول ورقة بشكل افتراضي
function readWorkbookRows(buffer, headerHints) {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheetName = wb.SheetNames.find((n) => {
    const raw = XLSX.utils.sheet_to_json(wb.Sheets[n], { header: 1, defval: null });
    if (!raw.length || !raw[0]) return false;
    const hdr = raw[0].map((h) => normalizeHeaderText(h));
    return headerHints.some((hint) => hdr.some((h) => h.includes(normalizeHeaderText(hint))));
  }) || wb.SheetNames[0];
  return XLSX.utils.sheet_to_json(wb.Sheets[sheetName], { defval: null });
}

function rowGetter(row) {
  const keys = Object.keys(row || {});
  return (label) => {
    const nl = normalizeHeaderText(label);
    let k = keys.find((k) => normalizeHeaderText(k) === nl);
    if (k == null) k = keys.find((k) => normalizeHeaderText(k).includes(nl));
    return k != null ? row[k] : null;
  };
}

// بحسب توضيح صريح من المستخدم: الحصر مطلوب فقط لمدارس "اساسي مشترك" و"مستقل"
function isCountedSchoolType(t) {
  return t === 'اساسي مشترك' || t === 'مستقل';
}

// حالة سجل الحصر الفعلية: done إن status==='done'، وإلا late إن تجاوز تاريخه دون اكتمال، وإلا pending
function inventoryEffectiveStatus(status, dateStr, todayIso) {
  if (status === 'done') return 'done';
  if (dateStr && dateStr < todayIso) return 'late';
  return 'pending';
}

module.exports = {
  normalizeHeaderText,
  parseExcelDateStr,
  readWorkbookRows,
  rowGetter,
  isCountedSchoolType,
  inventoryEffectiveStatus,
};
