#!/usr/local/bin/perl
# edit_authparam.cgi
# A form for editing authentication programs

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config, $auth_program);
require './squid-lib.pl';
$access{'authparam'} || &error($text{'authparam_ecannot'});
&ui_print_header(undef, $text{'authparam_title'}, "", "edit_authparam", 0, 0, 0,
	&restart_button());
my $conf = &get_config();

print &ui_form_start("save_authparam.cgi", "post");
print &ui_table_start($text{'authparam_header'}, "width=100%", 2);

if ($squid_version >= 2.5) {
	# Squid versions 2.5 and above use different config options for
	# the external authentication program
	my @auth = &find_config("auth_param", $conf);

	# Show basic authentication options
	my %basic = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'basic' } @auth;
	my @p = @{$basic{'program'} || []};
	my $m = !@p ? 0 : $p[2] =~ /^(\S+)/ && $1 eq $auth_program ? 2 : 1;
	print &ui_table_row($text{'authparam_bprogram'},
		&ui_radio("b_auth_mode", $m,
			  [ [ 0, $text{'none'} ],
			    [ 2, $text{'eprogs_capweb'} ],
			    [ 1, &ui_filebox("b_auth",
				$m == 1 ? join(" ", @p[2..$#p]) : "", 40) ] ]));

	my $c = $basic{'children'}->[2];
	print &ui_table_row($text{'eprogs_noap'},
		&ui_opt_textbox("b_children", $c, 5, $text{'default'}));

	my @t = @{$basic{'credentialsttl'} || []};
	print &ui_table_row($text{'eprogs_ttl'},
		&ui_radio("b_ttl_def", @t ? 0 : 1,
			  [ [ 1, $text{'default'} ],
			    [ 0, &time_fields("b_ttl", 6, $t[2], $t[3]) ] ]));

	my @r = @{$basic{'realm'} || []};
	my $r = join(" ", @r[2..$#r]);
	print &ui_table_row($text{'eprogs_realm'},
		&ui_opt_textbox("b_realm", $r, 40, $text{'default'}));

	# Show digest authentication options
	print &ui_table_hr();
	my %digest = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'digest' } @auth;
	@p = @{$digest{'program'} || []};
	$m = @p ? 1 : 0;
	print &ui_table_row($text{'authparam_dprogram'},
		&ui_radio("d_auth_mode", $m,
			  [ [ 0, $text{'none'} ],
			    [ 1, &ui_filebox("d_auth",
				$m == 1 ? join(" ", @p[2..$#p]) : "", 40) ] ]));

	$c = $digest{'children'}->[2];
	print &ui_table_row($text{'eprogs_noap'},
		&ui_opt_textbox("d_children", $c, 5, $text{'default'}));

	@r = @{$digest{'realm'} || []};
	$r = join(" ", @r[2..$#r]);
	print &ui_table_row($text{'eprogs_realm'},
		&ui_opt_textbox("d_realm", $r, 40, $text{'default'}));

	print &ui_table_hr();

	# Show NTML authentication options
	my %ntlm = map { $_->{'values'}->[1], $_->{'values'} }
			grep { $_->{'values'}->[0] eq 'ntlm' } @auth;
	@p = @{$ntlm{'program'} || []};
	$m = @p ? 1 : 0;
	print &ui_table_row($text{'authparam_nprogram'},
		&ui_radio("n_auth_mode", $m,
			  [ [ 0, $text{'none'} ],
			    [ 1, &ui_filebox("n_auth",
				$m == 1 ? join(" ", @p[2..$#p]) : "", 40) ] ]));

	$c = $ntlm{'children'}->[2];
	print &ui_table_row($text{'eprogs_noap'},
		&ui_opt_textbox("n_children", $c, 5, $text{'default'}));

	$r = $ntlm{'max_challenge_reuses'}->[2];
	print &ui_table_row($text{'authparam_reuses'},
		&ui_opt_textbox("n_reuses", $r, 5, $text{'default'}));

	@t = @{$ntlm{'max_challenge_lifetime'} || []};
	print &ui_table_row($text{'authparam_lifetime'},
		&ui_radio("n_ttl_def", @t ? 0 : 1,
			  [ [ 1, $text{'default'} ],
			    [ 0, &time_fields("n_ttl", 6, $t[2], $t[3]) ] ]));
	}
elsif ($squid_version >= 2) {
	# Squid versions 2 and above use a single external
	# authentication program
	my $v = &find_config("authenticate_program", $conf);
	my $m = !$v ? 0 :
		$v->{'value'} =~ /^(\S+)/ && $1 eq $auth_program ? 2 : 1;
	print &ui_table_row($text{'eprogs_cap'},
		&ui_radio("auth_mode", $m,
			[ [ 0, $text{'none'} ],
			  [ 2, $text{'eprogs_capweb'} ],
			  [ 1, &ui_filebox("auth",
				$m == 1 ? $v->{'value'} : "", 40) ] ]));

        print &opt_input($text{'eadm_par'}, "proxy_auth_realm",
                         $conf, $text{'eadm_default'}, 40); 

	print &opt_input($text{'eprogs_noap'},
			 "authenticate_children", $conf, $text{'default'}, 6);

	if ($squid_version >= 2.4) {
		print &opt_time_input($text{'authparam_ttl'},
		    "authenticate_ttl", $conf, $text{'default'}, 6);
		print &opt_time_input($text{'authparam_ipttl'},
		    "authenticate_ip_ttl", $conf, $text{'authparam_never'}, 6);
		}
	}

print &ui_table_hr();

my $taa = &find_value("authenticate_ip_ttl", $conf);
my @ta = split(/\s+/,$taa);
print &ui_table_row($text{'eprogs_aittl'},
	&ui_radio("b_aittl_def", @ta ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, &time_fields("b_aittl", 6, $ta[0], $ta[1]) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ] ]);

&ui_print_footer("", $text{'eprogs_return'});

