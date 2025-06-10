#!/usr/local/bin/perl
# Show a form for editing or creating a log source

require './syslog-ng-lib.pl';
&ReadParse();

# Show title and get the source
$conf = &get_config();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'source_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'source_title2'}, "");
	@sources = &find("source", $conf);
	($source) = grep { $_->{'value'} eq $in{'name'} } @sources;
	$source || &error($text{'source_egone'});
	}

# Form header
print &ui_form_start("save_source.cgi", "post");
print &ui_hidden("new", $in{'new'}),"\n";
print &ui_hidden("old", $in{'name'}),"\n";
print &ui_table_start($text{'source_header'}, undef, 2);

# Source name
print &ui_table_row($text{'source_name'},
		    &ui_textbox("name", $source->{'value'}, 20));

# Show internal option
$ttable = "<table>\n";
$internal = &find("internal", $source->{'members'});
$ttable .= "<tr> <td colspan=2>".&ui_checkbox("internal", 1, "<b>$text{'sources_typei'}</b>", $internal ? 1 : 0)."</td> </tr>\n";

# Show Unix stream and dgram socket options
foreach $t ("unix-stream", "unix-dgram") {
        $unix = &find($t, $source->{'members'});
        local ($unix_name, $unix_owner, $unix_group, $unix_perm,
               $unix_keep, $unix_max);
        if ($unix) {
          $unix_name = $unix->{'value'};
          $unix_owner = &find_value("owner", $unix->{'members'});
          $unix_group = &find_value("group", $unix->{'members'});
          $unix_perm = &find_value("perm", $unix->{'members'});
          $unix_keep = &find_value("keep-alive", $unix->{'members'});
          $unix_max = &find_value("max-connections", $unix->{'members'});
          }
        $msg = $t eq "unix-stream" ? 'sources_types' : 'sources_typed';
        $ttable .= "<tr> <td valign=top>".&ui_checkbox($t, 1, "<b>$text{$msg}</b>", $unix ? 1 : 0)."</td> <td><table>\n";

        # Socket filename
        $ttable .= "<tr> <td>$text{'destination_file'}</td> <td>".
                   &ui_textbox($t."_name", $unix_name, 35)." ".
                   &file_chooser_button("unix_name")."</td> </tr>\n";

        # Socket owner and group
        $ttable .= "<tr> <td>$text{'source_owner'}</td> <td>".
           &ui_opt_textbox($t."_owner", $unix_owner, 15, $text{'default'})." ".
           &user_chooser_button($t."_owner")."</td> </tr>\n";
        $ttable .= "<tr> <td>$text{'source_group'}</td> <td>".
           &ui_opt_textbox($t."_group", $unix_group, 15, $text{'default'})." ".
           &group_chooser_button($t."_group")."</td> </tr>\n";

        # File permissions, keep-alive and max connetions
        $ttable .= "<tr> <td>$text{'source_perm'}</td> <td>".
                   &ui_opt_textbox($t."_perm", $unix_perm, 5,$text{'default'}).
                   "</td> </tr>\n";
        if ($t eq "unix-stream") {
                $ttable .= "<tr> <td>$text{'source_keep'}</td> <td>".
                           &ui_radio($t."_keep", $unix_keep,
                                 [ [ 'y', $text{'yes'} ],
                                   [ 'n', $text{'no'} ],
                                   [ '', $text{'default'} ] ])."</td> </tr>\n";
                $ttable .= "<tr> <td>$text{'source_max'}</td> <td>".
                           &ui_opt_textbox($t."_max", $unix_max, 5,
                                           $text{'default'})."</td> </tr>\n";
                }

        $ttable .= "</table>\n";
        $ttable .= "</td> </tr>\n";
        }

# TCP and UDP network sockets
foreach $t ('tcp', 'udp') {
        $net = &find($t, $source->{'members'});
        local ($net_ip, $net_port, $net_keep, $net_tkeep, $net_max);
        if ($net) {
                $net_ip = &find_value("ip", $net->{'members'}) ||
                          &find_value("localip", $net->{'members'});
                $net_port = &find_value("port", $net->{'members'}) ||
                            &find_value("localport", $net->{'members'});
                $net_keep = &find_value("keep-alive", $net->{'members'});
                $net_tkeep = &find_value("tcp-keep-alive", $net->{'members'});
                $net_max = &find_value("max-connections", $net->{'members'});
                }
        $msg = $t eq "tcp" ? 'sources_typet' : 'sources_typeu';
        $ttable .= "<tr> <td valign=top>".&ui_checkbox($t, 1, "<b>$text{$msg}</b>", $net ? 1 : 0)."</td> <td><table>\n";

        # Local IP and port
        $ttable .= "<tr> <td>$text{'source_ip'}</td> <td>".
           &ui_opt_textbox($t."_ip", $net_ip, 15, $text{'source_any'}).
           "</td> </tr>\n";
        $ttable .= "<tr> <td>$text{'source_port'}</td> <td>".
           &ui_opt_textbox($t."_port", $net_port, 6, $text{'default'}." (514)").
           "</td> </tr>\n";

        # TCP-specific options and max connections
        if ($t eq "tcp") {
                $ttable .= "<tr> <td>$text{'source_keep'}</td> <td>".
                           &ui_radio($t."_keep", $net_keep,
                                 [ [ 'y', $text{'yes'} ],
                                   [ 'n', $text{'no'} ],
                                   [ '', $text{'default'} ] ])."</td> </tr>\n";
                $ttable .= "<tr> <td>$text{'source_tkeep'}</td> <td>".
                           &ui_radio($t."_tkeep", $net_tkeep,
                                 [ [ 'y', $text{'yes'} ],
                                   [ 'n', $text{'no'} ],
                                   [ '', $text{'default'} ] ])."</td> </tr>\n";
                }
        $ttable .= "<tr> <td>$text{'source_max'}</td> <td>".
                   &ui_opt_textbox($t."_max", $net_max, 5,
                                   $text{'default'})."</td> </tr>\n";

        $ttable .= "</table>\n";
        $ttable .= "</td> </tr>\n";
        }

# Kernel log file
$file = &find("file", $source->{'members'});
if ($file) {
        $file_name = $file->{'value'};
        $file_prefix = &find_value("log_prefix", $file->{'members'});
        }
$ttable .= "<tr> <td valign=top>".&ui_checkbox("file", 1, "<b>$text{'sources_typef'}</b>", $file ? 1 : 0)."</td> <td><table>\n";

# Log filename
$ttable .= "<tr> <td>$text{'destination_file'}</td> <td>".
           &ui_textbox("file_name", $file_name, 35)." ".
           &file_chooser_button("file_name")."</td> </tr>\n";

# Message prefix
$ttable .= "<tr> <td>$text{'source_prefix'}</td> <td>".
           &ui_opt_textbox("file_prefix", $file_prefix, 20,
                           $text{'source_none'})."</td> </tr>\n";
$ttable .= "</table>\n";
$ttable .= "</td> </tr>\n";


# Pipe file
$pipe = &find("pipe", $source->{'members'});
if ($pipe) {
        $pipe_name = $pipe->{'value'};
        $pipe_prefix = &find_value("log_prefix", $pipe->{'members'});
        $pad_size = &find_value("pad_size", $pipe->{'members'});
        }
$ttable .= "<tr> <td valign=top>".&ui_checkbox("pipe", 1, "<b>$text{'sources_typep'}</b>", $pipe ? 1 : 0)."</td> <td><table>\n";

# Log pipename
$ttable .= "<tr> <td>$text{'destination_file'}</td> <td>".
           &ui_textbox("pipe_name", $pipe_name, 35)." ".
           &file_chooser_button("pipe_name")."</td> </tr>\n";

# Message prefix and pad size
$ttable .= "<tr> <td>$text{'source_prefix'}</td> <td>".
           &ui_opt_textbox("pipe_prefix", $pipe_prefix, 20,
                           $text{'source_none'})."</td> </tr>\n";
$ttable .= "<tr> <td>$text{'source_pad'}</td> <td>".
           &ui_opt_textbox("pad_size", $pad_size, 20,
                           $text{'source_none'})."</td> </tr>\n";
$ttable .= "</table>\n";
$ttable .= "</td> </tr>\n";


if (&supports_sun_streams()) {
	# Sun streams file
	$sun_streams = &find("sun-streams", $source->{'members'});
	if ($sun_streams) {
		$sun_streams_name = $sun_streams->{'value'};
		$sun_streams_door = &find_value("door", $sun_streams->{'members'});
		}
	$ttable .= "<tr> <td valign=top>".&ui_checkbox("sun-streams", 1, "<b>$text{'sources_typen'}</b>", $sun_streams ? 1 : 0)."</td> <td><table>\n";

	# Log filename
	$ttable .= "<tr> <td>$text{'destination_file'}</td> <td>".
		   &ui_textbox("sun_streams_name", $sun_streams_name, 35)." ".
		   &file_chooser_button("sun_streams_name")."</td> </tr>\n";

	# Door name
	$ttable .= "<tr> <td>$text{'source_door'}</td> <td>".
		   &ui_textbox("sun_streams_door", $sun_streams_door, 35)." ".
		   &file_chooser_button("sun_streams_name")."</td> </tr>\n";
	$ttable .= "</table>\n";
	$ttable .= "</td> </tr>\n";
	}

# Syslog server protocol
$network = &find("network", $source->{'members'});
$ttable .= "<tr> <td valign=top>".&ui_checkbox("network", 1, "<b>$text{'sources_typenw'}</b>", $network ? 1 : 0)."</td> <td><table>\n";
if ($network) {
	$network_ip = &find_value("ip", $network->{'members'});
	$network_port = &find_value("port", $network->{'members'});
	$network_transport = &find_value("transport", $network->{'members'});
	}

# IP and port
$ttable .= "<tr> <td>$text{'source_ip'}</td> <td>".
   &ui_opt_textbox("network_ip", $network_ip, 15, $text{'source_any'}).
   "</td> </tr>\n";
$ttable .= "<tr> <td>$text{'source_port'}</td> <td>".
   &ui_opt_textbox("network_port", $network_port, 6, $text{'default'}." (601)").
   "</td> </tr>\n";

# Transport type
$ttable .= "<tr> <td>$text{'source_transport'}</td> <td>".
   &ui_select("network_transport", $network_transport,
	      [ [ "", $text{'default'} ],
		[ "tcp", "TCP" ],
		[ "udp", "UDP" ] ]).
   "</td> </tr>\n";

$ttable .= "</table>\n";
$ttable .= "</td> </tr>\n";

# Show types table
$ttable .= "</table>\n";
print "<tr> <td valign=top><b>$text{'source_type'}</b></td> <td>\n";
print $ttable;
print "</td> </tr>\n";

# Form footer and buttons
print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ "create", $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
&ui_print_footer("list_sources.cgi", $text{'sources_return'});
