// Приёмник телеметрии + управление лицензиями станций САҢЛАҚ.
//
// Установка (5 минут, один раз):
// 1. Создайте новую пустую Google-таблицу (sheets.new).
// 2. Расширения → Apps Script.
// 3. Вставьте весь этот файл вместо содержимого Code.gs, сохраните.
// 4. Развернуть → Новое развёртывание → тип "Веб-приложение".
//    Выполнять от имени: "Я". Доступ: "Все".
// 5. Скопируйте URL вида https://script.google.com/macros/s/XXXX/exec
// 6. Вставьте его в autoload/telemetry.gd, в константу ENDPOINT_URL.
//
// Если файл уже был развёрнут раньше и вы просто обновили код (добавили
// лицензии) — URL менять не нужно: Развернуть → Управление развёртываниями →
// карандаш у активного → Версия: "Новая версия" → Развернуть.
//
// Появляются 3 листа:
// - "events"    — журнал событий со станций (часы игры, кнопки, ошибки).
// - "licenses"  — ваш прайс-лист по точкам. Столбцы:
//     license_key | venue_name | max_devices | status
//   license_key — та же строка, что даёте точке как --venue=... / ?venue=...
//   status — "active" или "revoked" (перестала платить — просто впишите revoked).
//   Пример строки для пакета "25000тг за 15 устройств":
//     arena_almaty_01 | ТРЦ Arena, Алматы | 15 | active
// - "stations"  — кто уже зарегистрировался под каждым license_key
//   (заполняется автоматически, руками не трогать).
//
// Если license_key станции не найден в "licenses" вообще — считаем её
// демо/неоформленной и НЕ блокируем (чтобы свои тестовые копии не легли).

function doPost(e) {
  var body = JSON.parse(e.postData.contents);
  if (body.action === "register") {
    return handleRegister_(body);
  }
  return handleEvents_(body);
}

function handleEvents_(body) {
  var sheet = getOrCreateSheet_("events", ["ts", "station_id", "venue", "event", "payload"]);
  var rows = body.rows || [];
  rows.forEach(function (row) {
    sheet.appendRow([
      row.ts || "",
      row.station_id || "",
      row.venue || "",
      row.event || "",
      JSON.stringify(row.payload || {}),
    ]);
  });
  return jsonOutput_({ ok: true });
}

function handleRegister_(body) {
  var licenseKey = body.license_key || "";
  var stationId = body.station_id || "";
  var licenses = getOrCreateSheet_("licenses", ["license_key", "venue_name", "max_devices", "status"]);
  var stations = getOrCreateSheet_("stations", ["license_key", "station_id", "first_seen", "last_seen"]);

  var licenseRow = findRow_(licenses, 0, licenseKey);
  if (!licenseRow) {
    return jsonOutput_({ ok: true, reason: "no_license_configured" });
  }
  var status = String(licenseRow[3] || "active").toLowerCase();
  if (status === "revoked") {
    return jsonOutput_({ ok: false, reason: "revoked" });
  }
  var maxDevices = Number(licenseRow[2]) || 0;

  var data = stations.getDataRange().getValues();
  var existingRow = -1;
  var seen = {};
  var distinctCount = 0;
  for (var i = 1; i < data.length; i++) {
    if (data[i][0] !== licenseKey) continue;
    if (!seen[data[i][1]]) {
      seen[data[i][1]] = true;
      distinctCount++;
    }
    if (data[i][1] === stationId) existingRow = i;
  }

  var now = new Date().toISOString();
  if (existingRow >= 0) {
    stations.getRange(existingRow + 1, 4).setValue(now);
    return jsonOutput_({ ok: true });
  }

  if (maxDevices > 0 && distinctCount >= maxDevices) {
    return jsonOutput_({ ok: false, reason: "device_limit", max_devices: maxDevices });
  }

  stations.appendRow([licenseKey, stationId, now, now]);
  return jsonOutput_({ ok: true });
}

function getOrCreateSheet_(name, headers) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.appendRow(headers);
  }
  return sheet;
}

function findRow_(sheet, colIndex, value) {
  var data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (data[i][colIndex] === value) return data[i];
  }
  return null;
}

function jsonOutput_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
