#!/usr/local/bin/perl
# save_afile.cgi
# Save a filter file

require './qmail-lib.pl';
&ReadParseMime();
&error_setup($text{'ffile_err'});
my %access = &get_module_acl();
my $base = &simplify_path($access{'apath'} || $qmail_alias_dir);
my $file = &simplify_path($in{'file'});
&is_under_directory($base, $file) || &error(&text('ffile_efile', $in{'file'}));
$in{'file'} = $file;

for($i=0; defined($in{"field_$i"}); $i++) {
	next if (!$in{"field_$i"});
	$in{"match_$i"} || &error($text{'ffile_ematch'});
	$in{"action_$i"} || &error($text{'ffile_eaction'});
	push(@filter, $in{"what_$i"}." ".$in{"action_$i"}." ".
		      $in{"field_$i"}." ".$in{"match_$i"}."\n");
	}
push(@filter, "2 ".$in{'other'}."\n") if ($in{'other'});

&open_lock_tempfile(FILE, ">$in{'file'}");
&print_tempfile(FILE, @filter);
&close_tempfile(FILE);
&redirect("edit_alias.cgi?name=$in{'name'}");

