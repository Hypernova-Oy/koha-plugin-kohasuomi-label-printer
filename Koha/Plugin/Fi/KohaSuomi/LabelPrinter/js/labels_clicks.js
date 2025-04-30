Labels.init();



$("#regionDeleter").click(function() {Labels.GUI.deleteActive()});
$("#copyItem").click(function() {Labels.GUI.copyActiveRegion()});
$("#cloneItem").click(function() {Labels.GUI.cloneActiveRegion()});
$("#closeEditor").click(function() {Labels.GUI.SheetEditor.hide()});
$("#elementDispenser").draggable({
    helper: "clone"
});
$("#saveSheet").click(function() {
    var sheet = Labels.Sheets.getActiveSheet();
    sheet.save();
});
$("#importNew").click(function() {
    var name = $("#importName").val();
    var username = $("#importUsername").val();
    var userid = $("#importUserId").val();
    var file = $('#importFile').prop('files')[0];
    Labels.GUI.SheetList.importSheet(name, username, userid, file);

});
$("#printLabels").click(function(event) {
    event.preventDefault();
    var postData = {};
    postData.op           = "printLabels";
    postData.sheetId      = Labels.GUI.activeSheetId;
    postData.barcodes     = $("#labelPrinter textarea#barcodes").val();
    postData.ignoreErrors = ($("#labelPrinter input#ignoreErrors").prop("checked") == "true") ? 1 : 0;
    postData.leftMargin   = $("#labelPrinter input#leftMargin").val();
    postData.topMargin    = $("#labelPrinter input#topMargin").val();
    postData.bottomMargin = $("#labelPrinter input#bottomMargin").val();
    postData.rightMargin  = $("#labelPrinter input#rightMargin").val();

    var getParams = jQuery.param( postData );
    window.location="/cgi-bin/koha/plugins/run.pl?class=Koha%3A%3APlugin%3A%3AFi%3A%3AKohaSuomi%3A%3ALabelPrinter&method=tool&"+getParams;
})
