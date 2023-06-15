#!/usr/local/bin/perl
# Show a page for manually editing host keys
# Only displays keys for now

use File::Basename;
require './sshd-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'keys_title'}, "");

# Work out and show the files
@files = &get_mlvalues($config{'sshd_config'}, "HostKey");

# If there are no HostKey entries assume default keys in use

if (scalar(@files) == 0) {
	if (-r (dirname($config{'sshd_config'}) . '/ssh_host_rsa_key')) {
		push(@files, (dirname($config{'sshd_config'}) . '/ssh_host_rsa_key'));
		}
	if (-r (dirname($config{'sshd_config'}) . '/ssh_host_dsa_key')) {
		push(@files, (dirname($config{'sshd_config'}) . '/ssh_host_dsa_key'));
		}
	if (-r (dirname($config{'sshd_config'}) . '/ssh_host_key')) {
		push(@files, (dirname($config{'sshd_config'}) . '/ssh_host_key'));
		}
	}

foreach $key (@files) {
	 $key = $key . ".pub";
	 }
	
$in{'file'} ||= $files[0];
&indexof($in{'file'}, @files) >= 0 || &error($text{'keys_none'});
print &ui_form_start("edit_keys.cgi");
print "<b>Key filename</b>\n";
print &ui_select("file", $in{'file'},
		 [ map { [ $_ ] } @files ]),"\n";
print &ui_submit($text{'keys_change'});
print &ui_form_end();

# Show the file contents
print &ui_form_start("save_manual.cgi", "form-data");
print &ui_hidden("file", $in{'file'}),"\n";
$data = &read_file_contents($in{'file'});
print &ui_textarea("data", $data, 20, 80),"<br>\n";
print &ui_submit($text{'save'});
print &ui_form_end();

&ui_print_footer("", $text{'index_return'});

