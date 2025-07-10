#!/usr/local/bin/perl
# save_rfile.cgi
# Save an autoreply file

require (-r 'sendmail-lib.pl' ? './sendmail-lib.pl' :
	 -r 'qmail-lib.pl' ? './qmail-lib.pl' :
			     './postfix-lib.pl');
&ReadParseMime();
if (substr($in{'file'}, 0, length($access{'apath'})) ne $access{'apath'}) {
	&error(&text('rfile_efile', $in{'file'}));
	}
$in{'replies_def'} || $in{'replies'} =~ /^\/\S+/ ||
    $in{'replies'} =~ /^~\/\S+/ ||
	&error($text{'rfile_ereplies'});
$in{'period_def'} || $in{'period'} =~ /^\d+$/ ||
	&error($text{'rfile_eperiod'});
$in{'from_def'} || $in{'from'} =~ /\S/ ||
	&error($text{'rfile_efrom'});

$in{'text'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$in{'file'}");
if (!$in{'replies_def'}) {
	&print_tempfile(FILE, "Reply-Tracking: $in{'replies'}\n");
	}
if (!$in{'period_def'}) {
	&print_tempfile(FILE, "Reply-Period: $in{'period'}\n");
	}
if ($in{'no_autoreply'}) {
	&print_tempfile(FILE, "No-Autoreply: $in{'no_autoreply'}\n");
	}
foreach $r (split(/\r?\n/, $in{'no_regexp'})) {
	&print_tempfile(FILE, "No-Autoreply-Regexp: $r\n") if ($r =~ /\S/);
	}
if (!$in{'from_def'}) {
	&print_tempfile(FILE, "From: $in{'from'}\n");
	}
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&system_logged("cp autoreply.pl $module_config_directory");
&redirect("edit_alias.cgi?name=$in{'name'}&num=$in{'num'}");

