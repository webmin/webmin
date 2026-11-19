#!/usr/local/bin/perl
# Save settings from the Webmin module configuration form.

BEGIN { push(@INC, "."); };
use WebminCore;
require './config-lib.pl';
&init_config();

if ($ENV{'CONTENT_TYPE'} =~ m!^multipart/form-data\b!i) {
	# Decode multipart form fields.
	&ReadParseMime();
	}
else {
	# Accept URL-encoded settings.
	&ReadParse();
	}
&error_setup($text{'config_err'});

# Check module access before opening its config file.
my $m = $in{'module'};
my (undef, $mdir, $file) = &module_config_editor($m);
my $config_file = "$config_directory/$m/config";
mkdir("$config_directory/$m", 0700);

# Read the current settings under lock before applying edits.
&lock_file($config_file);
my (%newconfig, $saved);
&read_file($config_file, \%newconfig);
my %oldconfig = %newconfig;

if (-r "$mdir/config_info.pl" && &foreign_defined($m, 'config_form')) {
	# Track the settings written by the module's own editor.
	$saved = &parse_custom_config(\%newconfig, $file, $m, $in{'section'});
	}
else {
	# Parse the same fields the form displayed.
	my $fields = &read_config_fields($file, $m, 1);
	$saved = &parse_config(\%newconfig, $fields, $m, undef, $in{'section'});
	}

# Save the module-wide configuration.
&write_file($config_file, \%newconfig);
# Update prefs.<user> only for saved settings allowed by prefs.info.
&save_module_preferences($m, \%newconfig, $saved);
&unlock_file($config_file);

if (&foreign_defined($m, 'config_post_save')) {
	# Pass both versions to the module's post-save hook.
	&foreign_call($m, "config_post_save", \%newconfig, \%oldconfig);
	}
if (&foreign_check("webmin")) {
	# A settings change can affect the module's installed status.
	&foreign_require("webmin", "webmin-lib.pl");
	&webmin::build_installed_modules(0, $m);
	}
&webmin_log("_config_", undef, undef, \%in, $m);

if ($in{'skipredirect'}) {
	# Background saves need only an acknowledgment.
	print "Content-type: text/plain\n\nConfig saved successfully\n";
	}
elsif ($in{'save_next'}) {
	# Carry the caller's return parameters to the next section.
	my $return = &link_config_cparams($m, \%in, 1);
	my ($params) = $return =~ /\?(.*)$/;
	&redirect("config.cgi?module=".&urlize($m).
		  "&section=".&urlize($in{'section_next'}).
		  (length($params) ? "&$params" : ""));
	}
else {
	# Use the return location for this module and theme.
	my ($return) = &module_config_return($m, \%in);
	&redirect($return);
	}
