/*
 * plain.js
 * Behavior of the File Manager for themes without Bootstrap, on top of
 * the core widget script : row selection, the selection check before an
 * action on the selected entries, sending the selection form to an
 * action script with a dialog's fields as parameters, the rename and
 * delete dialogs, the permissions calculator and the upload options.
 * Everything is delegated from the document, keyed off data-filemin-*
 * attributes, so no handlers are generated in the markup.
 */
(function () {
	'use strict';
	var widgets = window.webminUiWidgets;

	// The selection form and its row checkboxes
	function listForm() {
		return document.getElementById('list_form');
	}
	function rowBoxes() {
		var form = listForm();
		return form ? Array.prototype.slice.call(
			form.querySelectorAll('input[type="checkbox"][name="name"]')) : [];
	}
	function selectedBoxes() {
		return rowBoxes().filter(function (box) { return box.checked; });
	}
	function selectRows(mode) {
		rowBoxes().forEach(function (box) {
			box.checked = mode === 'all' ? true :
				mode === 'none' ? false : !box.checked;
		});
	}

	// Called by the checkbox in the table heading
	window.selectUnselect = function (master) {
		selectRows(master.checked ? 'all' : 'none');
	};
	// Called by the rename link of a row, with the entry's name
	window.renameDialog = function (file) {
		widgets.openDialog('filemin_rename', { name: file, file: file });
	};

	// Send the selection form to a script, with parameters in its URL
	function submitSelection(script, params) {
		var form = listForm();
		if (!form) return;
		var url = script;
		var query = params ? params.toString() : '';
		if (query) url += (url.indexOf('?') >= 0 ? '&' : '?') + query;
		form.setAttribute('action', url);
		form.submit();
	}
	// The named, enabled fields of a dialog form as URL parameters,
	// leaving out the calculator's own fields
	function formParams(form) {
		var params = new URLSearchParams();
		Array.prototype.forEach.call(form.elements, function (field) {
			if (!field.name || field.disabled ||
			    field.hasAttribute('data-filemin-skip')) return;
			if (/^(?:file|submit|button|reset)$/.test(field.type)) return;
			if ((field.type === 'checkbox' || field.type === 'radio') &&
			    !field.checked) return;
			if (field.tagName === 'SELECT' && field.multiple) {
				Array.prototype.forEach.call(field.options, function (option) {
					if (option.selected) params.append(field.name, option.value);
				});
				return;
			}
			params.append(field.name, field.value);
		});
		return params;
	}

	// Toolbar entries : selecting rows, actions that need a selection,
	// and actions that send the selection straight to a script. Caught
	// before the widget script, so a dialog is not opened for an empty
	// selection.
	document.addEventListener('click', function (e) {
		var control = e.target.closest && e.target.closest(
			'[data-filemin-select], [data-filemin-selection], [data-filemin-submit]');
		if (!control) return;
		if (control.hasAttribute('data-filemin-select')) {
			e.preventDefault();
			selectRows(control.getAttribute('data-filemin-select'));
			return;
		}
		if (control.hasAttribute('data-filemin-selection') && !selectedBoxes().length) {
			e.preventDefault();
			e.stopImmediatePropagation();
			widgets.openDialog('filemin_nothing');
			return;
		}
		var script = control.getAttribute('data-filemin-submit');
		if (script) {
			e.preventDefault();
			submitSelection(script);
		}
	}, true);

	document.addEventListener('submit', function (e) {
		var form = e.target;
		if (!form.getAttribute) return;
		// A dialog acting on the selection : its fields become the
		// parameters of the action script
		var script = form.getAttribute('data-filemin-apply');
		if (script) {
			e.preventDefault();
			var dialog = form.closest('dialog');
			if (dialog && dialog.open) dialog.close();
			submitSelection(script, formParams(form));
			return;
		}
		// An upload : the options go in the URL, which the server reads
		// before the files arrive, and progress is shown in a popup
		var upload = form.getAttribute('data-filemin-upload');
		if (upload) {
			var action = upload;
			form.querySelectorAll('[data-filemin-upload-option]').forEach(function (box) {
				if (box.checked) {
					action += '&' + box.getAttribute('data-filemin-upload-option') + '=1';
				}
			});
			form.setAttribute('action', action);
			var tracker = form.getAttribute('data-filemin-tracker');
			if (tracker) {
				window.open(tracker, 'uptracker',
					'toolbar=no,menubar=no,scrollbars=no,location=no,resizable=no,' +
					'width=' + window.screen.width + ',height=' + window.screen.height);
			}
		}
	});

	// Directory upload : the file input picks directories instead
	document.addEventListener('change', function (e) {
		var box = e.target;
		if (box.matches && box.matches('[data-filemin-upload-dirs]')) {
			var input = box.form && box.form.querySelector('input[type="file"]');
			if (input) input.toggleAttribute('webkitdirectory', box.checked);
		}
	});

	// The delete dialog lists the selected entries as it opens
	document.addEventListener('ui-dialog-open', function (e) {
		if (e.target.id !== 'filemin_delete') return;
		var list = e.target.querySelector('#filemin_delete_items');
		if (list) {
			list.textContent = selectedBoxes().map(function (box) {
				return box.value;
			}).join('\n');
		}
	});

	// Permissions : the octal field, the checkbox matrix and the hidden
	// perms parameter stay in step through the shared calculator
	function syncPerms(fromMatrix) {
		var form = document.forms['chmod'];
		if (!form || typeof window.calc_chmod !== 'function') return;
		if (fromMatrix) {
			window.calc_chmod();
		}
		else if (/^[0-7]{4}$/.test(form.t_total.value) &&
			 typeof window.octalchange === 'function') {
			window.octalchange();
		}
		var perms = form.querySelector('input[name="perms"]');
		if (perms) perms.value = form.t_total.value;
	}
	document.addEventListener('input', function (e) {
		if (e.target.matches && e.target.matches('[data-filemin-chmod-octal]')) {
			syncPerms(false);
		}
	});
	document.addEventListener('change', function (e) {
		if (e.target.matches && e.target.matches('[data-filemin-chmod]')) {
			syncPerms(true);
		}
	});
	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', function () { syncPerms(false); });
	} else {
		syncPerms(false);
	}
})();
