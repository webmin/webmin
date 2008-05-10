#!/usr/local/bin/perl
# cluster.cgi
# Optionally copy to and run the configuration on all managed hosts

require './cfengine-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
&ui_print_header(undef, $text{'cluster_title'}, "");
$| = 1;

# Build options string
$args .= " -v" if ($in{'verbose'});
$args .= " --dry-run" if ($in{'dry'});
$args .= " -i" if ($in{'noifc'});
$args .= " -m" if ($in{'nomnt'});
$args .= " -s" if ($in{'nocmd'});
$args .= " -t" if ($in{'notidy'});
$args .= " -X" if ($in{'nolinks'});

# Setup error handler for down hosts
sub run_error
{
$run_error_msg = join("", @_);
}
&remote_error_setup(\&run_error);

# Run on all hosts
print "<b>$text{'cluster_header'}</b><p>\n";
@hosts = &list_cfengine_hosts();
@servers = &list_servers();
$p = 0;
foreach $h (@hosts) {
        local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
 
        local ($rh = "READ$p", $wh = "WRITE$p");
        pipe($rh, $wh);
        if (!fork()) {
                close($rh);
		&remote_foreign_require($s->{'host'}, "cfengine",
					"cfengine-lib.pl");
		if ($run_error_msg) {
			# Host is down
			print $wh &serialise_variable([ 0, $run_error_msg ]);
			exit;
			}
		local $rconf = &remote_eval($s->{'host'}, "cfengine",
				"\$cfengine_conf");

		# Copy the config if requested and if not local
		if ($in{'copy'} && $s->{'id'}) {
			$lst = [ stat($cfengine_conf) ];
			$rst = &remote_eval($s->{'host'}, "cfengine",
					'[ stat($cfengine_conf) ]');
			if ($lst->[1] != $rst->[1] ||
			    $lst->[7] != $rst->[7] ||
			    $lst->[9] != $rst->[9]) {
				&remote_write($s->{'host'}, $cfengine_conf, $rconf);
				}
			}

		# Execute code to run cfengine
		$out = &remote_eval($s->{'host'}, "cfengine",
			"\$ENV{'CFINPUTS'} = \$config{'cfengine_dir'}; `\$config{'cfengine'} -f \$cfengine_conf $args 2>&1 </dev/null`");
		print $wh &serialise_variable([ 1, $out ]);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Read back the results
$p = 0;
foreach $h (@hosts) {
	local ($s) = grep { $_->{'id'} == $h->{'id'} } @servers;
	local $d = $s->{'desc'} ? $s->{'desc'} : $s->{'host'};
	local $rh = "READ$p";
	local $line = <$rh>;
	local $rv = &unserialise_variable($line);
	close($rh);

	print &ui_hr();
	if ($rv && $rv->[0]) {
		# Run ok! Show the output
		print "<font size=+1>",&text('cluster_success', $d),"</font><br>\n";
		print "<font size=-1><pre>$rv->[1]</pre></font>\n";
		}
	else {
		# Something went wrong
		print &text('cluster_failed', $d, $rv->[1]),"<br>\n";
		}
	$p++;
	}

&remote_finished();
&ui_print_footer("list_hosts.cgi", $text{'hosts_return'});

