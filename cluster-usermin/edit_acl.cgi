#!/usr/local/bin/perl
# edit_acl.cgi
# Display a form for editing the ACL for some module for some user or group

require './cluster-usermin-lib.pl';
&ReadParse();

# Get hosts and module details
@hosts = &list_webmin_hosts();
if ($in{'whohost'} =~ /^(\d+),(\S*)$/) {
	# Coming from the module page, so know which host to look at
	($host) = grep { $_->{'id'} == $1 } @hosts;
	local ($u) = grep { $_->{'name'} eq $2 } @{$host->{'users'}};
	local ($g) = grep { $_->{'name'} eq $2 } @{$host->{'groups'}};
	$user = $u if ($u);
	$group = $g if ($g);
	($mod) = grep { $_->{'dir'} eq $in{'mod'} } @{$host->{'modules'}};
	}
elsif ($in{'modhost'} =~ /^(\d+),(\S*)$/) {
	# Coming from the user or group page, so know which host to look at
	($host) = grep { $_->{'id'} == $1 } @hosts;
	($mod) = grep { $_->{'dir'} eq $2 } @{$host->{'modules'}};
	if ($in{'user'}) {
		($user) = grep { $_->{'name'} eq $in{'user'} } @{$host->{'users'}};
		}
	else {
		($group) = grep { $_->{'name'} eq $in{'group'} } @{$host->{'groups'}};
		}
	}
else {
	# Find a host that has the user and module
	foreach $h (sort { $a->{'id'} <=> $b->{'id'} } @hosts) {
		local ($m) = grep { $_->{'dir'} eq $in{'mod'} } @{$h->{'modules'}};
		if ($in{'user'}) {
			local ($u) = grep { $_->{'name'} eq $in{'user'} }
					  @{$h->{'users'}};
			if ($u && (&indexof($in{'mod'}, @{$u->{'modules'}}) >= 0 ||
				   !$in{'mod'})) {
				$user = $u;
				$host = $h;
				$mod = $m;
				last;
				}
			}
		else {
			local ($g) = grep { $_->{'name'} eq $in{'group'} }
					  @{$h->{'groups'}};
			if ($g && (&indexof($in{'mod'}, @{$g->{'modules'}}) >= 0 ||
				   !$in{'mod'})) {
				$group = $g;
				$host = $h;
				$mod = $m;
				last;
				}
			}
		}
	$host || &error(&text('acl_efound',
			$in{'user'} ? $in{'user'} : $in{'group'}, $in{'mod'}));
	}
$who = $user ? $user->{'name'} : $group->{'name'};
@servers = &list_servers();
($serv) = grep { $_->{'id'} == $host->{'id'} } @servers;
$d = &server_name($serv);

$ga = "_ga" if (!$mod->{'dir'});
$desc = &text($user ? 'acl_title2'.$ga : 'acl_title3'.$ga,
		"<b>$who</b>", "<b>$mod->{'desc'}</b>", "<b>$d</b>");
&ui_print_header($desc, $text{'acl_title'}, "");

# Get the host's ACL options
&remote_foreign_require($serv->{'host'}, "acl", "acl-lib.pl");
$aref = &remote_eval($serv->{'host'}, "acl", "\%rv = &get_module_acl('$who', '$mod->{'dir'}'); \\%rv");
%access = %$aref;

# Display the editor form from this host
print "<form method=post action=save_acl.cgi>\n";
print "<input type=hidden name=_acl_mod value='$mod->{'dir'}'>\n";
print "<input type=hidden name=_acl_host value='$host->{'id'}'>\n";
if ($in{'group'}) {
	print "<input type=hidden name=_acl_group value='$group->{'name'}'>\n";
	}
else {
	print "<input type=hidden name=_acl_user value='$user->{'name'}'>\n";
	}
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",
	$mod->{'dir'} ? &text('acl_options', $mod->{'desc'}, &server_name($serv))
		      : &text('acl_optionsg', &server_name($serv)),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

if ($mod->{'dir'}) {
	print "<tr> <td><b>$text{'acl_config'}</b></td> <td>\n";
	printf "<input type=radio name=noconfig value=0 %s> $text{'yes'}\n",
		$access{'noconfig'} ? "" : "checked";
	printf "<input type=radio name=noconfig value=1 %s> $text{'no'}</td>\n",
		$access{'noconfig'} ? "checked" : "";
	print "<td width=50% colspan=2></td> </tr>\n";
	}

$mdir = &module_root_directory($mod->{'dir'});
if (!&foreign_exists($mod->{'dir'})) {
	# This server doesn't have the module .. use text editor
	print "<tr> <td colspan=4><hr></td> </tr>\n" if ($mod->{'dir'});
	print "<tr> <td colspan=4><b>$text{'acl_raw'}</b><br>\n";
	print "<textarea rows=10 cols=70 name=_acl_raw>\n";
	foreach $k (sort { $a cmp $b } keys %access) {
		print "$k=$access{$k}\n";
		}
	print "</textarea></td> </tr>\n";
	}
elsif (-r "$mdir/acl_security.pl") {
	print "<tr> <td colspan=4><hr></td> </tr>\n" if ($mod->{'dir'});
	&foreign_require($mod->{'dir'}, "acl_security.pl");
	&foreign_call($mod->{'dir'}, "acl_security_form", \%access);
	}

print "</table></td></tr></table>\n";
print "<input type=submit name=all value='",&text('acl_save1'),"'>\n";
print "<input type=submit value='",&text('acl_save2', &server_name($serv)),"'>\n";
print "</form>\n";
&ui_print_footer("", $text{'index_return'});

