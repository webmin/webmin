#!/usr/local/bin/perl
# index.cgi
# Display sshd option categories

require './sshd-lib.pl';

# Check if config file exists
if (!-r $config{'sshd_config'}) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &text('index_econfig', "<tt>$config{'sshd_config'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if sshd exists
if (!&has_command($config{'sshd_path'})) {
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &text('index_esshd', "<tt>$config{'sshd_path'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}

# Check if sshd is the right version
$out = &backquote_command(&quote_path($config{'sshd_path'})." -h 2>&1");
if ($config{'sshd_version'}) {
	# Forced version
	$version{'type'} = 'openssh';
	$version{'number'} = $version{'full'} = $config{'sshd_version'};
	}
elsif ($out =~ /(sshd\s+version\s+([0-9\.]+))/i ||
    $out =~ /(ssh\s+secure\s+shell\s+([0-9\.]+))/i) {
	# Classic commercial SSH
	$version{'type'} = 'ssh';
	$version{'number'} = $2;
	$version{'full'} = $1;
	}
elsif ($out =~ /(OpenSSH.([0-9\.]+))/i) {
	# OpenSSH .. assume all versions are supported
	$version{'type'} = 'openssh';
	$version{'number'} = $2;
	$version{'full'} = $1;
	}
elsif ($out =~ /(Sun_SSH_([0-9\.]+))/i) {
	# Solaris 9 SSH is actually OpenSSH 2.x
	$version{'type'} = 'openssh';
	$version{'number'} = 2.0;
	$version{'full'} = $1;
	}
elsif (($out = $config{'sshd_version'}) && ($out =~ /(Sun_SSH_([0-9\.]+))/i)) {
	# Probably Solaris 10 SSHD that didn't display version.  Use it.
	$version{'type'} = 'openssh';
	$version{'number'} = 2.0;
	$version{'full'} = $1;
	}
else {
	# Unknown version
	&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1);
	print &text('index_eversion', "<tt>$config{'sshd_path'}</tt>",
		    "$gconfig{'webprefix'}/config.cgi?$module_name",
		    "<tt>$config{'sshd_path'} -h</tt>",
		    "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{"index"});
	exit;
	}
&write_file("$module_config_directory/version", \%version);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("ssh", "man", "doc", "google"), undef, undef,
	&text('index_version', $version{'full'}));

# Display icons for options
foreach $i ('users', 'net', 'access', 'misc') {
	push(@links, "edit_$i.cgi");
	push(@titles, $text{$i.'_title'});
	push(@icons, "images/$i.gif");
	}
if (-r $config{'client_config'}) {
	push(@links, "list_hosts.cgi");
	push(@titles, $text{'hosts_title'});
	push(@icons, "images/hosts.gif");
	}
push(@links, "edit_sync.cgi");
push(@titles, $text{'sync_title'});
push(@icons, "images/sync.gif");

push(@links, "edit_keys.cgi");
push(@titles, $text{'keys_title'});
push(@icons, "images/keys.gif");

push(@links, "edit_manual.cgi");
push(@titles, $text{'manual_title'});
push(@icons, "images/manual.gif");
&icons_table(\@links, \@titles, \@icons, 4);

# Check if sshd is running
$pid = &get_sshd_pid();
print &ui_hr();
print &ui_buttons_start();
if ($pid) {
	# Running .. offer to apply changes and stop
	print &ui_buttons_row("apply.cgi",
	      $text{'index_apply'},
	      $config{'restart_cmd'} ?
		&text('index_applymsg2', "<tt>$config{'restart_cmd'}</tt>") :
		$text{'index_applymsg'});

	print &ui_buttons_row("stop.cgi",
			      $text{'index_stop'}, $text{'index_stopmsg'});
	}
else {
	# Not running .. offer to start
	print &ui_buttons_row("start.cgi", $text{'index_start'},
			      $text{'index_startmsg'});
	}
print &ui_buttons_end();

&ui_print_footer("/", $text{"index"});

