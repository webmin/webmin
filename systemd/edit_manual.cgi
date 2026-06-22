#!/usr/local/bin/perl
# Show a page for manually editing discovered systemd unit files.

use strict;
use warnings;

require './systemd-lib.pl'; ## no critic

our (%access, %in, %text);

ReadParse();
error_setup($text{'manual_edit_err'});

systemd_acl_bool('manual') ||
	systemd_acl_bool('manual_user') ||
	systemd_acl_error('pmanual');

# File choices are constrained to discovered system and local user unit files.
my @files = grep { systemd_can_manual($_) } list_manual_unit_files();
@files || error(manual_empty_message());
my %allowed = map { $_->{'file'}, $_ } @files;
my $info = $allowed{$in{'file'}} || $files[0];
my $file = $info->{'file'};
my $data = read_manual_unit_file($info);
defined($data) || error($text{'manual_eread'});

ui_print_header(undef, $text{'manual_title'}, "");
my $desc = $info->{'scope'} eq 'user' ?
	text('manual_desc_user',
	     ui_tag('tt', html_escape($info->{'user'}))) :
	$text{'manual_desc'};
print ui_div($desc);

# Keep the selector separate so changing files does not submit edits.
print ui_form_start("edit_manual.cgi");
print ui_tag('b', html_escape($text{'manual_select'}));
print ui_select("file", $file,
	[ map { [ $_->{'file'}, manual_unit_file_label($_) ] } @files ]);
print " ", ui_submit($text{'manual_ok'});
print ui_form_end();

# The editor preserves raw unit text; validation is limited to the file path.
print ui_form_start("save_manual.cgi", "form-data");
print ui_hidden("file", $file);
print ui_table_start(undef, undef, 2);
print ui_table_row(undef, ui_textarea("data", $data, 35, 120), 2);
print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

ui_print_footer("index.cgi", $text{'index_return'});

# manual_unit_file_label(info)
# Returns the selector label for a manual-edit unit file.
sub manual_unit_file_label
{
my ($info) = @_;
return html_escape($info->{'file'});
}

# manual_empty_message()
# Returns an empty-state message for the current manual-edit ACL scope.
sub manual_empty_message
{
my $user = systemd_acl_default_user();
return text('manual_enone_user',
	    ui_tag('tt', html_escape($user)))
	if ($user && systemd_acl_bool('manual_user') &&
	    !systemd_acl_bool('manual'));
return $text{'manual_enone'};
}
