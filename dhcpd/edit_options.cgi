#!/usr/local/bin/perl
# edit_options.cgi
# Edit client options for some subnet, shared net, group, host or global

require './dhcpd-lib.pl';
require './params-lib.pl';
&ReadParse();
$conf = &get_config();

%access = &get_module_acl();
&error_setup($text{'eacl_aviol'});

$client = &get_parent_config();
push(@parents, $client);
foreach $i ($in{'sidx'}, $in{'uidx'}, $in{'gidx'}, $in{'idx'}) {
	$client = $client->{'members'}->[$i] if ($i ne '');
	push(@parents, $client);
	}

if ($client->{'name'} eq 'subnet') {
	$title = &text('eopt_subtitle',$client->{'values'}->[0]);
	$back = $text{'eopt_returnsub'};
	$backlink = "edit_subnet.cgi";
	&error("$text{'eacl_np'} $text{'eacl_pss'}") if !&can('r',\%access,$client);
	}
elsif ($client->{'name'} eq 'shared-network') {
	$title = &text('eopt_snettitle',$client->{'values'}->[0]);
	$back = $text{'eopt_returnshsub'};
	$backlink = "edit_shared.cgi";
	&error("$text{'eacl_np'} $text{'eacl_psn'}") if !&can('r',\%access,$client);
	}
elsif ($client->{'name'} eq 'host') {
	$title = &text('eopt_hosttitle',$client->{'values'}->[0]);
	$back = $text{'eopt_returnhost'};
	$backlink = "edit_host.cgi";
	&error("$text{'eacl_np'} $text{'eacl_psh'}") if !&can('r',\%access,$client);
	}
elsif ($client->{'name'} eq 'group') {
	@mc = &find("host", $client->{'members'});
	$title = &text('eopt_grouptitle',scalar(@mc));
	$back = $text{'eopt_returngroup'};
	$backlink = "edit_group.cgi";
	&error("$text{'eacl_np'} $text{'eacl_psg'}") if !&can('r',\%access,$client);
	}
else {
	$title = $text{'eopt_alltitle'};
	$back = $text{'eopt_returnindex'};
	$backlink = "";
	&error("$text{'eacl_np'} $text{'eacl_pglob'}") if !$access{'global'};
	}

# display
$backlink .= "?idx=".$in{'idx'}."&gidx=".$in{'gidx'}."&uidx=".$in{'uidx'}.
	     "&sidx=".$in{'sidx'} if (backlink);
&ui_print_header($title, $text{'eopt_header'}, "");

print &ui_form_start("save_options.cgi", "post");
print &ui_hidden("level",($in{'global'} ? "global" : $client->{'name'}) );
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("gidx", $in{'gidx'});
print &ui_hidden("uidx", $in{'uidx'});
print &ui_hidden("sidx", $in{'sidx'});
print &ui_table_start($text{'eopt_tabhdr'}, "width=100%", 4);
@opts = &find("option", $client->{'members'});

print "<tr>\n";
print &option_input($text{'eopt_chost'}, "host-name", \@opts, 3);
print &option_input($text{'eopt_defrouters'}, "routers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_smask'}, "subnet-mask", \@opts, 0);
print &option_input($text{'eopt_baddr'}, "broadcast-address", \@opts, 0);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_domname'}, "domain-name", \@opts, 3);
print &option_input($text{'eopt_dnsserv'}, "domain-name-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_domsearch'}, "domain-search", \@opts, 6);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_timeserv'}, "time-servers", \@opts, 2);
print &option_input($text{'eopt_logserv'}, "log-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_swapserv'}, "swap-server", \@opts, 2);
print &option_input($text{'eopt_rdpath'}, "root-path", \@opts, 3);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_nisdom'}, "nis-domain", \@opts, 3);
print &option_input($text{'eopt_nisserv'}, "nis-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_fontserv'}, "font-servers", \@opts, 2);
print &option_input($text{'eopt_xdmserv'}, "x-display-manager", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_statrouters'}, "static-routes", \@opts, 5);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_ntpserv'}, "ntp-servers", \@opts, 2);
print &option_input($text{'eopt_nbns'}, "netbios-name-servers", \@opts, 2);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_nbs'}, "netbios-scope", \@opts, 3);
print &option_input($text{'eopt_nbntype'}, "netbios-node-type", \@opts, 1);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_toffset'}, "time-offset", \@opts, 1);
print &option_input($text{'plib_serverid'}, "dhcp-server-identifier", \@opts, 3);
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_slpa'}, "slp-directory-agent", \@opts, 2,
		    $text{'eopt_slpaips'});
print "</tr>\n";

print "<tr>\n";
print &option_input($text{'eopt_slps'}, "slp-service-scope", \@opts, 3,
		    $text{'eopt_slpsonly'});
print "</tr>\n";

if ($config{'dhcpd_version'} >= 3) {
	# Show option definitions
	print "<tr><td colspan=4><hr></td></tr>\n";
	@defs = grep { $_->{'values'}->[1] eq 'code' &&
		       $_->{'values'}->[3] eq '=' } @opts;
	push(@defs, undef);
	for($i=0; $i<@defs; $i++) {
		$o = $defs[$i];
		print "<tr>\n";
		print "<td><b>$text{'eopt_def'}</b></td><td nowrap colspan=3>\n";
		print "$text{'eopt_dname'}\n";
		print &ui_textbox("dname_".$i, $o->{'values'}->[0], 15);
		print "$text{'eopt_dnum'}\n";
		print &ui_textbox("dnum_".$i, $o->{'values'}->[2], 4);
		print "$text{'eopt_dtype'}\n";
		my $a=scalar(@{$o->{'values'}})-1;
		print &ui_textbox("dtype_".$i, join(" ",@{$o->{'values'}}[4..$a]), 40);
		print "</td></tr>\n";
		}

	# Find option definitions at higher levels
	%optdef = ( );
	foreach $p (@parents) {
		@popts = &find("option", $p->{'members'});
		@pdefs = grep { $_->{'values'}->[1] eq 'code' &&
			        $_->{'values'}->[3] eq '=' } @popts;
		foreach $o (@pdefs) {
			$optdef{$o->{'values'}->[0]} = $o
				if ($o->{'values'}->[0]);
			}
		}

	# Show values for custom options
	if (keys %optdef) {
		@custom = grep { $optdef{$_->{'values'}->[0]} &&
				 $_->{'values'}->[1] ne 'code' } @opts;
		push(@custom, undef);
		push(@custom, undef) if (@custom%2 == 1);
		for($i=0; $i<@custom; $i++) {
			$o = $custom[$i];
			print "<tr><td><b>$text{'eopt_custom'}</b></td>\n";
			print "<td nowrap colspan=3>$text{'eopt_cname'}\n";
			local ($ov, @v) = @{$o->{'values'}};
			print &ui_select("cname_$i", $ov,
				[ [ "", "&nbsp;" ],
				  sort { $a cmp $b } keys %optdef ],
				1, 0, $ov ? 1 : 0);
			print "$text{'eopt_cval'}\n";
			print &ui_textbox("cval_$i", join(" ", @v), 40);
			print "</td></tr>\n";
			}
		}
	}
else {
	# Show custom numeric options
	print "<tr><td colspan=4><hr></td></tr>\n";
	@custom = grep { $_->{'values'}->[0] =~ /^option-(\S+)$/ &&
			 $_->{'values'}->[1] ne 'code' } @opts;
	push(@custom, undef);
	push(@custom, undef) if (@custom%2 == 1);
	for($i=0; $i<@custom; $i++) {
		$o = $custom[$i];
		print "<tr>\n" if ($i%2 == 0);
		print "<td><b>$text{'eopt_custom'}</b></td>\n";
		print "<td nowrap>$text{'eopt_cnum'}\n";
		my ($ov, @v) = @{$o->{'values'}};
        print &ui_textbox("cnum_".$i, ( $ov =~ /^option-(\S+)$/ ? $1 : '' ), 4);
		print "$text{'eopt_cval'}\n";
        print &ui_textbox("cval_".$i, join(" ", @v), 15);
		print "</tr>\n" if ($i%2 != 0);
		}
	}

if ($in{'global'}) {
	# Display options for subnets and hosts too
	print "<tr><td colspan=4><hr></td></tr>\n";
	print "<tr>\n";
	print &choice_input($text{'egroup_nchoice'}, "use-host-decl-names",
			    $conf, $text{'yes'}, "on", $text{'no'}, "off",
			    $text{'default'}, "");
	&display_params($conf, "global");
	}

print &ui_table_end();
print &ui_submit($text{'save'});
print &ui_form_end();

#print "<input type=submit value=\"$text{'save'}\"></form>\n"
#	if &can('rw',\%access,$client);

&ui_print_footer($backlink, $back);

# option_input(text, name, &config, type, [initial-boolean])
# types values:	0  - IP address
#		1  - Integer
#		2  - IP address list
#		3  - String
#		4  - Yes/no flag
#		5  - IP address pairs
#		6  - String list
sub option_input
{
my($rv, $v, $i);
for($i=0; $i<@{$_[2]}; $i++) {
	if ($_[2]->[$i]->{'values'}->[0] eq $_[1]) {
		$v = $_[2]->[$i];
		last;
		}
	}
$rv = "<td><b>$_[0]</b></td>\n";
if ($_[3] == 5 || $_[3] == 6 || $_[4]) { $rv .= "<td colspan=3 nowrap>"; }
else { $rv .= "<td nowrap>"; }

$rv .= &ui_radio($_[1]."_def", ( $v ? 0 : 1 ),
                [ [ 1, $text{'default'} ],
                [ 0, "&nbsp;" ] ]);

my @vl = $v ? @{$v->{'values'}} : ();
@vl = @vl[1..$#vl];
my $bool;
if ($_[4]) {
	$bool = shift(@vl);
	}
if ($_[3] == 0) {
    $rv .= &ui_textbox($_[1], $vl[0], 15);
	}
elsif ($_[3] == 1) {
    $rv .= &ui_textbox($_[1], $vl[0], 4);
	}
elsif ($_[3] == 2) {
	@vl = map { s/,//g; $_ } grep { $_ ne "," } @vl;
    $rv .= &ui_textbox($_[1], join(" ", @vl), 20);
	}
elsif ($_[3] == 3) {
	my $str = &oct_to_string($vl[0]);
    $rv .= &ui_textbox($_[1], $str, 20);
	}
elsif ($_[3] == 4) {
    $rv .= &ui_radio($_[1], $vl[0],
                [ [ 1, $text{'yes'} ],
                [ 0, $text{'no'} ] ]);
	}
elsif ($_[3] == 5) {
	@vl = grep { $_ ne "," } @vl;
    my $val;
	for($i=0; $i<@vl; $i+=2) {
		$val .= " " if ($i);
		$val .= $vl[$i].",".$vl[$i+1];
		}
    $rv .= &ui_textbox($_[1], $val, 50);
	}
elsif ($_[3] == 6) {
	@vl = map { s/,//g; $_ } grep { $_ ne "," } @vl;
    $rv .= &ui_textbox($_[1], join(" ", @vl), 50);
	}
if ($_[4]) {
	$rv .= &ui_checkbox($_[1]."_bool", 1, $_[4], lc($bool) eq "true");
	}
$rv .= "</td>\n";
return $rv;
}

sub oct_to_string
{
my @b = split(/:/, $_[0]);
my $rv;
foreach $b (@b) {
	if ($b !~ /^[A-z0-9]{1,2}$/) {
		# Wasn't actually in octet format after all.
		return $_[0];
		}
	$rv .= chr(hex($b));
	}
return $rv;
}

