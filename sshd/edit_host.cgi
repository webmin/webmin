#!/usr/local/bin/perl
# edit_host.cgi
# Display options for a new or existing host config

require (-r 'sshd-lib.pl' ? './sshd-lib.pl' : './ssh-lib.pl');
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'host_create'}, "", "chost");
	}
else {
	&ui_print_header(undef, $text{'host_edit'}, "", "ehost");
	$hconf = &get_client_config();
	$host = $hconf->[$in{'idx'}];
	$conf = $host->{'members'};
	}

# Get version and type
if (&get_product_name() eq 'usermin') {
	$version_type = &get_ssh_type();
	$version_number = &get_ssh_version();
	}
else {
	$version_type = $version{'type'};
	$version_number = $version{'number'};
	}

print &ui_form_start("save_host.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'host_header'}, "width=100%", 2);

# Name for this host
print &ui_table_row($text{'host_name'},
	&ui_opt_textbox("name", $host->{'values'}->[0] eq '*' ? '' :
				 $host->{'values'}->[0],
			50, $text{'hosts_all'}));

# Default user to login as
$user = &find_value("User", $conf);
print &ui_table_row($text{'host_user'},
	&ui_opt_textbox("user", $user, 20, $text{'host_user_def'}));

# Send keep-alive packets?
$keep = &find_value($version_number >= 3.8 ? 'ServerAliveInterval' : 'KeepAlive',
		    $conf);
print &ui_table_row($text{'host_keep'},
	&yes_no_default_radio("keep", $keep));

# Real hostname to connect to
$hostname = &find_value("HostName", $conf);
print &ui_table_row($text{'host_hostname'},
	&ui_opt_textbox("hostname", $hostname, 30, $text{'host_hostname_def'}));

# Port to use
$port = &find_value("Port", $conf);
print &ui_table_row($text{'host_port'},
	&ui_opt_textbox("port", $port, 6, $text{'default'}." (22)"));

# Ask for password if needed, or fail fast?
$batch = &find_value("BatchMode", $conf);
print &ui_table_row($text{'host_batch'},
	&yes_no_default_radio("batch", $batch));

# Compress SSH?
$comp = &find_value("Compression", $conf);
print &ui_table_row($text{'host_comp'},
	&yes_no_default_radio("comp", $comp));

# SSH compression level
if ($version_type ne 'ssh' || $version_number < 3) {
	if ($version_number < 6) {
		$clevel = &find_value("CompressionLevel", $conf);
		print &ui_table_row($text{'host_clevel'},
			&ui_radio("clevel_def", $clevel ? 0 : 1,
			[ [ 1, $text{'default'} ],
				[ 0, &ui_select("clevel", $clevel,
				[ map { [ $_, $text{"host_clevel_".$_} ] }
					(1 .. 9) ]) ] ]));
		}
	}

# Escape character in session
$escape = &find_value("EscapeChar", $conf);
print &ui_table_row($text{'host_escape'},
	&ui_radio("escape_def", $escape eq "" ? 1 :
				$escape eq "none" ? 2 : 0,
		  [ [ 1, $text{'default'}." (~.)" ],
		    [ 2, $text{'host_escape_none'} ],
		    [ 0, &ui_textbox("escape",
				$escape eq "none" ? "" : $escape, 4) ] ]));

if ($version_type ne 'ssh' || $version_number < 3) {
	# Number of times to attempt connection
	$attempts = &find_value("ConnectionAttempts", $conf);
	print &ui_table_row($text{'host_attempts'},
		&ui_opt_textbox("attempts", $attempts, 5, $text{'default'}));

	# Use local privileged port?
	if ($version_number < 7.4) {
		$priv = &find_value("UsePrivilegedPort", $conf);
		print &ui_table_row($text{'host_priv'},
			&yes_no_default_radio("priv", $priv));
		}

	if ($version_number < 6) {
		# Try RSH if SSH fails?
		$rsh = &find_value("FallBackToRsh", $conf);
		print &ui_table_row($text{'host_rsh'},
			&yes_no_default_radio("rsh", $rsh));
		# Use RSH only?
		$usersh = &find_value("UseRsh", $conf);
		print &ui_table_row($text{'host_usersh'},
			&yes_no_default_radio("usersh", $usersh));
		}

	}

# Forward SSH agent?
$agent = &find_value("ForwardAgent", $conf);
print &ui_table_row($text{'host_agent'},
	&yes_no_default_radio('agent', $agent));

# Forward X connection?
$x11 = &find_value("ForwardX11", $conf);
print &ui_table_row($text{'host_x11'},
	&yes_no_default_radio('x11', $x11));

# Strictly check host keys?
$strict = &find_value("StrictHostKeyChecking", $conf);
print &ui_table_row($text{'host_strict'},
	&ui_radio('strict', lc($strict) eq 'no' ? 0 :
			    lc($strict) eq 'yes' ? 1 :
			    lc($strict) eq 'ask' ? 3 : 2,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ],
		    [ 3, $text{'host_ask'} ], [ 2, $text{'default'} ] ]));

if ($version_type eq 'openssh') {
	# Double-check remote host IP?
	$checkip = &find_value("CheckHostIP", $conf);
	print &ui_table_row($text{'host_checkip'},
		&yes_no_default_radio('checkip', $checkip));

	# SSH protocols to try
	if ($version_number < 7.4) {
		$prots = &find_value("Protocol", $conf);
		print &ui_table_row($text{'host_prots'},
			&ui_select("prots", $prots,
				[ [ '', $text{'default'} ],
					[ 1, $text{'host_prots1'} ],
					[ 2, $text{'host_prots2'} ],
					[ '1,2', $text{'host_prots12'} ],
					[ '2,1', $text{'host_prots21'} ] ], 1, 0, 1));
		}
	}

print &ui_table_hr();

# Local ports to forward
@lforward = &find("LocalForward", $conf);
@ltable = ( );
$i = 0;
foreach $l (@lforward, { }) {
	local ($lp, $rh, $rp) = ( $l->{'values'}->[0],
				  split(/:/, $l->{'values'}->[1]) );
	push(@ltable, [ &ui_textbox("llport_$i", $lp, 8),
			&ui_textbox("lrhost_$i", $rh, 8),
			&ui_textbox("lrport_$i", $rp, 8) ]);
	$i++;
	}
print &ui_table_row($text{'host_lforward'},
	&ui_columns_table([ $text{'host_llport'}, $text{'host_lrhost'},
			    $text{'host_lrport'} ],
			  50, \@ltable));

print &ui_table_hr();

# Remote ports to forward
@rforward = &find("RemoteForward", $conf);
@rtable = ( );
$i = 0;
foreach $r (@rforward, { }) {
	local ($rp, $lh, $lp) = ( $r->{'values'}->[0],
				  split(/:/, $r->{'values'}->[1]) );
	push(@rtable, [ &ui_textbox("rrport_$i", $rp, 8),
			&ui_textbox("rlhost_$i", $lh, 40),
			&ui_textbox("rlport_$i", $lp, 8) ]);
	$i++;
	}
print &ui_table_row($text{'host_rforward'},
        &ui_columns_table([ $text{'host_rrport'}, $text{'host_rlhost'},
                            $text{'host_rlport'} ],
                          50, \@rtable));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_hosts.cgi", $text{'hosts_return'},
		 "", $text{'index_return'});

