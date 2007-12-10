package Webmin::API;

require 5.005_62;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT = (
	'$config_directory',
	'$var_directory',
	'$remote_error_handler',
	'%month_to_number_map',
	'%number_to_month_map',
	'$config_file',
	'%gconfig',
	'$null_file',
	'$path_separator',
	'$root_directory',
	'$module_name',
	'@root_directories',
	'$base_remote_user',
	'$remote_user',
	'$module_config_directory',
	'$module_config_file',
	'%config',
	'$current_theme',
	'$theme_root_directory',
	'%tconfig',
	'$tb',
	'$cb',
	'$scriptname',
	'$webmin_logfile',
	'$current_lang',
	'$current_lang_info',
	'@lang_order_list',
	'%text',
	'%module_info',
	'$module_root_directory',
	'$default_lang',
	);

our $VERSION = '1.0';

# Find old symbols by Webmin import
my %oldsyms = %Webmin::API::;

# Preloaded methods go here.
$main::no_acl_check++;
$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
open(MINISERV, $ENV{'WEBMIN_CONFIG'}."/miniserv.conf") ||
	die "Could not open Webmin config file ".
	    $ENV{'WEBMIN_CONFIG'}."/miniserv.conf : $!";
my $webmin_root;
while(<MINISERV>) {
	s/\r|\n//g;
	if (/^root=(.*)/) {
		$webmin_root = $1;
		}
	}
close(MINISERV);
$webmin_root || die "Could not find Webmin root directory";
chdir($webmin_root);
if ($0 =~ /\/([^\/]+)$/) {
	$0 = $webmin_root."/".$1;
	}
else {
	$0 = $webmin_root."/api.pl";	# Fake name
	}
require './web-lib.pl';
&init_config();

# Export core symbols
foreach my $lib ("$webmin_root/web-lib.pl",
		 "$webmin_root/web-lib-funcs.pl") {
	open(WEBLIB, $lib);
	while(<WEBLIB>) {
		if (/^sub\s+([a-z0-9\_]+)/i) {
			push(@EXPORT, $1);
			}
		}
	close(WEBLIB);
	}
our @EXPORT_OK = ( @EXPORT );

1;
__END__

=head1 NAME

Webmin::API - Perl module to make calling of Webmin functions from regular
              command-line Perl scripts easier.

=head1 SYNOPSIS

  use Webmin::API;
  @pids = &find_byname("httpd");
  foreign_require("cron", "cron-lib.pl");
  @jobs = &cron::list_cron_jobs();

=head1 DESCRIPTION

This module just provides a convenient way to call Webmin API functions
from a script that is not run as a Webmin CGI, without having to include a 
bunch of boilerplate initialization code at the top. It's main job is to export
all API functions into the namespace of the caller, and to setup the Webmin
environment.

=head2 EXPORT

All core Webmin API functions, like find_byname, foreign_config and so on.

=head1 AUTHOR

Jamie Cameron, jcameron@webmin.com

=head1 SEE ALSO

perl(1).

=cut

