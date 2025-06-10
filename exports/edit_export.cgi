#!/usr/local/bin/perl
# edit_export.cgi
# Allow editing of one export to a client

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './exports-lib.pl';
our (%text, %in, %gconfig);

&ReadParse();
my $nfsv = $in{'ver'} || &nfs_max_version("localhost");
my ($exp, %opts);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create_export");
	if ($nfsv >= 4) {
		$exp->{"pfs"} = "/export";
		}
	$exp->{'active'} = 1;
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit_export");
	my @exps = &list_exports();
	$exp = $exps[$in{'idx'}];
	%opts = %{$exp->{'options'}};
	if ($nfsv == 4) {
		# If no NFSv4 options are in use, use NFSv3 form
		if (!$exp->{'pfs'} && $exp->{'host'} !~ /^gss/ &&
		    !$opts{'sec'}) {
			$nfsv = 3;
			}
		}
	}

# WebNFS doesn't exist on Linux
my $linux = ($gconfig{'os_type'} =~ /linux/i) ? 1 : 0;

print &ui_form_start("save_export.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("ver", $in{'ver'});
print &ui_table_start($text{'edit_details'}, "width=100%", 2);

# Show directory input
print &ui_table_row(&hlink($text{'edit_dir'}, "dir"),
	&ui_textbox("dir", $exp->{'dir'}, 60)." ".
	&file_chooser_button("dir", 1));

# Show PFS directory
if ($nfsv == 4 && $in{'new'}) {
	print &ui_table_row(&hlink($text{'edit_pfs'}, "pfs"),
		&ui_opt_textbox("pfs", $exp->{'pfs'}, 60, $text{'edit_none'})." ".
		&file_chooser_button("dir", 1));
	}
elsif ($exp->{'pfs'}) {
	print &ui_table_row(&hlink($text{'edit_pfs'}, "pfs"),
		"<tt>".&html_escape($exp->{'pfs'})."</tt>");
	}

# Show active input
print &ui_table_row(&hlink($text{'edit_active'}, "active"),
	&ui_yesno_radio("active", $exp->{'active'}));

# Work out export destination
my $h = $exp->{'host'};
my ($mode, $host, $netgroup, $network, $netmask, $network6, $netmask6, $sec);
if ($h eq "=public") {
	$mode = 0;
	}
elsif ($h =~ /^gss\/(.*)/) {
	# To all clients, but with security required
	$mode = 3;
	$sec = $1;
	}
elsif ($h =~ /^\@(.*)/) {
	$mode = 1;
	$netgroup = $1;
	}
elsif ($h =~ /^([0-9\.]+)\/([0-9\.]+)$/) {
	$mode = 2;
	$network = $1;
	$netmask = $2;
	}
elsif ($h =~ /^([a-f0-9:]+)\/([0-9]+)$/i) {
	$mode = 6;
	$network6 = $1;
	$netmask6 = $2;
	}
elsif ($h eq "") {
	$mode = 3;
	}
else {
	$mode = 4;
	$host = $h;
	}

# Allowed hosts table
my @table;
push(@table, [ 3, $text{'edit_all'} ]);
push(@table, [ 4, $text{'edit_host'},
	       &ui_textbox("host", $host, 40) ]);
if (!$linux) {
	push(@table, [ 0, $text{'edit_webnfs'} ]);
	}
push(@table, [ 1, $text{'edit_netgroup'},
	       &ui_textbox("netgroup", $netgroup, 20) ]);
push(@table, [ 2, $text{'edit_network4'},
	       &ui_textbox("network", $network, 15)." ".
	       $text{'edit_netmask'}." ".
	       &ui_textbox("netmask", $netmask, 15) ]);
push(@table, [ 6,  $text{'edit_network6'},
	       &ui_textbox("network6", $network6, 40)."/".
	       &ui_textbox("netmask6", $netmask6, 6) ]);
print &ui_table_row(&hlink($text{'edit_to'}, "client"),
	&ui_radio_table("mode", $mode, \@table));

if ($nfsv >= 4) {
	# Show security level list
	$sec ||= $opts{'sec'};
	$sec ||= 'sys';
	print &ui_table_row(&hlink($text{'edit_secs'}, "secs"),
		&ui_multi_select("sec",
			[ map { [ $_, $text{'edit_sec_'.$_} ] }
			      split(/:/, $sec) ],
			[ [ 'sys', $text{'edit_sec_sys'} ],
			  [ 'krb5', $text{'edit_sec_krb5'} ],
			  [ 'krb5i', $text{'edit_sec_krb5i'} ],
			  [ 'krb5p', $text{'edit_sec_krb5p'} ],
			  [ 'lipkey', $text{'edit_sec_lipkey'} ],
			  [ 'spkm', $text{'edit_sec_spkm'} ] ],
			6, 1, 0));
	}

print &ui_table_end();

print &ui_table_start($text{'edit_security'}, "width=100%", 4);

# Show read-only input
print &ui_table_row(&hlink($text{'edit_ro'}, "ro"),
	&ui_yesno_radio("ro", defined($opts{'rw'}) ? 0 : 1));

# Show input for secure port
print &ui_table_row(&hlink($text{'edit_insecure'}, "insecure"),
	&ui_yesno_radio("insecure", defined($opts{'insecure'}) ? 1 : 0, 0, 1));

# Show subtree check input
print &ui_table_row(&hlink($text{'edit_subtree_check'}, "subtree_check"),
	&ui_yesno_radio("no_subtree_check",defined($opts{'no_subtree_check'})));

# Show nohide check input
print &ui_table_row(&hlink($text{'edit_hide'}, "hide"),
	&ui_yesno_radio("nohide", defined($opts{'nohide'}) ? 1 : 0, 0, 1));

# Show sync input
my $sync = defined($opts{'sync'}) ? 1 : defined($opts{'async'}) ? 2 : 0;
print &ui_table_row(&hlink($text{'edit_sync'}, "sync"),
	&ui_radio("sync", $sync,
		  [ map { [ $_, $text{'edit_sync'.$_} ] } (1, 2, 0) ]));

# Show root trust input
my $squash = defined($opts{'no_root_squash'}) ? 0 :
	      defined($opts{'all_squash'}) ? 2 : 1;
print &ui_table_row(&hlink($text{'edit_squash'}, "squash"),
	&ui_radio("squash", $squash,
		  [ [ 0, $text{'edit_everyone'} ],
		    [ 1, $text{'edit_except'} ],
		    [ 2, $text{'edit_nobody'} ] ]));

# Show untrusted user input
my $anonuid;
if (defined($opts{'anonuid'})) {
	$anonuid = getpwuid($opts{'anonuid'}) || $opts{'anonuid'};
	}
print &ui_table_row(&hlink($text{'edit_anonuid'}, "anonuid"),
	&ui_opt_textbox("anonuid", $anonuid, 20, $text{'edit_default'})." ".
	&user_chooser_button("anonuid", 0));

# Show untrusted group input
my $anongid;
if (defined($opts{'anongid'})) {
	$anongid = getgrgid($opts{'anongid'}) || $opts{'anongid'};
	}
print &ui_table_row(&hlink($text{'edit_anongid'}, "anongid"),
	&ui_opt_textbox("anongid", $anongid, 20, $text{'edit_default'})." ".
	&group_chooser_button("anongid", 0));

# Show input for relative symlinks
print &ui_table_row(&hlink($text{'edit_relative'}, "link_relative"),
	&ui_yesno_radio("link_relative", defined($opts{'link_relative'})));

# Show deny access input
print &ui_table_row(&hlink($text{'edit_noaccess'}, "noaccess"),
	&ui_yesno_radio("noaccess", defined($opts{'noaccess'})));

# Show untrusted UIDs input
print &ui_table_row(&hlink($text{'edit_uids'}, "squash_uids"),
	&ui_opt_textbox("squash_uids", $opts{'squash_uids'}, 20,
			$text{'edit_none'}));

# Show untrusted GIDs input
print &ui_table_row(&hlink($text{'edit_gids'}, "squash_gids"),
	&ui_opt_textbox("squash_gids", $opts{'squash_gids'}, 20,
			$text{'edit_none'}));

print &ui_table_end();

if (!$in{'new'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});
