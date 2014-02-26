#!/usr/local/bin/perl
# edit_logs.cgi
# A form for editing logging options

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'logging'} || &error($text{'elogs_ecannot'});
&ui_print_header(undef, $text{'elogs_header'}, "", "edit_logs", 0, 0, 0, &restart_button());
my $conf = &get_config();

print &ui_form_start("save_logs.cgi", "post");
print &ui_table_start($text{'elogs_lalo'}, "width=100%", 4);

if ($squid_version < 2.6) {
	# Just a single logging directive
	print &opt_input($text{'elogs_alf'}, "cache_access_log", $conf,
			 $text{'default'}, 50);
	}
else {
	# Supports definition of log formats and files
	my @logformat = &find_config("logformat", $conf);
	my $ltable = &ui_radio("logformat_def", @logformat ? 0 : 1,
			    [ [ 1, $text{'elogs_logformat1'} ],
			      [ 0, $text{'elogs_logformat0'} ] ])."<br>\n";
	$ltable .= &ui_columns_start([ $text{'elogs_fname'},
				       $text{'elogs_ffmt'} ]);
	my $i = 0;
	foreach my $f (@logformat, { 'values' => [] }) {
		my ($fname, @ffmt) = @{$f->{'values'}};
		$ltable .= &ui_columns_row([
			&ui_textbox("fname_$i", $fname, 20),
			&ui_textbox("ffmt_$i", join(" ", @ffmt), 60)
			]);
		$i++;
		}
	$ltable .= &ui_columns_end();
	print &ui_table_row($text{'elogs_logformat'}, $ltable, 3);

	# Show log files
	my @access = &find_config("access_log", $conf);
	my $atable = &ui_columns_start([ $text{'elogs_afile'},
				         $text{'elogs_afmt'},
				         $text{'elogs_aacls'} ]);
	$i = 0;
	foreach my $a (@access, { 'values' => [] }) {
		my ($afile, $afmt, @aacls) = @{$a->{'values'}};
		$atable .= &ui_columns_row([
		  &ui_radio("afile_def_$i",
			    !$afile ? 1 : $afile eq "none" ? 2 : 0,
			    [ [ 1, $text{'elogs_notset'} ],
			      [ 2, $text{'elogs_dont'} ],
			      [ 0, &text('elogs_file',
				    &ui_textbox("afile_$i",
						$afile eq "none" ? "" : $afile,
						30)) ] ]),
		  &ui_select("afmt_$i", $afmt,
			     [ [ "", "&lt;".$text{'default'}."&gt;" ],
			       [ "squid", "&lt;".$text{'elogs_squid'}."&gt;" ],
			       map { [ $_->{'values'}->[0] ] } @logformat ],
			     1, 0, 1),
		  &ui_textbox("aacls_$i", join(" ", @aacls), 20)
		  ]);
		$i++;
		}
	$atable .= &ui_columns_end();
	print &ui_table_row($text{'elogs_access'}, $atable, 3);
	}

print &opt_input($text{'elogs_dlf'}, "cache_log", $conf, $text{'default'}, 50);

my $cslv = &find_config("cache_store_log", $conf);
my $cslm = $cslv->{'value'} eq 'none' ? 2 : $cslv->{'value'} ? 0 : 1;
print &ui_table_row($text{'elogs_slf'},
	&ui_radio("cache_store_log_def", $cslm,
		  [ [ 1, $text{'default'} ],
		    [ 2, $text{'elogs_none'} ],
		    [ 0, &ui_textbox("cache_store_log",
			    $cslm == 0 ? $cslv->{'value'} : "", 50) ] ]));

print &opt_input($text{'elogs_cmf'}, "cache_swap_log", $conf,
		 $text{'default'}, 50);

print &choice_input($text{'elogs_uhlf'}, "emulate_httpd_log", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");
print &choice_input($text{'elogs_lmh'}, "log_mime_hdrs", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");

print &opt_input($text{'elogs_ualf'}, "useragent_log", $conf,
		 $text{'none'}, 20);
print &opt_input($text{'elogs_pf'}, "pid_filename", $conf,
		 $text{'default'}, 20);

if ($squid_version >= 2.2) {
	my @ident = &find_config("ident_lookup_access", $conf);
	my (%ila, $bad_ident);
	foreach my $i (@ident) {
		my @v = @{$i->{'values'}};
		if ($v[0] eq "allow") {
			%ila = map { $_, 1 } @v[1..$#v];
			}
		elsif ($v[0] eq "deny" && $v[1] ne "all") {
			$bad_ident++;
			}
		}
	if (!$bad_ident) {
		my @acls = &find_config("acl", $conf);
		unshift(@acls, { 'values' => [ 'all' ] })
			if ($squid_version >= 3);
		my (%doneacl, @cbs);
		foreach my $acl (@acls) {
			my $aclv = $acl->{'values'}->[0];
			next if ($doneacl{$aclv}++);
			push(@cbs, &ui_checkbox("ident_lookup_access", $aclv,
						$aclv, $ila{$aclv}));
			}
		print &ui_table_row($text{'elogs_prilfa'},
			join("\n", @cbs), 3);
		}
	else { print "<input type=hidden name=complex_ident value=1>\n"; }
	print "<tr>\n";
	print &opt_time_input($text{'elogs_rit'}, "ident_timeout",
			      $conf, $text{'default'}, 6);
	}
else {
	print &choice_input($text{'elogs_dril'}, "ident_lookup", $conf,
			    "off", $text{'yes'}, "on", $text{'no'}, "off");
	}
print &choice_input($text{'elogs_lfh'}, "log_fqdn", $conf,
		    "off", $text{'yes'}, "on", $text{'no'}, "off");

print &opt_input($text{'elogs_ln'}, "client_netmask", $conf,
		 $text{'default'}, 15);
print &opt_input($text{'elogs_do'}, "debug_options", $conf,
		 $text{'default'}, 15);

if ($squid_version >= 2) {
	print &opt_input($text{'elogs_mht'}, "mime_table",
			 $conf, $text{'default'}, 20);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'elogs_return'});

