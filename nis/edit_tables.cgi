#!/usr/local/bin/perl
# edit_tables.cgi
# Allow the selection of and display a NIS table for editing

require './nis-lib.pl';
&ui_print_header(undef, $text{'tables_title'}, "");
&ReadParse();

$mode = &get_server_mode();
if ($mode == 0 || !(&get_nis_support() & 2)) {
	print "<p>$text{'tables_emaster'}<p>\n";
	&ui_print_footer("", $text{'index'});
	exit;
	}
elsif ($mode == 2) {
	print "<p>$text{'tables_eslave'}<p>\n";
	&ui_print_footer("", $text{'index'});
	exit;
	}

@tables = &list_nis_tables();
@domains = &unique(map { $_->{'domain'} } @tables);
$in{'table'} = int($in{'table'});

print "<form action=edit_tables.cgi method=post>\n";
print "<input type=submit value='$text{'tables_switch'}'>\n";
print "<select name=table>\n";
foreach $t (@tables) {
	$t->{'desc'} = $text{"desc_".$t->{'table'}};
	$t->{'desc'} = $t->{'table'} if (!$t->{'desc'});
	$t->{'desc'} .= " ($t->{'domain'})" if (@domains > 1);
	printf "<option value=%d %s>%s</option>\n",
		$t->{'index'}, $in{'table'} eq $t->{'index'} ? 'selected' : '',
		$t->{'desc'};
	}
print "</select></form>\n";

$t = $tables[$in{'table'}];
$type = $in{'text'} ? undef : $t->{'type'};
print "<b>",&text('tables_header', $t->{'desc'},
		   "<tt>".join(" ", @{$t->{'files'}})."</tt>"),"</b><p>\n";
if ($type eq 'hosts') {
	&show_nis_table([ $text{'hosts_ip'},
			  $text{'hosts_name'} ],
			$t, '\s+', [ 0, 1 ]);
	}
elsif ($type eq 'networks') {
	&show_nis_table([ $text{'networks_name'},
			  $text{'networks_ip'} ],
			$t, '\s+', [ 0, 1 ]);
	}
elsif ($type eq 'group' || $type eq 'group_shadow') {
	&show_nis_table([ $text{'group_name'},
			  $text{'group_gid'},
			  $text{'group_members'} ],
			$t, ':', [ 0, 2, 3 ], "width=100%");
	}
elsif ($type eq 'passwd_shadow' || $type eq 'passwd_shadow_full' ||
       $type eq 'passwd') {
	&show_nis_table([ $text{'passwd_name'},
			  $text{'passwd_uid'},
			  $text{'passwd_real'},
			  $text{'passwd_home'},
			  $text{'passwd_shell'} ],
			$t, ':', [ 0, 2, 4, 5, 6 ], "width=100%");
	}
elsif ($type eq 'services') {
	&show_nis_table([ $text{'services_name'},
			  $text{'services_proto'},
			  $text{'services_port'} ],
			$t, '[\s/]+', [ 0, 2, 1 ]);
	}
elsif ($type eq 'services2') {
	&show_nis_table([ $text{'services_name'},
			  $text{'services_proto'},
			  $text{'services_port'} ],
			$t, '[\s/]+', [ 0, 1, 2 ]);
	}
elsif ($type eq 'protocols') {
	&show_nis_table([ $text{'protocols_name'},
			  $text{'protocols_number'},
			  $text{'protocols_aliases'} ],
			$t, '\s+', [ 0, 1, -2 ]);
	}
elsif ($type eq 'netgroup') {
	&show_nis_table([ $text{'netgroup_name'},
			  $text{'netgroup_members'} ],
			$t, '\s+', [ 0, -1 ]);
	}
elsif ($type eq 'ethers') {
	&show_nis_table([ $text{'ethers_mac'},
			  $text{'ethers_ip'} ],
			$t, '\s+', [ 0, 1 ]);
	}
elsif ($type eq 'rpc') {
	&show_nis_table([ $text{'rpc_name'},
			  $text{'rpc_number'},
			  $text{'rpc_aliases'} ],
			$t, '\s+', [ 0, 1, -2 ]);
	}
elsif ($type eq 'netmasks') {
	&show_nis_table([ $text{'netmasks_net'},
			  $text{'netmasks_mask'} ],
			$t, '\s+', [ 0, 1 ]);
	}
elsif ($type eq 'aliases') {
	&show_nis_table([ $text{'aliases_from'},
			  $text{'aliases_to'} ],
			$t, '[\s:]+', [ 0, 1 ]);
	}
else {
	# Allow editing of file directly
	print "<form method=post action=save_file.cgi enctype=multipart/form-data>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	$fnum = 0;
	foreach $f (@{$t->{'files'}}) {
		print "<table border>\n";
		print "<tr $tb> <td><b>",&text('tables_file', "<tt>$f</tt>"),
		      "</b></td> </tr>\n";
		print "<tr $cb> <td><textarea name=data_$fnum rows=20 cols=80>";
		open(FILE, $f);
		print <FILE>;
		close(FILE);
		print "</textarea></td></tr></table><br>\n";
		$fnum++;
		}
	print "<input type=submit value='$text{'tables_ok'}'></form>\n";
	}

if ($config{'manual_build'}) {
	print &ui_hr();
	print "<table width=100%><tr>\n";
	print "<form action=build.cgi>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	print "<td><input type=submit value='$text{'tables_build'}'></td>\n";
	print "<td>$text{'tables_buildmsg'}</td>\n";
	print "</form></tr></table>\n";
	}

&ui_print_footer("", $text{'index_return'});

# show_nis_table(&headers, &table, splitter, &columns, params)
sub show_nis_table
{
local @f = @{$_[1]->{'files'}};
local $lines = 0;
open(FILE, $f[0]);
while(<FILE>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	push(@lines, $_);
	$lines++ if (/\S/);
	$empty = 0 if (/\S/);
	}
close(FILE);
if ($config{'max_size'} && $lines > $config{'max_size'}) {
	# Display a search form
	print "<form action=edit_tables.cgi>\n";
	print "<input type=hidden name=table value='$in{'table'}'>\n";
	local $sel = "<select name=field>\n";
	local $n = 0;
	foreach $f (@{$_[0]}) {
		$sel .= sprintf "<option value=%s %s>%s</option>\n",
			$n, $in{'field'} == $n ? 'selected' : '', $f;
		$n++;
		}
	$sel .= "</select>\n";
	print &text('tables_find', $t->{'desc'}, $sel,
		    "<input name=what size=15 value='$in{'what'}'>"),
		    "&nbsp;&nbsp;&nbsp;\n";
	print "<input type=submit value='$text{'tables_search'}'></form>\n";
	}
if ($lines && (defined($in{'field'}) || !$config{'max_size'} ||
	       $lines <= $config{'max_size'})) {
	# Show table records
	print "<a href='edit_$t->{'type'}.cgi?table=$in{'table'}'>",
	      "$text{'tables_add'}</a><br>\n";
	print "<table border $_[4]>\n";
	print "<tr $tb> ",(map { "<td><b>$_</b></td>" } @{$_[0]}),"</tr>\n";
	local ($c, @c) = @{$_[3]};
	local $lnum = 0;
	local $matches = 0;
	foreach $l (@lines) {
		local @r = split($_[2], $l);
		if ($l =~ /\S/ && (!defined($in{'field'}) ||
		    $r[$_[3]->[$in{'field'}]] =~ /$in{'what'}/i)) {
			print "<tr $cb><td><a href='edit_$t->{'type'}.cgi?",
			      "line=$lnum&table=$in{'table'}'>",
			      &html_escape($r[$c]),"</a></td>\n";
			foreach $i (@c) {
				if ($i < 0) {
					print "<td>",&html_escape(join(" ", @r[-$i .. $#r])),"<br></td>\n";
					}
				else {
					print "<td>",&html_escape($r[$i]),"<br></td>\n";
					}
				}
			$matches++;
			}
		$lnum++;
		}
	if (!$matches) {
		print "<tr $cb> <td colspan=",scalar(@{$_[3]}),">",
		      "$text{'tables_nomatch'}</td> </tr>\n";
		}
	print "</table>\n";
	}
else {
	print "<b>",&text('tables_none', $t->{'desc'}),"</b><p>\n";
	}
print "<a href='edit_$t->{'type'}.cgi?table=$in{'table'}'>",
      "$text{'tables_add'}</a>&nbsp;&nbsp;\n";
print "<a href='edit_tables.cgi?table=$in{'table'}&text=1'>",
      "$text{'tables_text'}</a><p>\n";
}

