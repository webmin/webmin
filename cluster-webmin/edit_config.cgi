#!/usr/local/bin/perl
# Display a form for editing this module's configuration on multiple hosts

require './cluster-webmin-lib.pl';
require '../config-lib.pl';
&ReadParse();

# Work out which hosts were selected
@hosts = &list_webmin_hosts();
@servers = &list_servers();
foreach $h (@hosts) {
	local ($got) = grep { $_->{'dir'} eq $in{'mod'} } @{$h->{'modules'}};
	if ($got) {
		push(@gothosts, $h);
		$gothosts{$h->{'id'}} = 1;
		}
	}
@hosts = &create_on_parse(undef, \@gothosts, $in{'mod'}, 1);
@hosts = grep { $gothosts{$_->{'id'}} } @hosts;
@hosts || &error($text{'config_enone'});
%minfo = &get_module_info($in{'mod'});
%minfo || &error($text{'config_ethis'});

# Get the config on the first host, or the local host
($getfrom) = grep { $_->{'id'} == 0 } @hosts;
$getfrom ||= $hosts[0];
($serv) = grep { $_->{'id'} == $getfrom->{'id'} } @servers;
&remote_foreign_require($serv->{'host'}, "webmin", "webmin-lib.pl");
%fconfig = &remote_foreign_call($serv->{'host'}, "webmin", "foreign_config",
				$in{'mod'});

# Show the config editor
%descmap = map { $_->{'id'}, $_->{'desc'} || $_->{'host'} } @servers;
$ondesc = $in{'server'} == -1 ? $text{'config_all'} :
	  $in{'server'} == -3 ? $text{'config_have'} :
	  $in{'server'} =~ /^group_(.*)/ ? &text('config_group', "$1") :
				   &text('config_on', $descmap{$in{'server'}});
&ui_print_header($ondesc, $text{'config_title'}, "");

print &ui_form_start("save_config.cgi", "post");
print &ui_hidden("mod", $in{'mod'});
foreach $h (@hosts) {
	print &ui_hidden("_host", $h->{'id'});
	}
print &ui_hidden("_getfrom", $getfrom->{'id'});
print &ui_table_start(&text('config_header', $minfo{'desc'}), "100%", 2);

$mdir = &module_root_directory($in{'mod'});
if (-r "$mdir/config_info.pl") {
	# Module has a custom config editor
	&foreign_require($in{'mod'}, "config_info.pl");
	if (&foreign_defined($in{'mod'}, "config_form")) {
		$func++;
		&foreign_call($in{'mod'}, "config_form", \%fconfig);
		}
	}
if (!$func) {
	# Use config.info to create config inputs
	&generate_config(\%fconfig, "$mdir/config.info", $in{'mod'});
	}
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

