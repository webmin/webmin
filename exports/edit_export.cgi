#!/usr/local/bin/perl
# edit_export.cgi
# Allow editing of one export to a client

use strict;
use warnings;
require './exports-lib.pl';
our (%text, %in, %gconfig);

&ReadParse();
my $via_pfs = 0;
my $nfsv = $in{'ver'} || &nfs_max_version("localhost");
my ($exp, %opts);

if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create_export");
	$via_pfs = $nfsv == 4 ? 1 : 0;
	$exp->{"pfs"} = "/export";
	$exp->{'active'} = 1;
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit_export");
	my @exps = &list_exports();
	$exp = $exps[$in{'idx'}];
	%opts = %{$exp->{'options'}};
	}

# WebNFS doesn't exist on Linux
my $linux = ($gconfig{'os_type'} =~ /linux/i) ? 1 : 0;

print "<script type=\"text/javascript\">\n";
print "function enable_sec(level) {\n";
print " if (level) {\n";
print "   document.forms[0].sec[1].disabled=0;\n";
print "   document.forms[0].sec[2].disabled=0;\n";
print "   } else {\n";
print "   document.forms[0].sec[1].disabled=1;\n";
print "   document.forms[0].sec[2].disabled=1;\n";
print "   document.forms[0].sec[0].checked=1;\n";
print " }\n}\n";
print "function enable_pfs(enable) {\n";
print" set_pfs_dir();\n";
print "if (enable == 1) {\n";
print "   document.forms[0].pfs.disabled=0;\n";
print "   document.forms[0].pfs_button.disabled=0;\n";
print "   document.forms[0].pfs_dir.disabled=0;\n";
print "   } else {\n";
print "   document.forms[0].pfs.disabled=1;\n";
print "   document.forms[0].pfs_button.disabled=1;\n";
print "   document.forms[0].pfs_dir.disabled=1;\n";
print "   }\n";
print "}\n";
print "function set_pfs_dir() {\n";
print "   var pfs = document.forms[0].pfs.value;\n";
print "   var dir = document.forms[0].dir.value;\n";
print "   if (document.forms[0].via_pfs[0].checked == 0) {\n";
print "      document.forms[0].pfs_dir.value = dir; }\n";
print "   else {\n";
print "      var reg = /\\/\$/;\n";
print "      dir = dir.replace(reg, \"\");\n";
print "      dir = dir.substring(dir.lastIndexOf(\"/\"));\n";
print "      document.forms[0].pfs_dir.value = pfs + dir; }\n";
print "}\n";
print "window.onload = function() {\n";
print "   enable_pfs(document.forms[0].via_pfs[0].checked);\n";
print "   if (document.forms[0].auth[0].checked == 1) {\n";
print "      enable_sec(0); }\n";
print "   else {\n";
print "      enable_sec(1); }\n";
print "   set_pfs_dir();\n";
print "}\n";
print "</script>\n";

print &ui_form_start("save_export.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("ver", $in{'ver'});
print &ui_table_start($text{'edit_details'}, "width=100%", 2);

# Show NFS pseudofilesystem (NFSv4)
if ($nfsv == 4) {
    print "<tr> <td>",&hlink("<b>$text{'edit_nfs_vers'}</b>","vers"),"</td>\n";
    printf "<td colspan=3><input type=radio name=via_pfs value=1 %s onclick=enable_pfs(1)> 4\n",
    $via_pfs ? "checked" : "";
    printf "<input type=radio name=via_pfs value=0 %s onclick=enable_pfs(0)> 3 (or lower)</td> </tr>\n",
    $via_pfs ? "" : "checked";
    
    print "<tr> <td>",&hlink("<b>$text{'edit_pfs'}</b>","pfs"),"</td>\n";
    printf "<td colspan=3><input name=pfs size=40 value=\"$exp->{'pfs'}\" onkeyup=set_pfs_dir()>";
    print &file_chooser_button2("pfs", 1, "pfs_button", ($via_pfs == 0)),"</td> </tr>\n";
} else {
    printf "<tr><td><input type=hidden name=via_pfs value=0></td></tr>\n";
}

# Show directory input
print &ui_table_row(&hlink(text{'edit_dir'}, "dir"),
	&ui_textbox("dir", $exp->{'dir'}, 60)." ".
	&file_chooser_button("dir", 1));

# XXX
#if ($nfsv == 4) {
#    print "$text{'edit_in'} <input style=\"background: rgb(238, 238, 238)\" name=pfs_dir size=40 readonly></td> </tr>\n";
#}

# Show active input
print &ui_table_row(&hlink($text{'edit_active'}, "active"),
	&ui_yesno_radio("active", $exp->{'active'}));

# Work out export destination
my $h = $exp->{'host'};
my ($mode, $host, $netgroup, $network, $netmask, $network6, $netmask6);
if ($h eq "=public") {
	$mode = 0;
	}
elsif ($h =~ /^gss\//) {
	$mode = 5;
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

# Work out authentication type
# XXX how does this sys/etc stuff work?
my $auth = "";
my $sec = "";
if ($h =~ /^gss\/krb5/) {
	$auth = "krb5";
	if ($h =~ /i$/) { $sec = "i"; }
	if ($h =~ /p$/) { $sec = "p"; }
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

if ($nfsv == 4) {
    print "<br>",&hlink("$text{'edit_auth'}","auth"),"</td>\n";
    
    printf "<td rowspan=5 valign=top><input type=radio name=auth value=0 %s onclick=enable_sec(0)> sys</td>\n",
    ($auth eq "") ? "checked" : "";
} else {
    printf "<td><input type=hidden name=auth value=0></td>\n";
}

if ($nfsv == 4) {
    printf "<tr><td colspan=3><input type=radio name=auth value=1 %s onclick=enable_sec(1)> krb5</td></tr>",
    ($auth eq "krb5") ? "checked" : "";
    printf "<tr><td colspan=3><input type=radio name=auth value=2 %s disabled> lipkey</td></tr>\n",
    ($auth eq "lipkey") ? "checked" : "";
    printf "<tr><td colspan=3><input type=radio name=auth value=3 %s disabled> spkm-3</td></tr>\n",
    ($auth eq "spkm") ? "checked" : "";

# Show security level input
print "<tr> <td>", &hlink("<b>$text{'edit_sec'}</b>", "sec"), "</td>\n";
printf "<td nowrap colspan=3><input type=radio name=sec value=0 %s> $text{'config_none'}\n",
    ($sec eq "") ? "checked" : "";
printf "<input type=radio name=sec value=1 %s> $text{'edit_integrity'}\n",
    ($sec eq "i") ? "checked" : "";
printf "<input type=radio name=sec value=2 %s> $text{'edit_privacy'}</td></tr>\n",
    ($sec eq "p") ? "checked" : "";
}

print &ui_table_end();

print &ui_table_start($text{'edit_security'}, "width=100%", 4);

# Show read-only input
print &ui_table_row(&hlink($text{'edit_ro'}, "ro"),
	&ui_yesno_radio("ro", defined($opts{'rw'}) ? 0 : 1));

# Show input for secure port
print &ui_table_row(&hlink($text{'edit_insecure'}, "insecure"),
	&ui_yesno_radio("insecure", defined($opts{'insecure'}) ? 0 : 1));

# Show subtree check input
print &ui_table_row(&hlink($text{'edit_subtree_check'}, "subtree_check"),
	&ui_yesno_radio("no_subtree_check",defined($opts{'no_subtree_check'})));

# Show nohide check input
print &ui_table_row(&hlink($text{'edit_hide'}, "hide"),
	&ui_yesno_radio("nohide", defined($opts{'nohide'})));

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
