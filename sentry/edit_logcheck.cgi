#!/usr/local/bin/perl
# edit_logcheck.cgi
# Display logcheck configuration menu

require './sentry-lib.pl';

# Check if logcheck is installed
if (!-x $config{'logcheck'}) {
	&ui_print_header(undef, $text{'logcheck_title'}, "");
	print "<p>",&text('logcheck_ecommand',
		  "<tt>$config{'logcheck'}</tt>", 
		  "@{[&get_webprefix()]}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# Check if it is the right version
$conf = &get_logcheck_config();
$hacking = &find_value("HACKING_FILE", $conf, 1);
$hacking = &find_value("CRACKING_FILE", $conf, 1) if (!$hacking);
if (!$hacking) {
	&ui_print_header(undef, $text{'logcheck_title'}, "");
	print "<p>",&text('logcheck_eversion',
			  "<tt>$config{'logcheck'}</tt>"),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

&ui_print_header(undef, $text{'logcheck_title'}, "", "logcheck", 0, 0, undef,
	&help_search_link("logcheck", "man", "doc"));

# Show configuration form
print "<form action=save_logcheck.cgi method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'logcheck_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

$to = &find_value("SYSADMIN", $conf, 1);
print "<tr> <td><b>$text{'logcheck_to'}</b></td>\n";
printf "<td colspan=2><input name=to size=50 value='%s'></td> </tr>\n", $to;

print "<tr> <td width=33% valign=top><b>$text{'logcheck_hacking'}</b><br>\n";
print "<textarea name=hacking rows=20 cols=30>";
open(HACKING, $hacking);
while(<HACKING>) {
	s/\r|\n//g;
	print &html_escape($_),"\n";
	}
close(HACKING);
print "</textarea></td>\n";

$violations = &find_value("VIOLATIONS_FILE", $conf, 1);
print "<td width=33% valign=top><b>$text{'logcheck_violations'}</b><br>\n";
print "<textarea name=violations rows=10 cols=30>";
open(VIOLATIONS, $violations);
while(<VIOLATIONS>) {
	s/\r|\n//g;
	print &html_escape($_),"\n";
	}
close(VIOLATIONS);
print "</textarea><br>\n";
$violations_ign = &find_value("VIOLATIONS_IGNORE_FILE", $conf, 1);
print "<b>$text{'logcheck_violations_ign'}</b><br>\n";
print "<textarea name=violations_ign rows=7 cols=30>";
open(IGNORE, $violations_ign);
while(<IGNORE>) {
	s/\r|\n//g;
	print &html_escape($_),"\n";
	}
close(IGNORE);
print "</textarea></td>\n";

$ignore = &find_value("IGNORE_FILE", $conf, 1);
print "<td width=33% valign=top><b>$text{'logcheck_ignore'}</b><br>\n";
print "<textarea name=ignore rows=20 cols=20>";
open(IGNORE, $ignore);
while(<IGNORE>) {
	s/\r|\n//g;
	print &html_escape($_),"\n";
	}
close(IGNORE);
print "</textarea></td> </tr>\n";

# Display files being monitored
open(CHECK, $config{'logcheck'});
while(<CHECK>) {
	s/\r|\n//g;
	s/#.*$//;
	if (/^\s*(\$LOGTAIL|\S*logtail)\s+(\S+)/) {
		push(@logfiles, $2);
		}
	}
close(CHECK);
if (@logfiles) {
	print "<tr> <td valign=top><b>$text{'logcheck_files'}</b></td>\n";
	print "<td colspan=2>",join(" ",
			map { "<tt>$_</tt>" } @logfiles),"</td> </tr>\n";
	}

# Display run times for logcheck
&foreign_require("cron", "cron-lib.pl");
@jobs = &cron::list_cron_jobs();
JOB: foreach $j (@jobs) {
	local $rpd;
	if ($j->{'command'} =~ /$config{'logcheck'}/) {
		$job = $j;
		last;
		}
	elsif ($rpd = &cron::is_run_parts($j->{'command'})) {
		local @exp = &cron::expand_run_parts($rpd);
		foreach $e (@exp) {
			if ($e =~ /logcheck/) {
				# Cannot change this :(
				$runparts = $e;
				last JOB;
				}
			}
		}
	}
if ($runparts) {
	print "<tr> <td colspan=3>",&text('logcheck_runparts',
				"<tt>$runparts</tt>"),"</td> </tr>\n";
	print "<input type=hidden name=runparts value='1'>\n";
	}
else {
	print "<input type=hidden name=job value='$job->{'index'}'>\n"
		if ($job);
	print "<tr> <td colspan=3>\n";
	$job = { 'mins' => 0,
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*' } if (!$job);
	printf "<input type=radio name=active value=0 %s> %s\n",
		$job->{'active'} ? "" : "checked", $text{'logcheck_disabled'};
	printf "<input type=radio name=active value=1 %s> %s<br>\n",
		$job->{'active'} ? "checked" : "", $text{'logcheck_enabled'};
	print "<table border width=100%>\n";
	&cron::show_times_input($job);
	print "</table></td> </tr>\n";
	}

print "</table></td></tr></table><br>\n";
print "<input type=submit value='$text{'logcheck_save'}'></form>\n";

&ui_print_footer("", $text{'index_return'});

