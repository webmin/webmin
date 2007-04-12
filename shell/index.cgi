#!/usr/local/bin/perl
# index.cgi
# Show the shell user interface

require './shell-lib.pl';
%access = &get_module_acl();
&ReadParseMime() if ($ENV{'REQUEST_METHOD'} ne 'GET');
&ui_print_header(undef, $text{'index_title'}, "", undef,
		 $module_info{'usermin'} ? 0 : 1, 1,
		 undef, undef, undef,
	"onLoad='window.scroll(0, 10000); document.forms[0].cmd.focus()'");

$prevfile = "$module_config_directory/previous.$remote_user";
if ($in{'clearcmds'}) {
	&lock_file($prevfile);
	unlink($prevfile);
	&unlock_file($prevfile);
	&webmin_log("clear");
	}
else {
	open(PREVFILE, $prevfile);
	chop(@previous = <PREVFILE>);
	close(PREVFILE);
	}
$cmd = $in{'doprev'} ? $in{'pcmd'} : $in{'cmd'};

if ($in{'pwd'}) {
	$pwd = $in{'pwd'};
	}
else {
	if ($gconfig{'os_type'} eq 'windows') {
		# Initial directory is c:/
		$pwd = "c:/";
		}
	else {
		# Initial directory is user's home
		local @uinfo = getpwnam($access{'user'} || $remote_user);
		$pwd = scalar(@uinfo) && -d $uinfo[7] ? $uinfo[7] : "/";
		}
	}
if (!$in{'clear'}) {
	$history = &un_urlize($in{'history'});
	if ($cmd) {
		# Execute the latest command
		$fullcmd = $cmd;
		$ok = chdir($pwd);
		$history .= "<b>&gt; ".&html_escape($cmd, 1)."</b>\n";
		if ($cmd =~ /^cd\s+"([^"]+)"\s*(;?\s*(.*))$/ ||
		    $cmd =~ /^cd\s+'([^']+)'\s*(;?\s*(.*))$/ ||
		    $cmd =~ /^cd\s+([^; ]*)\s*(;?\s*(.*))$/) {
			$cmd = undef;
			if (!chdir($1)) {
				$history .= &html_escape("$1: $!\n", 1);
				}
			else {
				$cmd = $3 if ($2);
				$pwd = &get_current_dir();
				}
			}
		if ($cmd) {
			local $user = $access{'user'} || $remote_user;
			&clean_environment() if ($config{'clear_envs'});
			delete($ENV{'SCRIPT_NAME'});	# So that called Webmin
							# programs get the right
							# module, not this one!
			if (&supports_users()) {
				$out = &backquote_logged(
				    &command_as_user($user, 0, $cmd)." 2>&1");
				}
			else {
				$out = &backquote_logged("($cmd) 2>&1");
				}
			&reset_environment() if ($config{'clear_envs'});
			$out = &html_escape($out, 1);
			$history .= $out;
			}
		@previous = &unique(@previous, $fullcmd);
		&lock_file($prevfile);
		&open_tempfile(PREVFILE, ">>$prevfile");
		&print_tempfile(PREVFILE, $fullcmd,"\n");
		&close_tempfile(PREVFILE);
		&unlock_file($prevfile);
		&webmin_log("run", undef, undef, { 'cmd' => $fullcmd });
		}
	}

# Show the history and command input
if ($history) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_history'}</b></td> </tr>\n";
	print "<tr $cb> <td><pre>";
	print $history;
	print "</pre></td></tr> </table><p>\n";
	print "<hr>\n";
	}

print "$text{'index_desc'}<br>\n";
print "<form action=index.cgi method=post enctype=multipart/form-data>\n";
print "<table width=100%><tr>\n";
print "<td><input type=submit value='$text{'index_ok'}'></td>\n";
print "<td><input name=cmd size=50></td>\n";
print "<td align=right><input type=submit name=clear ",
      "value='$text{'index_clear'}'></td>\n";
print "</tr>\n";
print "<input type=hidden name=pwd value='$pwd'>\n";
print "<input type=hidden name=history value='",&urlize($history),"'>\n";
foreach $p (@previous) {
	print "<input type=hidden name=previous value='",
	      &html_escape($p, 1),"'>\n";
	}

if (@previous) {
	print "<tr> <td><input name=doprev type=submit value='$text{'index_pok'}'></td>\n";
	print "<td><select name=pcmd>\n";
	foreach $p (reverse(@previous)) {
		printf "<option value='%s'>%s\n",
			&html_escape($p, 1),
			&html_escape($p, 1);
		}
	print "</select>\n";
	print "<input type=button name=movecmd ",
	      "value='$text{'index_edit'}' onClick='cmd.value = pcmd.options[pcmd.selectedIndex].value'>\n";
	print "</td> <td align=right><input type=submit name=clearcmds ",
	      "value='$text{'index_clearcmds'}'></td> </tr>\n";
	}
print "</table>\n";
print "</form>\n";

&ui_print_footer("/", $text{'index'});

