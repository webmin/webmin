#!/usr/local/bin/perl
# edit_serv.cgi
# Display a form for editing or creating an internet service

require './xinetd-lib.pl';
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'serv_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'serv_edit'}, "");
	@conf = &get_xinetd_config();
	$xinet = $conf[$in{'idx'}];
	$q = $xinet->{'quick'};
	($defs) = grep { $_->{'name'} eq 'defaults' } @conf;
	foreach $m (@{$defs->{'members'}}) {
		$ddisable{$m->{'value'}}++ if ($m->{'name'} eq 'disabled');
		}
	}

print &ui_form_start("save_serv.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'serv_header1'}, "width=100%", 4);

# Service name
print &ui_table_row($text{'serv_id'},
	&ui_textbox("id", $xinet->{'value'}, 10));

# Currently enabled
$id = $q->{'id'}->[0] || $xinet->{'value'};
$dis = $q->{'disable'}->[0] eq 'yes' || $ddisable{$id};
print &ui_table_row($text{'serv_enabled'},
	&ui_radio("disable", $dis ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

# BIND to IP
print &ui_table_row($text{'serv_bind'},
	&ui_opt_textbox("bind", $q->{'bind'} ? $q->{'bind'}->[0] : undef,
			20, $text{'serv_bind_def'}));

# Listen on port
print &ui_table_row($text{'serv_port'},
	&ui_opt_textbox("port", $q->{'port'} ? $q->{'port'}->[0] : undef,
			8, $text{'serv_port_def'}));

# Socket type
print &ui_table_row($text{'serv_sock'},
	&ui_select("sock", $q->{'socket_type'}->[0],
		   [ map { [ $_, $text{'sock_'.$_} ] }
			 ('stream', 'dgram', 'raw', 'seqpacket') ]));

# Network protocol
print &ui_table_row($text{'serv_proto'},
	&ui_select("proto", $q->{'protocol'}->[0],
		   [ map { [ $_, $text{'proto_'.$_} || uc($_) ] }
			 ('', &list_protocols()) ]));

print &ui_table_end();
print &ui_table_start($text{'serv_header2'}, "width=100%", 4);

$prog = &indexof('INTERNAL', @{$q->{'type'}}) >= 0 ? 0 :
	$q->{'redirect'} ? 2 : 1;
print &ui_table_row($text{'serv_prog'},
    &ui_radio_table("prog", $prog,
	[ [ 0, $text{'serv_internal'} ],
	  [ 1, $text{'serv_server'},
	    &ui_textbox("server", join(" ", $q->{'server'}->[0],
				    	    @{$q->{'server_args'}}), 50) ],
	  [ 2, $text{'serv_redirect'},
	    &ui_textbox("rhost", $prog == 2 ? $q->{'redirect'}->[0] : "", 20).
	    " ".$text{'serv_rport'}." ".
	    &ui_textbox("rport", $prog == 2 ? $q->{'redirect'}->[1] : "", 6)
	  ] ]), 3);

# Run as user
print &ui_table_row($text{'serv_user'},
	&ui_user_textbox("user", $q->{'user'}->[0]));

# Run as group
print &ui_table_row($text{'serv_group'},
	&ui_opt_textbox("group", $q->{'group'} ? $q->{'group'}->[0] : "",
			10, $text{'serv_group_def'})." ".
	&group_chooser_button("group"));

# Wait to finish?
print &ui_table_row($text{'serv_wait'},
	&ui_radio("wait", $q->{'wait'}->[0] eq 'yes' ? 1 : 0,
		  [ [ 1, $text{'yes'} ], [ 0, $text{'no'} ] ]));

# Max instances to run at once
$inst = uc($q->{'instances'}->[0]) eq 'UNLIMITED' ? '' : $q->{'instances'}->[0];
print &ui_table_row($text{'serv_inst'},
	&ui_opt_textbox("inst", $inst, 5, $text{'serv_inst_def'}));

# Max connections / second
$cps = uc($q->{'cps'}->[0]) eq 'UNLIMITED' ? '' : $q->{'cps'}->[0];
print &ui_table_row($text{'serv_cps0'},
	&ui_opt_textbox("cps", $cps, 5, $text{'serv_cps_def'}));

# Delay if max connections reached
print &ui_table_row($text{'serv_cps1'},
	&ui_textbox("cps1", $q->{'cps'}->[1], 5)." ".$text{'serv_sec'});

# Nice level
print &ui_table_row($text{'serv_nice'},
	&ui_opt_textbox("nice", $q->{'nice'} ? $q->{'nice'}->[0] : "",
			5, $text{'default'}));

print &ui_table_end();
print &ui_table_start($text{'serv_header3'}, "width=100%", 4);

# Allow access from
print &ui_table_row($text{'serv_from'},
	&ui_radio("from_def", $q->{'only_from'} ? 0 : 1,
		  [ [ 1, $text{'serv_from_def'} ],
		    [ 0, $text{'serv_from_sel'} ] ])."<br>\n".
	&ui_textarea("from", join("\n", @{$q->{'only_from'}}), 4, 20));

# Deny access from
print &ui_table_row($text{'serv_access'},
	&ui_radio("access_def", $q->{'no_access'} ? 0 : 1,
		  [ [ 1, $text{'serv_access_def'} ],
		    [ 0, $text{'serv_access_sel'} ] ])."<br>\n".
	&ui_textarea("access", join("\n", @{$q->{'no_access'}}), 4, 20));

# Allow access at times
print &ui_table_row($text{'serv_times'},
	&ui_radio("times_def", $q->{'access_times'} ? 0 : 1,
		  [ [ 1, $text{'serv_times_def'} ],
		    [ 0, &ui_textbox("times",
			   join(" ", @{$q->{'access_times'}}), 40) ] ]), 3);

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

