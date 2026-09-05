// Приёмник телеметрии САҢЛАҚ.
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
// После этого в таблице появится лист "events" — каждая строка это одно
// событие со станции: время, station_id, название точки, тип события, payload.

function doPost(e) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName("events");
  if (!sheet) {
    sheet = SpreadsheetApp.getActiveSpreadsheet().insertSheet("events");
    sheet.appendRow(["ts", "station_id", "venue", "event", "payload"]);
  }
  var body = JSON.parse(e.postData.contents);
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
  return ContentService.createTextOutput(JSON.stringify({ ok: true }))
    .setMimeType(ContentService.MimeType.JSON);
}
