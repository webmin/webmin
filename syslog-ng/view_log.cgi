#!/usr/local/bin/perl
# Show a log file

require './syslog-ng-lib.pl';
&ReadParse();
&foreign_require("proc", "proc-lib.pl");

# Work out the file
$conf = &get_config();
if ($in{'dest'}) {
	# From a destination
	@dests = &find("destination", $conf);
	($dest) = grep { $_->{'value'} eq $in{'dest'} } @dests;
	$dest || &error($text{'destination_egone'});
	$file = &find_value("file", $dest->{'members'});
	}
elsif ($in{'omod'}) {
	# From another module
	@others = &get_other_module_logs($in{'omod'});
	($other) = grep { $_->{'mindex'} == $in{'oidx'} } @others;
	if ($other->{'file'}) {
		$file = $other->{'file'};
		}
	else {
		$cmd = $other->{'cmd'};
		}
	}

print "Refresh: $config{'refresh'}\r\n"
	if ($config{'refresh'});
&ui_print_header("<tt>".($file || $cmd)."</tt>", $text{'view_title'}, "");

$lines = $in{'lines'} ? int($in{'lines'}) : int($config{'lines'});
$filter = $in{'filter'} ? quotemeta($in{'filter'}) : "";

&filter_form();

$| = 1;
print "<pre>";
local $tailcmd = $config{'tail_cmd'} || "tail -n LINES";
$tailcmd =~ s/LINES/$lines/g;
if ($filter ne "") {
	# Are we supposed to filter anything? Then use grep.
	local @cats;
	if ($cmd) {
		push(@cats, $cmd);
		}
	elsif ($config{'compressed'}) {
		# All compressed versions
		foreach $l (&all_log_files($file)) {
			$c = &catter_command($l);
			push(@cats, $c) if ($c);
			}
		}
	else {
		# Just the one log
		@cats = ( "cat ".quotemeta($file) );
		}
	$cat = "(".join(" ; ", @cats).")";
	$got = &foreign_call("proc", "safe_process_exec",
		"$cat | grep -i $filter | $tailcmd",
		0, 0, STDOUT, undef, 1, 0, undef, 1);
	}
else {
	# Not filtering .. so cat the most recent non-empty file
	if ($cmd) {
                # Getting output from a command
                $fullcmd = $cmd." | ".$tailcmd;
		}
	elsif ($config{'compressed'}) {
		# Find the first non-empty file, newest first
		$catter = "cat ".quotemeta($file);
		if (!-s $file) {
			foreach $l (&all_log_files($file)) {
				next if (!-s $l);
				$c = &catter_command($l);
				if ($c) {
					$catter = $c;
					last;
					}
				}
			}
		$fullcmd = $catter." | ".$tailcmd;
		}
	else {
		# Just run tail on the file
		$fullcmd = $tailcmd." ".quotemeta($file);
		}
	$got = &foreign_call("proc", "safe_process_exec",
		$fullcmd, 0, 0, STDOUT, undef, 1, 0, undef, 1);
	}
print "<i>$text{'view_empty'}</i>\n" if (!$got);
print "</pre>\n";
&filter_form();

&ui_print_footer("list_destinations.cgi", $text{'destinations_return'},
		 "", $text{'index_return'});

sub filter_form
{
print "<form action=view_log.cgi style='margin-left:1em'>\n";
print &ui_hidden("dest", $in{'dest'}),"\n";
print &ui_hidden("oidx", $in{'oidx'}),"\n";
print &ui_hidden("omod", $in{'omod'}),"\n";

print &text('view_header', &ui_textbox("lines", $lines, 3),
	    "<tt>".&html_escape($log->{'file'})."</tt>"),"\n";
print "&nbsp;&nbsp;\n";
print &text('view_filter', &ui_textbox("filter", $in{'filter'}, 25)),"\n";
print "&nbsp;&nbsp;\n";
print "<input type=submit value='$text{'view_refresh'}'></form>\n";
}

