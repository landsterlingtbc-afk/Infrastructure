// يحوّل صفوف قاعدة البيانات (snake_case) إلى نفس أسماء الحقول (camelCase) التي
// تتوقعها الواجهة الأمامية القديمة (SCHOOL_MASTER / PENDING_TICKETS / ...)
// حتى تعمل آلاف أسطر العرض والحسابات الحالية دون أي تعديل عليها.

function mapSchool(s) {
  if (!s) return s;
  return {
    id: s.id,
    name: s.name,
    stage: s.stage,
    gender: s.gender,
    cityAr: s.city_ar,
    cityEn: s.city_en,
    zone: s.zone,
    legacyZoneCode: s.legacy_zone_code,
    officeName: s.office_name,
    address: s.address,
    buildingOwn: s.building_own,
    buildingSize: s.building_size,
    schoolSize: s.school_size,
    shift: s.shift,
    schoolType: s.school_type,
    buildingType: s.building_type,
    classrooms: s.classrooms,
    lat: s.lat,
    lon: s.lon,
    principalName: s.principal_name,
    principalPhone: s.principal_phone,
    engineer: s.engineer,
    supervisor: s.supervisor,
    supervisorDataIssue: s.supervisor_data_issue,
    cleaningVendor: s.cleaning_vendor,
    hvacVendor: s.hvac_vendor,
    omVendor: s.om_vendor,
    isAdmin: s.is_admin,
    isClosed: s.is_closed,
    isVacated: s.is_vacated,
  };
}

function mapTicket(t) {
  if (!t) return t;
  return {
    id: t.id,
    status: t.status,
    statusAr: t.status_ar,
    isAdmin: t.is_admin,
    cr: t.cr,
    fin: t.fin,
    slaDays: t.sla_days,
    sla: t.sla,
    reopen: t.reopen,
    schoolNo: t.school_no,
    schoolResolved: t.school_resolved,
    school: t.school_name,
    cityAr: t.city_ar,
    cityEn: t.city_en,
    zone: t.zone,
    tso: t.tso,
    rawTso: t.raw_tso,
    tsoIssue: t.tso_issue,
    category: t.category,
    problem: t.problem,
    priority: t.priority,
    issue: t.issue,
    vendor: t.vendor,
    sourceSheet: t.source_sheet,
  };
}

function mapInventory(i) {
  if (!i) return i;
  const school = i.schools || null;
  return {
    id: i.id,
    schoolId: i.school_id,
    schoolName: school ? school.name : undefined,
    schoolType: school ? school.school_type : undefined,
    zone: school ? school.zone : undefined,
    engineer: school ? school.engineer : undefined,
    typeKey: i.type_key,
    supervisor: i.supervisor,
    date: i.date,
    status: i.status,
    data: i.data || {},
    bulkImportFile: i.bulk_import_file,
    updatedAt: i.updated_at,
    effectiveStatus: i.effectiveStatus,
    missingDetail: i.missingDetail,
  };
}

function mapVisit(v) {
  if (!v) return v;
  const school = v.schools || null;
  return {
    id: v.id,
    schoolId: v.school_id,
    schoolName: school ? school.name : undefined,
    zone: school ? school.zone : undefined,
    engineer: school ? school.engineer : undefined,
    supervisor: v.supervisor,
    siteCode: v.site_code,
    visitDate: v.visit_date,
    status: v.status,
    completedDate: v.completed_date,
    notes: v.notes,
    recommendations: v.recommendations,
    correctiveActions: v.corrective_actions,
    source: v.source,
    updatedAt: v.updated_at,
  };
}

module.exports = { mapSchool, mapTicket, mapInventory, mapVisit };
