#!/usr/local/bin/perl
# save_rfile.cgi
# Save an autoreply file

require './qmail-lib.pl';
&ReadParseMime();
my %access = &get_module_acl();
my $base = &simplify_path($access{'apath'} || $qmail_alias_dir);
my $file = &simplify_path($in{'file'});
&is_under_directory($base, $file) || &error(&text('rfile_efile', $in{'file'}));
$in{'file'} = $file;

$in{'replies_def'} || $in{'replies'} =~ /^\/\S+/ ||
	&error($text{'rfile_ereplies'});
$in{'period_def'} || $in{'period'} =~ /^\d+$/ ||
	&error($text{'rfile_eperiod'});

$in{'text'} =~ s/\r//g;
&open_lock_tempfile(FILE, ">$in{'file'}");
if (!$in{'replies_def'}) {
	&print_tempfile(FILE, "Reply-Tracking: $in{'replies'}\n");
	}
if (!$in{'period_def'}) {
	&print_tempfile(FILE, "Reply-Period: $in{'period'}\n");
	}
&print_tempfile(FILE, $in{'text'});
&close_tempfile(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}");

