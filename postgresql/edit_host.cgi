#!/usr/local/bin/perl
# edit_host.cgi
# Display a form for editing or creating an allowed host

require './postgresql-lib.pl';
&ReadParse();
$v = &get_postgresql_version();
if ($in{'new'}) {
	$type = $in{'new'};
	&ui_print_header(undef, $text{"host_create"}, "");
	$host = { 'type' => $type, 'netmask' => '0.0.0.0',
		  'auth' => 'trust', 'db' => 'all' };
	}
else {
	@all = &get_hba_config($v);
	$host = $all[$in{'idx'}];
	$type = $host->{'type'};
	&ui_print_header(undef, $text{"host_edit"}, "");
	}

# Start of form block
print &ui_form_start("save_host.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'host_header'}, "width=100%", 2);

# Allowed IP address, network or connection type
$mode = $type eq 'local' ? 3 :
	$host->{'cidr'} ne '' ? 4 :
	$host->{'netmask'} eq '0.0.0.0' ? 0 :
	$host->{'netmask'} eq '255.255.255.255' ? 1 : 2;
print &ui_table_row($text{'host_address'},
    &ui_radio_table("addr_mode", $mode,
	[ [ 3, $text{'host_local'} ],
	  [ 0, $text{'host_any'} ],
	  [ 1, $text{'host_single'},
	    &ui_textbox("host", $mode == 1 ? $host->{'address'} : '', 20) ],
	  [ 2, $text{'host_network'},
	    &ui_textbox("network", $mode == 2 ? $host->{'address'} : '', 20).
	    " ".$text{'host_netmask'}." ".
	    &ui_textbox("netmask", $mode == 2 ? $host->{'netmask'} : '', 20) ],
	  [ 4, $text{'host_network'},
	    &ui_textbox("network2", $mode == 4 ? $host->{'address'} : '', 20).
	    " ".$text{'host_cidr'}." ".
	    &ui_textbox("cidr", $mode == 4 ? $host->{'cidr'} : '', 5) ],
	]));

# Force SSL connection?
if ($type eq "hostssl" || $v >= 7.3) {
	print &ui_table_row($text{'host_ssl'},
		&ui_yesno_radio("ssl", $type eq "hostssl"));
	}

# Allowed databases
local $found = !$host->{'db'} || $host->{'db'} eq 'all' ||
	       $host->{'db'} eq 'sameuser' ||
	       $host->{'db'} eq 'samegroup';
@dbopts = ( [ "all", "&lt;$text{'host_all'}&gt;" ],
	    [ "sameuser", "&lt;$text{'host_same'}&gt;" ] );
if ($v >= 7.3) {
	push(@dbopts, [ "samegroup", "&lt;$text{'host_gsame'}&gt;" ]);
	}
eval {
	$main::error_must_die = 1;
	@dblist = &list_databases();
	};
foreach $d (@dblist) {
	push(@dbopts, $d);
	$found++ if ($host->{'db'} eq $d);
	}
push(@dbopts, [ '', $text{'host_other'} ]);
print &ui_table_row($text{'host_db'},
	&ui_select("db", $found ? $host->{'db'} : '', \@dbopts)." ".
	&ui_textbox("dbother",
		    $found ? "" : join(" ", split(/,/, $host->{'db'})), 40));

# Allowed users
if ($v >= 7.3) {
	print &ui_table_row($text{'host_user'},
		&ui_opt_textbox("user",
			$host->{'user'} eq 'all' ? '' :
			  join(" ", split(/,/, $host->{'user'})),
			40, $text{'host_uall'}, $text{'host_usel'}));
	}

# Authentication type
foreach $a ('password',
	    ($v < 8.4 ? ( 'crypt' ) : ( )),
	    ($v >= 7.2 ? ( 'md5' ) : ( )),
	    'trust', 'reject', 'ident', 'krb4', 'krb5',
	    ($v >= 7.3 ? ( 'pam' ) : ( )),
	    ($v >= 9.0 ? ( 'peer' ) : ( )) ) {
	$arg = $host->{'auth'} eq $a ? $host->{'arg'} : undef;
	$extra = undef;
	if ($a eq 'password') {
		# Password file
		$extra = &ui_checkbox("passwordarg", 1,
				      $text{'host_passwordarg'}, $arg)." ".
			 &ui_textbox("password", $arg, 40);
		}
	elsif ($a eq 'ident' || $a eq 'peer') {
		# Ident server
		$identarg = $arg eq "" ? 0 : $arg eq "sameuser" ? 2 : 1;
		$extra = &ui_radio_table($a."arg", $identarg,
			 [ [ 0, $text{'host_identarg0'} ],
			   [ 2, $text{'host_identarg1'} ],
			   [ 1, $text{'host_identarg2'},
			     &ui_textbox($a,
					 $identarg == 1 ? $arg : "", 40)." ".
			     &file_chooser_button($a) ] ]);
		}
	elsif ($a eq 'pam') {
		# PAM service
		$extra = &ui_checkbox("pamarg", 1, $text{'host_pamarg'},
				      $arg)." ".
			 &ui_textbox("pam", $arg, 20);
		}
	push(@auths, [ $a, $text{"host_$a"}, $extra ]);
	}
print &ui_table_row($text{'host_auth'},
	&ui_radio_table("auth", $host->{'auth'}, \@auths));

# End of the form
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_hosts.cgi", $text{'host_return'});

