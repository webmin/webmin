#!/usr/bin/perl
# Render drop-down menus, dialogs, breadcrumbs and page links for the
# browser checks in ui-menu-dialog-browser.mjs.
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/..";
use WebminCore;
our ($root_directory, %text);
$root_directory = "$Bin/..";
$main::ui_page_assets_done = 1;
open(my $lang, '<', "$root_directory/lang/en") or die $!;
while (<$lang>) { $text{$1} = $2 if /^([^=]+)=(.*)/; }
close($lang);
%WebminCore::text = %text;
print '<!doctype html><html><head><meta charset="utf-8">';
print '<link rel="stylesheet" href="file://'.$root_directory.'/unauthenticated/css/ui-lib.css">';
print '<script defer src="file://'.$root_directory.'/unauthenticated/js/ui-lib.js"></script>';
print '<style>html{font:14px Arial,sans-serif}body{margin:0;padding:16px;background:var(--ui-surface);color:var(--ui-fg)}</style></head><body>';
print '<div class="ui_page" id="page">';

# Two menus side by side, so one closes when the other opens, and a
# third at the right edge of the window, which must flip to stay inside
my @items = (
	{ 'label' => 'New', 'icon' => 'file-plus', 'dialog' => 'dlg_rename',
	  'attrs' => { 'id' => 'item_new' } },
	{ 'label' => 'Open', 'href' => '#open', 'attrs' => { 'id' => 'item_open' } },
	'-',
	{ 'heading' => 'Danger' },
	{ 'label' => 'Delete', 'state' => 'danger', 'dialog' => 'dlg_confirm',
	  'attrs' => { 'id' => 'item_delete' } },
	{ 'label' => 'Off', 'disabled' => 1 },
	);
print ui_cluster([
	ui_dropdown('File', \@items, { 'icon' => 'file', 'id' => 'menu_file' }),
	ui_dropdown('', \@items, { 'icon' => 'ellipsis', 'caret' => 0, 'align' => 'end',
				   'title' => 'More', 'id' => 'menu_more' }),
	]);
print ui_tag('div', ui_dropdown('Edge', \@items, { 'id' => 'menu_edge' }),
	     { 'style' => 'position:absolute; right:4px; top:4px' });

# A form dialog filled from its opening button, and a confirmation whose
# form only closes it
print ui_dialog_button('Rename', 'dlg_rename', 'info', {
	'id' => 'open_rename',
	'values' => { 'name' => 'web01.conf', 'file' => 'web01.conf', 'keep' => 1 } });
print ui_dialog({
	'id' => 'dlg_rename',
	'title' => 'Rename',
	'form' => { 'action' => 'noop.cgi', 'method' => 'get', 'id' => 'rename_form' },
	'body' => ui_textbox('name', '', 20).ui_hidden('file', '').
		  ui_checkbox('keep', 1, 'Keep a copy', 0),
	'footer' => ui_action_button('Go', 'success', { 'type' => 'submit', 'id' => 'rename_go' }),
	'close' => 'Cancel' });
print ui_dialog({
	'id' => 'dlg_confirm',
	'title' => 'Delete',
	'state' => 'danger',
	'form' => { 'method' => 'dialog' },
	'body' => 'Really?',
	'footer' => [
		ui_action_button('Cancel', 'neutral', { 'id' => 'confirm_cancel',
			'attrs' => { 'data-ui-dialog-close' => '1', 'autofocus' => undef } }),
		ui_action_button('Delete', 'danger', { 'type' => 'submit', 'id' => 'confirm_go' }),
		] });

print ui_breadcrumb([ { 'icon' => 'home', 'href' => '#', 'title' => 'Home' },
		      [ 'etc', '#' ], { 'label' => 'webmin' } ]);
print ui_pager({ 'page' => 3, 'pages' => 9, 'href' => '#page=' });

# A submit button and a link that ask first. Submissions are counted
# rather than sent, so the page stays put.
print '<script>document.addEventListener("submit", function (e) { if (e.target.id !== "confirm_form") return; e.preventDefault(); window.submitted = (window.submitted || 0) + 1; });</script>';
print ui_form_start('noop.cgi', 'post', undef, "id='confirm_form'").
      ui_submit('Delete', 'confirm_submit', 0, "data-ui-confirm='Really delete?' ".
					       "data-ui-confirm-state='danger' data-ui-confirm-ok='Delete'").
      ui_form_end();
print ui_tag('a', 'Go', { 'href' => '#confirmed', 'id' => 'confirm_link',
			  'data-ui-confirm' => 'Leave?' });
print '</div></body></html>';
