#!/usr/local/bin/perl
# delete_list.cgi
# Delete a mailing list, after asking the user if he is sure

require './majordomo-lib.pl';
&ReadParse();
$name = $in{'name'};
($namere = $name) =~ s/\./\\./g;
%access = &get_module_acl();
&can_edit_list(\%access, $name) || &error($text{'delete_ecannot'});

# find aliases and files
$conf = &get_config();
$aliases_files = &get_aliases_file();
&foreign_call($aliases_module, "lock_alias_files", $aliases_files)
	if ($in{'confirm'});
@aliases = &foreign_call($aliases_module, "list_aliases", $aliases_files);
foreach $a (@aliases) {
	if ($a->{'name'} eq $name && $a->{'value'} =~ /-digestify/i) {
		&error($text{'delete_edigest'});
		}
	if ($a->{'name'} =~ /-digestify$/i && $a->{'value'} =~ /\s$namere\s/i) {
		$digestify = $a;
		}
	if ($a->{'name'} eq $name) {
		foreach $v (@{$a->{'values'}}) {
			$real_list = $1
				if ($v =~ /^\|\S*wrapper\s+resend.*\s(\S+)$/);
			}
		}
	}
@daliases = grep { $_->{'name'} =~ /^$namere$/i ||
		  $_->{'name'} eq $real_list ||
		  $_->{'name'} =~ /^$namere-(list|owner|approval|outgoing|request|archive)$/i ||
		  $_->{'name'} =~ /owner-$namere-outgoing$/i ||
		  $_->{'name'} =~ /$namere-outgoing-(list|owner|approval)$/i ||
		  $_ eq $digestify ||
		  $_->{'name'} =~ /^owner-$namere$/i } @aliases;
$ldir = &perl_var_replace(&find_value("listdir", $conf), $conf);
opendir(LDIR, $ldir);
while($f = readdir(LDIR)) {
	if ($f eq $name || $f =~ /^$namere\./) {
		push(@files, "$ldir/$f");
		}
	}
closedir(LDIR);

if ($in{'confirm'}) {
	# do the deletion
	foreach $f (@files) { &lock_file($f); }
	foreach $f (@files) {
		system("rm -rf \"$f\"");
		}
	foreach $f (@files) { &unlock_file($f); }
	@daliases = sort { $b->{'line'} <=> $a->{'line'} } @daliases;
	foreach $a (@daliases) {
		&foreign_call($aliases_module, "delete_alias", $a,
			      $aliases_file, $a ne $daliases[$#daliases]);
		}

	if ($digestify) {
		# delete the digestify alias from the 'parent' list
		foreach $a (@aliases) {
			$idx = &indexof($digestify->{'name'},@{$a->{'values'}});
			if ($idx >= 0) {
				splice(@{$a->{'values'}}, $idx, 1);
				&foreign_call($aliases_module,
					      "modify_alias", $a, $a);
				}
			}
		}
	&foreign_call($aliases_module, "unlock_alias_files", $aliases_files);

	# remove from ACLs
	&read_acl(undef, \%wusers);
	foreach $u (keys %wusers) {
		%uaccess = &get_module_acl($u);
		$uaccess{'lists'} = join(' ', grep { $_ ne $name }
					      split(/\s+/, $uaccess{'lists'}));
		&save_module_acl(\%uaccess, $u) if ($uaccess{'lists'} ne '*');
		}
	&webmin_log("delete", "list", $name);
	&redirect("");
	}
else {
	# css for table
	local $tcss='style="width: 98%; margin: 1% !important;"';
	local $dcss='style="text-align: right; vertical-align: middle; padding: 0.3em 1em !important; min_heigth: 5em;"';
	local $vcss='style="width: 40%; border: 1px solid lightgrey; padding: 0.3em !important;"';

	# ask the user if he is sure
	&ui_print_header(undef, $text{'delete_title'}.": ".&html_escape($in{'name'}), "");
	print ui_table_start(&text('delete_rusure', "<font color=\"red\">".&html_escape($name)."</font>"), undef, 2);
	print "<tr $cb> <td><table $tcss>\n";
	      "</b><br>\n";
	print "<ul>\n";
	foreach $f (@files) {
		print "<tt>",&html_escape($f),"</tt><br>\n";
		}
	print "</ul>\n";
	print "</td> </tr>\n";
	print "</table></td></tr></table>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td>".&text('delete_aliases'),"</td>";
	print "<tr $cb> <td><table $tcss>\n";
	print "<ul>\n";
	foreach $a (@daliases) {
		print "<tt>",&html_escape("$a->{'name'}: $a->{'value'}"),
		      "</tt><br>\n";
		}
	print "</ul>\n";
	print "</td> </tr>\n";
	print "</table></td></tr></table>\n";
	local $bcss=' style="padding: 10px; text-align: center;"';
	local $name_link="?name=".&urlize($in{'name'});
	print "<div $bcss><form action=\"delete_list.cgi".$name_link."&confirm=1\" method=\"post\">",
        	&ui_submit($text{'delete_ok'})."</form></div>\n";
	&ui_print_footer("edit_list.cgi?name=$name", $text{'edit_return'});
	}

