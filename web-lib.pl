=head1 web-lib.pl

This file must be included by all Webmin CGI scripts, either directly or via
another module-specific .pl file. For example :

 do '../web-lib.pl';
 init_config();
 do '../ui-lib.pl';
 ui_print_header(undef, 'My Module', '');

This file in turn includes web-lib-funcs.pl, which is where the majority of
the Webmin API functions are defined.

=cut

# Configuration and spool directories
if (!defined($ENV{'WEBMIN_CONFIG'})) {
	die "WEBMIN_CONFIG not set";
	}
$config_directory = $ENV{'WEBMIN_CONFIG'};
if (!defined($ENV{'WEBMIN_VAR'})) {
	open(VARPATH, "$config_directory/var-path");
	chop($var_directory = <VARPATH>);
	close(VARPATH);
	}
else {
	$var_directory = $ENV{'WEBMIN_VAR'};
	}

if ($ENV{'SESSION_ID'}) {
	# Hide this variable from called programs, but keep it for internal use
	$main::session_id = $ENV{'SESSION_ID'};
	delete($ENV{'SESSION_ID'});
	}
if ($ENV{'REMOTE_PASS'}) {
	# Hide the password too
	$main::remote_pass = $ENV{'REMOTE_PASS'};
	delete($ENV{'REMOTE_PASS'});
	}

if ($> == 0 && $< != 0 && !$ENV{'FOREIGN_MODULE_NAME'}) {
	# Looks like we are running setuid, but the real UID hasn't been set.
	# Do so now, so that executed programs don't get confused
	$( = $);
	$< = $>;
	}

# On Windows, always do IO in binary mode
#binmode(STDIN);
#binmode(STDOUT);

$remote_error_handler = "error";
@INC = &unique(@INC, ".");
%month_to_number_map = ( 'jan' => 0, 'feb' => 1, 'mar' => 2, 'apr' => 3,
                	 'may' => 4, 'jun' => 5, 'jul' => 6, 'aug' => 7,
                	 'sep' => 8, 'oct' => 9, 'nov' =>10, 'dec' =>11 );
%number_to_month_map = reverse(%month_to_number_map);
$main::initial_process_id ||= $$;
$main::http_cache_directory = $ENV{'WEBMIN_VAR'}."/cache";
$main::default_debug_log_size = 10*1024*1024;
$main::default_debug_log_file = $ENV{'WEBMIN_VAR'}."/webmin.debug";

$webmin_feedback_address = "feedback\@webmin.com";
$default_charset = "iso-8859-1";

=head2 unique(string, ...)

Returns the unique elements of some array, passed as its parameters.

=cut
sub unique
{
local(%found, @rv, $e);
foreach $e (@_) {
	if (!$found{$e}++) { push(@rv, $e); }
	}
return @rv;
}

if (!$done_web_lib_funcs) {
	local $script = -r '../web-lib-funcs.pl' ? '../web-lib-funcs.pl'
						 : 'web-lib-funcs.pl';
	do $script;
	}

1;

