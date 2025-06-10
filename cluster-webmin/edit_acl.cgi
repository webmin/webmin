#!/usr/local/bin/perl
# edit_acl.cgi
# Display a form for editing the ACL for some module for some user or group

require './cluster-webmin-lib.pl';
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
if ($user) {
	$aref = &remote_eval($serv->{'host'}, "acl",
		"\%rv = &get_module_acl('$who', '$mod->{'dir'}'); \\%rv");
	}
else {
	$aref = &remote_eval($serv->{'host'}, "acl",
		"\%rv = &get_group_module_acl('$who', '$mod->{'dir'}'); \\%rv");
	}
%access = %$aref;

# Display the editor form from this host
print &ui_form_start("save_acl.cgi", "post");
print &ui_hidden("_acl_mod", $in{'mod'}),"\n";
print &ui_hidden("_acl_host", $in{'host'}),"\n";
if ($in{'group'}) {
	print &ui_hidden("_acl_group", $who),"\n";
	}
else {
	print &ui_hidden("_acl_user", $who),"\n";
	}
print &ui_table_start(
    $mod->{'dir'} ? &text('acl_options', $mod->{'desc'}, &server_name($serv))
		  : &text('acl_optionsg', &server_name($serv)),
    "width=100%", 4);

if ($mod->{'dir'}) {
	# Show module config editing option
	print &ui_table_row($text{'acl_config'},
		&ui_radio("noconfig", $access{'noconfig'} ? 1 : 0,
			[ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]), 3);
	}

$mdir = &module_root_directory($mod->{'dir'});
if (!&foreign_exists($mod->{'dir'})) {
	# This server doesn't have the module .. use text editor
	print &ui_table_hr() if ($mod->{'dir'});
	local $raw;
	foreach $k (sort { $a cmp $b } keys %access) {
		$raw .= "$k=$access{$k}\n";
		}
	print &ui_table_row($text{'acl_raw'},
			    &ui_textarea("_acl_raw", $raw, 10, 70));
	}
elsif (-r "$mdir/acl_security.pl") {
	# Show the module's ACL editor
	print &ui_table_hr() if ($mod->{'dir'});
	&foreign_require($mod->{'dir'}, "acl_security.pl");
	&foreign_call($mod->{'dir'}, "acl_security_form", \%access);
	}

print &ui_table_end();
print "<input type=submit name=all value='",&text('acl_save1'),"'>\n";
print "<input type=submit value='",&text('acl_save2', &server_name($serv)),"'>\n";
print &ui_form_end();
&ui_print_footer("", $text{'index_return'});

