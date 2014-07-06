#!/usr/local/bin/perl
# Shut down the servers, after asking for confirmation

require './cluster-shutdown-lib.pl';
&ReadParse();
$pfx = $in{'shut'} ? 'shut' : 'reboot';
$access{$pfx} || &error($text{$pfx.'_ecannot'});
@ids = split(/\0/, $in{'id'});
@ids || &error($text{$pfx.'_enone'});
@servers = &servers::list_servers();

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

if ($in{'confirm'}) {
	# Do it!
	&ui_print_unbuffered_header(undef, $text{$pfx.'_title'}, "");

	foreach $id (@ids) {
		($server) = grep { $_->{'id'} eq $id } @servers;
		next if (!$server);

		print &text($pfx.'_doing', $server->{'host'}),"<br>\n";
		$inst_error_msg = undef;
		$iconfig = &remote_foreign_config($server->{'host'}, "init");
		if ($inst_error_msg) {
			print &text('shut_failed', $inst_error_msg),"<p>\n";
			next;
			}
		&remote_foreign_require($server->{'host'}, "init",
					"init-lib.pl");
		$cmd = $pfx eq 'shut' ? $iconfig->{'shutdown_command'}
				      : $iconfig->{'reboot_command'};
		$out = &remote_eval($server->{'host'}, "init",
				    "system('$cmd')");
		print &text('shut_done'),"<p>\n";
		}

	&ui_print_footer("", $text{'index_return'});
	}
else {
	# Ask first
	&ui_print_header(undef, $text{$pfx.'_title'}, "");

	print &ui_form_start("shutdown.cgi", "post");
	foreach $id (@ids) {
		print &ui_hidden("id", $id);
		($server) = grep { $_->{'id'} eq $id } @servers;
		push(@names, $server->{'host'});
		}
	print &ui_hidden($pfx, 1);
	print "<center>\n";
	print "<b>",&text($pfx.'_rusure', scalar(@ids)),"</b> <p>\n";
	print &ui_submit($text{'shut_ok'}, "confirm"),"<p>\n";
	print "<b>",$text{'shut_sel'},"\n",
	      join(" ", map { "<tt>$_</tt>" } @names),"</b><p>\n";
	print "</center>\n";
	print &ui_form_end();

	&ui_print_footer("", $text{'index_return'});
	}


