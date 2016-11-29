
function countUploads(files) {
    if(files.files.length = 0) return;
    var info = '';
    for (i = 0; i < files.files.length; i++) {
        info += files.files[i].name + '<br>';
    }
    $('#readyForUploadList').html(info);
}

function invertSelection() {
    var rows = document.getElementsByClassName('ui_checked_columns');

    for (i = 0; i < rows.length; i++)
        rowClick(rows[i]);
}

function selectAll() {
    var rows = document.getElementsByClassName('ui_checked_columns');

    for (i = 0; i < rows.length; i++) {
        var input = rows[i].getElementsByTagName('input')[0];
        if (!input.checked) {
            rowClick(rows[i]);
        }
    }
}

function invertSelection() {
    var rows = document.getElementsByClassName('ui_checked_columns');
    for (i = 0; i < rows.length; i++)
        rowClick(rows[i]);
}

function compressDialog() {
    if(checkSelected())
        $("#compressDialog").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
}

function compressSelected() {
    var filename = $('#compressSelectedForm input[name=filename]').val();
    if (filename != null && filename != "") {
        var method = $('#compressSelectedForm select[name=method] option:selected').val();
        $('#list_form').attr('action', "compress.cgi?arch=" + filename + "&method=" + method);
        $('#list_form').submit();
    } else {
        $('#compressSelectedForm input[name=filename]').popover('show');
        $('#compressSelectedForm input[name=filename]').focus();
    }
}

function removeDialog() {
    if(checkSelected()) {
        $('#items-to-remove').html('');

        $(".ui_checked_checkbox input[type='checkbox']:checked").each(function() {
        $('#items-to-remove').append($(this).val() + '<br>');
        });

        $("#removeDialog").modal({
        "backdrop"  : "static",
        "keyboard"  : true,
        "show"      : true
        });
    }
}

function removeSelected() {
    $('#list_form').attr('action', "delete.cgi");
    $('#list_form').submit();
}

function chmodDialog() {
    if(checkSelected())
        $("#chmodDialog").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
}

function chmodSelected() {
    var perms = $('#perms').val();
    var recursive = $('#recursive').prop('checked');
    if (perms != null && perms != "") {
        var applyto = $('#chmodForm select[name=applyto] option:selected').val();
        $('#list_form').attr('action', "chmod.cgi?perms=" + perms + "&applyto=" + applyto);
        $('#list_form').submit();
    }
}

function chownDialog() {
    if(checkSelected())
        $("#chownDialog").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
}

function chownSelected() {
    var owner = $('#chownForm input[name=owner]').val();
    var group = $('#chownForm input[name=group]').val();
    var recursive = $('#chown-recursive').prop('checked');
    if (owner == null || owner == "") {
        $('#chownForm input[name=owner]').popover('show');
        $('#chownForm input[name=owner]').focus();
    }
    if (group == null || group == "") {
        $('#chownForm input[name=group]').popover('show');
        $('#chownForm input[name=group]').focus();
    }

    if (owner != null && owner != "" && group != null && group != "") {
        $('#list_form').attr('action', "chown.cgi?owner=" + owner + "&group=" + group + "&recursive=" + recursive);
        $('#list_form').submit();
    }
}

function chattrDialog() {
    if(checkSelected())
        $("#chattrDialog").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
}

function chattrSelected() {
    var label = $('#chattrForm input[name=label]').val();

    var recursive = $('#chattr-recursive').prop('checked');
    if (label == null || label == "") {
        $('#chattrForm input[name=label]').focus();
    } else if (label != null && label != "" ) {
        $('#list_form').attr('action', "chattr.cgi?label=" + encodeURIComponent(label) + "&recursive=" + recursive);
        $('#list_form').submit();
    }
}

function chconDialog() {
    if(checkSelected())
        $("#chconDialog").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
}

function chconSelected() {
    var label = $('#chconForm input[name=label]').val();

    var recursive = $('#chcon-recursive').prop('checked');
    if (label == null || label == "") {
        $('#chconForm input[name=label]').focus();
    } else if (label != null && label != "" ) {
        $('#list_form').attr('action', "chcon.cgi?label=" + label + "&recursive=" + recursive);
        $('#list_form').submit();
    }
}

function renameDialog(file) {
    $("#renameForm input[name=name]").val(file);
    $("#renameForm input[name=file]").val(file);
    $("#renameDialog").modal({
      "backdrop"  : "static",
      "keyboard"  : true,
      "show"      : true
    });
}

function renameSelected() {
    var name = $('#renameForm input[name=name]').val();
    var file = $('#renameForm input[name=file]').val();
    if (name != null && name != "" && name != file) {
        $('#renameForm').submit();
    } else {
        $('#renameForm input[name=name]').popover('show');
        $('#renameForm input[name=name]').focus();
    }
}

function copySelected() {
    if(checkSelected()) {
        document.forms['list_form'].action = "copy.cgi";
        document.forms['list_form'].submit();
    }
}

function cutSelected() {
    if(checkSelected()) {
        document.forms['list_form'].action = "cut.cgi";
        document.forms['list_form'].submit();
    }
}

function browseForUpload() {
    $('#upfiles').click();
    return true;
}

function uploadFiles() {
    var files = document.getElementById('upfiles');
    if (files.files.length > 0)
        $('#upload-form').submit();
    else
        files.click();
}

function createFolderDialog() {
    $("#createFolderDialog").modal({
      "backdrop"  : "static",
      "keyboard"  : true,
      "show"      : true
    });

}

function createFolder() {
    var name = $('#createFolderForm input[name=name]').val();
    if (name != null && name != "")
        $("#createFolderForm").submit();
    else {
        $('#createFolderForm input[name=name]').popover('show');
        $('#createFolderForm input[name=name]').focus();
    }
}

function createFileDialog(path) {
    $("#createFileDialog").modal({
      "backdrop"  : "static",
      "keyboard"  : true,
      "show"      : true
    });
}

function createFile() {
    var name = $('#createFileForm input[name=name]').val();
    if (name != null && name != "")
        $("#createFileForm").submit();
    else {
        $('#createFileForm input[name=name]').popover('show');
        $('#createFileForm input[name=name]').focus();
    }
}

function downFromUrlDialog() {
    $("#downFromUrlDialog").modal({
      "backdrop"  : "static",
      "keyboard"  : true,
      "show"      : true
    });
}

function downFromUrl(path) {
    var link = $('#downFromUrlForm input[name=link]').val();
    if (link != null && link != "")
        $('#downFromUrlForm').submit();
    else {
        $('#downFromUrlForm input[name=link]').popover('show');
        $('#downFromUrlForm input[name=link]').focus();
    }
}

function selectUnselect(cb) {
    var rows = document.getElementsByClassName('ui_checked_columns');
    for (i = 0; i < rows.length; i++) {
        switch(cb.checked) {
            case true:
                selectRow(rows[i]);
                break;
            case false:
                unselectRow(rows[i]);
                break;
        }
    }
}

function rowClick(row) {
    var input = row.getElementsByTagName('input')[0];
    input.checked = !input.checked;
    if (input.checked) {
        row.className = row.className + ' hl-aw';
    }
    else {
        row.className = row.className.replace(' hl-aw', '');
    }
}

function selectRow(row) {
    var input = row.getElementsByTagName('input')[0];
    if(!input.checked) {
        input.checked = true;
        row.className = row.className + ' hl-aw';
    }
}

function unselectRow(row) {
    var input = row.getElementsByTagName('input')[0];
    if(input.checked) {
        input.checked = false;
        row.className = row.className.replace(' hl-aw', '');
    }
}

function viewReadyForUpload() {
    $("#readyForUploadDialog").modal({
      "backdrop"  : "static",
      "keyboard"  : true,
      "show"      : true
    });
}

function checkSelected() {
    var checkboxes = $(".ui_checked_checkbox input[type='checkbox']:checked");
    if(checkboxes.length == 0) {
        $("#nothingSelected").modal({
          "backdrop"  : "static",
          "keyboard"  : true,
          "show"      : true
        });
        return false
    }
    return true;
}

function searchDialog() {
    $("#searchDialog").modal({
        "backdrop"  : "static",
        "keyboard"  : true,
        "show"      : true
    });
}

function search() {
    var query = $('#searchForm input[name=query]').val();
    if (query != null && query != "")
        $("#searchForm").submit();
    else {
        $('#searchForm input[name=query]').popover('show');
        $('#searchForm input[name=query]').focus();
    }
}
