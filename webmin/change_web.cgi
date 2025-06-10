#!/usr/local/bin/perl
# Save webserver options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'web_err'});
&get_miniserv_config(\%miniserv);

# Save expires
if ($in{'expires_def'}) {
	delete($miniserv{'expires'});
	}
else {
	$in{'expires'} =~ /^\d+$/ ||
		&error($text{'web_eexpires'});
	$miniserv{'expires'} = $in{'expires'};
	}

# Save per-path expires
for(my $i=0; defined($p = $in{"expirespath_$i"}); $i++) {
	$t = $in{"expirestime_$i"};
	next if ($p !~ /\S/);
	$t =~ /^\d+$/ || &error(&text('web_eexpires2', $i+1));
	push(@expires_paths, [ $p, $t ]);
	}
$miniserv{'expires_paths'} = join("\t", map { $_->[0]."=".$_->[1] }
					    @expires_paths);
# Save redirects
delete($miniserv{'redirect_host'});
delete($miniserv{'redirect_port'});
delete($miniserv{'redirect_prefix'});
delete($miniserv{'redirect_ssl'});
my $redir_host = $in{'redirect_host'};
$redir_host =~ /^[A-z0-9\-\.\:]+$/ ||
		$redir_host =~ /^\s*$/ ||
		&error(&text('web_eredirhost', &html_escape($redir_host)));
$miniserv{'redirect_host'} = $redir_host
	if ($redir_host);
my $redir_port = &trim($in{'redirect_port'});
($redir_port =~ /^\d+$/ && $redir_port < 65536) ||
			$redir_port =~ /^\s*$/ ||
			&error(&text('bind_eport2', &html_escape($redir_port)));
$miniserv{'redirect_port'} = $redir_port
	if ($redir_port);
my $redir_pref = &trim($in{'redirect_prefix'});
$redir_pref =~ /^\// || $redir_pref =~ /^\s*$/ ||
	&error($text{'web_eredirpref'});
$redir_pref !~ /\s/ || &error($text{'web_eredirpref2'});
$miniserv{'redirect_prefix'} = $redir_pref
	if ($redir_pref);
my $redir_ssl = $in{'redirect_ssl'};
$miniserv{'redirect_ssl'} = 1 if ($redir_ssl == 1);

# Save stack trace option
$gconfig{'error_stack'} = $in{'stack'};

# Save showing of stderr
$miniserv{'noshowstderr'} = !$in{'showstderr'};

if (!$miniserv{'session'}) {
	# Save password pass option
	$miniserv{'pass_password'} = $in{'pass'};
	}

# Save gzip option
if ($in{'gzip'} == 1) {
	eval "use Compress::Zlib";
	$@ && &error(&text('advanced_egzip', '<tt>Compress::Zlib</tt>'));
	}
$miniserv{'gzip'} = $in{'gzip'};

# Save redirect type
$gconfig{'relative_redir'} = $in{'redir'};

# Save directory list option
$miniserv{'nolistdir'} = !$in{'listdir'};

# Save global config
&lock_file("$config_directory/config");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

# Save miniserv config
&lock_file($ENV{'MINISERV_CONFIG'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("web");

