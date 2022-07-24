#!/usr/local/bin/perl
# save_log.cgi
# Update, create or delete a log, or global settings

require './logrotate-lib.pl';
&ReadParse();
$parent = &get_config_parent();
$conf = $parent->{'members'};
@files = split(/\s+/, $in{'file'});
if ($in{'global'}) {
	# Editing the global options
	$log = $parent;
	}
elsif ($in{'new'}) {
	# Adding a new section
	$cfilename = $files[0] =~ /\/([^\/]+)$/ ? $1 : undef;
	$log = { 'members' => [ ],
		 'file' => &get_add_file($cfilename) };
	$logfile = $in{'file'};
	}
else {
	# Editing a section
	$oldlog = $log = $conf->[$in{'idx'}];
	$logfile = join(" ", @{$oldlog->{'name'}});
	}

if ($in{'delete'}) {
	# Just delete this log entry
	&lock_file($log->{'file'});
	&save_directive($parent, $log, undef);
	}
elsif ($in{'now'}) {
	# Rotate log immediately
	&ui_print_header(undef, $text{'force_title'}, "");

	print $text{'force_doingone'},"\n";
	($ex, $out) = &rotate_log_now($log);
	print "<pre>$out</pre>";
	if ($?) {
		print $text{'force_failed'},"<br>\n";
		}
	else {
		print $text{'force_done'},"<br>\n";
		}

	&webmin_log("force", $logfile);
	&ui_print_footer("", $text{'index_return'});
	exit;
	}
else {
	# Validate and store inputs
	&lock_file($log->{'file'});
	&error_setup($text{'save_err'});
	if (!$in{'global'}) {
		foreach $f (@files) {
			$f =~ /^\/\S+$/ || &error($text{'save_efile'});
			}
		@files || &error($text{'save_enofiles'});
		$in{'file'} =~ s/\r//g;
		$log->{'name'} = [ split(/\n/, $in{'file'}) ];
		}

	foreach $period ("daily", "weekly", "monthly") {
		&save_directive($log, $period,
				$in{'sched'} eq $period ? "" : undef);
		}

	$in{'size_def'} || $in{'size'} =~ /^\d+[kM]?$/ ||
		&error($text{'save_esize'});
	&save_directive($log, "size", $in{'size_def'} ? undef : $in{'size'});

	$in{'minsize_def'} || $in{'minsize'} =~ /^\d+[kM]?$/ ||
		&error($text{'save_eminsize'});
	&save_directive($log, "minsize",
			$in{'minsize_def'} ? undef : $in{'minsize'});

	$in{'rotate_def'} || $in{'rotate'} =~ /^\d+$/ ||
		&error($text{'save_erotate'});
	&save_directive($log, "rotate", $in{'rotate_def'} ? undef
							    : $in{'rotate'});

	&parse_yesno("compress", "nocompress", $log);
	&parse_yesno("delaycompress", "nodelaycompress", $log);
	&parse_yesno("copytruncate", "nocopytruncate", $log);
	&parse_yesno("ifempty", "notifempty", $log);
	&parse_yesno("missingok", "nomissingok", $log);

	if ($in{'create'} == 2) {
		&error($text{'save_emust1'}) if ($in{'createuser'} ne '' &&
						   $in{'createmode'} eq '');
		&error($text{'save_emust2'}) if ($in{'creategroup'} ne '' &&
						   $in{'createuser'} eq '');
		$in{'createmode'} eq '' ||
		    $in{'createmode'} =~ /^[0-7]{3,4}$/ ||
			&error($text{'save_ecreatemode'});
		$in{'createuser'} eq '' ||
		    defined(getpwnam($in{'createuser'})) ||
			&error($text{'save_ecreateuser'});
		$in{'creategroup'} eq '' ||
		    defined(getgrnam($in{'creategroup'})) ||
			&error($text{'save_ecreategroup'});
		&save_directive($log, "create",
				$in{'createmode'}." ".
				$in{'createuser'}." ".$in{'creategroup'});
		&save_directive($log, "nocreate");
		}
	elsif ($in{'create'} == 1) {
		&save_directive($log, "create");
		&save_directive($log, "nocreate", "");
		}
	elsif ($in{'create'} == 0) {
		&save_directive($log, "create");
		&save_directive($log, "nocreate");
		}

	if ($in{'olddir'} == 2) {
		-d $in{'olddirto'} || &error($text{'save_eolddirto'});
		&save_directive($log, "olddir", $in{'olddirto'});
		&save_directive($log, "noolddir");
		}
	elsif ($in{'olddir'} == 1) {
		&save_directive($log, "olddir");
		&save_directive($log, "noolddir", "");
		}
	elsif ($in{'olddir'} == 0) {
		&save_directive($log, "olddir");
		&save_directive($log, "noolddir");
		}

	$in{'ext_def'} || $in{'ext'} =~ /^\S+$/ ||
		&error($text{'save_eext'});
	&save_directive($log, "extension", $in{'ext_def'} ? undef : $in{'ext'});

	&parse_yesno("dateext", "nodateext", $log);

	if ($in{'mail'} == 2) {
		$in{'mailto'} =~ /^\S+$/ || &error($text{'save_emailto'});
		&save_directive($log, "mail", $in{'mailto'});
		&save_directive($log, "nomail");
		}
	elsif ($in{'mail'} == 1) {
		&save_directive($log, "mail");
		&save_directive($log, "nomail", "");
		}
	elsif ($in{'mail'} == 0) {
		&save_directive($log, "mail");
		&save_directive($log, "nomail");
		}

	&parse_yesno("mailfirst", "maillast", $log);

	if (defined($in{'errors'})) {
		$in{'errors_def'} || $in{'errors'} =~ /^\S+$/ ||
			&error($text{'save_eerrors'});
		&save_directive($log, "errors", $in{'errors_def'} ? undef
							  : $in{'errors'});
		}

	if ($in{'pre'} =~ /\S/) {
		$in{'pre'} =~ s/\r//g;
		&has_endscript($in{'pre'}) && &error($text{'save_epre'});
		&save_directive($log, "prerotate",
				{ "name" => "prerotate",
				  "script" => $in{'pre'} });
		}
	else {
		&save_directive($log, "prerotate");
		}

	if ($in{'post'} =~ /\S/) {
		$in{'post'} =~ s/\r//g;
		&has_endscript($in{'post'}) && &error($text{'save_epost'});
		&save_directive($log, "postrotate",
				{ "name" => "postrotate",
				  "script" => $in{'post'} });
		}
	else {
		&save_directive($log, "postrotate");
		}

	if (defined($in{'sharedscripts'})) {
		&parse_yesno("sharedscripts", "nosharedscripts", $log);
		}

	if (!$in{'global'}) {
		# Save or create the actual log entry
		&save_directive($parent, $oldlog, $log);
		}
	}

&flush_file_lines();
&delete_if_empty($log->{'file'}) if ($in{'delete'});
&unlock_file($log->{'file'});
&webmin_log($in{'delete'} ? "delete" : $in{'new'} ? "create" : "modify",
	    $in{'global'} ? "global" : "log", $logfile);

&redirect("");

# parse_yesno(yesvalue, novalue, &conf)
sub parse_yesno
{
local $d0 = &find($_[0], $_[2]->{'members'});
local $d1 = &find($_[1], $_[2]->{'members'});
if ($in{$_[0]} == 2 && !$d0) {
	# Adding or replacing 'yes' value
	&save_directive($_[2], $d1 || $_[0],
			{ 'name' => $_[0], 'value' => '' });
	}
elsif ($in{$_[0]} == 1 && !$d1) {
	# Adding or replacing 'no' value
	&save_directive($_[2], $d0 || $_[1],
			{ 'name' => $_[1], 'value' => '' });
	}
elsif ($in{$_[0]} == 0) {
	&save_directive($_[2], $_[0]);
	&save_directive($_[2], $_[1]);
	}
}

sub has_endscript
{
local $l;
foreach $l (split(/\n/, $_[0])) {
	return 1 if ($l =~ /^\s*(endscript|endrotate)\s*$/);
	}
return 0;
}

